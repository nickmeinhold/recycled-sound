import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {ImageAnnotatorClient} from "@google-cloud/vision";

const vision = new ImageAnnotatorClient();

/** Lazy Firestore reference — avoids calling admin.firestore() before initializeApp(). */
function getDb() {
  return admin.firestore();
}

interface SpecMatch {
  value: string;
  confidence: number;
}

interface AnalysisResult {
  brand: SpecMatch;
  model: SpecMatch;
  type: SpecMatch;
  year: SpecMatch;
  batterySize: SpecMatch;
  domeType: SpecMatch;
  waxFilter: SpecMatch;
  receiver: SpecMatch;
}

interface CatalogEntry {
  brand: string;
  model: string;
  type: string;
  specs: Record<string, string>;
  visualCues: string[];
  ocrPatterns: string[];
}

/**
 * Analyzes a hearing aid photo using Vision API + catalog lookup.
 *
 * Strategy:
 * 1. Run label detection + OCR on the image
 * 2. Search OCR text for known brand/model patterns from the catalog
 * 3. Match Vision API labels against catalog visual cues
 * 4. Score confidence based on match quality:
 *    - Exact OCR brand match = 95%
 *    - Partial OCR match = 80-90%
 *    - Label-only match = 70-85%
 *    - No match = returns raw labels with low confidence
 */
/** Expected Storage URL prefix for uploaded hearing aid images. */
const STORAGE_BUCKET = "gs://recycled-sound-app.firebasestorage.app/";

export const analyzeHearingAid = functions.https.onCall(
  {region: "australia-southeast1"},
  async (request) => {
    // Require authentication — don't trust client-supplied userId
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be signed in"
      );
    }
    const userId = request.auth.uid;

    const {imageUrl} = request.data;

    if (!imageUrl) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "imageUrl is required"
      );
    }

    // Validate URL points to our Storage bucket to prevent SSRF
    if (typeof imageUrl !== "string" || !imageUrl.startsWith(STORAGE_BUCKET)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "imageUrl must be a Firebase Storage URL in the project bucket"
      );
    }

    // 1. Call Vision API — label detection + OCR in parallel
    const [labelResult, textResult] = await Promise.all([
      vision.labelDetection(imageUrl),
      vision.textDetection(imageUrl),
    ]);

    const labels = labelResult[0].labelAnnotations?.map(
      (l) => l.description?.toLowerCase() ?? ""
    ) ?? [];

    const ocrText = textResult[0].fullTextAnnotation?.text?.toLowerCase() ?? "";
    const ocrWords = ocrText.split(/\s+/).filter((w) => w.length > 1);

    // 2. Load catalog entries
    const db = getDb();
    const catalogSnap = await db.collection("hearingAidCatalog").get();
    const catalog: CatalogEntry[] = catalogSnap.docs.map(
      (doc) => doc.data() as CatalogEntry
    );

    // 3. Find best match
    const result = matchAgainstCatalog(catalog, labels, ocrWords, ocrText);

    // 4. Write scan document to Firestore
    const scanRef = db.collection("scans").doc();
    const scanDoc = {
      scanId: scanRef.id,
      userId,
      imageUrl,
      status: "completed",
      result,
      rawLabels: labels,
      rawOcrText: ocrText,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await scanRef.set(scanDoc);

    return {
      scanId: scanRef.id,
      ...result,
      rawLabels: labels,
      // Raw signals for client-side fusion engine
      rawOcrText: ocrText,
      rawOcrWords: ocrWords,
    };
  }
);

/**
 * Matches Vision API output against the hearing aid catalog.
 *
 * Scoring priority:
 * - OCR exact brand match → highest confidence
 * - OCR pattern match (model number) → high confidence
 * - Visual cue label match → medium confidence
 * - No match → returns "Unknown" with low confidence
 */
function matchAgainstCatalog(
  catalog: CatalogEntry[],
  labels: string[],
  ocrWords: string[],
  ocrText: string
): AnalysisResult {
  let bestMatch: CatalogEntry | null = null;
  let bestScore = 0;
  type MatchType = "ocr_exact" | "ocr_partial" | "label" | "none";
  let matchType: MatchType = "none";

  for (const entry of catalog) {
    let score = 0;
    let type: MatchType = "none";

    // Check OCR for brand name (exact match in text)
    const brandLower = entry.brand.toLowerCase();
    if (ocrText.includes(brandLower)) {
      score += 50;
      type = "ocr_exact";
    }

    // Check OCR patterns (model numbers, serial patterns)
    for (const pattern of entry.ocrPatterns) {
      if (ocrText.includes(pattern.toLowerCase())) {
        score += 30;
        if (type !== "ocr_exact") type = "ocr_partial";
      }
    }

    // Check visual cue labels
    for (const cue of entry.visualCues) {
      if (labels.includes(cue.toLowerCase())) {
        score += 10;
        if (type === "none") type = "label";
      }
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = entry;
      matchType = type;
    }
  }

  // Convert match quality to confidence percentages
  const brandConfidence = matchType === "ocr_exact" ? 95 :
    matchType === "ocr_partial" ? 85 : matchType === "label" ? 70 : 30;

  const modelConfidence = matchType === "ocr_exact" ? 90 :
    matchType === "ocr_partial" ? 80 : matchType === "label" ? 60 : 20;

  const specConfidence = bestMatch ? 70 : 20;

  if (bestMatch) {
    return {
      brand: {value: bestMatch.brand, confidence: brandConfidence},
      model: {value: bestMatch.model, confidence: modelConfidence},
      type: {value: bestMatch.type, confidence: specConfidence},
      year: {value: bestMatch.specs.year ?? "Unknown", confidence: specConfidence - 10},
      batterySize: {value: bestMatch.specs.batterySize ?? "Unknown", confidence: specConfidence},
      domeType: {value: bestMatch.specs.domeType ?? "Unknown", confidence: specConfidence - 15},
      waxFilter: {value: bestMatch.specs.waxFilter ?? "Unknown", confidence: specConfidence - 20},
      receiver: {value: bestMatch.specs.receiver ?? "Unknown", confidence: specConfidence - 10},
    };
  }

  // No catalog match — return what we can from raw OCR
  const possibleBrand = ocrWords.find((w) =>
    ["phonak", "oticon", "signia", "resound", "widex", "unitron", "beltone"].includes(w)
  );

  return {
    brand: {value: possibleBrand ?? "Unknown", confidence: possibleBrand ? 75 : 20},
    model: {value: "Unknown", confidence: 20},
    type: {value: inferType(labels), confidence: 50},
    year: {value: "Unknown", confidence: 10},
    batterySize: {value: "Unknown", confidence: 10},
    domeType: {value: "Unknown", confidence: 10},
    waxFilter: {value: "Unknown", confidence: 10},
    receiver: {value: "Unknown", confidence: 10},
  };
}

/** Infers hearing aid type from Vision API labels. */
function inferType(labels: string[]): string {
  const joined = labels.join(" ");
  if (joined.includes("behind") || joined.includes("bte")) return "BTE";
  if (joined.includes("receiver") || joined.includes("ric")) return "RIC";
  if (joined.includes("in-the-ear") || joined.includes("ite")) return "ITE";
  if (joined.includes("canal") || joined.includes("cic")) return "CIC";
  return "Unknown";
}
