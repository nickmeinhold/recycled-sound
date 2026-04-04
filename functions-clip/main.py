"""CLIP Inference Cloud Function — encodes hearing aid photos into 512-dim vectors.

Receives an image URL from Firebase Storage, downloads it, encodes it with
OpenCLIP ViT-B/32 (laion2b_s34b_b79k — same model used for pre-computed
embeddings), L2-normalises the vector, and returns 512 floats.

The client then performs cosine similarity search against bundled embeddings
on-device, achieving $0/month infrastructure cost.

Deployment:
  firebase deploy --only functions:clip_encode

Cost at 2GB × ~10s per invocation:
  Free tier: 400K GB-seconds/month → 20,000 scans/month free
"""

import numpy as np
from firebase_admin import initialize_app, storage
from firebase_functions import https_fn, options
from PIL import Image

initialize_app()

# Lazy-loaded model — survives across warm invocations (~15 min)
_model = None
_preprocess = None
_tokenizer = None

# Expected Storage bucket prefix (SSRF prevention)
STORAGE_BUCKET = "recycled-sound-app.firebasestorage.app"


def _load_model():
    """Load CLIP model on first invocation. Stays warm for ~15 min."""
    global _model, _preprocess, _tokenizer
    if _model is not None:
        return

    import open_clip

    _model, _, _preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k"
    )
    _model.eval()
    _tokenizer = open_clip.get_tokenizer("ViT-B-32")


@https_fn.on_call(
    memory=options.MemoryOption.GB_2,
    timeout_sec=120,
    region="australia-southeast1",
    max_instances=5,
)
def clip_encode(req: https_fn.CallableRequest) -> dict:
    """Encode a hearing aid photo into a 512-dim CLIP vector.

    Args:
        req.data["imageUrl"]: Firebase Storage gs:// URL of the image.

    Returns:
        {"embedding": [512 floats], "model": "ViT-B-32-laion2b"}
    """
    import torch

    # Require authentication
    if req.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Must be signed in",
        )

    image_url = req.data.get("imageUrl")
    if not image_url or not isinstance(image_url, str):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="imageUrl is required",
        )

    # SSRF prevention: validate URL points to our Storage bucket
    if not image_url.startswith(f"gs://{STORAGE_BUCKET}/"):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="imageUrl must be a Firebase Storage URL in the project bucket",
        )

    # Download image from Storage
    bucket = storage.bucket(STORAGE_BUCKET)
    # Extract blob path from gs:// URL
    blob_path = image_url[len(f"gs://{STORAGE_BUCKET}/") :]
    blob = bucket.blob(blob_path)

    import tempfile

    with tempfile.NamedTemporaryFile(suffix=".jpg") as tmp:
        blob.download_to_filename(tmp.name)
        image = Image.open(tmp.name).convert("RGB")

    # Load model (cached across warm invocations)
    _load_model()

    # Preprocess and encode
    image_tensor = _preprocess(image).unsqueeze(0)
    with torch.no_grad():
        embedding = _model.encode_image(image_tensor)

    # L2 normalise
    embedding = embedding / embedding.norm(dim=-1, keepdim=True)

    # Convert to plain Python floats
    vector = embedding.squeeze().cpu().numpy().astype(np.float32)

    return {
        "embedding": vector.tolist(),
        "model": "ViT-B-32-laion2b",
    }
