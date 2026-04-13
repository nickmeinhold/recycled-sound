import 'dart:math';

/// Result of a brand match, including how the match was made.
class BrandMatchResult {
  const BrandMatchResult({
    required this.displayName,
    required this.distance,
    required this.matchType,
  });

  final String displayName;

  /// Levenshtein distance (0 = exact).
  final int distance;

  /// How the match was found: 'EXACT', 'CONTAINS', or 'FUZZY'.
  final String matchType;

  /// Human-readable confidence label for the HUD.
  String get confidenceLabel => switch (matchType) {
        'EXACT' => 'EXACT',
        'CONTAINS' => 'EXACT',
        'FUZZY' => 'FUZZY \u2264$distance',
        _ => '',
      };
}

/// Fuzzy text matcher for hearing aid brands and models.
///
/// Uses Levenshtein distance to handle OCR misreads like "oricon" → "oticon"
/// and "movi" → "moxi". Threshold of 2 catches single-character substitutions,
/// insertions, and deletions — the most common OCR failure modes on small
/// printed text.
class BrandMatcher {
  BrandMatcher._();

  /// Known hearing aid manufacturers, lowercase → display name.
  ///
  /// Includes aliases for common OCR misreads and legacy brand names.
  static const _brands = <String, String>{
    // Primary brands (from our device catalog)
    'oticon': 'Oticon',
    'phonak': 'Phonak',
    'signia': 'Signia',
    'widex': 'Widex',
    'resound': 'ReSound',
    'starkey': 'Starkey',
    'unitron': 'Unitron',
    'bernafon': 'Bernafon',
    'beltone': 'Beltone',
    'rexton': 'Rexton',
    'hansaton': 'Hansaton',
    'jabra': 'Jabra',
    'philips': 'Philips',
    'amplifon': 'Amplifon',
    // Aliases and legacy names
    'siemens': 'Signia', // Siemens hearing aids rebranded to Signia
    'gn resound': 'ReSound',
    'gn hearing': 'ReSound',
    'blamey saunders': 'Blamey Saunders',
    'blamey & saunders': 'Blamey Saunders',
    'specsavers': 'Specsavers Advance',
    'hearing australia': 'Hearing Australia',
    // Demant group brands
    'sonic': 'Sonic',
    'sonic innovations': 'Sonic',
  };

  /// Minimum text length to attempt matching. Short strings produce
  /// too many false positives with Levenshtein distance ≤ 2.
  static const _minLength = 4;

  /// Maximum Levenshtein distance for a fuzzy match.
  static const _maxDistance = 2;

  /// Simple brand match (backwards compatible) — returns display name or null.
  static String? matchBrand(String text) {
    return matchBrandDetailed(text)?.displayName;
  }

  /// Detailed brand match — returns match result with confidence info.
  static BrandMatchResult? matchBrandDetailed(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.length < _minLength) return null;

    // Exact match (handles multi-word brands too)
    final exact = _brands[normalized];
    if (exact != null) {
      return BrandMatchResult(
          displayName: exact, distance: 0, matchType: 'EXACT');
    }

    // Check if the text contains a brand name as a substring
    for (final entry in _brands.entries) {
      if (normalized.contains(entry.key)) {
        return BrandMatchResult(
            displayName: entry.value, distance: 0, matchType: 'CONTAINS');
      }
      if (entry.key.contains(normalized) && normalized.length >= 5) {
        return BrandMatchResult(
            displayName: entry.value, distance: 0, matchType: 'CONTAINS');
      }
    }

    // Fuzzy match against single-word brands only
    for (final entry in _brands.entries) {
      if (entry.key.contains(' ')) continue;
      if ((normalized.length - entry.key.length).abs() > _maxDistance) continue;
      final dist = _levenshtein(normalized, entry.key);
      if (dist <= _maxDistance) {
        return BrandMatchResult(
            displayName: entry.value, distance: dist, matchType: 'FUZZY');
      }
    }

    return null;
  }

  /// Reverse-lookup: given OCR text, check if it matches a known model
  /// across ALL brands. Returns (brand, modelText) if found.
  ///
  /// This allows model text like "moxi2 kiss" to identify both the brand
  /// (Unitron) and the model, even when the brand name isn't visible.
  ///
  /// More conservative than brand-specific matching — only matches
  /// distinctive model names (5+ chars) to avoid false positives like
  /// random text matching "nera", "key", "own", etc.
  static ({String brand, String model})? matchModelAnyBrand(String text) {
    final normalized = text.trim();
    if (normalized.length < 4 || normalized.length > 30) return null;
    final lower = normalized.toLowerCase();

    for (final entry in _modelPatterns.entries) {
      final brandKey = entry.key;
      for (final pattern in entry.value) {
        // Exact substring: 4+ chars is reliable (catches "moxi" in "moxi2 kiss")
        if (pattern.length >= 4 && lower.contains(pattern)) {
          final brandName = _brands[brandKey];
          if (brandName == null) continue;
          return (brand: brandName, model: normalized);
        }
        // Fuzzy: 5+ chars only to avoid false positives on short words
        if (pattern.length >= 5 && _levenshtein(lower, pattern) <= 1) {
          final brandName = _brands[brandKey];
          if (brandName == null) continue;
          return (brand: brandName, model: normalized);
        }
      }
    }

    return null;
  }

  /// Try to extract a model identifier from [text] given a known [brand].
  static String? matchModel(String text, String brand) {
    final normalized = text.trim();
    if (normalized.length < 2 || normalized.length > 30) return null;

    // Don't match the brand itself as a model
    if (normalized.toLowerCase() == brand.toLowerCase()) return null;

    final patterns = _modelPatterns[brand.toLowerCase()];
    if (patterns == null) return null;

    final lower = normalized.toLowerCase();
    for (final pattern in patterns) {
      if (lower.contains(pattern)) return normalized;
      if (_levenshtein(lower, pattern) <= 1) return normalized;
    }

    return null;
  }

  /// Common model name fragments by brand (lowercase).
  static const _modelPatterns = <String, List<String>>{
    'oticon': [
      'own', 'real', 'more', 'opn', 'xceed', 'play', 'siya', 'ruby',
      'nera', 'alta', 'ria', 'intent', 'zircon',
    ],
    'phonak': [
      'audeo', 'audéo', 'naida', 'naída', 'bolero', 'virto', 'sky',
      'paradise', 'lumity', 'infinio', 'slim',
    ],
    'signia': [
      'pure', 'styletto', 'silk', 'motion', 'insio', 'augmented',
      'active', 'intuis', 'prompt',
    ],
    'widex': [
      'moment', 'evoke', 'beyond', 'unique', 'dream', 'super',
      'smartric', 'magnify',
    ],
    'resound': [
      'one', 'omnia', 'linx', 'enzo', 'key', 'nexia',
    ],
    'starkey': [
      'genesis', 'evolv', 'livio', 'muse', 'halo',
    ],
    'unitron': [
      'vivante', 'blu', 'discover', 'moxi', 'stride', 'insera',
    ],
    'bernafon': [
      'encanta', 'alpha', 'viron', 'zerena', 'leox',
    ],
    'beltone': [
      'achieve', 'imagine', 'amaze', 'rely',
    ],
    'sonic': [
      'captivate', 'enchant', 'celebrate', 'cheer', 'bliss',
      'joy', 'charm', 'radiance', 'pep', 'flip',
    ],
  };

  /// Standard Levenshtein distance between two strings.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce(min);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[b.length];
  }
}
