import 'dart:typed_data';

import '../data/device_catalog.dart';
import '../data/embedding_search.dart';
import 'models/scan_result.dart';

/// Fuses CLIP visual similarity results with Vision API OCR/label signals
/// to produce a confident [ScanResult].
///
/// The fusion algorithm:
/// 1. Start with CLIP's top visual match
/// 2. Use OCR brand/model text to confirm, rerank, or override
/// 3. Use Vision API labels to validate device type (BTE/RIC/ITE/CIC)
/// 4. Pull full specs from the Device DNA catalog for the matched device
/// 5. Assign per-field confidence scores based on signal agreement
class ScanFusion {
  ScanFusion({
    required EmbeddingSearch embeddingSearch,
    required DeviceCatalog deviceCatalog,
  })  : _embeddingSearch = embeddingSearch,
        _catalog = deviceCatalog;

  final EmbeddingSearch _embeddingSearch;
  final DeviceCatalog _catalog;

  /// Known hearing aid brand names for OCR matching.
  static const _knownBrands = {
    'phonak',
    'oticon',
    'signia',
    'resound',
    'widex',
    'unitron',
    'beltone',
    'starkey',
    'bernafon',
    'sonic',
    'rexton',
    'hansaton',
    'amplifon',
    'miracle-ear',
  };

  /// Fuse CLIP embedding results with Vision API signals into a [ScanResult].
  ///
  /// [clipEmbedding] — 512-dim L2-normalised CLIP vector from Cloud Function
  /// [visionResult] — raw Vision API response (from analyzeHearingAid)
  /// [imageUrl] — Firebase Storage URL of the scanned image
  /// [scanId] — Firestore scan document ID
  ScanResult fuse({
    required Float32List clipEmbedding,
    required Map<String, dynamic> visionResult,
    required String imageUrl,
    required String scanId,
  }) {
    // 1. CLIP similarity search
    final clipResults = _embeddingSearch.findSimilar(clipEmbedding, topK: 5);

    // 2. Extract OCR signals from Vision API response
    final ocrText = (visionResult['rawOcrText'] as String? ?? '').toLowerCase();
    final rawLabels = (visionResult['rawLabels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    // 3. Detect brand and model from OCR text
    final ocrBrand = _detectBrand(ocrText);
    final ocrModel = _detectModel(ocrText, ocrBrand);

    // 4. Resolve CLIP candidates to devices
    final candidates = <_FusionCandidate>[];
    for (final result in clipResults) {
      final deviceIds = _catalog.deviceIdsForEmbedding(result.embeddingIndex);
      for (final id in deviceIds) {
        final device = _catalog.getDevice(id);
        if (device != null) {
          candidates.add(_FusionCandidate(
            device: device,
            clipScore: result.score,
          ));
        }
      }
    }

    if (candidates.isEmpty) {
      // No CLIP matches — fall back to Vision API result or unknowns
      return _buildFromVisionOnly(
        visionResult: visionResult,
        ocrBrand: ocrBrand,
        rawLabels: rawLabels,
        imageUrl: imageUrl,
        scanId: scanId,
      );
    }

    // 5. Fusion: determine best candidate considering both signals
    final best = _selectBestCandidate(candidates, ocrBrand);

    // 6. Determine signal combination for confidence scoring
    final clipHigh = best.clipScore > 0.7;
    final clipMedium = best.clipScore > 0.5;
    final ocrConfirms = ocrBrand != null &&
        best.device.manufacturer.toLowerCase() == ocrBrand.toLowerCase();
    final hasOcr = ocrBrand != null;

    // 7. Assign confidence scores based on signal matrix
    final int brandConf;
    final int modelConf;
    final int specsConf;

    if (clipHigh && ocrConfirms) {
      brandConf = 95;
      modelConf = 90;
      specsConf = 75;
    } else if (clipHigh && !hasOcr) {
      brandConf = 85;
      modelConf = 80;
      specsConf = 70;
    } else if (clipMedium && ocrConfirms) {
      brandConf = 90;
      modelConf = 75;
      specsConf = 65;
    } else if (hasOcr && !clipHigh) {
      // OCR brand detected but CLIP doesn't strongly agree
      brandConf = 80;
      modelConf = 40;
      specsConf = 30;
    } else {
      brandConf = 60;
      modelConf = 50;
      specsConf = 40;
    }

    // 8. Infer type from labels if available, otherwise use catalog
    final typeFromLabels = _inferTypeFromLabels(rawLabels);
    final typeValue = typeFromLabels ?? best.device.type;
    final typeConf = typeFromLabels != null && typeFromLabels == best.device.type
        ? specsConf + 15
        : specsConf;

    // When OCR found a model match in the catalog, prefer it over CLIP's guess
    final resolvedModel = ocrModel ?? best.device.model;
    // If OCR matched a model, look up the full device for richer specs
    final ocrDevice = ocrBrand != null && ocrModel != null
        ? _catalog.findByName(ocrBrand, ocrModel)
        : null;
    final specDevice = ocrDevice ?? best.device;

    // Boost model confidence when OCR matched a catalog model
    final resolvedModelConf =
        ocrDevice != null ? (modelConf + 20).clamp(0, 95) : modelConf;

    return ScanResult(
      scanId: scanId,
      imageUrl: imageUrl,
      brand: SpecField(
        value: hasOcr && !ocrConfirms
            ? ocrBrand // Trust OCR brand when it disagrees with CLIP
            : best.device.manufacturer,
        confidence: brandConf,
      ),
      model: SpecField(value: resolvedModel, confidence: resolvedModelConf),
      type: SpecField(value: typeValue, confidence: typeConf.clamp(0, 100)),
      year: SpecField(
        value: specDevice.year,
        confidence: specDevice.year == 'Unknown' ? 20 : specsConf - 5,
      ),
      batterySize: SpecField(
        value: specDevice.batterySize,
        confidence:
            specDevice.batterySize == 'Unknown' ? 20 : specsConf,
      ),
      domeType: SpecField(value: 'Unknown', confidence: 25),
      waxFilter: SpecField(value: 'Unknown', confidence: 25),
      receiver: SpecField(value: 'Unknown', confidence: 25),
      rawLabels: rawLabels,
    );
  }

  /// Select the best candidate considering CLIP score and OCR brand match.
  _FusionCandidate _selectBestCandidate(
    List<_FusionCandidate> candidates,
    String? ocrBrand,
  ) {
    if (ocrBrand == null) {
      // No OCR — trust CLIP ranking
      return candidates.first;
    }

    // If OCR brand matches a CLIP candidate, promote it
    final brandLower = ocrBrand.toLowerCase();
    for (final candidate in candidates) {
      if (candidate.device.manufacturer.toLowerCase() == brandLower) {
        return candidate;
      }
    }

    // OCR brand doesn't match any CLIP candidate — still use top CLIP
    return candidates.first;
  }

  /// Detect a known hearing aid brand in OCR text.
  ///
  /// Tries exact match first, then fuzzy match (Levenshtein distance ≤ 1)
  /// to handle common single-character OCR errors on tiny printed text
  /// (e.g. "oricon" → "oticon", "phonac" → "phonak").
  String? _detectBrand(String ocrText) {
    // Exact match first
    for (final brand in _knownBrands) {
      if (ocrText.contains(brand)) {
        return brand[0].toUpperCase() + brand.substring(1);
      }
    }

    // Fuzzy match: check each OCR word against brands
    final words = ocrText.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 4) continue;
      for (final brand in _knownBrands) {
        if (brand.length < 4) continue;
        if ((word.length - brand.length).abs() > 1) continue;
        if (_levenshtein(word, brand) <= 1) {
          return brand[0].toUpperCase() + brand.substring(1);
        }
      }
    }

    return null;
  }

  /// Detect a model name from OCR text by fuzzy matching against the catalog.
  ///
  /// When [brand] is known, searches only that brand's models.
  /// Handles common OCR errors like "movi" → "moxi", "nera2 pr" → "nera2 pro".
  String? _detectModel(String ocrText, String? brand) {
    if (!_catalog.isLoaded) return null;

    final words = ocrText.split(RegExp(r'\s+'));
    final candidates = <String>[];

    // Collect model-like words (contain digits or are 3+ chars)
    for (final word in words) {
      if (word.length >= 3 &&
          !_knownBrands.contains(word) &&
          _levenshteinAnyBrand(word) > 1) {
        candidates.add(word);
      }
    }
    if (candidates.isEmpty) return null;

    // If we know the brand, search that brand's models in the catalog
    if (brand != null) {
      final brandDeviceIds = _catalog.findByBrand(brand);
      String? bestModel;
      var bestScore = 999;

      for (final id in brandDeviceIds) {
        final device = _catalog.getDevice(id);
        if (device == null) continue;

        // Check model name words against OCR candidates
        final modelWords = device.model.toLowerCase().split(RegExp(r'[\s\-]+'));
        for (final modelWord in modelWords) {
          if (modelWord.length < 3) continue;
          for (final candidate in candidates) {
            final dist = _levenshtein(candidate, modelWord);
            if (dist <= 1 && dist < bestScore) {
              bestScore = dist;
              bestModel = device.model;
            }
          }
        }
      }

      if (bestModel != null) return bestModel;
    }

    // Return raw candidates joined as a hint
    return candidates.join(' ');
  }

  /// Check if a word is within Levenshtein distance 1 of any known brand.
  int _levenshteinAnyBrand(String word) {
    var minDist = 999;
    for (final brand in _knownBrands) {
      final dist = _levenshtein(word, brand);
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  /// Levenshtein edit distance between two strings.
  static int _levenshtein(String s1, String s2) {
    if (s1.length < s2.length) return _levenshtein(s2, s1);
    if (s2.isEmpty) return s1.length;

    var prev = List.generate(s2.length + 1, (i) => i);
    for (var i = 0; i < s1.length; i++) {
      final curr = [i + 1];
      for (var j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        curr.add([prev[j + 1] + 1, curr[j] + 1, prev[j] + cost].reduce(
          (a, b) => a < b ? a : b,
        ));
      }
      prev = curr;
    }
    return prev[s2.length];
  }

  /// Infer hearing aid type from Vision API labels.
  String? _inferTypeFromLabels(List<String> labels) {
    final joined = labels.join(' ').toLowerCase();
    if (joined.contains('behind') || joined.contains('bte')) {
      return 'BTE (Behind-the-Ear)';
    }
    if (joined.contains('receiver') || joined.contains('ric')) {
      return 'RIC (Receiver-in-Canal)';
    }
    if (joined.contains('in-the-ear') || joined.contains('ite')) {
      return 'ITE (In-the-Ear)';
    }
    if (joined.contains('canal') || joined.contains('cic')) {
      return 'CIC (Completely-in-Canal)';
    }
    return null;
  }

  /// Build a result when no CLIP matches are found — use Vision API only.
  ScanResult _buildFromVisionOnly({
    required Map<String, dynamic> visionResult,
    required String? ocrBrand,
    required List<String> rawLabels,
    required String imageUrl,
    required String scanId,
  }) {
    // Try to use the existing Vision API catalog match
    final visionBrand = visionResult['brand'] as Map<String, dynamic>?;
    final visionModel = visionResult['model'] as Map<String, dynamic>?;

    final brandValue =
        ocrBrand ?? visionBrand?['value'] as String? ?? 'Unknown';
    final brandConf = ocrBrand != null
        ? 75
        : (visionBrand?['confidence'] as int?) ?? 20;

    // Try fuzzy model matching from OCR text
    final ocrText = (visionResult['rawOcrText'] as String? ?? '').toLowerCase();
    final ocrModel = _detectModel(ocrText, ocrBrand);
    final ocrDevice = ocrBrand != null && ocrModel != null
        ? _catalog.findByName(ocrBrand, ocrModel)
        : null;

    final modelValue = ocrModel ??
        visionModel?['value'] as String? ??
        'Unknown';
    final modelConf = ocrDevice != null
        ? 70
        : (visionModel?['confidence'] as int?) ?? 15;

    return ScanResult(
      scanId: scanId,
      imageUrl: imageUrl,
      brand: SpecField(value: brandValue, confidence: brandConf),
      model: SpecField(value: modelValue, confidence: modelConf),
      type: SpecField(
        value: _inferTypeFromLabels(rawLabels) ?? 'Unknown',
        confidence: 50,
      ),
      year: SpecField(value: 'Unknown', confidence: 10),
      batterySize: SpecField(value: 'Unknown', confidence: 10),
      domeType: SpecField(value: 'Unknown', confidence: 10),
      waxFilter: SpecField(value: 'Unknown', confidence: 10),
      receiver: SpecField(value: 'Unknown', confidence: 10),
      rawLabels: rawLabels,
    );
  }
}

/// Internal candidate for fusion ranking.
class _FusionCandidate {
  const _FusionCandidate({
    required this.device,
    required this.clipScore,
  });

  final DeviceEntry device;
  final double clipScore;
}
