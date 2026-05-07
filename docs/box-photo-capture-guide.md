# Box Photo Capture Guide

Quick guide for photographing hearing aids in their numbered storage boxes. These photos will train the scanner to identify devices more accurately.

## What you need

- Your phone (iPhone is fine)
- The numbered plastic storage boxes with hearing aids
- A plain surface (desk, table) — avoid patterned tablecloths
- Decent lighting (overhead fluorescent or daylight is fine, avoid direct sunlight)

## Photo naming

Name each photo using this pattern:

```
box{NUMBER}_{BRAND}_{ANGLE}.jpg
```

Examples:
- `box07_oticon_top.jpg`
- `box07_oticon_45deg.jpg`
- `box07_oticon_text.jpg`
- `box07_oticon_battery.jpg`
- `box12_phonak_top.jpg`

If you're unsure of the brand, use `unknown`:
- `box03_unknown_top.jpg`

## The 5 shots per device

For each box/device, take these 5 photos:

### 1. Top-down overview (`_top`)
- Box flat on the desk, lid closed
- Phone directly above, looking straight down
- Whole box visible with some desk around it
- Box number should be readable

### 2. Angled view (`_45deg`)
- Same setup, but hold the phone at roughly 45 degrees
- This gives the AI a sense of the 3D shape

### 3. Text close-up (`_text`)
- Zoom in on the side of the hearing aid where the brand/model text is
- Still inside the box — don't remove the device
- Get as close as you can while keeping it in focus

### 4. Battery door (`_battery`)
- Angle to show the battery door
- We're training a battery-size classifier — the door shape differs by size

### 5. Box number (`_boxnum`)
- The box label/number clearly visible
- This links the photo to the device register

## Tips

- **Don't remove the hearing aid from the box** — the box edges are actually useful for the AI
- **Keep the box clean** — wipe fingerprints off the clear plastic if they're heavy
- **Consistent lighting** — try to keep the same lighting for all devices in one session
- **No flash** — flash creates harsh reflections on the plastic
- **Landscape or portrait is fine** — the AI handles both

## Quick checklist

```
Box #___  Brand: ___________

[ ] top      — top-down overview, whole box visible
[ ] 45deg    — angled view showing 3D shape
[ ] text     — close-up on brand/model text
[ ] battery  — battery door visible
[ ] boxnum   — box number label clearly readable
```

## After shooting

Send the photos to Nick. The preprocessing pipeline will:
1. Detect the box rectangle in each photo
2. Correct perspective to a flat top-down view
3. Estimate and correct white balance from the box edges
4. Add the processed images to the training set
5. Retrain the brand classifier with real-device data

Estimated time: 3-5 minutes per device, ~60-90 minutes for 20 devices.
