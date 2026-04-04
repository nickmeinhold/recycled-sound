#!/usr/bin/env python3
"""
🧪 Recycled Sound — Pipeline Test Harness

Runs the same photo through both identification paths and compares results:

  Path A: Local CLIP visual search (same model as Cloud Function clip_encode)
          → cosine similarity against 1,927 pre-computed embeddings in ChromaDB

  Path B: Google Vision API (same API as Cloud Function analyzeHearingAid)
          → label detection + OCR text extraction

  Fusion: Combines both signals using the same logic as scan_fusion.dart

Usage:
    python3 test_pipeline.py /path/to/photo.jpg
    python3 test_pipeline.py /path/to/folder/        # batch mode
    python3 test_pipeline.py /path/to/folder/ --json  # machine-readable output
"""

import argparse
import json
import sys
import time
from pathlib import Path

DATA_DIR = Path(__file__).parent
CHROMA_DIR = DATA_DIR / "chroma_db"

# Known brands from the device register
KNOWN_BRANDS = [
    "phonak", "oticon", "signia", "resound", "widex",
    "unitron", "beltone", "starkey", "bernafon", "sonic",
    "blamey saunders", "hansaton",
]


def _levenshtein(s1: str, s2: str) -> int:
    """Levenshtein edit distance between two strings."""
    if len(s1) < len(s2):
        return _levenshtein(s2, s1)
    if len(s2) == 0:
        return len(s1)
    prev = list(range(len(s2) + 1))
    for i, c1 in enumerate(s1):
        curr = [i + 1]
        for j, c2 in enumerate(s2):
            curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (c1 != c2)))
        prev = curr
    return prev[len(s2)]

# ─── CLIP Path ───────────────────────────────────────────────

def run_clip(image_path: Path, n_results: int = 5):
    """Encode image with CLIP and search against ChromaDB visual collection."""
    import open_clip
    import torch
    from PIL import Image
    import chromadb

    t0 = time.time()

    # Load model (same as Cloud Function: ViT-B-32 laion2b)
    model, _, preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k"
    )
    model.eval()
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    model = model.to(device)
    t_model = time.time() - t0

    # Encode query image
    img = Image.open(image_path).convert("RGB")
    img_tensor = preprocess(img).unsqueeze(0).to(device)
    with torch.no_grad():
        embedding = model.encode_image(img_tensor)
        embedding = embedding / embedding.norm(dim=-1, keepdim=True)
    query_vec = embedding.cpu().numpy().tolist()[0]
    t_encode = time.time() - t0 - t_model

    # Search visual collection
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    visual = client.get_collection("hearing_aids_visual")
    results = visual.query(query_embeddings=[query_vec], n_results=n_results * 3)
    t_search = time.time() - t0 - t_model - t_encode

    # Deduplicate by device name
    seen = set()
    matches = []
    for meta, dist in zip(results["metadatas"][0], results["distances"][0]):
        name = meta["name"]
        if name in seen:
            continue
        seen.add(name)
        similarity = 1 - dist
        matches.append({
            "name": name,
            "manufacturer": meta["manufacturer"],
            "style": meta["style"],
            "similarity": round(similarity, 4),
            "confidence": "HIGH" if similarity > 0.95 else "MEDIUM" if similarity > 0.85 else "LOW",
        })
        if len(matches) >= n_results:
            break

    return {
        "matches": matches,
        "timing": {
            "model_load": round(t_model, 2),
            "encode": round(t_encode, 2),
            "search": round(t_search, 2),
        },
        "top_brand": matches[0]["manufacturer"] if matches else None,
        "top_model": matches[0]["name"] if matches else None,
        "top_similarity": matches[0]["similarity"] if matches else 0,
    }


# ─── Vision API Path ────────────────────────────────────────

def _load_brand_models():
    """Load all device models grouped by brand from ChromaDB."""
    import chromadb
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    visual = client.get_collection("hearing_aids_visual")
    all_meta = visual.get(include=["metadatas"])
    brand_models = {}  # brand -> set of model names
    for m in all_meta["metadatas"]:
        brand = m["manufacturer"].lower()
        name = m["name"]  # e.g. "Unitron Moxi S-R"
        if brand not in brand_models:
            brand_models[brand] = set()
        brand_models[brand].add(name)
    return brand_models


# Cache brand models on first use
_BRAND_MODELS = None


def _get_brand_models():
    global _BRAND_MODELS
    if _BRAND_MODELS is None:
        _BRAND_MODELS = _load_brand_models()
    return _BRAND_MODELS


def _fuzzy_match_model(ocr_words: list, brand: str) -> tuple:
    """
    Fuzzy-match OCR words against known model names for a brand.
    Returns (matched_device_name, match_detail) or (None, None).
    """
    brand_models = _get_brand_models()
    brand_lower = brand.lower()
    if brand_lower not in brand_models:
        return None, None

    best_name = None
    best_score = 999
    best_detail = None

    for device_name in brand_models[brand_lower]:
        # Extract model words from the full device name (remove brand prefix)
        model_part = device_name.lower().replace(brand_lower, "").strip()
        model_words = [w for w in model_part.split() if len(w) >= 3]

        for model_word in model_words:
            for ocr_word in ocr_words:
                if len(ocr_word) < 3:
                    continue
                dist = _levenshtein(ocr_word, model_word)
                if dist <= 1 and dist < best_score:
                    best_score = dist
                    best_name = device_name
                    match_type = "exact" if dist == 0 else "fuzzy"
                    best_detail = f"{match_type} ('{ocr_word}' → '{model_word}', dist={dist})"

    return best_name, best_detail


def run_vision(image_path: Path, project: str = "recycled-sound-app"):
    """Call Google Vision API for label detection + OCR (same as analyzeHearingAid)."""
    from google.cloud import vision

    t0 = time.time()

    client = vision.ImageAnnotatorClient(
        client_options={"quota_project_id": project},
    )

    with open(image_path, "rb") as f:
        content = f.read()
    image = vision.Image(content=content)

    # Same parallel calls as the Cloud Function
    label_response = client.label_detection(image=image)
    text_response = client.text_detection(image=image)
    t_api = time.time() - t0

    labels = [
        {"description": l.description.lower(), "score": round(l.score, 3)}
        for l in label_response.label_annotations
    ]

    ocr_text = ""
    if text_response.text_annotations:
        ocr_text = text_response.text_annotations[0].description.lower().strip()
    ocr_words = [w for w in ocr_text.split() if len(w) > 1]

    # Detect brand from OCR — with fuzzy matching for single-char OCR errors
    detected_brand = None
    brand_match_type = None
    for brand in KNOWN_BRANDS:
        if brand in ocr_text:
            detected_brand = brand.title()
            brand_match_type = "exact"
            break
    if not detected_brand:
        # Fuzzy match: check each OCR word against brands (Levenshtein ≤ 1)
        for word in ocr_words:
            for brand in KNOWN_BRANDS:
                if len(word) >= 4 and len(brand) >= 4 and abs(len(word) - len(brand)) <= 1:
                    dist = _levenshtein(word, brand)
                    if dist <= 1:
                        detected_brand = brand.title()
                        brand_match_type = f"fuzzy ('{word}' → '{brand}', dist={dist})"
                        break
            if detected_brand:
                break

    # Detect potential model from OCR (words that look like model numbers)
    model_candidates = [
        w for w in ocr_words
        if any(c.isdigit() for c in w) and len(w) >= 3
    ]

    # Fuzzy model matching against known devices for this brand
    matched_model = None
    model_match_detail = None
    if detected_brand:
        matched_model, model_match_detail = _fuzzy_match_model(
            ocr_words, detected_brand,
        )

    return {
        "labels": labels[:10],
        "ocr_text": ocr_text,
        "ocr_words": ocr_words,
        "detected_brand": detected_brand,
        "brand_match_type": brand_match_type,
        "matched_model": matched_model,
        "model_match_detail": model_match_detail,
        "model_candidates": model_candidates,
        "timing": {"api_call": round(t_api, 2)},
    }


# ─── Fusion ──────────────────────────────────────────────────

def fuse(clip_result: dict, vision_result: dict) -> dict:
    """
    Combine CLIP + Vision signals — mirrors scan_fusion.dart confidence matrix.

    Signal matrix:
      clipHigh (>0.7) + ocrConfirms  → 95% brand, 90% model
      clipHigh + !hasOcr             → 85% brand, 80% model
      clipMedium (>0.5) + ocrConfirms → 90% brand, 75% model
      hasOcr + !clipHigh             → 80% brand, 40% model
      else                           → 60% brand, 50% model
    """
    clip_sim = clip_result["top_similarity"]
    clip_brand = (clip_result["top_brand"] or "").lower()
    ocr_brand = (vision_result["detected_brand"] or "").lower()
    has_ocr = bool(ocr_brand)

    clip_high = clip_sim > 0.7
    clip_medium = clip_sim > 0.5
    ocr_confirms = has_ocr and clip_brand and (
        ocr_brand in clip_brand or clip_brand in ocr_brand
    )

    has_model_match = bool(vision_result.get("matched_model"))

    if clip_high and ocr_confirms:
        scenario = "clipHigh + ocrConfirms"
        brand_conf, model_conf, spec_conf = 95, 90, 75
    elif clip_high and not has_ocr:
        scenario = "clipHigh + noOcr"
        brand_conf, model_conf, spec_conf = 85, 80, 70
    elif clip_medium and ocr_confirms:
        scenario = "clipMedium + ocrConfirms"
        brand_conf, model_conf, spec_conf = 90, 75, 65
    elif has_ocr and has_model_match:
        scenario = "ocrBrand + ocrModel"
        brand_conf, model_conf, spec_conf = 85, 75, 60
    elif has_ocr and not clip_high:
        scenario = "hasOcr + noClipHigh"
        brand_conf, model_conf, spec_conf = 80, 40, 30
    else:
        scenario = "fallback"
        brand_conf, model_conf, spec_conf = 60, 50, 40

    # Pick best brand: prefer OCR if available, otherwise CLIP
    best_brand = vision_result["detected_brand"] or clip_result["top_brand"] or "Unknown"
    # Prefer OCR-matched model (fuzzy matched against catalog) over CLIP guess
    best_model = vision_result.get("matched_model") or clip_result["top_model"] or "Unknown"

    # Check for OCR/CLIP disagreement
    agreement = "N/A"
    if has_ocr and clip_brand:
        if ocr_confirms:
            agreement = "AGREE ✓"
        else:
            agreement = f"DISAGREE ✗ (CLIP: {clip_result['top_brand']}, OCR: {vision_result['detected_brand']})"

    return {
        "brand": {"value": best_brand, "confidence": brand_conf},
        "model": {"value": best_model, "confidence": model_conf},
        "spec_confidence": spec_conf,
        "scenario": scenario,
        "agreement": agreement,
        "clip_similarity": clip_sim,
    }


# ─── Display ─────────────────────────────────────────────────

def print_report(image_path: Path, clip_result: dict, vision_result: dict, fused: dict):
    """Print a formatted comparison report."""
    name = image_path.name
    print(f"\n{'═' * 60}")
    print(f"  📸 {name}")
    print(f"{'═' * 60}")

    # CLIP results
    print(f"\n  🔬 CLIP Visual Search (local, {clip_result['timing']['encode']}s encode + {clip_result['timing']['search']}s search)")
    for i, m in enumerate(clip_result["matches"][:5]):
        bar = "█" * int(m["similarity"] * 20) + "░" * (20 - int(m["similarity"] * 20))
        print(f"    {i+1}. {m['manufacturer']} {m['name']}")
        print(f"       {bar} {m['similarity']:.3f} [{m['confidence']}]  ({m['style']})")

    # Vision API results
    print(f"\n  👁️  Vision API ({vision_result['timing']['api_call']}s)")
    label_strs = [f"{l['description']} ({l['score']})" for l in vision_result['labels'][:6]]
    print(f"    Labels: {', '.join(label_strs)}")
    if vision_result["ocr_text"]:
        ocr_display = vision_result["ocr_text"][:120]
        if len(vision_result["ocr_text"]) > 120:
            ocr_display += "..."
        print(f"    OCR text: \"{ocr_display}\"")
    else:
        print(f"    OCR text: (none detected)")
    if vision_result["detected_brand"]:
        match_info = f" ({vision_result.get('brand_match_type', 'exact')})" if vision_result.get("brand_match_type") else ""
        print(f"    Brand detected: {vision_result['detected_brand']}{match_info}")
    if vision_result.get("matched_model"):
        print(f"    Model matched: {vision_result['matched_model']} ({vision_result['model_match_detail']})")
    elif vision_result["model_candidates"]:
        print(f"    Model candidates (unmatched): {', '.join(vision_result['model_candidates'][:5])}")

    # Fused result
    print(f"\n  🔀 Fused Result ({fused['scenario']})")
    print(f"    Brand: {fused['brand']['value']} ({fused['brand']['confidence']}%)")
    print(f"    Model: {fused['model']['value']} ({fused['model']['confidence']}%)")
    print(f"    Spec confidence: {fused['spec_confidence']}%")
    print(f"    CLIP similarity: {fused['clip_similarity']:.3f}")
    print(f"    Signal agreement: {fused['agreement']}")
    print()


def print_summary(all_results: list):
    """Print a summary table across all photos."""
    print(f"\n{'═' * 60}")
    print(f"  📊 SUMMARY — {len(all_results)} photos tested")
    print(f"{'═' * 60}\n")

    print(f"  {'Photo':<32} {'Brand':<12} {'B%':>3} {'Model':<20} {'M%':>3} {'Scenario'}")
    print(f"  {'─' * 32} {'─' * 12} {'─' * 3} {'─' * 20} {'─' * 3} {'─' * 20}")
    for r in all_results:
        f = r["fused"]
        photo = r["photo"][:30]
        brand = f["brand"]["value"][:11]
        model = f["model"]["value"][:19]
        print(f"  {photo:<32} {brand:<12} {f['brand']['confidence']:>3} {model:<20} {f['model']['confidence']:>3} {f['scenario']}")

    # Stats
    scenarios = {}
    for r in all_results:
        s = r["fused"]["scenario"]
        scenarios[s] = scenarios.get(s, 0) + 1

    print(f"\n  Scenarios:")
    for s, c in sorted(scenarios.items(), key=lambda x: -x[1]):
        print(f"    {s}: {c}")

    avg_sim = sum(r["fused"]["clip_similarity"] for r in all_results) / len(all_results)
    print(f"\n  Avg CLIP similarity: {avg_sim:.3f}")


# ─── Main ────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="🧪 Pipeline Test Harness — CLIP + Vision API comparison",
    )
    parser.add_argument("path", help="Image file or directory of images")
    parser.add_argument("-n", type=int, default=5, help="Number of CLIP results")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--clip-only", action="store_true", help="Skip Vision API")
    parser.add_argument("--vision-only", action="store_true", help="Skip CLIP")
    args = parser.parse_args()

    path = Path(args.path)
    if path.is_dir():
        images = sorted(path.glob("*.jpg")) + sorted(path.glob("*.png"))
    elif path.is_file():
        images = [path]
    else:
        print(f"Not found: {path}")
        sys.exit(1)

    if not images:
        print(f"No images found in {path}")
        sys.exit(1)

    print(f"\n🧪 Testing {len(images)} image(s) through CLIP + Vision pipeline\n")

    all_results = []
    for i, img in enumerate(images):
        print(f"  [{i+1}/{len(images)}] Processing {img.name}...")

        clip_result = None
        vision_result = None

        if not args.vision_only:
            clip_result = run_clip(img, n_results=args.n)

        if not args.clip_only:
            try:
                vision_result = run_vision(img)
            except Exception as e:
                print(f"    ⚠️  Vision API error: {e}")
                vision_result = {
                    "labels": [], "ocr_text": "", "ocr_words": [],
                    "detected_brand": None, "model_candidates": [],
                    "timing": {"api_call": 0},
                }

        # Build defaults for skipped paths
        if clip_result is None:
            clip_result = {
                "matches": [], "timing": {"model_load": 0, "encode": 0, "search": 0},
                "top_brand": None, "top_model": None, "top_similarity": 0,
            }
        if vision_result is None:
            vision_result = {
                "labels": [], "ocr_text": "", "ocr_words": [],
                "detected_brand": None, "model_candidates": [],
                "timing": {"api_call": 0},
            }

        fused = fuse(clip_result, vision_result)

        result = {
            "photo": img.name,
            "clip": clip_result,
            "vision": vision_result,
            "fused": fused,
        }
        all_results.append(result)

        if not args.json:
            print_report(img, clip_result, vision_result, fused)

    if args.json:
        print(json.dumps(all_results, indent=2))
    elif len(all_results) > 1:
        print_summary(all_results)


if __name__ == "__main__":
    main()
