/// Represents a single identified spec field with its confidence score.
class SpecField {
  const SpecField({required this.value, required this.confidence});

  final String value;

  /// 0–100 confidence percentage.
  final int confidence;

  SpecField copyWith({String? value, int? confidence}) => SpecField(
        value: value ?? this.value,
        confidence: confidence ?? this.confidence,
      );

  factory SpecField.fromJson(Map<String, dynamic> json) => SpecField(
        value: json['value'] as String,
        confidence: json['confidence'] as int,
      );

  Map<String, dynamic> toJson() => {'value': value, 'confidence': confidence};
}

/// The result of a hearing aid scan, returned by the Cloud Function.
class ScanResult {
  const ScanResult({
    required this.scanId,
    required this.imageUrl,
    required this.brand,
    required this.model,
    required this.type,
    required this.year,
    required this.batterySize,
    required this.domeType,
    required this.waxFilter,
    required this.receiver,
    this.colour,
    this.rawLabels = const [],
  });

  final String scanId;
  final String imageUrl;
  final SpecField brand;
  final SpecField model;
  final SpecField type;
  final SpecField year;
  final SpecField batterySize;
  final SpecField domeType;
  final SpecField waxFilter;
  final SpecField receiver;

  /// Device colour identified by on-device colour sampling.
  final SpecField? colour;

  final List<String> rawLabels;

  ScanResult copyWith({
    String? scanId,
    String? imageUrl,
    SpecField? brand,
    SpecField? model,
    SpecField? type,
    SpecField? year,
    SpecField? batterySize,
    SpecField? domeType,
    SpecField? waxFilter,
    SpecField? receiver,
    SpecField? colour,
    List<String>? rawLabels,
  }) =>
      ScanResult(
        scanId: scanId ?? this.scanId,
        imageUrl: imageUrl ?? this.imageUrl,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        type: type ?? this.type,
        year: year ?? this.year,
        batterySize: batterySize ?? this.batterySize,
        domeType: domeType ?? this.domeType,
        waxFilter: waxFilter ?? this.waxFilter,
        receiver: receiver ?? this.receiver,
        colour: colour ?? this.colour,
        rawLabels: rawLabels ?? this.rawLabels,
      );

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        scanId: json['scanId'] as String,
        imageUrl: json['imageUrl'] as String,
        brand: SpecField.fromJson(json['brand'] as Map<String, dynamic>),
        model: SpecField.fromJson(json['model'] as Map<String, dynamic>),
        type: SpecField.fromJson(json['type'] as Map<String, dynamic>),
        year: SpecField.fromJson(json['year'] as Map<String, dynamic>),
        batterySize:
            SpecField.fromJson(json['batterySize'] as Map<String, dynamic>),
        domeType:
            SpecField.fromJson(json['domeType'] as Map<String, dynamic>),
        waxFilter:
            SpecField.fromJson(json['waxFilter'] as Map<String, dynamic>),
        receiver:
            SpecField.fromJson(json['receiver'] as Map<String, dynamic>),
        colour: json['colour'] != null
            ? SpecField.fromJson(json['colour'] as Map<String, dynamic>)
            : null,
        rawLabels: (json['rawLabels'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );

  /// Returns a mock result for development/testing.
  factory ScanResult.mock() => const ScanResult(
        scanId: 'mock-001',
        imageUrl: '',
        brand: SpecField(value: 'Phonak', confidence: 95),
        model: SpecField(value: 'Audéo P90', confidence: 88),
        type: SpecField(value: 'RIC (Receiver-in-Canal)', confidence: 92),
        year: SpecField(value: '2021', confidence: 75),
        batterySize: SpecField(value: 'Size 312', confidence: 80),
        domeType: SpecField(value: 'Closed', confidence: 70),
        waxFilter: SpecField(value: 'CeruShield Disk', confidence: 65),
        receiver: SpecField(value: 'M receiver', confidence: 72),
        colour: SpecField(value: 'Champagne', confidence: 70),
        rawLabels: ['hearing aid', 'Phonak', 'behind-the-ear', 'medical device'],
      );
}
