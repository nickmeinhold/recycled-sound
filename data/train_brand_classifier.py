#!/usr/bin/env python3
"""
Train a hearing aid brand classifier using EfficientNet-B0 transfer learning.

Uses the 2,267 product images from unaudinary.com, labelled by brand via
visual_embeddings.json. Fine-tunes with aggressive augmentation to bridge
the domain gap between product shots and real-world hand-held photos.

Exports:
  - brand_classifier.tflite  (quantized, ~13MB, for on-device inference)
  - brand_classifier_labels.json (class names + training metadata)

Usage:
  python3 train_brand_classifier.py              # train + export
  python3 train_brand_classifier.py --epochs 30  # more epochs
  python3 train_brand_classifier.py --test-only  # evaluate existing model

Requires: tensorflow, Pillow
"""

import argparse
import json
import os
import shutil
import sys
from collections import Counter
from pathlib import Path

import numpy as np

# Suppress TF warnings
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
import tensorflow as tf


DATA_DIR = Path(__file__).parent
IMAGE_DIR = DATA_DIR / "images"
PROCESSED_DIR = DATA_DIR / "processed"
ORGANISED_DIR = DATA_DIR / "images_by_brand"
MODEL_DIR = DATA_DIR / "models"

# Training params
IMG_SIZE = 224  # EfficientNet-B0 native input
BATCH_SIZE = 32
DEFAULT_EPOCHS = 20
MIN_IMAGES_PER_BRAND = 30  # Skip brands with too few images

# Brands to merge (sub-brands → parent)
BRAND_ALIASES = {
    "Specsavers Advance": None,  # Drop — white-label, not identifiable
    "Hearing Australia": None,   # Drop — white-label
    "Hansaton": "Signia",        # Same parent (WS Audiology)
    "Rexton": "Signia",         # Same parent (WS Audiology)
    "Amplifon": None,           # Drop — white-label
    "Jabra": "ReSound",         # Same parent (GN Group)
}


def organise_images():
    """Symlink images into brand subfolders for tf.keras dataset loading."""
    print("Organising images by brand...")

    with open(PROCESSED_DIR / "visual_embeddings.json") as f:
        entries = json.load(f)

    # Build image → brand mapping (use first device's manufacturer)
    image_brands = {}
    for entry in entries:
        path = entry.get("local_path", "")
        devices = entry.get("devices", [])
        if not devices or not path:
            continue

        brand = devices[0].get("manufacturer", "")
        if not brand:
            continue

        # Apply aliases
        if brand in BRAND_ALIASES:
            brand = BRAND_ALIASES[brand]
            if brand is None:
                continue  # Drop this brand

        image_brands[path] = brand

    # Count brands
    brand_counts = Counter(image_brands.values())
    print(f"\nBrand distribution (before filtering):")
    for brand, count in brand_counts.most_common():
        marker = " ✓" if count >= MIN_IMAGES_PER_BRAND else " ✗ (too few)"
        print(f"  {brand}: {count}{marker}")

    # Filter brands with too few images
    valid_brands = {b for b, c in brand_counts.items() if c >= MIN_IMAGES_PER_BRAND}
    print(f"\nKeeping {len(valid_brands)} brands with ≥{MIN_IMAGES_PER_BRAND} images")

    # Create symlinks
    if ORGANISED_DIR.exists():
        shutil.rmtree(ORGANISED_DIR)

    created = 0
    skipped = 0
    for rel_path, brand in image_brands.items():
        if brand not in valid_brands:
            continue

        src = IMAGE_DIR / rel_path
        if not src.exists():
            skipped += 1
            continue

        dest_dir = ORGANISED_DIR / brand
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / src.name

        if not dest.exists():
            os.symlink(src.resolve(), dest)
            created += 1

    print(f"\nCreated {created} symlinks, skipped {skipped} missing images")
    return valid_brands


def create_datasets(valid_brands):
    """Create train/val datasets with augmentation."""
    print("\nLoading datasets...")

    # Training dataset with augmentation
    train_ds = tf.keras.utils.image_dataset_from_directory(
        str(ORGANISED_DIR),
        validation_split=0.2,
        subset="training",
        seed=42,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="categorical",
    )

    val_ds = tf.keras.utils.image_dataset_from_directory(
        str(ORGANISED_DIR),
        validation_split=0.2,
        subset="validation",
        seed=42,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="categorical",
    )

    class_names = train_ds.class_names
    num_classes = len(class_names)
    print(f"\nClasses ({num_classes}): {class_names}")
    print(f"Train batches: {tf.data.experimental.cardinality(train_ds).numpy()}")
    print(f"Val batches: {tf.data.experimental.cardinality(val_ds).numpy()}")

    # Aggressive augmentation to bridge product-shot → real-world domain gap
    augmentation = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.15),        # ±54°
        tf.keras.layers.RandomZoom((-0.2, 0.2)),     # 80-120% zoom
        tf.keras.layers.RandomBrightness(0.2),       # ±20% brightness
        tf.keras.layers.RandomContrast(0.2),         # ±20% contrast
        tf.keras.layers.RandomTranslation(0.1, 0.1), # ±10% shift
    ], name="augmentation")

    # Apply augmentation only to training
    train_ds = train_ds.map(
        lambda x, y: (augmentation(x, training=True), y),
        num_parallel_calls=tf.data.AUTOTUNE,
    )

    # Prefetch for performance
    train_ds = train_ds.prefetch(tf.data.AUTOTUNE)
    val_ds = val_ds.prefetch(tf.data.AUTOTUNE)

    return train_ds, val_ds, class_names, num_classes


def build_model(num_classes):
    """Build EfficientNet-B0 with frozen backbone + trainable head."""
    print("\nBuilding model...")

    # EfficientNet-B0: 5.3M params, good accuracy/speed tradeoff for mobile
    base_model = tf.keras.applications.EfficientNetB0(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base_model.trainable = False  # Freeze backbone initially

    model = tf.keras.Sequential([
        # EfficientNet includes its own preprocessing (scaling to [0, 255])
        base_model,
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(num_classes, activation="softmax"),
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )

    total_params = model.count_params()
    trainable_params = sum(
        tf.keras.backend.count_params(w) for w in model.trainable_weights
    )
    print(f"Total params: {total_params:,}")
    print(f"Trainable params: {trainable_params:,} (head only)")

    return model, base_model


def fine_tune_backbone(model, base_model, train_ds, val_ds, epochs=10):
    """Unfreeze top layers of backbone for fine-tuning."""
    print("\n── Fine-tuning backbone (top 30 layers) ──")

    base_model.trainable = True
    # Freeze everything except the top 30 layers
    for layer in base_model.layers[:-30]:
        layer.trainable = False

    trainable_params = sum(
        tf.keras.backend.count_params(w) for w in model.trainable_weights
    )
    print(f"Trainable params after unfreeze: {trainable_params:,}")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),  # Lower LR
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(
                monitor="val_accuracy",
                patience=5,
                restore_best_weights=True,
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                monitor="val_loss",
                factor=0.5,
                patience=3,
            ),
        ],
    )
    return history


def export_tflite(model, class_names):
    """Export to quantized TFLite for on-device inference."""
    MODEL_DIR.mkdir(exist_ok=True)

    # Full precision first (for accuracy comparison)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_fp32 = converter.convert()
    fp32_path = MODEL_DIR / "brand_classifier_fp32.tflite"
    fp32_path.write_bytes(tflite_fp32)
    print(f"\nFP32 model: {fp32_path} ({len(tflite_fp32) / 1e6:.1f} MB)")

    # Dynamic range quantization (best size/accuracy tradeoff)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_quant = converter.convert()
    quant_path = MODEL_DIR / "brand_classifier.tflite"
    quant_path.write_bytes(tflite_quant)
    print(f"Quantized model: {quant_path} ({len(tflite_quant) / 1e6:.1f} MB)")

    # Save labels + metadata
    labels = {
        "classes": class_names,
        "num_classes": len(class_names),
        "input_size": IMG_SIZE,
        "quantized": True,
        "brand_aliases": BRAND_ALIASES,
    }
    labels_path = MODEL_DIR / "brand_classifier_labels.json"
    with open(labels_path, "w") as f:
        json.dump(labels, f, indent=2)
    print(f"Labels: {labels_path}")

    return quant_path


def evaluate_tflite(tflite_path, val_ds, class_names):
    """Run TFLite model on validation set to verify accuracy."""
    print(f"\nEvaluating TFLite model: {tflite_path}")

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    correct = 0
    total = 0

    for images, labels in val_ds:
        for i in range(images.shape[0]):
            img = tf.expand_dims(images[i], 0)
            # Ensure float32 input
            if input_details[0]["dtype"] == np.float32:
                img = tf.cast(img, tf.float32)

            interpreter.set_tensor(input_details[0]["index"], img.numpy())
            interpreter.invoke()
            output = interpreter.get_tensor(output_details[0]["index"])

            pred = np.argmax(output[0])
            true = np.argmax(labels[i].numpy())
            if pred == true:
                correct += 1
            total += 1

    accuracy = correct / total if total > 0 else 0
    print(f"TFLite accuracy: {accuracy:.1%} ({correct}/{total})")
    return accuracy


def main():
    parser = argparse.ArgumentParser(description="Train hearing aid brand classifier")
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS,
                        help=f"Head training epochs (default: {DEFAULT_EPOCHS})")
    parser.add_argument("--fine-tune-epochs", type=int, default=10,
                        help="Backbone fine-tuning epochs (default: 10)")
    parser.add_argument("--test-only", action="store_true",
                        help="Evaluate existing model without training")
    parser.add_argument("--no-fine-tune", action="store_true",
                        help="Skip backbone fine-tuning")
    args = parser.parse_args()

    # Check for MPS (Apple Silicon) or GPU
    gpus = tf.config.list_physical_devices("GPU")
    if gpus:
        print(f"GPU available: {gpus}")
    elif hasattr(tf, "config") and tf.config.list_physical_devices("GPU"):
        print("MPS (Apple Silicon) available")
    else:
        print("No GPU detected — training on CPU (slower)")

    # Step 1: Organise images
    valid_brands = organise_images()

    if not ORGANISED_DIR.exists() or not any(ORGANISED_DIR.iterdir()):
        print("\nERROR: No images found. Run download_images.py first.")
        sys.exit(1)

    # Step 2: Create datasets
    train_ds, val_ds, class_names, num_classes = create_datasets(valid_brands)

    if args.test_only:
        tflite_path = MODEL_DIR / "brand_classifier.tflite"
        if not tflite_path.exists():
            print(f"ERROR: {tflite_path} not found")
            sys.exit(1)
        evaluate_tflite(tflite_path, val_ds, class_names)
        return

    # Step 3: Train head
    print(f"\n── Training head ({args.epochs} epochs) ──")
    model, base_model = build_model(num_classes)
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(
                monitor="val_accuracy",
                patience=5,
                restore_best_weights=True,
            ),
        ],
    )

    head_acc = max(history.history["val_accuracy"])
    print(f"\nBest head-only val accuracy: {head_acc:.1%}")

    # Step 4: Fine-tune backbone
    if not args.no_fine_tune:
        ft_history = fine_tune_backbone(
            model, base_model, train_ds, val_ds, epochs=args.fine_tune_epochs,
        )
        ft_acc = max(ft_history.history["val_accuracy"])
        print(f"\nBest fine-tuned val accuracy: {ft_acc:.1%}")

    # Step 5: Export
    tflite_path = export_tflite(model, class_names)

    # Step 6: Verify TFLite accuracy
    evaluate_tflite(tflite_path, val_ds, class_names)

    print("\n✅ Done! Model ready for on-device deployment.")
    print(f"   Copy {tflite_path} to recycled_sound/assets/")


if __name__ == "__main__":
    main()
