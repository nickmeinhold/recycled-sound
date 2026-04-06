# Scanner Roadmap

> From the CLIP paper deep-dive and T2 HUD session (2026-04-05).
> Each phase builds on the last. Ordered by ROI — highest impact first.

---

## Phase 1: Validate & Polish the Live Scanner

**Goal:** Get Seray's real-world feedback on the T2 scanner, fix what breaks, polish what works.

### 1.1 Real-device testing with Seray
- [ ] Have Seray test v0.3.1 on devices from the register (~20 donated aids)
- [ ] Record which brands/models the live OCR catches vs misses
- [ ] Note any false positives (OCR text that isn't a brand/model)
- [ ] Document edge cases: dark devices, worn-off text, non-standard branding
- [ ] Get her reaction to the boot sequence, ambient detection, completion overlay

### 1.2 Coordinate transform calibration
- [ ] Verify green bounding boxes align correctly with detected text on iPhone
- [ ] Test on different iPhone models (SE, 14, 15 — different screen sizes)
- [ ] Adjust `FeatureOverlayPainter._transformRect()` if boxes are offset
- [ ] Handle front camera (mirror) if anyone uses it

### 1.3 Scanner UX polish
- [ ] Add proximity indicator — if largest text block < threshold, show "move closer"
  - ML Kit gives text block sizes; small blocks = device too far away
  - Visual: frame overlay dims/brightens based on distance
- [ ] Fade out "Slowly rotate" instruction after first detection (it's served its purpose)
- [ ] Add subtle scan-line or sweep animation to the boot sequence
- [ ] Tune haptic feedback — light for ambient, medium for brand, heavy for completion
- [ ] Handle landscape orientation (lock to portrait or support both)

### 1.4 Fallback robustness
- [ ] If camera permission denied, go straight to gallery picker (no error screen)
- [ ] If ML Kit fails to initialize, fall back to photo-only mode silently
- [ ] "Scan Another" from results screen should return to live scanner, not re-boot
- [ ] Timeout: after 30s with no detection, offer photo picker more prominently

---

## Phase 2: Linear Probe — Diagnostic

**Goal:** Answer the question "how much signal is already in CLIP's features for our domain?"
This tells us whether fine-tuning is worth the effort.

### 2.1 Prepare labeled dataset
- [ ] Extract (image_path, brand, model, style) tuples from device catalog + image manifest
- [ ] Split: 80% train, 20% test, stratified by brand
- [ ] Ensure each brand has ≥5 images in test set

### 2.2 Train linear probe on frozen CLIP embeddings
- [ ] Load pre-computed 512-dim CLIP embeddings from `visual_embeddings.json`
- [ ] Train scikit-learn `LogisticRegression` on brand classification
- [ ] Train separate probe on style classification (BTE/RIC/ITE/CIC)
- [ ] Report accuracy, confusion matrix, per-class precision/recall

### 2.3 Interpret results
- [ ] If brand accuracy >80% → CLIP features are useful, fine-tuning adds incremental value
- [ ] If brand accuracy <50% → features need adaptation, fine-tuning is essential
- [ ] If style accuracy is high → we can add on-device style detection to the live scanner
- [ ] Compare linear probe accuracy to the live scanner's OCR hit rate — which wins?

### 2.4 Decision point
- [ ] If linear probe is strong → skip to Phase 4 (fine-tuning becomes polish, not necessity)
- [ ] If linear probe is weak → Phase 3 becomes critical (fix the features before classifying)

---

## Phase 3: Battery Door Classifier

**Goal:** Train a tiny 4-class visual classifier for battery door sizes (10/13/312/675).
This is Seray's idea — the 4 sizes have physically distinct door shapes.

### 3.1 Data collection
- [ ] Photograph battery doors from Seray's 20 registered devices
- [ ] Need ≥10 images per class (40 total minimum, more is better)
- [ ] Mix of angles, lighting, with/without battery inserted
- [ ] Supplement with product photos from manufacturer websites

### 3.2 Model training
- [ ] Use CLIP features + linear head (transfer learning, same approach as Phase 2)
- [ ] Or: train a tiny CNN (MobileNetV3-small) from scratch on battery door crops
- [ ] Or: use Apple's Create ML (drag-and-drop, exports Core ML model)
- [ ] Evaluate all three, pick the one that works best with least complexity

### 3.3 On-device deployment
- [ ] Export model as TensorFlow Lite (Android) or Core ML (iOS)
- [ ] Integrate into live scanner: when battery door is visible, classify automatically
- [ ] Add to the T2 HUD: `BATTERY .... SIZE 13 [HIGH]`
- [ ] This is the first time the scanner identifies something CLIP and OCR can't

### 3.4 Multi-photo trigger
- [ ] When brand+model are detected but battery size isn't → prompt "Show the battery door"
- [ ] This is the first step toward the guided multi-photo flow
- [ ] The scanner adapts to what it's already found — smart sequencing

---

## Phase 4: CLIP Fine-Tuning

**Goal:** Adapt CLIP's visual representation to hearing aids, closing the domain gap.
The linear probe (Phase 2) tells us how much headroom this has.

### 4.1 Data augmentation
- [ ] Take 1,927 product-shot embeddings and augment the source images:
  - Random crops (simulate partial visibility)
  - Color jitter (simulate different lighting)
  - Gaussian blur (simulate phone camera quality)
  - Background replacement (product shots on white → clinic desk, hand-held)
  - Rotation (hearing aids are held at arbitrary angles)
- [ ] Target: 10K augmented images from 1,927 originals

### 4.2 Contrastive fine-tuning with LoRA
- [ ] Use `open_clip` + `peft` (HuggingFace) for LoRA injection
- [ ] Training pairs: (augmented_image, device_description)
  - Text: "{manufacturer} {model} {name}, {style} hearing aid, {batterySize}"
  - Generated automatically from device catalog metadata
- [ ] Freeze text encoder, fine-tune image encoder only (the text side already understands brand names)
- [ ] LoRA rank 8-16, learning rate 1e-5, train for 5-10 epochs
- [ ] Train on Mac with MPS — should take ~30 min on M-series

### 4.3 Evaluate improvement
- [ ] Re-run `test_pipeline.py` with Seray's 12 real photos using fine-tuned model
- [ ] Compare cosine similarity: before (0.518 avg) vs after
- [ ] Target: avg similarity >0.75 on correct matches
- [ ] Check for overfitting: similarity on *wrong* matches shouldn't increase

### 4.4 Deploy fine-tuned model
- [ ] Export LoRA adapter weights (~1MB)
- [ ] Update `clip_encode` Cloud Function to load base model + adapter
- [ ] Re-compute all 1,927 embeddings with fine-tuned model
- [ ] Update `device_catalog.json` with new embeddings
- [ ] Rebuild `device_db.bin` asset

### 4.5 Integrate with live scanner
- [ ] On key frames during live scan, send to Cloud Function for CLIP embedding
- [ ] Compare against device catalog in background
- [ ] When visual match confidence > threshold, add to HUD: `VISUAL MATCH: Oticon Nera2 [0.87]`
- [ ] This runs in parallel with OCR — two independent identification pathways

---

## Phase 5: Multi-Photo Guided Flow

**Goal:** Each photo optimized for a different signal's strengths.
The live scanner is phase 1 of this — it handles brand/model via OCR.

### 5.1 Flow design
- [ ] Photo 1: **Live scanner** (brand + model via OCR) — already built
- [ ] Photo 2: **Text close-up** — triggered after brand detected: "Now get a close-up of any labels"
  - Higher resolution OCR for model, serial numbers, year codes
  - Could catch regulatory text (FCC ID → year range lookup)
- [ ] Photo 3: **Battery door** — triggered after brand+model: "Show the battery door"
  - Battery door classifier (Phase 3)
  - Battery size narrows device options significantly
- [ ] Photo 4: **Confirmation** — pre-filled results screen with all 7 fields

### 5.2 Smart sequencing
- [ ] Don't always require all 4 steps — if brand+model+battery are all caught in the live scan, skip straight to confirmation
- [ ] Each additional photo request includes context: "We've identified this as an Oticon — now show us the battery door"
- [ ] The scanner should feel like it's *learning as it goes*, not running a fixed script
- [ ] Track which transitions happen in practice — maybe most devices only need 1-2 photos

### 5.3 Add tubing field
- [ ] Add tubing (slim/standard/none) to device schema and scan result model
- [ ] This is always human-input — include as a selection in the confirmation screen
- [ ] Seray specifically requested this field (Sprint 6 feedback)

### 5.4 Colour selection
- [ ] Present colour swatches based on the detected brand's colour range
  - Oticon devices come in: beige, silver, chroma beige, diamond black, terracotta
  - Different brands have different palettes
- [ ] Human taps the closest match — no AI needed, faster than typing

---

## Phase 6: Cloud Pipeline Integration

**Goal:** Merge on-device live detections with cloud pipeline results for complete identification.

### 6.1 Hybrid result fusion
- [ ] Live scanner detections (brand, model, battery) feed into the analysing screen
- [ ] Cloud pipeline (CLIP + Vision API) runs on the captured frame
- [ ] `scan_fusion.dart` merges: live detections get higher confidence if cloud confirms
- [ ] Disagreements highlighted for human review

### 6.2 Correction feedback loop
- [ ] Audiologist corrections on the results screen are already tracked (`Correction` model)
- [ ] Wire these to Firestore: `scans/{scanId}/corrections`
- [ ] Accumulate corrections → training data for future model improvements
- [ ] Track per-brand accuracy over time — which brands does the scanner struggle with?

### 6.3 Offline mode
- [ ] Live scanner works entirely on-device — no internet needed
- [ ] Cloud pipeline is enhancement, not requirement
- [ ] If offline: skip cloud step, present live detections + empty fields for human input
- [ ] Queue the image for cloud processing when connectivity returns

---

## Phase 7: Grant Demo & Impact

**Goal:** Make the scanner demo-ready for the CGD grant outcome (June 2026) and 2027 large grant bid.

### 7.1 Demo video
- [ ] Screen-record the full flow on Seray's phone with a real hearing aid
- [ ] Boot sequence → live detection → green boxes → completion → results → add to register
- [ ] This is the hero clip for the grant application

### 7.2 Metrics dashboard
- [ ] Track: scans completed, brands detected, corrections made, devices registered
- [ ] Show in admin dashboard: "34 hearing aids identified, 28 added to register, 6 redistributed"
- [ ] Impact story: "devices saved from landfill, estimated value redistributed"

### 7.3 Scale testing
- [ ] Test with 100+ hearing aid photos (source from audiologist networks)
- [ ] Benchmark: what % of brands/models does the scanner correctly identify?
- [ ] Target: >80% brand accuracy on first attempt, >60% model accuracy
- [ ] Publish results in grant progress report

---

## Technical Debt & Infrastructure

### T.1 Testing
- [ ] Unit tests for `BrandMatcher` (exact, fuzzy, contains, edge cases)
- [ ] Widget tests for boot sequence, HUD, completion overlay
- [ ] Integration test: mock ML Kit → verify detection pipeline
- [ ] E2E test: photo through full pipeline → correct ScanResult

### T.2 Performance
- [ ] Profile ML Kit frame processing time on target devices
- [ ] Ensure <100ms per frame to maintain smooth camera preview
- [ ] Consider skipping frames more aggressively on older devices

### T.3 Analytics
- [ ] Log scan events to Firebase Analytics: scan_started, brand_detected, model_detected, scan_completed, scan_abandoned
- [ ] Measure: time from camera open to first detection, detection-to-review conversion rate
- [ ] These metrics tell us if the UX is working

---

## Principles (from this session)

1. **Legibility of process** — show the AI thinking, not just the answer
2. **Prompt engineering applies to humans** — guiding the camera operator IS prompt engineering
3. **Ambient detection makes AI feel alive** — showing misses alongside hits
4. **OCR > visual similarity** for fine-grained product identification (CLIP paper, Section 6)
5. **Decompose identification into focused questions** — the field guide approach
6. **The completion ceremony matters** — making identification feel earned
7. **On-device first, cloud second** — ML Kit is fast, free, and works offline
8. **Human-in-the-loop is the architecture, not a fallback** — design for confirmation, not elimination
