#!/usr/bin/env python3
"""
🔬 Recycled Sound — Linear Probe on Frozen CLIP Embeddings

Diagnostic experiment: do CLIP's frozen ViT-B/32 features contain enough signal
to classify hearing aids by brand, style, or battery size?

Three probes on pre-computed 512-dim embeddings from device_catalog.json:
  1. Brand classification (16 manufacturers)
  2. Style classification (BTE/RIC/ITE/CIC/ITC/IIC)
  3. Battery size classification (10/13/312/675/Rechargeable)

Each probe: LogisticRegression on frozen features, 80/20 stratified split,
accuracy + confusion matrix + per-class precision/recall.

Usage:
    python3 data/linear_probe.py                    # full report
    python3 data/linear_probe.py --json             # machine-readable
    python3 data/linear_probe.py --real /path/to/   # test real-world photos

Requires: scikit-learn, numpy. Optional: open_clip, torch, PIL (for --real).
"""

import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np

DATA_DIR = Path(__file__).parent
CATALOG_PATH = DATA_DIR.parent / "recycled_sound" / "assets" / "device_catalog.json"
EMBEDDINGS_PATH = DATA_DIR / "processed" / "visual_embeddings.json"


def load_data():
    """Load embeddings and labels from the visual embeddings + device catalog.

    Returns (embeddings, labels_dict) where labels_dict maps:
        'brand' -> list[str]     manufacturer name per embedding
        'style' -> list[str]     device type (BTE/RIC/ITE/CIC/ITC/IIC)
        'battery' -> list[str]   battery size (10/13/312/675/Rechargeable)

    Embeddings with ambiguous labels (multiple manufacturers) are kept and
    labeled by majority vote. This is intentional — OEM rebrands (e.g.
    Amplifon ≡ ReSound hardware) are real-world ambiguity the probe should
    surface, not hide.
    """
    print("Loading visual embeddings...", end=" ", flush=True)
    with open(EMBEDDINGS_PATH) as f:
        vis_data = json.load(f)
    print(f"{len(vis_data)} entries")

    print("Loading device catalog...", end=" ", flush=True)
    with open(CATALOG_PATH) as f:
        catalog = json.load(f)
    devices = catalog["devices"]
    embedding_index = catalog["embeddingIndex"]
    print(f"{len(devices)} devices, {len(embedding_index)} embedding mappings")

    embeddings = []
    brands = []
    styles = []
    batteries = []

    for i, entry in enumerate(vis_data):
        emb = entry["embedding"]
        if len(emb) != 512:
            continue

        # Get brand from visual_embeddings (majority vote if mixed)
        mfr_counts = Counter(d["manufacturer"] for d in entry["devices"])
        brand = mfr_counts.most_common(1)[0][0]

        # Get style and battery from device_catalog via embeddingIndex
        style = None
        battery = None
        if i < len(embedding_index):
            device_ids = embedding_index[i]["deviceIds"]
            # Take first device that has type/battery info
            for did in device_ids:
                if did in devices:
                    dev = devices[did]
                    if not style and dev.get("type"):
                        # Normalize: "BTE (Behind-the-Ear)" -> "BTE"
                        style = dev["type"].split(" ")[0]
                    if not battery and dev.get("batterySize"):
                        bs = dev["batterySize"]
                        # Normalize: "Size 312" -> "312"
                        battery = bs.replace("Size ", "")
                    if style and battery:
                        break

        embeddings.append(emb)
        brands.append(brand)
        styles.append(style or "unknown")
        batteries.append(battery or "unknown")

    return (
        np.array(embeddings, dtype=np.float32),
        {"brand": brands, "style": styles, "battery": batteries},
    )


def run_probe(X, y, task_name, min_samples=5):
    """Train and evaluate a linear probe.

    Args:
        X: (N, 512) embedding matrix
        y: list of string labels
        task_name: name for reporting
        min_samples: minimum samples per class to include

    Returns dict with accuracy, per-class metrics, confusion matrix.
    """
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import (
        accuracy_score,
        classification_report,
        confusion_matrix,
    )
    from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
    from sklearn.preprocessing import LabelEncoder

    # Filter out unknowns and rare classes
    label_counts = Counter(y)
    valid_labels = {l for l, c in label_counts.items() if l != "unknown" and c >= min_samples}
    mask = [l in valid_labels for l in y]
    X_filtered = X[mask]
    y_filtered = [l for l, m in zip(y, mask) if m]

    n_classes = len(valid_labels)
    n_samples = len(y_filtered)
    print(f"\n{'='*60}")
    print(f"PROBE: {task_name}")
    print(f"{'='*60}")
    print(f"Samples: {n_samples} (dropped {len(y) - n_samples} unknown/rare)")
    print(f"Classes: {n_classes}")

    # Show class distribution
    dist = Counter(y_filtered)
    print(f"\nClass distribution:")
    for label, count in sorted(dist.items(), key=lambda x: -x[1]):
        bar = "█" * (count * 40 // max(dist.values()))
        print(f"  {label:25s} {count:4d}  {bar}")

    # Encode labels
    le = LabelEncoder()
    y_enc = le.fit_transform(y_filtered)

    # 80/20 stratified split
    X_train, X_test, y_train, y_test = train_test_split(
        X_filtered, y_enc, test_size=0.2, random_state=42, stratify=y_enc
    )

    # L2-normalize embeddings (CLIP outputs are already roughly normalized,
    # but let's be explicit — this makes the linear probe equivalent to
    # cosine-similarity-based classification)
    from sklearn.preprocessing import normalize
    X_train = normalize(X_train)
    X_test = normalize(X_test)

    # Train logistic regression
    # max_iter=2000 because some convergence is slow with 16 classes
    clf = LogisticRegression(
        max_iter=2000,
        C=1.0,
        solver="lbfgs",
        random_state=42,
    )
    clf.fit(X_train, y_train)

    # Evaluate
    y_pred = clf.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)

    print(f"\n>>> ACCURACY: {accuracy:.1%} <<<")

    # Per-class report
    report = classification_report(
        y_test, y_pred, target_names=le.classes_, output_dict=True, zero_division=0
    )
    print(f"\nPer-class precision / recall / F1:")
    print(f"  {'Class':25s} {'Prec':>6s} {'Recall':>6s} {'F1':>6s} {'N':>5s}")
    print(f"  {'-'*50}")
    for cls in le.classes_:
        r = report[cls]
        print(f"  {cls:25s} {r['precision']:6.1%} {r['recall']:6.1%} {r['f1-score']:6.1%} {r['support']:5.0f}")

    # Confusion matrix
    cm = confusion_matrix(y_test, y_pred)
    print(f"\nConfusion matrix (rows=true, cols=predicted):")
    # Header
    header = "  " + " " * 14 + "".join(f"{c[:6]:>7s}" for c in le.classes_)
    print(header)
    for i, cls in enumerate(le.classes_):
        row = f"  {cls[:13]:13s} " + "".join(
            f"{cm[i, j]:7d}" if cm[i, j] > 0 else "      ." for j in range(len(le.classes_))
        )
        print(row)

    # Cross-validation for robustness check
    X_all = normalize(X_filtered)
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_scores = cross_val_score(clf, X_all, y_enc, cv=cv, scoring="accuracy")
    print(f"\n5-fold CV: {cv_scores.mean():.1%} ± {cv_scores.std():.1%}")

    # Find most-confused pairs
    print(f"\nMost confused pairs:")
    confused = []
    for i in range(len(le.classes_)):
        for j in range(len(le.classes_)):
            if i != j and cm[i, j] > 0:
                confused.append((cm[i, j], le.classes_[i], le.classes_[j]))
    confused.sort(reverse=True)
    for count, true, pred in confused[:10]:
        print(f"  {true} → {pred}: {count} times")

    return {
        "task": task_name,
        "accuracy": accuracy,
        "n_samples": n_samples,
        "n_classes": n_classes,
        "cv_mean": cv_scores.mean(),
        "cv_std": cv_scores.std(),
        "report": report,
        "confusion_matrix": cm.tolist(),
        "class_names": le.classes_.tolist(),
        "confused_pairs": [(c, t, p) for c, t, p in confused[:10]],
    }


def probe_real_photos(real_dir, catalog_devices, results):
    """Encode real-world photos with CLIP and classify using trained probes.

    This measures the domain gap: product shot accuracy vs real-world accuracy.
    """
    try:
        import open_clip
        import torch
        from PIL import Image
    except ImportError:
        print("\n⚠️  Skipping real-photo test (requires open_clip, torch, PIL)")
        return

    real_path = Path(real_dir)
    photos = list(real_path.glob("*.jpg")) + list(real_path.glob("*.png")) + list(real_path.glob("*.heic"))
    if not photos:
        print(f"\n⚠️  No photos found in {real_dir}")
        return

    print(f"\n{'='*60}")
    print(f"REAL-WORLD DOMAIN GAP TEST")
    print(f"{'='*60}")
    print(f"Photos: {len(photos)} from {real_dir}")

    # Load CLIP model (same as cloud function: ViT-B-32, laion2b_s34b_b79k)
    print("Loading CLIP ViT-B/32...", end=" ", flush=True)
    model, _, preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k"
    )
    model.eval()
    print("done")

    # Encode each photo
    for photo in sorted(photos):
        print(f"\n  {photo.name}:")
        try:
            image = preprocess(Image.open(photo).convert("RGB")).unsqueeze(0)
            with torch.no_grad():
                emb = model.encode_image(image)
                emb = emb / emb.norm(dim=-1, keepdim=True)
                emb_np = emb.squeeze().numpy()
            print(f"    Encoded: {emb_np.shape} (norm={np.linalg.norm(emb_np):.3f})")

            # Classify with each trained probe
            for result in results:
                if "classifier" in result:
                    from sklearn.preprocessing import normalize
                    emb_normed = normalize(emb_np.reshape(1, -1))
                    pred = result["classifier"].predict(emb_normed)[0]
                    proba = result["classifier"].predict_proba(emb_normed)[0]
                    top_idx = np.argsort(proba)[-3:][::-1]
                    classes = result["class_names"]
                    print(f"    {result['task']:10s}: {classes[pred]} "
                          f"({proba[pred]:.1%})")
                    print(f"               top-3: "
                          + ", ".join(f"{classes[i]} ({proba[i]:.1%})" for i in top_idx))
        except Exception as e:
            print(f"    ERROR: {e}")


def write_results_doc(results, output_path):
    """Write decision gate document."""
    with open(output_path, "w") as f:
        f.write("# Linear Probe Results — CLIP Frozen Embeddings\n\n")
        f.write(f"**Date:** {__import__('datetime').date.today()}\n")
        f.write(f"**Model:** ViT-B/32 (laion2b_s34b_b79k)\n")
        f.write(f"**Embeddings:** 1,927 × 512-dim from product shots\n\n")

        f.write("## Summary\n\n")
        f.write("| Task | Accuracy | 5-fold CV | Classes | Samples |\n")
        f.write("|------|----------|-----------|---------|--------|\n")
        for r in results:
            f.write(f"| {r['task']} | {r['accuracy']:.1%} | "
                    f"{r['cv_mean']:.1%} ± {r['cv_std']:.1%} | "
                    f"{r['n_classes']} | {r['n_samples']} |\n")

        f.write("\n## Decision Gate\n\n")
        brand_acc = next((r["accuracy"] for r in results if r["task"] == "Brand"), 0)
        if brand_acc > 0.8:
            f.write(f"**Brand accuracy: {brand_acc:.1%} → CLIP features work.**\n\n")
            f.write("CLIP's frozen representations contain enough brand-discriminative signal "
                    "for visual search. Prompt engineering and embedding-space techniques "
                    "are sufficient. LoRA fine-tuning is not required.\n\n")
            f.write("**Next:** Focus investment on battery door classifier and confirmation screen.\n")
        elif brand_acc > 0.5:
            f.write(f"**Brand accuracy: {brand_acc:.1%} → Mixed signal.**\n\n")
            f.write("CLIP features capture some brand structure but not enough for reliable "
                    "classification. LoRA fine-tuning on hearing aid product shots is worth "
                    "investigating.\n\n")
            f.write("**Next:** Run LoRA experiment (Step 6 of forward plan) before "
                    "investing further in CLIP-based features.\n")
        else:
            f.write(f"**Brand accuracy: {brand_acc:.1%} → CLIP doesn't transfer.**\n\n")
            f.write("Frozen CLIP features do not contain enough signal to distinguish "
                    "hearing aid brands. The visual similarity between devices across "
                    "manufacturers is too high for general-purpose embeddings.\n\n")
            f.write("**Next:** Go all-in on OCR + specialized classifiers. "
                    "Deprioritize CLIP visual search entirely.\n")

        f.write("\n## Most Confused Pairs\n\n")
        f.write("These confusions reveal how CLIP's internal representation groups "
                "hearing aids — and whether those groupings reflect visual similarity, "
                "OEM relationships, or noise.\n\n")
        for r in results:
            f.write(f"### {r['task']}\n\n")
            if r["confused_pairs"]:
                for count, true, pred in r["confused_pairs"][:5]:
                    f.write(f"- **{true}** misclassified as **{pred}**: {count}×\n")
            else:
                f.write("No confusions (perfect classification).\n")
            f.write("\n")

        # Per-task detailed sections
        for r in results:
            f.write(f"## {r['task']} — Detailed Results\n\n")
            f.write(f"Accuracy: {r['accuracy']:.1%} | "
                    f"5-fold CV: {r['cv_mean']:.1%} ± {r['cv_std']:.1%} | "
                    f"{r['n_classes']} classes, {r['n_samples']} samples\n\n")
            f.write("| Class | Precision | Recall | F1 | Support |\n")
            f.write("|-------|-----------|--------|----|---------|\n")
            report = r["report"]
            for cls in r["class_names"]:
                cr = report[cls]
                f.write(f"| {cls} | {cr['precision']:.1%} | {cr['recall']:.1%} | "
                        f"{cr['f1-score']:.1%} | {cr['support']:.0f} |\n")
            f.write("\n")

    print(f"\n📄 Results written to {output_path}")


def plot_results(results, output_dir):
    """Generate confusion matrix heatmaps and accuracy bar charts."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.colors import LogNorm

    output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)

    # ── 1. Confusion matrices ──────────────────────────────────────────
    for r in results:
        cm = np.array(r["confusion_matrix"])
        classes = r["class_names"]
        n = len(classes)

        fig, ax = plt.subplots(figsize=(max(8, n * 0.7), max(6, n * 0.6)))

        # Normalize by row (true label) for percentage view
        cm_norm = cm.astype(float) / cm.sum(axis=1, keepdims=True)

        im = ax.imshow(cm_norm, cmap="YlOrRd", vmin=0, vmax=1)
        fig.colorbar(im, ax=ax, label="Recall (row-normalized)", shrink=0.8)

        # Labels
        ax.set_xticks(range(n))
        ax.set_yticks(range(n))
        short_names = [c[:12] for c in classes]
        ax.set_xticklabels(short_names, rotation=45, ha="right", fontsize=8)
        ax.set_yticklabels(short_names, fontsize=8)
        ax.set_xlabel("Predicted")
        ax.set_ylabel("True")
        ax.set_title(f"{r['task']} — Confusion Matrix ({r['accuracy']:.1%} accuracy)")

        # Annotate cells with counts
        for i in range(n):
            for j in range(n):
                if cm[i, j] > 0:
                    color = "white" if cm_norm[i, j] > 0.5 else "black"
                    ax.text(j, i, str(cm[i, j]), ha="center", va="center",
                            fontsize=7, color=color)

        fig.tight_layout()
        path = output_dir / f"probe_{r['task'].lower()}_confusion.png"
        fig.savefig(path, dpi=150)
        plt.close(fig)
        print(f"  {path}")

    # ── 2. Summary accuracy bar chart ──────────────────────────────────
    fig, ax = plt.subplots(figsize=(8, 4))
    tasks = [r["task"] for r in results]
    accs = [r["accuracy"] for r in results]
    cvs = [r["cv_mean"] for r in results]
    cv_errs = [r["cv_std"] for r in results]

    x = np.arange(len(tasks))
    width = 0.35
    bars1 = ax.bar(x - width/2, [a * 100 for a in accs], width, label="Test (80/20)", color="#2ecc71")
    bars2 = ax.bar(x + width/2, [a * 100 for a in cvs], width,
                   yerr=[e * 100 for e in cv_errs], label="5-fold CV", color="#3498db", capsize=5)

    # Decision gate lines
    ax.axhline(y=80, color="#e74c3c", linestyle="--", alpha=0.5, label="High confidence (80%)")
    ax.axhline(y=50, color="#e67e22", linestyle="--", alpha=0.5, label="Low confidence (50%)")

    ax.set_ylabel("Accuracy (%)")
    ax.set_title("CLIP Linear Probe — Can the AI see the difference?")
    ax.set_xticks(x)
    ax.set_xticklabels(tasks)
    ax.set_ylim(0, 105)
    ax.legend(loc="lower right", fontsize=8)

    # Value labels on bars
    for bar in bars1:
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f"{bar.get_height():.0f}%", ha="center", va="bottom", fontsize=9)
    for bar in bars2:
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f"{bar.get_height():.0f}%", ha="center", va="bottom", fontsize=9)

    fig.tight_layout()
    path = output_dir / "probe_summary.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"  {path}")

    # ── 3. Per-class F1 bar charts ─────────────────────────────────────
    for r in results:
        classes = r["class_names"]
        report = r["report"]
        f1s = [report[c]["f1-score"] * 100 for c in classes]
        supports = [report[c]["support"] for c in classes]

        # Sort by F1
        order = np.argsort(f1s)[::-1]
        classes_sorted = [classes[i] for i in order]
        f1s_sorted = [f1s[i] for i in order]
        supports_sorted = [supports[i] for i in order]

        fig, ax = plt.subplots(figsize=(max(8, len(classes) * 0.5), 5))
        colors = ["#2ecc71" if f > 80 else "#f39c12" if f > 50 else "#e74c3c" for f in f1s_sorted]
        bars = ax.bar(range(len(classes_sorted)), f1s_sorted, color=colors)

        ax.set_xticks(range(len(classes_sorted)))
        ax.set_xticklabels(classes_sorted, rotation=45, ha="right", fontsize=8)
        ax.set_ylabel("F1 Score (%)")
        ax.set_title(f"{r['task']} — Per-class F1 (green >80%, amber >50%, red <50%)")
        ax.set_ylim(0, 110)

        # Support labels
        for i, (bar, n) in enumerate(zip(bars, supports_sorted)):
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                    f"n={n:.0f}", ha="center", va="bottom", fontsize=7, color="gray")

        fig.tight_layout()
        path = output_dir / f"probe_{r['task'].lower()}_f1.png"
        fig.savefig(path, dpi=150)
        plt.close(fig)
        print(f"  {path}")

    print(f"\n📊 All plots saved to {output_dir}/")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Linear probe on frozen CLIP embeddings")
    parser.add_argument("--json", action="store_true", help="Machine-readable JSON output")
    parser.add_argument("--real", type=str, help="Directory of real-world photos to test")
    parser.add_argument("--plot", action="store_true", help="Generate visualisation plots")
    args = parser.parse_args()

    # Load data
    X, labels = load_data()
    print(f"\nEmbedding matrix: {X.shape}")

    # Run three probes
    results = []
    for task, y in [("Brand", labels["brand"]), ("Style", labels["style"]), ("Battery", labels["battery"])]:
        result = run_probe(X, y, task)
        results.append(result)

    # Real-world domain gap test
    if args.real:
        probe_real_photos(args.real, None, results)

    # Generate plots
    if args.plot:
        print("\nGenerating plots...")
        plot_dir = DATA_DIR.parent / "docs" / "plots"
        plot_results(results, plot_dir)

    # Write results document
    docs_dir = DATA_DIR.parent / "docs"
    docs_dir.mkdir(exist_ok=True)
    write_results_doc(results, docs_dir / "linear-probe-results.md")

    # JSON output
    if args.json:
        # Strip non-serializable fields
        json_results = []
        for r in results:
            jr = {k: v for k, v in r.items() if k != "classifier"}
            json_results.append(jr)
        print(json.dumps(json_results, indent=2, default=str))

    # Print decision gate summary
    brand_acc = next((r["accuracy"] for r in results if r["task"] == "Brand"), 0)
    style_acc = next((r["accuracy"] for r in results if r["task"] == "Style"), 0)
    battery_acc = next((r["accuracy"] for r in results if r["task"] == "Battery"), 0)

    print(f"\n{'='*60}")
    print(f"DECISION GATE")
    print(f"{'='*60}")
    print(f"  Brand:   {brand_acc:.1%}", end="")
    print(f"  {'✅ CLIP works' if brand_acc > 0.8 else '⚠️  Mixed' if brand_acc > 0.5 else '❌ CLIP fails'}")
    print(f"  Style:   {style_acc:.1%}", end="")
    print(f"  {'→ AI-assisted on confirmation screen' if style_acc > 0.7 else '→ human-only field'}")
    print(f"  Battery: {battery_acc:.1%}", end="")
    print(f"  {'→ AI-assisted on confirmation screen' if battery_acc > 0.7 else '→ human-only field'}")


if __name__ == "__main__":
    main()
