#!/usr/bin/env python3
"""
Download all hearing aid images from unaudinary.com.

Downloads 2,267 images in parallel using asyncio + aiohttp,
preserving the original filenames and organizing by source path.
"""

import asyncio
import aiohttp
import json
import os
import ssl
import sys
from pathlib import Path
from urllib.parse import urlparse

BASE_URL = "https://unaudinary.com"
FIREBASE_BUCKET = "gs://recycled-sound-app.firebasestorage.app/training-data/images/"
DATA_DIR = Path(__file__).parent
IMAGE_DIR = DATA_DIR / "images"
URLS_FILE = DATA_DIR / "raw" / "image_urls.json"

# Throttle to be respectful — 20 concurrent downloads
SEMAPHORE_LIMIT = 20
TIMEOUT = aiohttp.ClientTimeout(total=30)

# macOS Python often lacks system certs — skip verification for scraping
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE


def url_to_filename(url: str) -> str:
    """Convert a URL path to a safe local filename."""
    parsed = urlparse(url)
    # e.g. /uploaded_assets/image-123.webp → uploaded_assets/image-123.webp
    # or /objects/uploads/uuid.webp → objects/uploads/uuid.webp
    return parsed.path.lstrip("/")


async def download_one(
    session: aiohttp.ClientSession,
    semaphore: asyncio.Semaphore,
    url: str,
    dest: Path,
    progress: dict,
):
    """Download a single image with retry."""
    async with semaphore:
        full_url = f"{BASE_URL}{url}" if url.startswith("/") else url
        dest_file = dest / url_to_filename(url)
        dest_file.parent.mkdir(parents=True, exist_ok=True)

        if dest_file.exists() and dest_file.stat().st_size > 0:
            progress["skipped"] += 1
            return

        for attempt in range(3):
            try:
                async with session.get(full_url) as resp:
                    if resp.status == 200:
                        content = await resp.read()
                        dest_file.write_bytes(content)
                        progress["downloaded"] += 1
                        total = progress["downloaded"] + progress["failed"] + progress["skipped"]
                        if total % 50 == 0:
                            print(f"  Progress: {total}/{progress['total']} "
                                  f"(✓{progress['downloaded']} ✗{progress['failed']} ⊘{progress['skipped']})")
                        return
                    else:
                        progress["failed"] += 1
                        if attempt == 2:
                            print(f"  ✗ {resp.status}: {url}")
                        return
            except Exception as e:
                if attempt == 2:
                    progress["failed"] += 1
                    print(f"  ✗ Error: {url}: {e}")
                await asyncio.sleep(1)


async def main():
    with open(URLS_FILE) as f:
        urls = json.load(f)

    print(f"🎧 Downloading {len(urls)} hearing aid images...")
    print(f"   Destination: {IMAGE_DIR}")
    print(f"   Concurrency: {SEMAPHORE_LIMIT}")
    print()

    progress = {"downloaded": 0, "failed": 0, "skipped": 0, "total": len(urls)}
    semaphore = asyncio.Semaphore(SEMAPHORE_LIMIT)

    connector = aiohttp.TCPConnector(ssl=SSL_CTX)
    async with aiohttp.ClientSession(timeout=TIMEOUT, connector=connector) as session:
        tasks = [download_one(session, semaphore, url, IMAGE_DIR, progress) for url in urls]
        await asyncio.gather(*tasks)

    print()
    print(f"✅ Done!")
    print(f"   Downloaded: {progress['downloaded']}")
    print(f"   Skipped (already existed): {progress['skipped']}")
    print(f"   Failed: {progress['failed']}")

    # Save a manifest mapping URL → local path
    manifest = {}
    for url in urls:
        local_path = url_to_filename(url)
        full_local = IMAGE_DIR / local_path
        if full_local.exists():
            manifest[url] = str(local_path)

    manifest_path = DATA_DIR / "processed" / "image_manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"   Manifest: {manifest_path} ({len(manifest)} entries)")


def restore_from_firebase():
    """Restore training images from Firebase Storage backup.

    Use this if unaudinary.com is down. Requires gsutil and GCP auth.
    Usage: python3 download_images.py --from-firebase
    """
    print(f"🔥 Restoring from Firebase Storage...")
    print(f"   Source: {FIREBASE_BUCKET}")
    print(f"   Destination: {IMAGE_DIR}")
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    os.system(f"gsutil -m rsync -r {FIREBASE_BUCKET} {IMAGE_DIR}/")
    print("✅ Done!")


if __name__ == "__main__":
    if "--from-firebase" in sys.argv:
        restore_from_firebase()
    else:
        asyncio.run(main())
