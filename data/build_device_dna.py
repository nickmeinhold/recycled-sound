#!/usr/bin/env python3
"""
🧬 Device DNA — A Hearing Aid Genome

Every hearing aid gets a multi-dimensional fingerprint that captures its
"personality" across four dimensions:

1. VISUAL SIGNATURE  — Image embeddings (built separately via CLIP)
2. TECHNICAL GENOME  — Normalized specs (bandwidth, channels, fitting bands)
3. CAPABILITY BITS   — Feature flags as a binary vector
4. SUITABILITY FIELD — What hearing loss profiles it serves

This script processes the raw scraped data into:
- A ChromaDB vector store for similarity search
- Structured JSON for Firestore seeding
- Device DNA vectors for donor↔recipient matching

The magic: donated hearing aids can be matched to recipient needs using
nearest-neighbor search in capability space. A refugee who needs a
rechargeable BTE with telecoil for severe hearing loss can be matched
to the closest donated device — even across different brands.
"""

import json
import hashlib
from pathlib import Path
from typing import Any

import chromadb
from chromadb.config import Settings

DATA_DIR = Path(__file__).parent
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
CHROMA_DIR = DATA_DIR / "chroma_db"

# ─────────────────────────────────────────────
# Feature encoding schema
# ─────────────────────────────────────────────

STYLES = [
    "Behind The Ear",
    "Receiver In Canal",
    "In The Canal",
    "In The Ear",
    "Invisible In Canal",
    "Completely In Canal",
]

FEATURES = [
    "iPhone Streaming",
    "Android Streaming",
    "Tinnitus Relief",
    "Long Battery Life",
    "Telecoil",
    "Artificial Intelligence",
]

BEST_FOR = [
    "Value",
    "Tinnitus Relief",
    "Noisy Environments",
    "Music Lovers",
    "Invisibility",
    "Connectivity",
    "Simplicity",
    "Tinnitus",
]

SUITABILITY = ["Mild", "Moderate", "Severe", "Profound"]

TECH_TIERS = {
    "Premium": 5,
    "Enhanced": 4,
    "Enhance": 4,  # typo in source data
    "Advanced": 3,
    "Active": 3,
    "Standard": 2,
    "Essential": 1,
}

BATTERY_TYPES = {
    "Rechargeable": "rechargeable",
    "10": "disposable_10",
    "13": "disposable_13",
    "312": "disposable_312",
    "675": "disposable_675",
}

NOISE_REDUCTION = {
    "Enhanced": 5,
    "Advanced": 4,
    "Standard": 3,
    "Basic": 2,
    "Essential": 1,
}

# Known brands from Recycled Sound's register
RECYCLED_SOUND_BRANDS = {
    "Unitron", "Phonak", "Oticon", "Signia",
    "ReSound", "Beltone", "Widex", "Bernafon",
}


def encode_device_dna(device: dict) -> dict[str, Any]:
    """
    Encode a hearing aid into its Device DNA — a structured fingerprint
    that enables similarity search across brands and models.

    Returns a dict with:
    - dna_vector: list of floats (the actual embedding for ChromaDB)
    - dna_metadata: human-readable breakdown of the encoding
    """
    vector = []
    metadata = {}

    # ── Style (one-hot, 6 dims) ──
    style_vec = [1.0 if device.get("style") == s else 0.0 for s in STYLES]
    vector.extend(style_vec)
    metadata["style"] = device.get("style", "Unknown")

    # ── Tech tier (1 dim, normalized 0-1) ──
    tier = device.get("technologyTier", "Standard")
    tier_val = TECH_TIERS.get(tier, 2) / 5.0
    vector.append(tier_val)
    metadata["tech_tier"] = tier
    metadata["tech_tier_score"] = tier_val

    # ── Features (binary, 6 dims) ──
    device_features = set(device.get("features") or [])
    # Normalize the AI typo
    if "Artifical Intelligence" in device_features:
        device_features.add("Artificial Intelligence")
    feature_vec = [1.0 if f in device_features else 0.0 for f in FEATURES]
    vector.extend(feature_vec)
    metadata["features"] = list(device_features & set(FEATURES))

    # ── Best for (binary, 8 dims) ──
    device_best = set(device.get("bestFor") or [])
    best_vec = [1.0 if b in device_best else 0.0 for b in BEST_FOR]
    vector.extend(best_vec)

    # ── Suitability (binary, 4 dims) ──
    device_suit = set(device.get("suitableFor") or [])
    suit_vec = [1.0 if s in device_suit else 0.0 for s in SUITABILITY]
    vector.extend(suit_vec)
    metadata["suitability"] = list(device_suit & set(SUITABILITY))

    # ── Battery (one-hot, 5 dims) ──
    bat = device.get("batteryType", "")
    bat_vec = [1.0 if bat == k else 0.0 for k in BATTERY_TYPES.keys()]
    vector.extend(bat_vec)
    metadata["battery_type"] = BATTERY_TYPES.get(bat, f"other_{bat}")

    # ── Bluetooth (1 dim) ──
    bt = 1.0 if device.get("bluetoothConnectivity") else 0.0
    vector.append(bt)

    # ── Noise reduction (1 dim, normalized) ──
    nr = device.get("noiseReduction", "Basic")
    nr_val = NOISE_REDUCTION.get(nr, 2) / 5.0
    vector.append(nr_val)

    # ── Water resistance (1 dim) ──
    wr = 1.0 if device.get("waterResistant") else 0.0
    vector.append(wr)

    # ── HSP fully subsidised (1 dim) — important for affordability! ──
    hsp = 1.0 if device.get("hspFullySubsidised") else 0.0
    vector.append(hsp)
    metadata["hsp_subsidised"] = bool(device.get("hspFullySubsidised"))

    # ── Price (1 dim, log-normalized) ──
    try:
        price = float(device.get("price", 0))
    except (ValueError, TypeError):
        price = 0
    # Normalize: log scale, most aids $500-$10000
    import math
    price_norm = math.log1p(price) / math.log1p(10000) if price > 0 else 0
    vector.append(price_norm)
    metadata["price_aud"] = price

    # ── Specs: fitting bands (1 dim, normalized) ──
    specs = device.get("specifications") or {}
    try:
        bands = int(specs.get("Fitting Bands", 0))
    except (ValueError, TypeError):
        bands = 0
    bands_norm = min(bands / 24.0, 1.0)  # 24 is max observed
    vector.append(bands_norm)

    # ── Specs: frequency bandwidth (1 dim, normalized) ──
    bw_str = specs.get("Frequency Bandwidth", "0")
    try:
        bw = float(bw_str.replace("Hz", "").replace("kHz", "000").replace("k", "000"))
    except (ValueError, TypeError):
        bw = 0
    bw_norm = min(bw / 12000.0, 1.0)  # 12kHz is roughly max
    vector.append(bw_norm)

    # ── Recycled Sound relevance flag ──
    brand = device.get("manufacturer", "")
    metadata["recycled_sound_brand"] = brand in RECYCLED_SOUND_BRANDS

    # Total: 6 + 1 + 6 + 8 + 4 + 5 + 1 + 1 + 1 + 1 + 1 + 1 + 1 = 37 dimensions
    return {
        "dna_vector": vector,
        "dna_dims": len(vector),
        "dna_metadata": metadata,
    }


def build_document_text(device: dict) -> str:
    """
    Build a rich text document for semantic search.
    This is what ChromaDB will embed using its default model.
    """
    parts = [
        f"{device.get('manufacturer', '')} {device.get('name', '')}",
        f"Style: {device.get('style', 'Unknown')}",
        f"Technology: {device.get('technologyTier', 'Unknown')} tier",
    ]

    if device.get("description"):
        parts.append(device["description"])

    features = device.get("features") or []
    if features:
        parts.append(f"Features: {', '.join(features)}")

    suitable = device.get("suitableFor") or []
    if suitable:
        parts.append(f"Suitable for: {', '.join(suitable)} hearing loss")

    best_for = device.get("bestFor") or []
    if best_for:
        parts.append(f"Best for: {', '.join(best_for)}")

    specs = device.get("specifications") or {}
    if specs:
        spec_str = ", ".join(f"{k}: {v}" for k, v in specs.items())
        parts.append(f"Specs: {spec_str}")

    price = device.get("price")
    if price:
        parts.append(f"Price: ${price} AUD")

    if device.get("hspFullySubsidised"):
        parts.append("Fully subsidised under Hearing Services Program")

    return "\n".join(parts)


def stable_id(device: dict) -> str:
    """Generate a stable, unique ID for a device."""
    key = f"{device.get('manufacturer', '')}_{device.get('name', '')}_{device.get('id', '')}"
    return hashlib.md5(key.encode()).hexdigest()[:16]


def main():
    print("🧬 Building Device DNA for Recycled Sound")
    print("=" * 55)
    print()

    # Load raw data
    with open(RAW_DIR / "hearing-aids-raw.json") as f:
        devices = json.load(f)
    with open(RAW_DIR / "hearing-aid-generations.json") as f:
        generations = json.load(f)

    print(f"📊 Loaded {len(devices)} hearing aids, {len(generations)} product generations")

    # Filter to active devices only
    active = [d for d in devices if d.get("isActive") and not d.get("isArchived")]
    print(f"   Active devices: {len(active)}")

    # ── Encode Device DNA ──
    print()
    print("🧬 Encoding Device DNA vectors...")
    dna_records = []
    for device in active:
        dna = encode_device_dna(device)
        record = {
            "id": stable_id(device),
            "source_id": device.get("id"),
            "name": device.get("name", ""),
            "manufacturer": device.get("manufacturer", ""),
            "model": device.get("model", ""),
            "product_family": device.get("productFamily", ""),
            "style": device.get("style", ""),
            "technology_tier": device.get("technologyTier", ""),
            "price": device.get("price"),
            "image_url": device.get("imageUrl", ""),
            "image_urls": device.get("imageUrls", []),
            "description": device.get("description", ""),
            "dna_vector": dna["dna_vector"],
            "dna_dims": dna["dna_dims"],
            "dna_metadata": dna["dna_metadata"],
            # Full structured data for Firestore
            "structured": {
                "battery_type": device.get("batteryType"),
                "battery_life": device.get("batteryLife"),
                "bluetooth": device.get("bluetoothConnectivity"),
                "noise_reduction": device.get("noiseReduction"),
                "tinnitus_relief": device.get("tinnitusRelief"),
                "water_resistant": device.get("waterResistant"),
                "water_resistance_rating": device.get("waterResistanceRating"),
                "mobile_app": device.get("mobileApp"),
                "features": device.get("features", []),
                "best_for": device.get("bestFor", []),
                "suitable_for": device.get("suitableFor", []),
                "specifications": device.get("specifications", {}),
                "hsp_subsidised": device.get("hspFullySubsidised"),
                "release_date": device.get("releaseDate"),
            },
        }
        dna_records.append(record)

    print(f"   Encoded {len(dna_records)} devices into {dna_records[0]['dna_dims']}-dimensional DNA vectors")

    # ── Stats ──
    brands = {}
    styles = {}
    rs_count = 0
    hsp_count = 0
    for r in dna_records:
        brands[r["manufacturer"]] = brands.get(r["manufacturer"], 0) + 1
        styles[r["style"]] = styles.get(r["style"], 0) + 1
        if r["dna_metadata"].get("recycled_sound_brand"):
            rs_count += 1
        if r["dna_metadata"].get("hsp_subsidised"):
            hsp_count += 1

    print()
    print("📈 Dataset statistics:")
    print(f"   Brands: {len(brands)}")
    for brand, count in sorted(brands.items(), key=lambda x: -x[1]):
        rs_flag = " ⭐" if brand in RECYCLED_SOUND_BRANDS else ""
        print(f"     {brand}: {count}{rs_flag}")
    print(f"\n   Styles:")
    for style, count in sorted(styles.items(), key=lambda x: -x[1]):
        print(f"     {style}: {count}")
    print(f"\n   Recycled Sound brands: {rs_count}/{len(dna_records)} ({100*rs_count//len(dna_records)}%)")
    print(f"   HSP subsidised: {hsp_count}/{len(dna_records)} ({100*hsp_count//len(dna_records)}%)")

    # ── Save processed data ──
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    processed_path = PROCESSED_DIR / "device_dna.json"
    with open(processed_path, "w") as f:
        json.dump(dna_records, f, indent=2)
    print(f"\n💾 Saved processed data to {processed_path}")

    # ── Build ChromaDB ──
    print()
    print("🗄️  Building ChromaDB vector store...")
    CHROMA_DIR.mkdir(parents=True, exist_ok=True)

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))

    # Collection 1: Semantic search (text embeddings via ChromaDB's default model)
    try:
        client.delete_collection("hearing_aids_semantic")
    except Exception:
        pass

    semantic = client.create_collection(
        name="hearing_aids_semantic",
        metadata={"description": "Semantic search over hearing aid descriptions and specs"},
    )

    # Collection 2: Device DNA (custom numeric vectors for capability matching)
    try:
        client.delete_collection("hearing_aids_dna")
    except Exception:
        pass

    dna_collection = client.create_collection(
        name="hearing_aids_dna",
        metadata={
            "description": "Device DNA vectors for donor↔recipient matching",
            "dimensions": str(dna_records[0]["dna_dims"]),
            "hnsw:space": "cosine",
        },
    )

    # Batch insert (ChromaDB max batch = 5461)
    BATCH = 500
    for i in range(0, len(dna_records), BATCH):
        batch = dna_records[i : i + BATCH]

        # Semantic collection — let ChromaDB embed the text
        semantic.add(
            ids=[r["id"] for r in batch],
            documents=[build_document_text(r) for r in batch],
            metadatas=[
                {
                    "name": r["name"],
                    "manufacturer": r["manufacturer"],
                    "model": r["model"],
                    "style": r["style"],
                    "technology_tier": r["technology_tier"],
                    "price": str(r["price"] or "0"),
                    "hsp_subsidised": str(r["dna_metadata"].get("hsp_subsidised", False)),
                    "recycled_sound_brand": str(r["dna_metadata"].get("recycled_sound_brand", False)),
                    "image_url": r["image_url"],
                    "suitable_for": ",".join(r["structured"]["suitable_for"]),
                    "battery_type": r["structured"]["battery_type"] or "",
                }
                for r in batch
            ],
        )

        # DNA collection — custom vectors
        dna_collection.add(
            ids=[r["id"] for r in batch],
            embeddings=[r["dna_vector"] for r in batch],
            metadatas=[
                {
                    "name": r["name"],
                    "manufacturer": r["manufacturer"],
                    "model": r["model"],
                    "style": r["style"],
                    "technology_tier": r["technology_tier"],
                    "price": str(r["price"] or "0"),
                    "hsp_subsidised": str(r["dna_metadata"].get("hsp_subsidised", False)),
                    "recycled_sound_brand": str(r["dna_metadata"].get("recycled_sound_brand", False)),
                    "image_url": r["image_url"],
                    "suitable_for": ",".join(r["structured"]["suitable_for"]),
                    "battery_type": r["structured"]["battery_type"] or "",
                }
                for r in batch
            ],
            documents=[r["name"] for r in batch],
        )

        print(f"   Indexed batch {i // BATCH + 1}: {len(batch)} devices")

    print(f"\n✅ ChromaDB ready at {CHROMA_DIR}")
    print(f"   Collection 'hearing_aids_semantic': {semantic.count()} docs (text embeddings)")
    print(f"   Collection 'hearing_aids_dna': {dna_collection.count()} docs (37-dim DNA vectors)")

    # ── Demo queries ──
    print()
    print("=" * 55)
    print("🎯 DEMO: Device DNA in action")
    print("=" * 55)

    # Demo 1: Semantic search
    print()
    print('🔍 Semantic: "rechargeable hearing aid for severe hearing loss with bluetooth"')
    results = semantic.query(
        query_texts=["rechargeable hearing aid for severe hearing loss with bluetooth streaming"],
        n_results=5,
    )
    for i, (doc_id, meta, dist) in enumerate(
        zip(results["ids"][0], results["metadatas"][0], results["distances"][0])
    ):
        print(f"   {i+1}. {meta['name']} ({meta['manufacturer']})")
        print(f"      Style: {meta['style']} | Tier: {meta['technology_tier']} | ${meta['price']}")
        print(f"      Distance: {dist:.4f}")

    # Demo 2: DNA matching — "I have a donated Phonak, find similar capability devices"
    print()
    print('🧬 DNA Match: "Find devices similar to a donated Phonak Audéo RIC"')
    # Find a Phonak Audéo to use as the query vector
    phonak_results = semantic.query(
        query_texts=["Phonak Audeo Receiver In Canal"],
        n_results=1,
    )
    if phonak_results["ids"][0]:
        phonak_id = phonak_results["ids"][0][0]
        # Get its DNA vector
        phonak_dna = dna_collection.get(ids=[phonak_id], include=["embeddings"])
        if phonak_dna["embeddings"] is not None and len(phonak_dna["embeddings"]) > 0:
            similar = dna_collection.query(
                query_embeddings=[phonak_dna["embeddings"][0]],
                n_results=6,  # first will be itself
            )
            for i, (doc_id, meta, dist) in enumerate(
                zip(similar["ids"][0], similar["metadatas"][0], similar["distances"][0])
            ):
                if doc_id == phonak_id:
                    continue
                rs = " ⭐RS" if meta["recycled_sound_brand"] == "True" else ""
                print(f"   {i}. {meta['name']} ({meta['manufacturer']}){rs}")
                print(f"      Style: {meta['style']} | Tier: {meta['technology_tier']} | ${meta['price']}")
                print(f"      DNA similarity: {1 - dist:.4f}")

    # Demo 3: Recipient matching
    print()
    print('💚 Recipient Match: "Elderly refugee, severe loss, needs simple rechargeable BTE with telecoil"')
    # Construct a "need vector" manually
    need_vector = [0.0] * dna_records[0]["dna_dims"]
    # BTE style
    need_vector[0] = 1.0  # Behind The Ear
    # Lower tech tier (simpler)
    need_vector[6] = 0.3  # Standard/Essential
    # Telecoil needed
    need_vector[11] = 1.0  # Telecoil
    # Suitable for severe
    need_vector[22] = 1.0  # Severe
    need_vector[23] = 1.0  # Profound
    # Rechargeable
    need_vector[25] = 1.0  # Rechargeable
    # HSP subsidised preferred
    need_vector[31] = 1.0  # HSP
    # Low price preferred
    need_vector[32] = 0.2  # Low price

    matches = dna_collection.query(
        query_embeddings=[need_vector],
        n_results=5,
    )
    for i, (doc_id, meta, dist) in enumerate(
        zip(matches["ids"][0], matches["metadatas"][0], matches["distances"][0])
    ):
        rs = " ⭐RS" if meta["recycled_sound_brand"] == "True" else ""
        hsp = " 🆓HSP" if meta["hsp_subsidised"] == "True" else ""
        print(f"   {i+1}. {meta['name']} ({meta['manufacturer']}){rs}{hsp}")
        print(f"      Style: {meta['style']} | Tier: {meta['technology_tier']} | ${meta['price']}")
        print(f"      Need match: {1 - dist:.4f}")

    print()
    print("=" * 55)
    print("🎧 Recycled Sound — every hearing aid deserves a second life")
    print("=" * 55)


if __name__ == "__main__":
    main()
