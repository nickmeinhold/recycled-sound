# Recycled Sound

Community app for collecting, servicing, and redistributing donated hearing aids to people who can't afford them — primarily refugees, asylum seekers, and low-income residents in Greater Dandenong, Victoria, Australia.

A joint initiative of the **Rotary Club of Springvale City** and **Arches Audiology**.

## Status

Early development. The wireframes and design system are complete. Backend scaffolding (Firebase Cloud Functions, Firestore rules, storage rules) is in place. The Flutter app has project structure and dependencies declared but no Dart source code yet.

**What exists today:**

- HTML wireframes covering 13 screens across 4 user flows (scanner, audiologist review, donor journey, recipient application)
- Design system in Figma with colour palette, typography, and component library
- Figma plugin to regenerate wireframe screens
- Firebase Cloud Functions: hearing aid photo analysis (Vision API + catalog lookup) and role-based access control
- Firestore and Storage security rules with role-based permissions
- Hearing aid catalog seed script (10 devices across 8 brands)
- Python data pipeline: Device DNA vector store (ChromaDB) for semantic search, capability matching, and CLIP-based visual identification across ~2,200 hearing aid models
- Privacy policy
- CI workflow (Flutter analyze/test + Cloud Functions build)

## Architecture

```
├── recycled_sound/     Flutter app (iOS + Android) — pubspec only, no source yet
├── functions/          Firebase Cloud Functions (TypeScript)
│   ├── analyzeHearingAid   Vision API + catalog matcher
│   ├── setUserRole         Role-based custom claims
│   └── seedCatalog         Populate hearing aid catalog in Firestore
├── data/               Python data pipeline
│   ├── build_device_dna.py          37-dim capability vectors → ChromaDB
│   ├── build_visual_embeddings.py   CLIP image embeddings → ChromaDB
│   ├── download_images.py           Scrape hearing aid product photos
│   └── query_hearing_aids.py        CLI: search, match, need, scan
├── figma-plugin/       Figma plugin for wireframe generation
└── wireframes/         Static HTML wireframes (hosted on GitHub Pages)
```

**Backend:** Firebase (Auth, Firestore, Storage, Cloud Functions)
**AI:** Google Cloud Vision API for OCR/labels, ChromaDB + CLIP for visual identification, custom scoring for catalog matching

## User Roles

| Role | Can do |
|------|--------|
| Donor | Donate hearing aids, upload photos for AI identification |
| Recipient | Apply for a device, upload hearing assessment |
| Audiologist | Review AI-identified specs, QA devices |
| Admin | Manage matching, approve workflows, assign roles |

All recipient-facing workflows are human-mediated by design — no automation touches vulnerable users directly.

## Links

- **Wireframes:** https://nickmeinhold.github.io/recycled-sound/
- **Figma:** https://www.figma.com/design/b86mwNrRnm5lbxawcVZb64/Recycled-Sound
- **Kanban:** https://tasks.xdeca.com/boards/tqy0nch0m8tm

## License

Not yet specified.
