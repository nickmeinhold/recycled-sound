import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color;

/// A reference colour in the hearing aid palette.
class HearingAidColour {
  const HearingAidColour(this.name, this.color);

  final String name;
  final Color color;
}

/// Result of classifying a sampled colour against the palette.
class ColourMatch {
  const ColourMatch({
    required this.name,
    required this.reference,
    required this.deltaE,
  });

  final String name;
  final Color reference;

  /// CIELAB Delta E distance — lower is closer. <10 is a strong match.
  final double deltaE;
}

/// Classifies camera frame colours against a hearing aid colour palette.
///
/// Uses CIELAB colour space for perceptually uniform distance calculations.
/// Hearing aid colours are muted, skin-tone-adjacent — RGB Euclidean distance
/// performs poorly on this palette (confuses Beige/Tan/Champagne).
class ColourClassifier {
  ColourClassifier._();

  /// The hearing aid colour palette. Values are approximate and may need
  /// tuning against real devices.
  static const palette = <HearingAidColour>[
    HearingAidColour('Beige', Color(0xFFD4B896)),
    HearingAidColour('Tan', Color(0xFFC4A882)),
    HearingAidColour('Silver', Color(0xFFA8A9AD)),
    HearingAidColour('Black', Color(0xFF2C2C2C)),
    HearingAidColour('Brown', Color(0xFF7B5B3A)),
    HearingAidColour('Espresso', Color(0xFF4A3728)),
    HearingAidColour('Champagne', Color(0xFFE8D5B7)),
    HearingAidColour('Chestnut', Color(0xFF8B5E3C)),
    HearingAidColour('Rose Gold', Color(0xFFC9A087)),
    HearingAidColour('Graphite', Color(0xFF5C5C5C)),
  ];

  /// Pre-computed Lab values for the palette (lazily initialised).
  static final List<_Lab> _paletteLab = palette
      .map((c) => _rgbToLab(_r(c.color), _g(c.color), _b(c.color)))
      .toList(growable: false);

  /// Sample the dominant colour from the centre region of a BGRA8888 frame.
  ///
  /// Samples every [stride]th pixel in the centre 20% of the frame.
  /// Returns the average colour. Typically completes in <0.1ms.
  static Color sampleFromBgra8888({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    int stride = 4,
  }) {
    // Centre 20% crop region
    final x0 = (width * 0.4).toInt();
    final y0 = (height * 0.4).toInt();
    final x1 = (width * 0.6).toInt();
    final y1 = (height * 0.6).toInt();

    int totalR = 0, totalG = 0, totalB = 0;
    int count = 0;

    for (var y = y0; y < y1; y += stride) {
      final rowOffset = y * bytesPerRow;
      for (var x = x0; x < x1; x += stride) {
        final i = rowOffset + x * 4;
        // BGRA8888: B=0, G=1, R=2, A=3
        totalB += bytes[i];
        totalG += bytes[i + 1];
        totalR += bytes[i + 2];
        count++;
      }
    }

    if (count == 0) return const Color(0xFF808080);

    return Color.fromARGB(
      255,
      totalR ~/ count,
      totalG ~/ count,
      totalB ~/ count,
    );
  }

  /// Classify a colour against the hearing aid palette.
  ///
  /// Returns the nearest match using CIELAB Delta E distance.
  static ColourMatch classify(Color sampled) {
    final lab = _rgbToLab(_r(sampled), _g(sampled), _b(sampled));

    var bestIndex = 0;
    var bestDist = double.infinity;

    for (var i = 0; i < _paletteLab.length; i++) {
      final ref = _paletteLab[i];
      final dL = lab.l - ref.l;
      final dA = lab.a - ref.a;
      final dB = lab.b - ref.b;
      final dist = sqrt(dL * dL + dA * dA + dB * dB);
      if (dist < bestDist) {
        bestDist = dist;
        bestIndex = i;
      }
    }

    return ColourMatch(
      name: palette[bestIndex].name,
      reference: palette[bestIndex].color,
      deltaE: bestDist,
    );
  }

  // ── Colour channel helpers (Flutter 3.11+ deprecates .red/.green/.blue) ─

  static int _r(Color c) => (c.r * 255.0).round().clamp(0, 255);
  static int _g(Color c) => (c.g * 255.0).round().clamp(0, 255);
  static int _b(Color c) => (c.b * 255.0).round().clamp(0, 255);

  // ── CIELAB conversion ──────────────────────────────────────────────────

  static _Lab _rgbToLab(int r, int g, int b) {
    // sRGB → linear RGB
    var lr = _srgbToLinear(r / 255.0);
    var lg = _srgbToLinear(g / 255.0);
    var lb = _srgbToLinear(b / 255.0);

    // Linear RGB → XYZ (D65 illuminant)
    var x = 0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb;
    var y = 0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb;
    var z = 0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb;

    // Normalise to D65 white point
    x /= 0.95047;
    y /= 1.00000;
    z /= 1.08883;

    // XYZ → Lab
    x = _labF(x);
    y = _labF(y);
    z = _labF(z);

    return _Lab(
      l: 116.0 * y - 16.0,
      a: 500.0 * (x - y),
      b: 200.0 * (y - z),
    );
  }

  static double _srgbToLinear(double c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _labF(double t) {
    const delta = 6.0 / 29.0;
    return t > delta * delta * delta
        ? pow(t, 1.0 / 3.0).toDouble()
        : t / (3.0 * delta * delta) + 4.0 / 29.0;
  }
}

/// Internal CIELAB representation.
class _Lab {
  const _Lab({required this.l, required this.a, required this.b});
  final double l;
  final double a;
  final double b;
}

/// Stabilises colour readings across frames using a voting buffer.
///
/// Prevents flicker by requiring [threshold] out of [bufferSize] recent
/// frames to agree before reporting a stable colour.
class ColourStabiliser {
  ColourStabiliser({this.bufferSize = 8, this.threshold = 5});

  final int bufferSize;
  final int threshold;

  final List<String> _buffer = [];
  final List<Color> _rgbBuffer = [];

  /// The current leading colour name, or null if buffer is empty.
  String? get leadingColour => _leading()?.name;

  /// The palette reference colour for the leading reading.
  Color? get leadingRgb {
    final name = leadingColour;
    if (name == null) return null;
    for (var i = _buffer.length - 1; i >= 0; i--) {
      if (_buffer[i] == name) return _rgbBuffer[i];
    }
    return null;
  }

  /// How confident we are: count of the leading colour / bufferSize.
  /// Returns 0.0–1.0.
  double get confidence {
    final lead = _leading();
    if (lead == null) return 0.0;
    return lead.count / bufferSize;
  }

  /// Whether the leading colour has reached the consensus threshold.
  bool get isStable {
    final lead = _leading();
    return lead != null && lead.count >= threshold;
  }

  /// Push a new reading into the buffer.
  void push(String name, Color rgb) {
    _buffer.add(name);
    _rgbBuffer.add(rgb);
    if (_buffer.length > bufferSize) {
      _buffer.removeAt(0);
      _rgbBuffer.removeAt(0);
    }
  }

  /// Reset the buffer (e.g. when scanner restarts).
  void reset() {
    _buffer.clear();
    _rgbBuffer.clear();
  }

  ({String name, int count})? _leading() {
    if (_buffer.isEmpty) return null;
    final counts = <String, int>{};
    for (final name in _buffer) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final best = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return (name: best.key, count: best.value);
  }
}
