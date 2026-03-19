#!/usr/bin/env python3
"""
👁️ Visual Fingerprints — CLIP Embeddings for Hearing Aid Scanner

Takes the 2,267 scraped hearing aid images and encodes them into
512-dimensional CLIP vectors. These power the scanner's visual
identification: snap a photo → nearest-neighbor in CLIP space →
"that's an Oticon Intent BTE."

Uses OpenCLIP with ViT-B/32 (fast, good enough for product shots).

The embeddings are stored in a third ChromaDB collection alongside
the existing semantic and DNA collections, completing the trifecta:

  1. hearing_aids_semantic  — "find aids matching this description"
  2. hearing_aids_dna       — "find aids with similar capabilities"
  3. hearing_aids_visual    — "find aids that look like this photo"
"""

import json
import time
from pathlib import Path

import chromadb
import open_clip
import torch
from PIL import Image

DATA_DIR = Path(__file__).parent
CHROMA_DIR = DATA_DIR / "chroma_db"
IMAGE_DIR = DATA_DIR / "images"
PROCESSED_DIR = DATA_DIR / "processed"

# Load the mapping from image URLs → device records
RAW_FILE = DATA_DIR / "raw" / "hearing-aids-raw.json"
MANIFEST_FILE = PROCESSED_DIR / "image_manifest.json"
DNA_FILE = PROCESSED_DIR / "device_dna.json"

BATCH_SIZE = 32


def build_image_to_device_map(devices: list) -> dict:
    """Map each image URL to the device(s) that reference it."""
    img_to_devices = {}
    for device in devices:
        urls = []
        if device.get("imageUrl"):
            urls.append(device["imageUrl"])
        for u in device.get("imageUrls") or []:
            urls.append(u)
        for url in urls:
            if url not in img_to_devices:
                img_to_devices[url] = []
            img_to_devices[url].append({
                "id": device.get("id"),
                "name": device.get("name", ""),
                "manufacturer": device.get("manufacturer", ""),
                "model": device.get("model", ""),
                "style": device.get("style", ""),
                "technology_tier": device.get("technologyTier", ""),
            })
    return img_to_devices


def main():
    print("👁️  Building Visual Fingerprints for Hearing Aid Scanner")
    print("=" * 58)
    print()

    # Load device data and manifest
    with open(RAW_FILE) as f:
        all_devices = json.load(f)
    with open(MANIFEST_FILE) as f:
        manifest = json.load(f)

    active = [d for d in all_devices if d.get("isActive") and not d.get("isArchived")]
    img_to_devices = build_image_to_device_map(active)

    print(f"📊 {len(active)} active devices, {len(manifest)} images on disk")
    print(f"   {len(img_to_devices)} unique image URLs linked to devices")

    # Load CLIP model
    print()
    print("🧠 Loading CLIP model (ViT-B-32)...")
    t0 = time.time()
    model, _, preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k"
    )
    model.eval()
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    model = model.to(device)
    print(f"   Loaded in {time.time() - t0:.1f}s on {device}")

    # Collect images that are both on disk and linked to active devices
    valid_images = []
    for url, local_path in manifest.items():
        if url in img_to_devices:
            full_path = IMAGE_DIR / local_path
            if full_path.exists() and full_path.stat().st_size > 0:
                valid_images.append((url, local_path, img_to_devices[url]))

    print(f"   {len(valid_images)} images to embed (linked to active devices + on disk)")

    # Encode in batches
    print()
    print("🔮 Encoding visual fingerprints...")
    t0 = time.time()

    all_embeddings = []  # (url, local_path, devices, embedding)
    failed = 0

    for i in range(0, len(valid_images), BATCH_SIZE):
        batch = valid_images[i : i + BATCH_SIZE]
        images = []
        valid_batch = []

        for url, local_path, devices in batch:
            try:
                img = Image.open(IMAGE_DIR / local_path).convert("RGB")
                images.append(preprocess(img))
                valid_batch.append((url, local_path, devices))
            except Exception as e:
                failed += 1
                continue

        if not images:
            continue

        image_tensor = torch.stack(images).to(device)
        with torch.no_grad():
            embeddings = model.encode_image(image_tensor)
            embeddings = embeddings / embeddings.norm(dim=-1, keepdim=True)  # L2 normalize

        for (url, local_path, devices), emb in zip(valid_batch, embeddings):
            all_embeddings.append((url, local_path, devices, emb.cpu().numpy().tolist()))

        done = min(i + BATCH_SIZE, len(valid_images))
        if done % 100 < BATCH_SIZE or done == len(valid_images):
            elapsed = time.time() - t0
            rate = done / elapsed if elapsed > 0 else 0
            print(f"   {done}/{len(valid_images)} ({rate:.0f} img/s)")

    print(f"\n   Encoded {len(all_embeddings)} images, {failed} failed")
    print(f"   Time: {time.time() - t0:.1f}s")

    # Build ChromaDB collection
    print()
    print("🗄️  Building visual search collection...")

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))

    try:
        client.delete_collection("hearing_aids_visual")
    except Exception:
        pass

    visual = client.create_collection(
        name="hearing_aids_visual",
        metadata={
            "description": "CLIP visual embeddings for hearing aid photo identification",
            "model": "ViT-B-32 (laion2b_s34b_b79k)",
            "dimensions": "512",
            "hnsw:space": "cosine",
        },
    )

    # Index — one entry per image, with device metadata
    BATCH_DB = 500
    for i in range(0, len(all_embeddings), BATCH_DB):
        batch = all_embeddings[i : i + BATCH_DB]
        ids = []
        embeddings = []
        metadatas = []
        documents = []

        for url, local_path, devices, emb in batch:
            # Use first linked device as primary metadata
            d = devices[0]
            img_id = local_path.replace("/", "_").replace(".", "_")
            ids.append(img_id)
            embeddings.append(emb)
            metadatas.append({
                "image_url": url,
                "local_path": local_path,
                "name": d["name"],
                "manufacturer": d["manufacturer"],
                "model": d["model"],
                "style": d["style"],
                "technology_tier": d["technology_tier"],
                "linked_device_count": str(len(devices)),
                "all_device_names": "; ".join(
                    sorted(set(dd["name"] for dd in devices))
                )[:500],  # truncate for metadata limit
            })
            documents.append(
                f"{d['manufacturer']} {d['name']} - {d['style']}"
            )

        visual.add(
            ids=ids,
            embeddings=embeddings,
            metadatas=metadatas,
            documents=documents,
        )
        print(f"   Indexed batch {i // BATCH_DB + 1}: {len(batch)} images")

    print(f"\n✅ Visual collection ready: {visual.count()} image embeddings")

    # Save embeddings to disk too (for later use outside ChromaDB)
    visual_data = []
    for url, local_path, devices, emb in all_embeddings:
        visual_data.append({
            "image_url": url,
            "local_path": local_path,
            "devices": [{"name": d["name"], "manufacturer": d["manufacturer"]} for d in devices],
            "embedding": emb,
        })

    visual_path = PROCESSED_DIR / "visual_embeddings.json"
    with open(visual_path, "w") as f:
        json.dump(visual_data, f)
    print(f"💾 Saved to {visual_path} ({len(visual_data)} entries)")

    # ── Demo ──
    print()
    print("=" * 58)
    print("🎯 DEMO: Visual Scanner Simulation")
    print("=" * 58)
    print()
    print('📸 "Scanning" a random Oticon image...')

    # Find an Oticon image and use it as the query
    oticon_imgs = [
        (url, lp, devs, emb) for url, lp, devs, emb in all_embeddings
        if any(d["manufacturer"] == "Oticon" for d in devs)
    ]
    if oticon_imgs:
        query_url, query_path, query_devs, query_emb = oticon_imgs[0]
        print(f"   Query image: {query_path}")
        print(f"   Actual device: {query_devs[0]['name']}")
        print()

        results = visual.query(
            query_embeddings=[query_emb],
            n_results=6,
        )
        print("   Scanner results:")
        seen = set()
        for meta, dist in zip(results["metadatas"][0], results["distances"][0]):
            name = meta["name"]
            if name in seen:
                continue
            seen.add(name)
            similarity = 1 - dist
            confidence = "HIGH" if similarity > 0.95 else "MEDIUM" if similarity > 0.85 else "LOW"
            print(f"   {'→' if similarity > 0.95 else ' '} {name} ({meta['manufacturer']})")
            print(f"     Style: {meta['style']} | Confidence: {confidence} ({similarity:.3f})")

    # Demo 2: Cross-brand visual similarity
    print()
    print('🔄 Cross-brand: "What looks like this Phonak?"')
    phonak_imgs = [
        (url, lp, devs, emb) for url, lp, devs, emb in all_embeddings
        if any(d["manufacturer"] == "Phonak" for d in devs)
    ]
    if phonak_imgs:
        _, _, p_devs, p_emb = phonak_imgs[0]
        print(f"   Query: {p_devs[0]['name']}")
        results = visual.query(
            query_embeddings=[p_emb],
            n_results=8,
        )
        seen = set()
        for meta, dist in zip(results["metadatas"][0], results["distances"][0]):
            if meta["manufacturer"] == "Phonak":
                continue
            name = f"{meta['name']} ({meta['manufacturer']})"
            if name in seen:
                continue
            seen.add(name)
            print(f"   → {name} | Visual similarity: {1 - dist:.3f}")
            if len(seen) >= 4:
                break

    print()
    print("=" * 58)
    print("👁️  The scanner has eyes. 2,267 images × 512 dimensions.")
    print("🎧 Every hearing aid deserves a second life.")
    print("=" * 58)


if __name__ == "__main__":
    main()
