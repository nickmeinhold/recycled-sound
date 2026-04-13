# Linear Probe Results — CLIP Frozen Embeddings

**Date:** 2026-04-08
**Model:** ViT-B/32 (laion2b_s34b_b79k)
**Embeddings:** 1,927 × 512-dim from product shots

## Summary

| Task | Accuracy | 5-fold CV | Classes | Samples |
|------|----------|-----------|---------|--------|
| Brand | 69.7% | 71.6% ± 1.6% | 16 | 1927 |
| Style | 91.2% | 92.2% ± 1.0% | 6 | 1927 |
| Battery | 78.7% | 78.4% ± 1.5% | 5 | 1925 |

## Decision Gate

**Brand accuracy: 69.7% → Mixed signal.**

CLIP features capture some brand structure but not enough for reliable classification. LoRA fine-tuning on hearing aid product shots is worth investigating.

**Next:** Run LoRA experiment (Step 6 of forward plan) before investing further in CLIP-based features.

## Most Confused Pairs

These confusions reveal how CLIP's internal representation groups hearing aids — and whether those groupings reflect visual similarity, OEM relationships, or noise.

### Brand

- **ReSound** misclassified as **Hearing Australia**: 13×
- **Unitron** misclassified as **Specsavers Advance**: 11×
- **Hearing Australia** misclassified as **ReSound**: 11×
- **Signia** misclassified as **Specsavers Advance**: 9×
- **Specsavers Advance** misclassified as **ReSound**: 6×

### Style

- **BTE** misclassified as **RIC**: 10×
- **ITC** misclassified as **ITE**: 5×
- **RIC** misclassified as **BTE**: 4×
- **IIC** misclassified as **CIC**: 4×
- **IIC** misclassified as **RIC**: 3×

### Battery

- **312** misclassified as **Rechargeable**: 27×
- **13** misclassified as **Rechargeable**: 17×
- **Rechargeable** misclassified as **312**: 9×
- **675** misclassified as **Rechargeable**: 8×
- **13** misclassified as **312**: 5×

## Brand — Detailed Results

Accuracy: 69.7% | 5-fold CV: 71.6% ± 1.6% | 16 classes, 1927 samples

| Class | Precision | Recall | F1 | Support |
|-------|-----------|--------|----|---------|
| Amplifon | 0.0% | 0.0% | 0.0% | 2 |
| Beltone | 88.2% | 57.7% | 69.8% | 26 |
| Bernafon | 84.0% | 95.5% | 89.4% | 44 |
| Hansaton | 100.0% | 16.7% | 28.6% | 6 |
| Hearing Australia | 37.5% | 53.6% | 44.1% | 28 |
| Jabra | 0.0% | 0.0% | 0.0% | 8 |
| Oticon | 84.2% | 97.0% | 90.1% | 33 |
| Philips | 100.0% | 45.5% | 62.5% | 11 |
| Phonak | 97.1% | 94.4% | 95.8% | 36 |
| ReSound | 46.9% | 62.2% | 53.5% | 37 |
| Rexton | 91.7% | 50.0% | 64.7% | 22 |
| Signia | 71.4% | 64.5% | 67.8% | 31 |
| Specsavers Advance | 34.5% | 51.4% | 41.3% | 37 |
| Starkey | 100.0% | 83.3% | 90.9% | 12 |
| Unitron | 75.0% | 35.3% | 48.0% | 17 |
| Widex | 94.7% | 100.0% | 97.3% | 36 |

## Style — Detailed Results

Accuracy: 91.2% | 5-fold CV: 92.2% ± 1.0% | 6 classes, 1927 samples

| Class | Precision | Recall | F1 | Support |
|-------|-----------|--------|----|---------|
| BTE | 95.5% | 91.5% | 93.4% | 117 |
| CIC | 89.2% | 86.8% | 88.0% | 38 |
| IIC | 92.3% | 63.2% | 75.0% | 19 |
| ITC | 92.3% | 82.8% | 87.3% | 29 |
| ITE | 85.2% | 93.9% | 89.3% | 49 |
| RIC | 90.3% | 97.0% | 93.5% | 134 |

## Battery — Detailed Results

Accuracy: 78.7% | 5-fold CV: 78.4% ± 1.5% | 5 classes, 1925 samples

| Class | Precision | Recall | F1 | Support |
|-------|-----------|--------|----|---------|
| 10 | 94.0% | 87.0% | 90.4% | 54 |
| 13 | 80.6% | 53.2% | 64.1% | 47 |
| 312 | 82.7% | 75.0% | 78.6% | 108 |
| 675 | 0.0% | 0.0% | 0.0% | 12 |
| Rechargeable | 72.8% | 91.5% | 81.1% | 164 |

