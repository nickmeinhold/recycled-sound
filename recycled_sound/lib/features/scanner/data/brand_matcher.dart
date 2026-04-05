import 'dart:math';

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
  };

  /// Minimum text length to attempt matching. Short strings produce
  /// too many false positives with Levenshtein distance ≤ 2.
  static const _minLength = 4;

  /// Maximum Levenshtein distance for a fuzzy match.
  static const _maxDistance = 2;

  /// Attempt to match [text] against known hearing aid brands.
  ///
  /// Returns the canonical display name if matched, or null.
  /// Tries exact match first (fast path), then fuzzy match.
  static String? matchBrand(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.length < _minLength) return null;

    // Exact match (handles multi-word brands too)
    final exact = _brands[normalized];
    if (exact != null) return exact;

    // Check if the text contains a brand name as a substring
    for (final entry in _brands.entries) {
      if (normalized.contains(entry.key)) return entry.value;
      if (entry.key.contains(normalized) && normalized.length >= 5) {
        return entry.value;
      }
    }

    // Fuzzy match against single-word brands only
    // (multi-word brands like "gn resound" are too long for Levenshtein)
    for (final entry in _brands.entries) {
      if (entry.key.contains(' ')) continue; // skip multi-word
      if ((normalized.length - entry.key.length).abs() > _maxDistance) continue;
      if (_levenshtein(normalized, entry.key) <= _maxDistance) {
        return entry.value;
      }
    }

    return null;
  }

  /// Try to extract a model identifier from [text] given a known [brand].
  ///
  /// Model names on hearing aids are typically short alphanumeric strings
  /// like "Nera2", "Moxi", "Audéo", "Pure". We match against common
  /// model name patterns for each brand.
  ///
  /// Returns the cleaned model string if it looks like a model name, or null.
  static String? matchModel(String text, String brand) {
    final normalized = text.trim();
    if (normalized.length < 2 || normalized.length > 30) return null;

    // Don't match the brand itself as a model
    if (normalized.toLowerCase() == brand.toLowerCase()) return null;

    // Known model name patterns per brand.
    // These are prefixes/keywords that appear on the device body.
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
  };

  /// Standard Levenshtein distance between two strings.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use two-row optimization to save memory
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost, // substitution
        ].reduce(min);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[b.length];
  }
}
