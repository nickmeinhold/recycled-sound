import 'package:flutter/material.dart';

/// A detected text region to highlight on the camera preview.
class TextDetection {
  const TextDetection({
    required this.boundingBox,
    required this.label,
  });

  /// Bounding box in ML Kit's coordinate space (rotated image).
  final Rect boundingBox;

  /// What was matched — e.g. "Brand: Oticon".
  final String label;
}

/// Paints green corner brackets around detected text regions,
/// using the same visual language as the scan frame overlay.
///
/// Transforms coordinates from ML Kit's rotated image space
/// to the camera preview widget space.
class FeatureOverlayPainter extends CustomPainter {
  FeatureOverlayPainter({
    required this.detections,
    required this.imageSize,
    required this.previewSize,
    required this.sensorOrientation,
    required this.animationValue,
  });

  final List<TextDetection> detections;

  /// Raw camera image size (before rotation).
  final Size imageSize;

  /// The size of the preview widget on screen.
  final Size previewSize;

  /// Camera sensor orientation in degrees.
  final int sensorOrientation;

  /// 0.0–1.0 pulsing animation for the brackets.
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    for (final detection in detections) {
      final rect = _transformRect(detection.boundingBox, size);
      _drawCornerBrackets(canvas, rect);
      _drawLabel(canvas, rect, detection.label);
    }
  }

  /// Transform a bounding box from ML Kit space to widget space.
  ///
  /// ML Kit returns coordinates in the *rotated* image space (i.e. after
  /// applying InputImageRotation). For iOS back camera in portrait mode,
  /// the rotated image is portrait-oriented, so we just need to scale.
  Rect _transformRect(Rect rect, Size widgetSize) {
    // ML Kit coordinates are in rotated image space.
    // For 90° or 270° rotation, the rotated image dimensions are swapped.
    final Size rotatedSize;
    if (sensorOrientation == 90 || sensorOrientation == 270) {
      rotatedSize = Size(imageSize.height, imageSize.width);
    } else {
      rotatedSize = imageSize;
    }

    final scaleX = widgetSize.width / rotatedSize.width;
    final scaleY = widgetSize.height / rotatedSize.height;

    // Use the larger scale to maintain aspect ratio (cover mode)
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final offsetX = (widgetSize.width - rotatedSize.width * scale) / 2;
    final offsetY = (widgetSize.height - rotatedSize.height * scale) / 2;

    return Rect.fromLTRB(
      rect.left * scale + offsetX,
      rect.top * scale + offsetY,
      rect.right * scale + offsetX,
      rect.bottom * scale + offsetY,
    );
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect) {
    // Pulse opacity: 0.6 → 1.0
    final opacity = 0.6 + 0.4 * animationValue;
    final paint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: opacity) // success green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Pad the rect slightly so brackets don't touch the text
    final padded = rect.inflate(4);
    final cl = padded.shortestSide * 0.25; // corner length proportional to box

    final l = padded.left;
    final t = padded.top;
    final r = padded.right;
    final b = padded.bottom;

    // Top-left
    canvas.drawLine(Offset(l, t + cl), Offset(l, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l + cl, t), paint);
    // Top-right
    canvas.drawLine(Offset(r - cl, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cl), paint);
    // Bottom-left
    canvas.drawLine(Offset(l, b - cl), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + cl, b), paint);
    // Bottom-right
    canvas.drawLine(Offset(r, b - cl), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r - cl, b), paint);
  }

  void _drawLabel(Canvas canvas, Rect rect, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF10B981),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Draw label background
    final labelRect = Rect.fromLTWH(
      rect.left,
      rect.top - textPainter.height - 6,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(3)),
      Paint()..color = const Color(0xCC000000),
    );

    textPainter.paint(canvas, Offset(rect.left + 4, rect.top - textPainter.height - 4));
  }

  @override
  bool shouldRepaint(covariant FeatureOverlayPainter old) =>
      detections != old.detections || animationValue != old.animationValue;
}
