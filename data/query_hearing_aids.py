#!/usr/bin/env python3
"""
🎧 Recycled Sound — Hearing Aid Knowledge Engine

Interactive query tool for the Device DNA vector store.
Supports three types of queries:

1. SEARCH  — Natural language search ("small invisible hearing aid for tinnitus")
2. MATCH   — Find devices with similar capabilities to a given device
3. NEED    — Match a recipient's needs to the best available devices
4. SCAN    — Identify a hearing aid from a photo (visual CLIP search)

Usage:
    python query_hearing_aids.py search "rechargeable BTE with telecoil"
    python query_hearing_aids.py match "Phonak Audeo"
    python query_hearing_aids.py need --style BTE --severity severe --rechargeable --telecoil --affordable
    python query_hearing_aids.py scan /path/to/photo.jpg
    python query_hearing_aids.py stats
"""

import argparse
import json
import sys
from pathlib import Path

import chromadb

DATA_DIR = Path(__file__).parent
CHROMA_DIR = DATA_DIR / "chroma_db"

# Same encoding schema as build_device_dna.py
STYLES_INDEX = {
    "BTE": 0, "Behind The Ear": 0,
    "RIC": 1, "Receiver In Canal": 1,
    "ITC": 2, "In The Canal": 2,
    "ITE": 3, "In The Ear": 3,
    "IIC": 4, "Invisible In Canal": 4,
    "CIC": 5, "Completely In Canal": 5,
}

DNA_DIMS = 37


def get_collections():
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    semantic = client.get_collection("hearing_aids_semantic")
    dna = client.get_collection("hearing_aids_dna")
    return semantic, dna


def format_result(meta, score=None, score_label="Score"):
    """Pretty-print a hearing aid result."""
    rs = " ⭐" if meta.get("recycled_sound_brand") == "True" else ""
    hsp = " 🆓HSP" if meta.get("hsp_subsidised") == "True" else ""
    score_str = f" | {score_label}: {score:.3f}" if score is not None else ""
    return (
        f"  {meta['name']} ({meta['manufacturer']}){rs}{hsp}\n"
        f"    Style: {meta['style']} | Tier: {meta['technology_tier']} | "
        f"${meta['price']} | Battery: {meta['battery_type']}{score_str}\n"
        f"    Suitable for: {meta['suitable_for']}"
    )


def cmd_search(args):
    """Natural language semantic search."""
    semantic, _ = get_collections()
    query = " ".join(args.query)
    print(f'\n🔍 Searching: "{query}"\n')

    results = semantic.query(query_texts=[query], n_results=args.n)
    for i, (meta, dist) in enumerate(
        zip(results["metadatas"][0], results["distances"][0])
    ):
        print(f"  {i+1}. {format_result(meta, 1 - dist, 'Relevance')}")
        print()


def cmd_match(args):
    """Find devices with similar capability DNA."""
    semantic, dna = get_collections()
    query = " ".join(args.query)
    print(f'\n🧬 Finding devices similar to: "{query}"\n')

    # First find the device by name
    found = semantic.query(query_texts=[query], n_results=1)
    if not found["ids"][0]:
        print("  No device found matching that name.")
        return

    source_id = found["ids"][0][0]
    source_meta = found["metadatas"][0][0]
    print(f"  Source: {source_meta['name']} ({source_meta['manufacturer']})")
    print(f"  Style: {source_meta['style']} | Tier: {source_meta['technology_tier']}")
    print()

    # Get its DNA vector and find neighbors
    source_dna = dna.get(ids=[source_id], include=["embeddings"])
    if source_dna["embeddings"] is not None and len(source_dna["embeddings"]) > 0:
        similar = dna.query(
            query_embeddings=[source_dna["embeddings"][0].tolist()],
            n_results=args.n + 1,
        )
        print(f"  Similar devices:")
        count = 0
        for meta, dist in zip(similar["metadatas"][0], similar["distances"][0]):
            if meta["name"] == source_meta["name"] and meta["manufacturer"] == source_meta["manufacturer"]:
                continue
            count += 1
            print(f"  {count}. {format_result(meta, 1 - dist, 'DNA similarity')}")
            print()
            if count >= args.n:
                break


def cmd_need(args):
    """Match recipient needs to devices using DNA vectors."""
    _, dna = get_collections()

    print("\n💚 Recipient Need Matching\n")
    print("  Profile:")
    if args.style:
        print(f"    Style: {args.style}")
    if args.severity:
        print(f"    Hearing loss: {', '.join(args.severity)}")
    if args.rechargeable:
        print(f"    Rechargeable: yes")
    if args.telecoil:
        print(f"    Telecoil: required")
    if args.bluetooth:
        print(f"    Bluetooth: required")
    if args.affordable:
        print(f"    Budget: affordable/HSP")
    print()

    # Build need vector
    need = [0.0] * DNA_DIMS

    # Style preference
    if args.style and args.style.upper() in STYLES_INDEX:
        need[STYLES_INDEX[args.style.upper()]] = 1.0

    # Tech tier (affordable = lower tier)
    if args.affordable:
        need[6] = 0.2
    else:
        need[6] = 0.6

    # Features
    if args.bluetooth:
        need[7] = 1.0   # iPhone streaming
        need[8] = 1.0   # Android streaming
    if args.telecoil:
        need[11] = 1.0

    # Severity
    severity_map = {"mild": 19, "moderate": 20, "severe": 21, "profound": 22}
    for s in (args.severity or []):
        idx = severity_map.get(s.lower())
        if idx is not None:
            need[idx] = 1.0

    # Battery
    if args.rechargeable:
        need[25] = 1.0  # Rechargeable slot

    # Bluetooth flag
    if args.bluetooth:
        need[30] = 1.0

    # HSP / affordability
    if args.affordable:
        need[31] = 1.0  # HSP
        need[32] = 0.15  # Low price

    results = dna.query(query_embeddings=[need], n_results=args.n)
    print("  Best matches:")
    for i, (meta, dist) in enumerate(
        zip(results["metadatas"][0], results["distances"][0])
    ):
        print(f"  {i+1}. {format_result(meta, 1 - dist, 'Need match')}")
        print()


def cmd_scan(args):
    """Identify a hearing aid from a photo using CLIP visual search."""
    import open_clip
    import torch
    from PIL import Image

    print(f'\n📸 Scanning: {args.image}\n')

    image_path = Path(args.image)
    if not image_path.exists():
        print(f"  File not found: {args.image}")
        return

    # Load CLIP
    print("  Loading visual model...")
    model, _, preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k"
    )
    model.eval()
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    model = model.to(device)

    # Encode the query image
    img = Image.open(image_path).convert("RGB")
    img_tensor = preprocess(img).unsqueeze(0).to(device)
    with torch.no_grad():
        embedding = model.encode_image(img_tensor)
        embedding = embedding / embedding.norm(dim=-1, keepdim=True)

    query_vec = embedding.cpu().numpy().tolist()[0]

    # Search visual collection
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    visual = client.get_collection("hearing_aids_visual")

    results = visual.query(query_embeddings=[query_vec], n_results=args.n * 2)

    print("  Identification results:\n")
    seen = set()
    count = 0
    for meta, dist in zip(results["metadatas"][0], results["distances"][0]):
        name = meta["name"]
        if name in seen:
            continue
        seen.add(name)
        count += 1
        similarity = 1 - dist
        if similarity > 0.95:
            confidence = "HIGH ✓"
        elif similarity > 0.85:
            confidence = "MEDIUM"
        else:
            confidence = "LOW"
        print(f"  {count}. {name} ({meta['manufacturer']})")
        print(f"     Style: {meta['style']} | Confidence: {confidence} ({similarity:.3f})")
        print()
        if count >= args.n:
            break


def cmd_stats(args):
    """Show dataset statistics."""
    semantic, dna = get_collections()

    print("\n📊 Recycled Sound Knowledge Engine Stats\n")
    print(f"  Total devices: {semantic.count()}")
    print(f"  DNA vectors: {dna.count()}")

    # Visual collection
    try:
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        visual = client.get_collection("hearing_aids_visual")
        print(f"  Visual embeddings: {visual.count()}")
    except Exception:
        print(f"  Visual embeddings: not built yet (run build_visual_embeddings.py)")

    # Load processed data for richer stats
    dna_path = DATA_DIR / "processed" / "device_dna.json"
    if dna_path.exists():
        with open(dna_path) as f:
            records = json.load(f)

        brands = {}
        styles = {}
        tiers = {}
        rs_brands = set()
        for r in records:
            brands[r["manufacturer"]] = brands.get(r["manufacturer"], 0) + 1
            styles[r["style"]] = styles.get(r["style"], 0) + 1
            tiers[r["technology_tier"]] = tiers.get(r["technology_tier"], 0) + 1
            if r["dna_metadata"].get("recycled_sound_brand"):
                rs_brands.add(r["manufacturer"])

        print(f"\n  Brands ({len(brands)}):")
        for brand, count in sorted(brands.items(), key=lambda x: -x[1]):
            flag = " ⭐" if brand in rs_brands else ""
            print(f"    {brand}: {count}{flag}")

        print(f"\n  Styles:")
        for style, count in sorted(styles.items(), key=lambda x: -x[1]):
            print(f"    {style}: {count}")

        print(f"\n  Tech tiers:")
        for tier, count in sorted(tiers.items(), key=lambda x: -x[1]):
            print(f"    {tier}: {count}")

        rs_count = sum(1 for r in records if r["dna_metadata"].get("recycled_sound_brand"))
        print(f"\n  Recycled Sound brand coverage: {rs_count}/{len(records)} ({100*rs_count//len(records)}%)")
        print(f"  ⭐ Brands on RS register: {', '.join(sorted(rs_brands))}")


def main():
    parser = argparse.ArgumentParser(
        description="🎧 Recycled Sound — Hearing Aid Knowledge Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", help="Query type")

    # search
    s = sub.add_parser("search", help="Natural language search")
    s.add_argument("query", nargs="+", help="Search query")
    s.add_argument("-n", type=int, default=5, help="Number of results")

    # match
    m = sub.add_parser("match", help="Find similar devices")
    m.add_argument("query", nargs="+", help="Device name to match against")
    m.add_argument("-n", type=int, default=5, help="Number of results")

    # need
    n = sub.add_parser("need", help="Match recipient needs")
    n.add_argument("--style", help="Preferred style: BTE, RIC, ITC, ITE, IIC, CIC")
    n.add_argument("--severity", nargs="+", help="Hearing loss: mild moderate severe profound")
    n.add_argument("--rechargeable", action="store_true")
    n.add_argument("--telecoil", action="store_true")
    n.add_argument("--bluetooth", action="store_true")
    n.add_argument("--affordable", action="store_true", help="Prefer HSP-subsidised / low cost")
    n.add_argument("-n", type=int, default=5, help="Number of results")

    # scan
    sc = sub.add_parser("scan", help="Identify hearing aid from photo")
    sc.add_argument("image", help="Path to hearing aid photo")
    sc.add_argument("-n", type=int, default=5, help="Number of results")

    # stats
    sub.add_parser("stats", help="Dataset statistics")

    args = parser.parse_args()
    if args.command == "search":
        cmd_search(args)
    elif args.command == "match":
        cmd_match(args)
    elif args.command == "need":
        cmd_need(args)
    elif args.command == "scan":
        cmd_scan(args)
    elif args.command == "stats":
        cmd_stats(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
