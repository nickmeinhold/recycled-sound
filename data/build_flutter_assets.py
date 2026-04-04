#!/usr/bin/env python3
"""Build Flutter asset bundle from Device DNA + CLIP visual embeddings.

Produces two files for the Flutter app:
  - assets/device_db.bin   — Binary CLIP embeddings (header + float32 matrix)
  - assets/device_catalog.json — Device metadata + embedding-to-device index

Binary format:
  [uint32 entry_count] [uint32 dims]
  [entry_count * dims float32 values, row-major, little-endian]

The catalog JSON maps embedding indices to device IDs and provides full
device metadata for spec lookup after visual matching.
"""

import json
import struct
import sys
from pathlib import Path

DATA_DIR = Path(__file__).parent
PROCESSED_DIR = DATA_DIR / "processed"
FLUTTER_ASSETS_DIR = DATA_DIR.parent / "recycled_sound" / "assets"

# ScanResult fields we need from Device DNA structured data
SPEC_FIELDS = [
    "battery_type",
    "battery_life",
    "release_date",
]


def load_device_dna() -> dict[str, dict]:
    """Load device DNA and index by stable ID."""
    path = PROCESSED_DIR / "device_dna.json"
    print(f"Loading device DNA from {path}...")
    with open(path) as f:
        devices = json.load(f)
    print(f"  Loaded {len(devices)} devices")
    return {d["id"]: d for d in devices}


def load_visual_embeddings() -> list[dict]:
    """Load CLIP visual embeddings."""
    path = PROCESSED_DIR / "visual_embeddings.json"
    print(f"Loading visual embeddings from {path}...")
    with open(path) as f:
        embeddings = json.load(f)
    print(f"  Loaded {len(embeddings)} image embeddings")
    return embeddings


def match_device(
    name: str, manufacturer: str, devices_by_name: dict[str, list[str]]
) -> str | None:
    """Match an image's device to a Device DNA ID by name + manufacturer."""
    key = f"{manufacturer}||{name}".lower()
    matches = devices_by_name.get(key)
    if matches:
        return matches[0]
    return None


def build_name_index(devices: dict[str, dict]) -> dict[str, list[str]]:
    """Build a lookup from 'manufacturer||name' -> list of device IDs."""
    index: dict[str, list[str]] = {}
    for device_id, device in devices.items():
        key = f"{device['manufacturer']}||{device['name']}".lower()
        index.setdefault(key, []).append(device_id)
    return index


def trim_device_metadata(device: dict) -> dict:
    """Extract only the fields needed for ScanResult population."""
    structured = device.get("structured", {})
    dna_meta = device.get("dna_metadata", {})

    # Map style names to short form for type field
    style_map = {
        "Behind The Ear": "BTE (Behind-the-Ear)",
        "Receiver In Canal": "RIC (Receiver-in-Canal)",
        "In The Canal": "ITC (In-the-Canal)",
        "In The Ear": "ITE (In-the-Ear)",
        "Invisible In Canal": "IIC (Invisible-in-Canal)",
        "Completely In Canal": "CIC (Completely-in-Canal)",
    }

    style_raw = device.get("style", "")
    device_type = style_map.get(style_raw, style_raw)

    # Battery size mapping (battery_type values -> display names)
    battery_map = {
        "rechargeable": "Rechargeable",
        "10": "Size 10",
        "13": "Size 13",
        "312": "Size 312",
        "675": "Size 675",
    }
    battery_raw = structured.get("battery_type", "")
    battery_size = battery_map.get(battery_raw, battery_raw)

    return {
        "id": device["id"],
        "manufacturer": device.get("manufacturer", "Unknown"),
        "model": device.get("model", "Unknown"),
        "name": device.get("name", "Unknown"),
        "type": device_type,
        "year": structured.get("release_date", "Unknown"),
        "batterySize": battery_size,
        "technologyTier": device.get("technology_tier", "Unknown"),
        "features": dna_meta.get("features", []),
        "suitability": dna_meta.get("suitability", []),
        "batteryLife": structured.get("battery_life", "Unknown"),
        "bluetooth": structured.get("bluetooth", False),
        "noiseReduction": structured.get("noise_reduction", "Unknown"),
        "waterResistant": structured.get("water_resistant", False),
        "hspSubsidised": dna_meta.get("hsp_subsidised", False),
        "recycledSoundBrand": dna_meta.get("recycled_sound_brand", False),
    }


def build_assets(devices: dict[str, dict], embeddings: list[dict]) -> None:
    """Build binary embedding file and JSON catalog."""
    FLUTTER_ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    name_index = build_name_index(devices)

    # Process embeddings — resolve device links and filter valid ones
    valid_entries = []
    device_ids_seen = set()

    for emb in embeddings:
        vector = emb.get("embedding")
        if not vector or len(vector) != 512:
            continue

        # Resolve linked devices to DNA IDs
        linked_ids = []
        for dev_ref in emb.get("devices", []):
            device_id = match_device(
                dev_ref.get("name", ""),
                dev_ref.get("manufacturer", ""),
                name_index,
            )
            if device_id:
                linked_ids.append(device_id)
                device_ids_seen.add(device_id)

        if not linked_ids:
            continue

        valid_entries.append(
            {
                "vector": vector,
                "device_ids": linked_ids,
            }
        )

    print(f"\nValid embeddings: {len(valid_entries)} (of {len(embeddings)})")
    print(f"Unique devices referenced: {len(device_ids_seen)}")

    # Write binary embeddings file
    dims = 512
    bin_path = FLUTTER_ASSETS_DIR / "device_db.bin"
    print(f"\nWriting binary embeddings to {bin_path}...")

    with open(bin_path, "wb") as f:
        # Header: entry_count (uint32) + dims (uint32)
        f.write(struct.pack("<II", len(valid_entries), dims))
        # Embedding data: row-major float32
        for entry in valid_entries:
            f.write(struct.pack(f"<{dims}f", *entry["vector"]))

    bin_size = bin_path.stat().st_size
    print(f"  Written: {bin_size:,} bytes ({bin_size / 1024 / 1024:.1f} MB)")

    # Build catalog JSON
    embedding_index = []
    for entry in valid_entries:
        embedding_index.append(
            {
                "deviceIds": entry["device_ids"],
            }
        )

    # Trim device metadata to only what the app needs
    device_catalog = {}
    for device_id in device_ids_seen:
        device = devices[device_id]
        device_catalog[device_id] = trim_device_metadata(device)

    catalog = {
        "version": 1,
        "embeddingCount": len(valid_entries),
        "dims": dims,
        "embeddingIndex": embedding_index,
        "devices": device_catalog,
    }

    json_path = FLUTTER_ASSETS_DIR / "device_catalog.json"
    print(f"\nWriting device catalog to {json_path}...")
    with open(json_path, "w") as f:
        json.dump(catalog, f, separators=(",", ":"))

    json_size = json_path.stat().st_size
    print(f"  Written: {json_size:,} bytes ({json_size / 1024 / 1024:.1f} MB)")
    print(f"  Devices in catalog: {len(device_catalog)}")

    print(f"\nTotal asset size: {(bin_size + json_size) / 1024 / 1024:.1f} MB")


def main():
    devices = load_device_dna()
    embeddings = load_visual_embeddings()
    build_assets(devices, embeddings)
    print("\nDone! Assets ready in recycled_sound/assets/")


if __name__ == "__main__":
    main()
