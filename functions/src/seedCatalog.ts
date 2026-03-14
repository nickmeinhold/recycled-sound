/**
 * Seed script for the hearingAidCatalog collection.
 *
 * Run with: cd functions && npm run seed
 *
 * Each entry maps a hearing aid model to:
 * - Its known specs (from Seray's device register)
 * - Visual cues that Vision API might detect in photos
 * - OCR patterns (brand names, model numbers) to match in detected text
 */
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

interface CatalogEntry {
  brand: string;
  model: string;
  type: string;
  specs: Record<string, string>;
  visualCues: string[];
  ocrPatterns: string[];
}

const catalog: CatalogEntry[] = [
  // ── Phonak ───────────────────────────────────────────────────────────
  {
    brand: "Phonak",
    model: "Audéo P90",
    type: "RIC",
    specs: {
      year: "2021",
      batterySize: "312",
      domeType: "Closed",
      waxFilter: "CeruShield Disk",
      receiver: "M receiver",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "myPhonak",
    },
    visualCues: ["hearing aid", "behind-the-ear", "medical device", "receiver-in-canal"],
    ocrPatterns: ["phonak", "audeo", "p90", "audéo"],
  },
  {
    brand: "Phonak",
    model: "Naída P-UP",
    type: "BTE",
    specs: {
      year: "2021",
      batterySize: "675",
      domeType: "Earmold",
      waxFilter: "N/A",
      receiver: "Internal",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "myPhonak",
    },
    visualCues: ["hearing aid", "behind-the-ear", "medical device", "power aid"],
    ocrPatterns: ["phonak", "naida", "naída", "p-up"],
  },

  // ── Oticon ───────────────────────────────────────────────────────────
  {
    brand: "Oticon",
    model: "More 1",
    type: "BTE",
    specs: {
      year: "2022",
      batterySize: "13",
      domeType: "Open",
      waxFilter: "ProWax miniFit",
      receiver: "miniReceiver",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "Oticon ON",
    },
    visualCues: ["hearing aid", "behind-the-ear", "medical device"],
    ocrPatterns: ["oticon", "more", "more 1"],
  },
  {
    brand: "Oticon",
    model: "Real 1",
    type: "RIC",
    specs: {
      year: "2023",
      batterySize: "Rechargeable",
      domeType: "Open",
      waxFilter: "ProWax miniFit",
      receiver: "miniReceiver",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "Oticon Companion",
    },
    visualCues: ["hearing aid", "receiver-in-canal", "medical device"],
    ocrPatterns: ["oticon", "real", "real 1"],
  },

  // ── Signia ───────────────────────────────────────────────────────────
  {
    brand: "Signia",
    model: "Pure 7Nx",
    type: "RIC",
    specs: {
      year: "2020",
      batterySize: "312",
      domeType: "Click sleeve",
      waxFilter: "CeruGuard",
      receiver: "S receiver",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "Signia app",
    },
    visualCues: ["hearing aid", "receiver-in-canal", "medical device"],
    ocrPatterns: ["signia", "pure", "7nx", "nx"],
  },

  // ── GN Resound ───────────────────────────────────────────────────────
  {
    brand: "GN Resound",
    model: "ONE 9",
    type: "RIC",
    specs: {
      year: "2023",
      batterySize: "Rechargeable",
      domeType: "Tulip",
      waxFilter: "Wax Guard",
      receiver: "M&RIE",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "ReSound Smart 3D",
    },
    visualCues: ["hearing aid", "receiver-in-canal", "medical device"],
    ocrPatterns: ["resound", "gn resound", "one 9", "one9"],
  },

  // ── Widex ────────────────────────────────────────────────────────────
  {
    brand: "Widex",
    model: "Moment 440",
    type: "RIC",
    specs: {
      year: "2021",
      batterySize: "10",
      domeType: "Easywear",
      waxFilter: "Nanocare",
      receiver: "S receiver",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "Widex Moment",
    },
    visualCues: ["hearing aid", "receiver-in-canal", "medical device"],
    ocrPatterns: ["widex", "moment", "440", "moment 440"],
  },

  // ── Unitron ──────────────────────────────────────────────────────────
  {
    brand: "Unitron",
    model: "Moxi Vivante",
    type: "RIC",
    specs: {
      year: "2024",
      batterySize: "Rechargeable",
      domeType: "Closed",
      waxFilter: "CeruShield Disk",
      receiver: "M receiver",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "Unitron Remote Plus",
    },
    visualCues: ["hearing aid", "receiver-in-canal", "medical device"],
    ocrPatterns: ["unitron", "moxi", "vivante"],
  },

  // ── Beltone ──────────────────────────────────────────────────────────
  {
    brand: "Beltone",
    model: "Achieve 17",
    type: "RIC",
    specs: {
      year: "2023",
      batterySize: "Rechargeable",
      domeType: "Tulip",
      waxFilter: "Wax Guard",
      receiver: "M&RIE",
      programmingInterface: "Noahlink Wireless",
      techLevel: "Premium",
      remoteFT: "Yes",
      appCompatible: "Beltone HearMax",
    },
    visualCues: ["hearing aid", "receiver-in-canal", "medical device"],
    ocrPatterns: ["beltone", "achieve", "achieve 17"],
  },

  // ── Blamey & Saunders ────────────────────────────────────────────────
  {
    brand: "Blamey & Saunders",
    model: "LOF",
    type: "ITE",
    specs: {
      year: "2019",
      batterySize: "10",
      domeType: "Custom mold",
      waxFilter: "Integrated",
      receiver: "Internal",
      programmingInterface: "Bluetooth",
      techLevel: "Standard",
      remoteFT: "Yes",
      appCompatible: "IHearYou",
    },
    visualCues: ["hearing aid", "in-the-ear", "medical device", "earphone"],
    ocrPatterns: ["blamey", "saunders", "lof", "blamey & saunders"],
  },
];

async function seed() {
  const batch = db.batch();

  for (const entry of catalog) {
    const id = `${entry.brand}-${entry.model}`.toLowerCase().replace(/\s+/g, "-");
    const ref = db.collection("hearingAidCatalog").doc(id);
    batch.set(ref, entry);
  }

  await batch.commit();
  console.log(`Seeded ${catalog.length} hearing aid catalog entries.`);
  process.exit(0);
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
