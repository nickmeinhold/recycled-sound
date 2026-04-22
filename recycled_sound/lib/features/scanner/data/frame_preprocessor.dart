import 'dart:math' as math;
import 'dart:typed_data';

/// Available preprocessing filters for the live scanner.
///
/// Each filter targets a specific detection weakness:
/// - [none]: raw camera output, baseline
/// - [contrastStretch]: remaps pixel intensity to full 0–255 range,
///   making faint embossed/debossed text visible
/// - [highContrast]: aggressive contrast + gamma shadow lift,
///   optimised for reading text on curved dark hearing aid surfaces
/// - [greyscaleOcr]: strips colour, maximises luminance contrast —
///   best for ML Kit text recognition on low-contrast markings
enum PreprocessFilter {
  none,
  contrastStretch,
  highContrast,
  greyscaleOcr;

  /// Human-readable label for HUD display.
  String get label => switch (this) {
        none => 'RAW',
        contrastStretch => 'ENHANCE',
        highContrast => 'HI-CON',
        greyscaleOcr => 'OCR',
      };

  /// Cycle to the next filter.
  PreprocessFilter get next =>
      PreprocessFilter.values[(index + 1) % PreprocessFilter.values.length];
}

/// Applies real-time image preprocessing to BGRA8888 camera frames.
///
/// All operations work on a copy of the byte buffer to avoid corrupting
/// the camera's own memory. Designed to complete in <2ms on a centre crop,
/// keeping the pipeline at 30fps.
class FramePreprocessor {
  FramePreprocessor._();

  // ── Pre-computed LUTs (built once, reused every frame) ────────────────

  /// Gamma 0.7 shadow-lift LUT. Brightens dark pixels disproportionately,
  /// making text stamped into dark plastic (Espresso, Graphite) readable.
  static final _gammaLut = _buildGammaLut(0.7);

  static Uint8List _buildGammaLut(double gamma) {
    final lut = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      lut[i] = (math.pow(i / 255.0, gamma) * 255).round().clamp(0, 255);
    }
    return lut;
  }

  /// Apply [filter] to BGRA8888 bytes, returning a new buffer.
  ///
  /// Only processes the centre [cropFraction] of the frame to save time.
  /// Pixels outside the crop are copied unchanged — ML Kit can still
  /// read the full frame, but the enhanced region is where text lives.
  static Uint8List apply({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    required PreprocessFilter filter,
    double cropFraction = 0.6,
  }) {
    if (filter == PreprocessFilter.none) return bytes;

    // Work on a copy — never mutate the camera's buffer.
    final out = Uint8List.fromList(bytes);

    final x0 = (width * (1 - cropFraction) / 2).toInt();
    final y0 = (height * (1 - cropFraction) / 2).toInt();
    final x1 = (width * (1 + cropFraction) / 2).toInt();
    final y1 = (height * (1 + cropFraction) / 2).toInt();

    switch (filter) {
      case PreprocessFilter.none:
        break; // unreachable

      case PreprocessFilter.contrastStretch:
        _contrastStretch(out, bytesPerRow, x0, y0, x1, y1);

      case PreprocessFilter.highContrast:
        _contrastStretch(out, bytesPerRow, x0, y0, x1, y1);
        _applyLut(out, bytesPerRow, x0, y0, x1, y1, _gammaLut);

      case PreprocessFilter.greyscaleOcr:
        _contrastStretch(out, bytesPerRow, x0, y0, x1, y1);
        _greyscale(out, bytesPerRow, x0, y0, x1, y1);
    }

    return out;
  }

  /// Stretch pixel intensities so min→0, max→255 within the crop region.
  ///
  /// Pass 1: sample every 8th pixel to find min/max luminance (~0.1ms).
  /// Pass 2: remap all pixels via LUT (~0.8ms on centre crop).
  ///
  /// This is the single most effective filter for embossed text — it
  /// uses the full dynamic range even when the hearing aid surface has
  /// very low contrast between text and body.
  static void _contrastStretch(
    Uint8List buf,
    int bytesPerRow,
    int x0,
    int y0,
    int x1,
    int y1,
  ) {
    // Pass 1: find min/max luminance (sample stride=8 for speed)
    var minL = 255;
    var maxL = 0;

    for (var y = y0; y < y1; y += 8) {
      final rowOff = y * bytesPerRow;
      for (var x = x0; x < x1; x += 8) {
        final i = rowOff + x * 4;
        // BGRA: luminance ≈ 0.299R + 0.587G + 0.114B (integer math)
        final lum =
            (buf[i + 2] * 77 + buf[i + 1] * 150 + buf[i] * 29) >> 8;
        if (lum < minL) minL = lum;
        if (lum > maxL) maxL = lum;
      }
    }

    final range = maxL - minL;
    if (range < 10) return; // Already maxed out or flat — skip.

    // Build stretch LUT (avoids per-pixel division).
    final lut = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      lut[i] = ((i - minL) * 255 ~/ range).clamp(0, 255);
    }

    _applyLut(buf, bytesPerRow, x0, y0, x1, y1, lut);
  }

  /// Apply a pre-computed LUT to B, G, R channels in the crop region.
  static void _applyLut(
    Uint8List buf,
    int bytesPerRow,
    int x0,
    int y0,
    int x1,
    int y1,
    Uint8List lut,
  ) {
    for (var y = y0; y < y1; y++) {
      final rowOff = y * bytesPerRow;
      for (var x = x0; x < x1; x++) {
        final i = rowOff + x * 4;
        buf[i] = lut[buf[i]]; // B
        buf[i + 1] = lut[buf[i + 1]]; // G
        buf[i + 2] = lut[buf[i + 2]]; // R
        // A unchanged
      }
    }
  }

  /// Convert to greyscale — strips colour, maximises text/background contrast.
  ///
  /// For OCR, colour is noise. A greyscale image with stretched contrast
  /// gives ML Kit the clearest possible signal for text detection.
  static void _greyscale(
    Uint8List buf,
    int bytesPerRow,
    int x0,
    int y0,
    int x1,
    int y1,
  ) {
    for (var y = y0; y < y1; y++) {
      final rowOff = y * bytesPerRow;
      for (var x = x0; x < x1; x++) {
        final i = rowOff + x * 4;
        // BT.601 luminance weights (integer approximation, >>8)
        final lum =
            (buf[i + 2] * 77 + buf[i + 1] * 150 + buf[i] * 29) >> 8;
        buf[i] = lum; // B
        buf[i + 1] = lum; // G
        buf[i + 2] = lum; // R
      }
    }
  }
}
