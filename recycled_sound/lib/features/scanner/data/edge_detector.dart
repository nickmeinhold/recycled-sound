import 'dart:typed_data';
import 'dart:ui';

/// Lightweight Sobel edge detector for live camera frames.
///
/// Runs on a downscaled grayscale image to stay under 2ms per frame.
/// Returns edge points as normalized coordinates (0.0–1.0) that can be
/// drawn on any size canvas.
class EdgeDetector {
  /// Downscale target — smaller = faster, coarser edges.
  static const _targetWidth = 100;

  /// Sobel gradient threshold — high value to only catch strong edges
  /// (device outlines, text) and ignore soft background gradients.
  static const _threshold = 100;

  /// Only detect edges in the centre of the frame (this fraction each side).
  /// 0.3 = centre 40% of the frame (30% margin on each side).
  static const _marginFraction = 0.2;

  /// Detect edges from a BGRA8888 camera frame.
  ///
  /// Returns a list of normalized (x, y) points where edges were found.
  /// Points are in 0.0–1.0 space relative to the original image dimensions.
  static List<Offset> detect({
    required Uint8List bytes,
    required int width,
    required int height,
  }) {
    // Downscale to target width, maintaining aspect ratio
    final scale = _targetWidth / width;
    final dw = _targetWidth;
    final dh = (height * scale).round();

    // Convert to grayscale and downscale in one pass
    final gray = Uint8List(dw * dh);
    final stepX = width / dw;
    final stepY = height / dh;

    for (var dy = 0; dy < dh; dy++) {
      final srcY = (dy * stepY).toInt().clamp(0, height - 1);
      for (var dx = 0; dx < dw; dx++) {
        final srcX = (dx * stepX).toInt().clamp(0, width - 1);
        final i = (srcY * width + srcX) * 4; // BGRA8888
        if (i + 2 >= bytes.length) continue;
        // Fast luminance: (R + G + G + B) >> 2
        final b = bytes[i];
        final g = bytes[i + 1];
        final r = bytes[i + 2];
        gray[dy * dw + dx] = (r + g + g + b) >> 2;
      }
    }

    // Sobel edge detection — restricted to centre of frame
    final edges = <Offset>[];
    final invW = 1.0 / dw;
    final invH = 1.0 / dh;

    final marginX = (dw * _marginFraction).round();
    final marginY = (dh * _marginFraction).round();
    final startX = marginX.clamp(1, dw - 2);
    final startY = marginY.clamp(1, dh - 2);
    final endX = (dw - marginX).clamp(startX + 1, dw - 1);
    final endY = (dh - marginY).clamp(startY + 1, dh - 1);

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        // 3x3 Sobel kernels
        final tl = gray[(y - 1) * dw + (x - 1)];
        final tc = gray[(y - 1) * dw + x];
        final tr = gray[(y - 1) * dw + (x + 1)];
        final ml = gray[y * dw + (x - 1)];
        final mr = gray[y * dw + (x + 1)];
        final bl = gray[(y + 1) * dw + (x - 1)];
        final bc = gray[(y + 1) * dw + x];
        final br = gray[(y + 1) * dw + (x + 1)];

        // Gx = [-1 0 1; -2 0 2; -1 0 1]
        final gx = -tl + tr - 2 * ml + 2 * mr - bl + br;
        // Gy = [-1 -2 -1; 0 0 0; 1 2 1]
        final gy = -tl - 2 * tc - tr + bl + 2 * bc + br;

        // Magnitude (fast approximation: |gx| + |gy|)
        final mag = gx.abs() + gy.abs();

        if (mag > _threshold) {
          edges.add(Offset(x * invW, y * invH));
        }
      }
    }

    return edges;
  }

  /// Detect edges and return as pixel coordinates scaled to [canvasSize].
  ///
  /// Convenience method for direct use in CustomPainter.
  static Float32List detectForCanvas({
    required Uint8List bytes,
    required int width,
    required int height,
    required Size canvasSize,
  }) {
    final points = detect(bytes: bytes, width: width, height: height);
    final result = Float32List(points.length * 2);

    for (var i = 0; i < points.length; i++) {
      result[i * 2] = points[i].dx * canvasSize.width;
      result[i * 2 + 1] = points[i].dy * canvasSize.height;
    }

    return result;
  }
}
