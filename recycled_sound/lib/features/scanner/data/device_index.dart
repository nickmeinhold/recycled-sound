import 'dart:async';

import 'package:flutter/foundation.dart';

import 'brand_matcher.dart';
import 'device_catalog.dart';

/// Fields that can be narrowed / auto-locked during a scan.
enum DeviceField {
  brand,
  model,
  type, // BTE, RIC, ITE, CIC, ITC, IIC
  batterySize, // Size 10, 13, 312, 675, Rechargeable
  power, // Battery | Rechargeable (derived from batterySize)
  tubing, // Standard | Slim | None (derived from type)
  colour, // Not in catalog — always open
}

/// How a field value was determined.
enum DetectionSource { ocr, neuralNet, catalog, inferred, manual }

/// A single locked field with its value and provenance.
class LockedField {
  const LockedField({
    required this.value,
    required this.source,
    this.confidence,
    required this.lockedAt,
  });

  final String value;
  final DetectionSource source;

  /// e.g. "EXACT", "85% AI", "CATALOG"
  final String? confidence;
  final DateTime lockedAt;
}

/// Immutable snapshot of detection state.
class DetectionState {
  const DetectionState({
    required this.locked,
    required this.candidateCount,
  });

  /// Locked fields and their values.
  final Map<DeviceField, LockedField> locked;

  /// How many devices remain in the candidate set.
  final int candidateCount;

  bool isLocked(DeviceField f) => locked.containsKey(f);
  String? valueOf(DeviceField f) => locked[f]?.value;
  LockedField? fieldOf(DeviceField f) => locked[f];
  int get filledCount => locked.length;

  static const empty = DetectionState(
    locked: {},
    candidateCount: 0,
  );
}

/// Catalog-driven elimination tree for hearing aid identification.
///
/// Builds inverted indexes from [DeviceCatalog] at load time. Each detection
/// signal narrows the candidate set via [narrow]. Fields auto-lock when
/// only one possible value remains. [possibleValues] feeds slot reel
/// animations with dynamically shrinking candidate lists.
///
/// Layers on top of [BrandMatcher] — uses its fuzzy matching for OCR text,
/// then maps results to catalog device IDs for elimination.
class DeviceIndex {
  DeviceIndex._();

  /// Singleton instance — loaded once alongside DeviceCatalog.
  static final DeviceIndex instance = DeviceIndex._();

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ── Inverted indexes (built at load time) ────────────────────────────

  /// brand (lowercase, normalized) → device IDs
  final _brandIndex = <String, Set<String>>{};

  /// model text (lowercase) → device IDs
  final _modelIndex = <String, Set<String>>{};

  /// device type prefix (lowercase, e.g. "bte") → device IDs
  final _typeIndex = <String, Set<String>>{};

  /// battery size (lowercase, e.g. "size 312") → device IDs
  final _batteryIndex = <String, Set<String>>{};

  /// All device IDs in the catalog.
  final _allDeviceIds = <String>{};

  /// device ID → DeviceEntry for quick lookups.
  final _devices = <String, DeviceEntry>{};

  /// Brand alias map: normalized alias → canonical display name.
  /// Merged from BrandMatcher.brands and catalog manufacturers.
  final _brandAliases = <String, String>{};

  // ── Live scan state ──────────────────────────────────────────────────

  var _candidates = <String>{};
  final _locked = <DeviceField, LockedField>{};
  final _stateController = StreamController<DetectionState>.broadcast();

  /// Build all inverted indexes from the catalog and BrandMatcher patterns.
  Future<void> load(DeviceCatalog catalog) async {
    if (_loaded) return;
    if (!catalog.isLoaded) {
      debugPrint('DeviceIndex: catalog not loaded yet');
      return;
    }

    // Build brand alias map from BrandMatcher
    for (final entry in BrandMatcher.brands.entries) {
      _brandAliases[entry.key] = entry.value;
    }

    // Index each device
    for (final device in catalog.allDevices) {
      final id = device.id;
      _allDeviceIds.add(id);
      _devices[id] = device;

      // Brand index — normalize to lowercase
      final brandKey = device.manufacturer.toLowerCase();
      _brandIndex.putIfAbsent(brandKey, () => {}).add(id);

      // Also index via aliases pointing to this brand
      final canonicalBrand = device.manufacturer;
      for (final alias in BrandMatcher.brands.entries) {
        if (alias.value == canonicalBrand) {
          _brandIndex.putIfAbsent(alias.key, () => {}).add(id);
        }
      }

      // Model index — index both the model code and full name
      final modelKey = device.model.toLowerCase();
      _modelIndex.putIfAbsent(modelKey, () => {}).add(id);

      // Index individual words from the full name (for fuzzy model matching)
      final nameWords = device.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3);
      for (final word in nameWords) {
        // Skip the brand name itself as a model index entry
        if (word == brandKey) continue;
        _modelIndex.putIfAbsent(word, () => {}).add(id);
      }

      // Type index — extract prefix (BTE, RIC, ITE, etc.)
      final typePrefix = _extractTypePrefix(device.type);
      if (typePrefix != null) {
        _typeIndex.putIfAbsent(typePrefix, () => {}).add(id);
      }

      // Battery index
      final batteryKey = device.batterySize.toLowerCase();
      if (batteryKey.isNotEmpty && batteryKey != 'unknown') {
        _batteryIndex.putIfAbsent(batteryKey, () => {}).add(id);
      }
    }

    // Merge BrandMatcher model patterns as loose associations.
    // E.g., "ino" → all Oticon devices (since Ino isn't in catalog model field
    // but IS a real Oticon model).
    for (final entry in BrandMatcher.modelPatterns.entries) {
      final brandName = BrandMatcher.brands[entry.key];
      if (brandName == null) continue;
      final brandDevices = _brandIndex[entry.key] ?? {};

      for (final pattern in entry.value) {
        // Only add if not already indexed from catalog
        if (!_modelIndex.containsKey(pattern)) {
          _modelIndex[pattern] = Set.from(brandDevices);
        }
      }
    }

    _candidates = Set.from(_allDeviceIds);
    _loaded = true;
    debugPrint(
      'DeviceIndex: loaded ${_allDeviceIds.length} devices, '
      '${_brandIndex.length} brand keys, '
      '${_modelIndex.length} model keys, '
      '${_typeIndex.length} type keys, '
      '${_batteryIndex.length} battery keys',
    );
  }

  /// Reset to full candidate set. Call at the start of each new scan.
  void reset() {
    _candidates = Set.from(_allDeviceIds);
    _locked.clear();
    _emitState();
  }

  /// Narrow candidates by a detected field value.
  ///
  /// If narrowing would produce 0 candidates (device not in catalog),
  /// enters **open mode**: locks the field with [DetectionSource.ocr]
  /// but keeps the previous candidate set intact.
  ///
  /// After narrowing, auto-locks any other fields that have only one
  /// remaining possible value.
  DetectionState narrow(
    DeviceField field,
    String value, {
    DetectionSource source = DetectionSource.ocr,
    String? confidence,
  }) {
    // Don't re-narrow a field to the same value
    if (_locked[field]?.value == value) return state;

    final normalized = value.toLowerCase().trim();
    final index = _indexForField(field);

    Set<String>? matches;
    if (index != null) {
      matches = _fuzzyLookup(field, normalized, index);
    }

    final now = DateTime.now();

    if (matches != null && matches.isNotEmpty) {
      // Narrow the candidate set
      final intersection = _candidates.intersection(matches);

      if (intersection.isNotEmpty) {
        _candidates = intersection;
        _locked[field] = LockedField(
          value: value,
          source: source,
          confidence: confidence,
          lockedAt: now,
        );

        // Auto-lock derived fields
        _autoLockDerived(field, value, now);

        // Auto-lock any field with only one remaining possibility
        _autoLockSingletons(now);
      } else {
        // Intersection empty — open mode: lock field, keep candidates
        _locked[field] = LockedField(
          value: value,
          source: source,
          confidence: confidence ?? 'OCR',
          lockedAt: now,
        );
      }
    } else {
      // No index for this field or no match — open mode
      _locked[field] = LockedField(
        value: value,
        source: source,
        confidence: confidence ?? 'OCR',
        lockedAt: now,
      );
    }

    _emitState();
    return state;
  }

  /// Possible values for [field] across remaining candidates.
  ///
  /// Returns an empty list if the field is already locked.
  /// For [DeviceField.colour], returns a static palette (not in catalog).
  /// For derived fields (power, tubing), returns computed possibilities.
  List<String> possibleValues(DeviceField field) {
    if (_locked.containsKey(field)) return const [];
    if (!_loaded) return _staticFallback(field);

    switch (field) {
      case DeviceField.brand:
        return _uniqueValues((d) => d.manufacturer);
      case DeviceField.model:
        return _uniqueValues((d) => d.model);
      case DeviceField.type:
        return _uniqueValues(
          (d) => _extractTypePrefix(d.type)?.toUpperCase(),
        );
      case DeviceField.batterySize:
        return _uniqueValues((d) {
          final bs = d.batterySize;
          return (bs.isEmpty || bs == 'Unknown') ? null : bs;
        });
      case DeviceField.power:
        return _uniqueValues((d) {
          final bs = d.batterySize.toLowerCase();
          if (bs.isEmpty || bs == 'unknown') return null;
          return bs == 'rechargeable' ? 'Rechargeable' : 'Battery';
        });
      case DeviceField.tubing:
        return _uniqueValues((d) => _inferTubing(d.type));
      case DeviceField.colour:
        return _colourPalette;
    }
  }

  /// Current detection state snapshot.
  DetectionState get state => DetectionState(
        locked: Map.unmodifiable(_locked),
        candidateCount: _candidates.length,
      );

  /// Stream of state changes — subscribe for cascade animations.
  Stream<DetectionState> get stateStream => _stateController.stream;

  /// Number of remaining candidates.
  int get candidateCount => _candidates.length;

  /// Number of devices in the catalog for a given brand.
  int brandDeviceCount(String brand) {
    final key = brand.toLowerCase();
    return _brandIndex[key]?.length ?? 0;
  }

  /// The single matched device, if exactly one candidate remains.
  DeviceEntry? get matchedDevice {
    if (_candidates.length != 1) return null;
    return _devices[_candidates.first];
  }

  /// Dispose the stream controller.
  void dispose() {
    _stateController.close();
  }

  // ── Private helpers ──────────────────────────────────────────────────

  /// Get the inverted index for a field, or null for derived/colour fields.
  Map<String, Set<String>>? _indexForField(DeviceField field) {
    switch (field) {
      case DeviceField.brand:
        return _brandIndex;
      case DeviceField.model:
        return _modelIndex;
      case DeviceField.type:
        return _typeIndex;
      case DeviceField.batterySize:
        return _batteryIndex;
      case DeviceField.power:
      case DeviceField.tubing:
      case DeviceField.colour:
        return null;
    }
  }

  /// Fuzzy lookup in an inverted index. Tries exact → substring → Levenshtein.
  Set<String>? _fuzzyLookup(
    DeviceField field,
    String normalized,
    Map<String, Set<String>> index,
  ) {
    // 1. Exact key match
    if (index.containsKey(normalized)) {
      return index[normalized]!;
    }

    // 2. For brand: try alias resolution
    if (field == DeviceField.brand) {
      final alias = _brandAliases[normalized];
      if (alias != null) {
        final aliasKey = alias.toLowerCase();
        if (index.containsKey(aliasKey)) return index[aliasKey]!;
      }
    }

    // 3. Substring match — check if normalized contains any key
    for (final entry in index.entries) {
      if (normalized.contains(entry.key) && entry.key.length >= 3) {
        return entry.value;
      }
      if (entry.key.contains(normalized) && normalized.length >= 3) {
        return entry.value;
      }
    }

    // 4. Fuzzy match — Levenshtein ≤ 2 for brand, ≤ 1 for model
    final maxDist = field == DeviceField.brand ? 2 : 1;
    for (final entry in index.entries) {
      if ((normalized.length - entry.key.length).abs() > maxDist) continue;
      if (_levenshtein(normalized, entry.key) <= maxDist) {
        return entry.value;
      }
    }

    return null;
  }

  /// Auto-lock derived fields (power from batterySize, tubing from type).
  void _autoLockDerived(DeviceField field, String value, DateTime now) {
    if (field == DeviceField.batterySize && !_locked.containsKey(DeviceField.power)) {
      final power = value.toLowerCase() == 'rechargeable'
          ? 'Rechargeable'
          : 'Battery';
      _locked[DeviceField.power] = LockedField(
        value: power,
        source: DetectionSource.inferred,
        confidence: 'INFERRED',
        lockedAt: now,
      );
    }

    if (field == DeviceField.type && !_locked.containsKey(DeviceField.tubing)) {
      final tubing = _inferTubing(value);
      if (tubing != null) {
        _locked[DeviceField.tubing] = LockedField(
          value: tubing,
          source: DetectionSource.inferred,
          confidence: 'INFERRED',
          lockedAt: now,
        );
      }
    }
  }

  /// Check all unlocked fields — if only one value remains, auto-lock it.
  void _autoLockSingletons(DateTime now) {
    for (final field in DeviceField.values) {
      if (_locked.containsKey(field)) continue;
      if (field == DeviceField.colour) continue; // Never auto-lock colour

      final values = possibleValues(field);
      if (values.length == 1) {
        _locked[field] = LockedField(
          value: values.first,
          source: DetectionSource.catalog,
          confidence: 'CATALOG',
          lockedAt: now,
        );

        // Derived field cascade
        _autoLockDerived(field, values.first, now);
      }
    }
  }

  /// Unique values for a field extractor across remaining candidates.
  List<String> _uniqueValues(String? Function(DeviceEntry) extractor) {
    final values = <String>{};
    for (final id in _candidates) {
      final device = _devices[id];
      if (device == null) continue;
      final v = extractor(device);
      if (v != null && v.isNotEmpty) values.add(v);
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  /// Extract type prefix from full type string.
  /// "BTE (Behind-the-Ear)" → "bte"
  static String? _extractTypePrefix(String type) {
    if (type.isEmpty || type == 'Unknown') return null;
    final prefix = type.split(' ').first.toLowerCase();
    return prefix.isNotEmpty ? prefix : null;
  }

  /// Infer tubing from device type.
  static String? _inferTubing(String type) {
    final prefix = _extractTypePrefix(type)?.toUpperCase();
    if (prefix == null) return null;
    if (prefix == 'BTE') return 'Standard';
    if ({'RIC', 'ITE', 'CIC', 'ITC', 'IIC'}.contains(prefix)) return 'None';
    return null;
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Fallback static candidates when catalog isn't loaded.
  static List<String> _staticFallback(DeviceField field) {
    switch (field) {
      case DeviceField.brand:
        return const [
          'Oticon', 'Phonak', 'Signia', 'Widex', 'ReSound',
          'Starkey', 'Unitron', 'Bernafon', 'Beltone',
        ];
      case DeviceField.model:
        return const [
          'Real', 'More', 'Intent', 'Audeo', 'Naida', 'Pure',
          'Moment', 'Nexia', 'Genesis', 'Moxi',
        ];
      case DeviceField.type:
        return const ['BTE', 'RIC', 'ITE', 'CIC', 'ITC', 'IIC'];
      case DeviceField.batterySize:
        return const [
          'Size 10', 'Size 13', 'Size 312', 'Size 675', 'Rechargeable',
        ];
      case DeviceField.power:
        return const ['Battery', 'Rechargeable'];
      case DeviceField.tubing:
        return const ['Standard', 'Slim', 'None'];
      case DeviceField.colour:
        return _colourPalette;
    }
  }

  static const _colourPalette = [
    'Beige', 'Tan', 'Silver', 'Black', 'White', 'Brown',
    'Grey', 'Champagne', 'Sand', 'Espresso',
  ];

  /// Levenshtein distance (mirrors BrandMatcher's implementation).
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
        ].reduce((a, b) => a < b ? a : b);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[b.length];
  }
}
