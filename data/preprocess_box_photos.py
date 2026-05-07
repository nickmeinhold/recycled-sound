#!/usr/bin/env python3
"""
Preprocess hearing aid photos taken inside clear plastic storage boxes.

Detects the box rectangle via contour detection, applies perspective
correction to produce a normalised top-down crop, and optionally
estimates white balance from the box edge colour.

Outputs both the raw photo and the perspective-corrected version,
ready for symlink into images_by_brand/ for training.

Usage:
  python3 preprocess_box_photos.py /path/to/box_photos/
  python3 preprocess_box_photos.py /path/to/box_photos/ --visualise
  python3 preprocess_box_photos.py /path/to/single_photo.jpg

Input naming convention:
  box{NN}_{brand}_{angle}.jpg
  e.g. box07_oticon_top.jpg, box07_oticon_45deg.jpg

Output:
  data/images_box/
    {brand}/
      box07_oticon_top.jpg          (original, resized)
      box07_oticon_top_rect.jpg     (perspective-corrected)

Requires: opencv-python, numpy, Pillow
"""

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import cv2
    import numpy as np
except ImportError:
    print("ERROR: This script requires opencv-python and numpy.")
    print("Install with: pip install opencv-python numpy")
    sys.exit(1)

DATA_DIR = Path(__file__).parent
OUTPUT_DIR = DATA_DIR / "images_box"
ORGANISED_DIR = DATA_DIR / "images_by_brand"

# Target size for the perspective-corrected output.
# Matches EfficientNet-B0 training input (will be resized to 224x224 by TF).
RECT_WIDTH = 448
RECT_HEIGHT = 448

# Box detection parameters — tuned for clear plastic hearing aid cases.
# These are typical Audiologist storage boxes: ~8cm × 5cm × 3cm.
MIN_AREA_RATIO = 0.05   # Box must be at least 5% of frame area
MAX_AREA_RATIO = 0.85   # Box can't be more than 85% of frame area
APPROX_EPSILON = 0.02   # Contour approximation tolerance (fraction of perimeter)


def order_corners(pts):
    """Order 4 corner points as: top-left, top-right, bottom-right, bottom-left.

    Uses the sum (x+y) and difference (y-x) trick:
    - Top-left has the smallest sum
    - Bottom-right has the largest sum
    - Top-right has the smallest difference
    - Bottom-left has the largest difference
    """
    rect = np.zeros((4, 2), dtype=np.float32)
    s = pts.sum(axis=1)
    d = np.diff(pts, axis=1).flatten()

    rect[0] = pts[np.argmin(s)]   # top-left
    rect[2] = pts[np.argmax(s)]   # bottom-right
    rect[1] = pts[np.argmin(d)]   # top-right
    rect[3] = pts[np.argmax(d)]   # bottom-left

    return rect


def detect_box(image, visualise=False):
    """Detect the largest rectangular contour (the plastic box).

    Returns the 4 ordered corner points, or None if no box found.

    Strategy:
    1. Convert to grayscale + bilateral filter (smooths but preserves edges)
    2. Adaptive threshold (handles uneven lighting from overhead fluorescents)
    3. Find contours, filter by area, approximate to polygon
    4. Keep the largest 4-sided polygon — that's the box
    """
    grey = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Bilateral filter: smooths interior while keeping box edges sharp.
    # d=9, sigmaColor=75, sigmaSpace=75 — standard for edge-preserving smoothing.
    blurred = cv2.bilateralFilter(grey, 9, 75, 75)

    # Adaptive threshold handles uneven lighting much better than global.
    # Block size 11, C=2 works well for clear plastic edges on desks.
    thresh = cv2.adaptiveThreshold(
        blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV, 11, 2,
    )

    # Morphological close to bridge small gaps in the box edge
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel, iterations=2)

    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if not contours:
        return None

    frame_area = image.shape[0] * image.shape[1]
    best_quad = None
    best_area = 0

    for contour in contours:
        area = cv2.contourArea(contour)
        area_ratio = area / frame_area

        if area_ratio < MIN_AREA_RATIO or area_ratio > MAX_AREA_RATIO:
            continue

        # Approximate contour to polygon
        peri = cv2.arcLength(contour, True)
        approx = cv2.approxPolyDP(contour, APPROX_EPSILON * peri, True)

        # We want a quadrilateral (4 corners = rectangle/trapezoid)
        if len(approx) == 4 and area > best_area:
            best_area = area
            best_quad = approx.reshape(4, 2)

    if best_quad is None:
        # Fallback: try Canny edge detection (works better for some lighting)
        edges = cv2.Canny(blurred, 50, 150)
        dilated = cv2.dilate(edges, kernel, iterations=1)
        contours2, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        for contour in sorted(contours2, key=cv2.contourArea, reverse=True):
            area = cv2.contourArea(contour)
            area_ratio = area / frame_area

            if area_ratio < MIN_AREA_RATIO or area_ratio > MAX_AREA_RATIO:
                continue

            peri = cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, APPROX_EPSILON * peri, True)

            if len(approx) == 4:
                best_quad = approx.reshape(4, 2)
                best_area = area
                break

    if best_quad is None:
        return None

    ordered = order_corners(best_quad.astype(np.float32))

    if visualise:
        vis = image.copy()
        for i, pt in enumerate(ordered.astype(int)):
            cv2.circle(vis, tuple(pt), 10, (0, 255, 0), -1)
            cv2.putText(vis, str(i), tuple(pt + [5, -10]),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        cv2.drawContours(vis, [ordered.astype(int)], -1, (0, 255, 0), 3)
        return ordered, vis

    return ordered


def perspective_correct(image, corners):
    """Warp the box region to a top-down rectangular view.

    Uses OpenCV's getPerspectiveTransform — the same operation a
    document scanner uses to flatten a photo of a page.
    """
    dst = np.array([
        [0, 0],
        [RECT_WIDTH - 1, 0],
        [RECT_WIDTH - 1, RECT_HEIGHT - 1],
        [0, RECT_HEIGHT - 1],
    ], dtype=np.float32)

    M = cv2.getPerspectiveTransform(corners, dst)
    warped = cv2.warpPerspective(image, M, (RECT_WIDTH, RECT_HEIGHT))

    return warped


def estimate_white_balance(image, corners):
    """Estimate white balance correction from the clear plastic box edge.

    Samples pixels along the box edges (which should be neutral/clear).
    Returns per-channel scaling factors to normalise colour cast.

    The clear plastic box edge acts as a grey card — it should be near-white
    or near-neutral. Any colour cast from ambient lighting shows up here.
    """
    # Sample a thin strip (5px wide) along each edge
    samples = []

    for i in range(4):
        p1 = corners[i].astype(int)
        p2 = corners[(i + 1) % 4].astype(int)

        # Sample 20 evenly-spaced points along this edge
        for t in np.linspace(0.1, 0.9, 20):
            x = int(p1[0] + t * (p2[0] - p1[0]))
            y = int(p1[1] + t * (p2[1] - p1[1]))

            # Clamp to image bounds
            y = max(0, min(y, image.shape[0] - 1))
            x = max(0, min(x, image.shape[1] - 1))

            # Sample a 5x5 patch around the point
            patch = image[max(0, y-2):y+3, max(0, x-2):x+3]
            if patch.size > 0:
                samples.append(patch.mean(axis=(0, 1)))

    if not samples:
        return np.array([1.0, 1.0, 1.0])

    edge_colour = np.mean(samples, axis=0)  # Average BGR of box edges

    # Target: neutral grey (equal channels). Scale each channel to match
    # the brightest channel (preserves brightness, corrects cast).
    target = edge_colour.max()
    if edge_colour.min() < 1:
        return np.array([1.0, 1.0, 1.0])

    scale = target / edge_colour
    # Clamp to reasonable range (don't over-correct)
    scale = np.clip(scale, 0.7, 1.4)

    return scale


def apply_white_balance(image, scale):
    """Apply per-channel white balance correction."""
    corrected = image.astype(np.float32)
    corrected[:, :, 0] *= scale[0]  # B
    corrected[:, :, 1] *= scale[1]  # G
    corrected[:, :, 2] *= scale[2]  # R
    return np.clip(corrected, 0, 255).astype(np.uint8)


def parse_filename(path):
    """Extract box number and brand from naming convention.

    Expected: box{NN}_{brand}_{angle}.jpg
    Returns: (box_number, brand, angle) or None
    """
    name = Path(path).stem.lower()

    # Try structured name first
    match = re.match(r"box(\d+)_([a-z]+)_(.+)", name)
    if match:
        return int(match.group(1)), match.group(2).title(), match.group(3)

    # Fallback: try just box number + brand
    match = re.match(r"box(\d+)_([a-z]+)", name)
    if match:
        return int(match.group(1)), match.group(2).title(), "unknown"

    return None


def process_image(image_path, visualise=False):
    """Process a single box photo.

    Returns:
    - (original_resized, perspective_corrected, white_balanced, metadata)
    - or None if box detection fails
    """
    image = cv2.imread(str(image_path))
    if image is None:
        print(f"  ERROR: Could not read {image_path}")
        return None

    # Resize to manageable size for processing (preserve aspect ratio)
    h, w = image.shape[:2]
    max_dim = 1200
    if max(h, w) > max_dim:
        scale = max_dim / max(h, w)
        image = cv2.resize(image, None, fx=scale, fy=scale)

    # Detect box
    result = detect_box(image, visualise=visualise)

    if result is None:
        print(f"  WARNING: No box detected in {image_path.name}")
        return None

    if visualise:
        corners, vis_image = result
    else:
        corners = result
        vis_image = None

    # Perspective correct
    rectified = perspective_correct(image, corners)

    # White balance from box edges
    wb_scale = estimate_white_balance(image, corners)
    wb_corrected = apply_white_balance(rectified, wb_scale)

    parsed = parse_filename(image_path)
    metadata = {
        "source": str(image_path),
        "box_number": parsed[0] if parsed else None,
        "brand": parsed[1] if parsed else None,
        "angle": parsed[2] if parsed else None,
        "white_balance_scale": wb_scale.tolist(),
        "box_corners": corners.tolist(),
    }

    return image, rectified, wb_corrected, vis_image, metadata


def process_directory(input_dir, visualise=False):
    """Process all box photos in a directory."""
    input_path = Path(input_dir)
    image_extensions = {".jpg", ".jpeg", ".png", ".webp", ".heic"}

    images = sorted(
        p for p in input_path.iterdir()
        if p.suffix.lower() in image_extensions
    )

    if not images:
        print(f"No images found in {input_path}")
        return

    print(f"Found {len(images)} images in {input_path}")
    print(f"Output: {OUTPUT_DIR}\n")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    vis_dir = OUTPUT_DIR / "_visualisations"
    if visualise:
        vis_dir.mkdir(parents=True, exist_ok=True)

    all_metadata = []
    success = 0
    failed = 0
    brands_found = set()

    for img_path in images:
        print(f"Processing {img_path.name}...")
        result = process_image(img_path, visualise=visualise)

        if result is None:
            failed += 1
            continue

        original, rectified, wb_corrected, vis_image, metadata = result
        brand = metadata.get("brand", "unknown")
        brands_found.add(brand)

        # Save to brand subdirectory
        brand_dir = OUTPUT_DIR / brand
        brand_dir.mkdir(parents=True, exist_ok=True)

        stem = img_path.stem
        # Save original (resized)
        cv2.imwrite(str(brand_dir / f"{stem}.jpg"), original)
        # Save perspective-corrected
        cv2.imwrite(str(brand_dir / f"{stem}_rect.jpg"), rectified)
        # Save white-balance-corrected
        cv2.imwrite(str(brand_dir / f"{stem}_wb.jpg"), wb_corrected)

        if visualise and vis_image is not None:
            cv2.imwrite(str(vis_dir / f"{stem}_vis.jpg"), vis_image)

        all_metadata.append(metadata)
        success += 1

    # Save manifest
    manifest_path = OUTPUT_DIR / "box_manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(all_metadata, f, indent=2)

    print(f"\n{'='*50}")
    print(f"Processed: {success}/{success + failed} images")
    print(f"Failed:    {failed}")
    print(f"Brands:    {', '.join(sorted(brands_found))}")
    print(f"Output:    {OUTPUT_DIR}")
    print(f"Manifest:  {manifest_path}")


def link_to_training(weight=3):
    """Symlink box images into images_by_brand/ for training.

    Box images are duplicated [weight] times to increase their influence
    during training, compensating for being outnumbered by product shots.
    """
    if not OUTPUT_DIR.exists():
        print("No box images found. Run processing first.")
        return

    linked = 0

    for brand_dir in OUTPUT_DIR.iterdir():
        if not brand_dir.is_dir() or brand_dir.name.startswith("_"):
            continue

        brand = brand_dir.name
        dest_dir = ORGANISED_DIR / brand
        dest_dir.mkdir(parents=True, exist_ok=True)

        for img_path in brand_dir.glob("*.jpg"):
            # Link each image [weight] times with different suffixes
            for w in range(weight):
                suffix = f"_box_w{w}" if w > 0 else "_box"
                dest = dest_dir / f"{img_path.stem}{suffix}{img_path.suffix}"
                if not dest.exists():
                    import os
                    os.symlink(img_path.resolve(), dest)
                    linked += 1

    print(f"Linked {linked} box images into {ORGANISED_DIR} (weight={weight}x)")


def main():
    parser = argparse.ArgumentParser(
        description="Preprocess hearing aid photos in plastic storage boxes"
    )
    parser.add_argument("input", help="Image file or directory of box photos")
    parser.add_argument("--visualise", action="store_true",
                        help="Save visualisation images showing detected box corners")
    parser.add_argument("--link", action="store_true",
                        help="After processing, symlink into images_by_brand/ for training")
    parser.add_argument("--weight", type=int, default=3,
                        help="Duplication weight for training symlinks (default: 3)")
    parser.add_argument("--link-only", action="store_true",
                        help="Only create training symlinks (skip processing)")

    args = parser.parse_args()

    if args.link_only:
        link_to_training(args.weight)
        return

    input_path = Path(args.input)

    if input_path.is_dir():
        process_directory(input_path, visualise=args.visualise)
    elif input_path.is_file():
        result = process_image(input_path, visualise=args.visualise)
        if result:
            original, rectified, wb_corrected, vis_image, metadata = result
            OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            stem = input_path.stem
            cv2.imwrite(str(OUTPUT_DIR / f"{stem}_rect.jpg"), rectified)
            cv2.imwrite(str(OUTPUT_DIR / f"{stem}_wb.jpg"), wb_corrected)
            if vis_image is not None:
                cv2.imwrite(str(OUTPUT_DIR / f"{stem}_vis.jpg"), vis_image)
            print(f"Saved to {OUTPUT_DIR}")
            print(f"White balance scale: {metadata['white_balance_scale']}")
    else:
        print(f"ERROR: {input_path} not found")
        sys.exit(1)

    if args.link:
        print()
        link_to_training(args.weight)


if __name__ == "__main__":
    main()
