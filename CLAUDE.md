# Recycled Sound

## What This Is
Recycled Sound is a community app that collects, services, and redistributes donated hearing aids to people who can't afford them — primarily refugees, asylum seekers, and low-income residents in Greater Dandenong, Victoria.

The hero feature is a **Google Lens-style scanner** that identifies hearing aid brand, model, specs, and capabilities from a photo. The scanner is a **human-in-the-loop tool** — it pre-fills what it can, then the audiologist confirms/corrects.

## Partners
- **Rotary Club of Springvale City** — applicant org, volunteers, governance
- **Arches Audiology** (Seray Lim, Clinical Audiologist) — clinical partner, QA, device fitting
- **University of Melbourne & La Trobe** — audiology student volunteers

## Key Decision: Human in the Loop
**All recipient-facing workflows must be human-mediated.** No automation touches recipients (asylum seekers, refugees) directly until manual workflows are tested and proven safe. This is a firm project decision from Sprint 6 (Feb 2026).

## App User Types
- **Donor** — donates hearing aids, optionally connects with recipient
- **Recipient** — applies for a device, uploads hearing assessment
- **Audiologist** — reviews AI-identified specs, confirms tech level, marks QA passed
- **Admin** — manages matching, approves workflows, moderates messaging
- **Psychologist** — directory listing (Sprint 3)
- **Overseas Partner Organisation** — Phase 2

## Device Register
~20 devices already collected. The register tracks 26 fields per device:
- Brand, model, type, year, serial numbers
- Battery size, dome type, wax filter, receiver
- Programming interface (HiPro, Noahlink, Noahlink Wireless)
- Tech level, gain range, fitting range
- Remote fine-tuning capability, app compatibility, Auracast readiness
- Charger details, accessories, QA status, servicing costs

Brands on register: Unitron, Phonak, Oticon, Signia, GN Resound, Beltone, Widex, Blamey & Saunders.

## Scanner Pipeline

### Architecture
Hybrid **CLIP visual search** + **Google Vision API** (OCR + labels) → **on-device fusion engine**.

Two Cloud Functions fire in parallel:
- `clip_encode` (Python, ViT-B-32 laion2b) → 512-dim embedding → cosine similarity against 1,927 pre-computed embeddings
- `analyzeHearingAid` (TypeScript) → Vision API label + text detection → catalog matching

Results fused on-device by `scan_fusion.dart` using a confidence matrix.

### E2E Test Results (2026-03-22)
Tested with 12 real photos from Seray's device register. Key findings:
- **OCR is the strongest signal** — correctly ID'd Oticon Nera2 Pro and Unitron Moxi S-R from device body text
- **CLIP visual search has a domain gap** — avg similarity 0.518 (all LOW). Product shots ≠ real-world hand-held photos
- **Fuzzy matching essential** — OCR reads "oricon" not "oticon", "movi" not "moxi". Levenshtein ≤ 1 catches these

### Audiologist's 7-Field Model (from Seray)
What the scanner should capture per device:
1. **Make** — AI via OCR ✓
2. **Model** — AI via OCR ✓
3. **Style** (BTE/RIC/ITE/CIC) — needs human input
4. **Tubing** (slim/standard/none) — needs human input (NEW field, not yet in schema)
5. **Battery or Rechargeable** — needs human confirmation
6. **Battery size** (10/13/312/675) — potential AI task (battery door shapes are visually distinct)
7. **Colour** — present swatches for human to confirm

### Test Harness
`data/test_pipeline.py` — runs photos through both CLIP and Vision API locally, compares results. Usage:
```
python3 data/test_pipeline.py /path/to/photo.jpg        # single photo
python3 data/test_pipeline.py /path/to/folder/           # batch mode
python3 data/test_pipeline.py /path/to/folder/ --json    # machine-readable
```
Requires: `google-cloud-vision`, `open_clip`, `torch`, `chromadb`. Uses ADC credentials — set `quota_project_id` to `recycled-sound-app`.

### Next Steps for Scanner
- [ ] Multi-photo flow: overview → text close-up → (battery door?) → confirmation screen
- [ ] Add tubing field to device schema
- [ ] Battery door visual classifier (4 classes, distinct shapes)
- [ ] Address CLIP domain gap (data augmentation or fine-tuning)

## What's Been Built

### Wireframes (13 screens, 4 flows) — completed 2026-03-12
- **Flow 1: Hearing Aid Scanner** — Home → Camera → AI Analysing → AI Results
- **Flow 2: Audiologist Review** — QA Queue → Review Detail → Device Ready
- **Flow 3: Donor Journey** — Signup → Donation Form → Confirmation
- **Flow 4: Recipient Application** — Hearing Needs → Situation → Status Tracker

### Design System (Figma)
- 15-colour palette with paint styles
- Typography scale (H1–H4, Body, Caption, Label, Chip, Button, Nav)
- UI components: Button (3 variants), Chip (5 variants), Input Field, Spec Row, Toggle, Confidence Row, List Item, Annotation, Nav Bar, Tab Bar, Progress Dots

### Deliverables
- **HTML wireframes**: https://nickmeinhold.github.io/recycled-sound/
- **Privacy policy**: `docs/privacy.html` (also at project root)
- **Figma file**: https://www.figma.com/design/b86mwNrRnm5lbxawcVZb64/Recycled-Sound
- **Figma plugin**: `figma-plugin/` — run in Figma Desktop to regenerate all screens
- **GitHub repo**: https://github.com/nickmeinhold/recycled-sound

## Sprint Roadmap

### Sprint 0 (current) — Define & Design
- [x] Wireframes and design system
- [ ] Define User Types — roles/permissions matrix
- [ ] Define Core User Journeys — flow diagrams (wireframes partially done)
- [ ] Define MVP Scope — locked feature list

### Sprint 1 — Core Build
- [ ] User Authentication (email/password, role selection, profile)
- [ ] Donor Listing Module (upload device, photos, donation intent, connect toggle)
- [ ] Recipient Application Module (apply, upload docs, location, hearing loss)
- [ ] Admin Dashboard (view listings, view applications, match, change status)

### Sprint 2 — Matching & Tracking
- [ ] Matching Logic (manual first — admin selects, system notifies)
- [ ] Messaging (secure in-app chat, post-match only, admin moderation)
- [ ] Status Tracking (Donated → Reprogramming → Ready → Shipped → Delivered → Active)

### Sprint 3 — Directories
- [ ] Audiologist Directory (location search, low-cost filter, telehealth indicator)
- [ ] Auditory Training Referrals
- [ ] Psychologist Directory (deaf/HoH specialisation, telehealth vs in-person)

### Sprint 4 — Legal & Safety
- [ ] Medical disclaimer, donation liability waiver, device condition disclaimer
- [ ] Privacy policy (GDPR + Australian Privacy Act)
- [ ] Identity verification, fraud prevention, abuse reporting

### Sprint 5 — Impact
- [ ] E-waste Metrics Dashboard (devices saved, landfill reduction, countries impacted)
- [ ] Impact Stories (donor-recipient testimonials, case studies)

## External Systems
- **Kanban board**: https://tasks.xdeca.com/boards/tqy0nch0m8tm
- **Knowledge base**: https://kb.xdeca.com/collection/recycled-sound-9y9o7u1sZ1
- **Arches Audiology**: https://www.archesaudiology.com.au/
- **Grant portal**: https://www.greaterdandenong.vic.gov.au/grants

## Funding
- Applied for CGD Medium Grant ($10k) — outcome pending June 2026
- Rotary co-contribution: $2k
- Large grants (up to $50k) opening 2027
- Total project value with in-kind: $27,240

## Way Forward (as of 2026-03-23)
1. **Scanner pipeline tested** — OCR works, CLIP has domain gap, fuzzy matching added
2. **Seray's feedback incorporated** — 7-field audiologist model, multi-photo flow confirmed
3. **Next: multi-photo capture flow** — overview → text → battery door → confirmation
4. **Next: add tubing field** to device schema and scan result model
5. **Next: battery door classifier** — 4-class visual problem (sizes 10/13/312/675)
6. **Grant outcome June 2026** shapes resourcing; working app strengthens 2027 large grant bid
7. **TestFlight** — v0.1.0 live with external testers; v0.2.0 (build 3) waiting for Beta App Review since Mar 31
