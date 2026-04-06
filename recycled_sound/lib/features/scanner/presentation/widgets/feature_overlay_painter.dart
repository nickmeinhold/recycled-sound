import 'package:flutter/material.dart';

/// Whether a detection is a confirmed match or ambient (unmatched) text.
enum DetectionType { matched, ambient }

/// A detected text region to highlight on the camera preview.
class TextDetection {
  const TextDetection({
    required this.boundingBox,
    required this.label,
    this.type = DetectionType.matched,
  });

  /// Bounding box in ML Kit's coordinate space (rotated image).
  final Rect boundingBox;

  /// What was matched — e.g. "MAKE: Oticon" or raw text for ambient.
  final String label;

  /// Whether this is a confirmed match or ambient text the scanner is reading.
  final DetectionType type;
}

/// A snap event — records when and where a feature was first detected,
/// so the painter can draw the trailing-border capture effect.
class SnapEvent {
  SnapEvent({required this.boundingBox, required this.label})
      : timestamp = DateTime.now();

  final Rect boundingBox;
  final String label;
  final DateTime timestamp;

  /// Milliseconds since the snap fired.
  int get ageMs => DateTime.now().difference(timestamp).inMilliseconds;
}

/// Paints overlays on detected text regions:
/// - **Matched**: green corner brackets with label (brand/model identified)
/// - **Ambient**: dim amber brackets (scanner is reading but no match yet)
///
/// The ambient detections show the scanner is alive and working — reading
/// serial numbers, regulatory marks, everything — before a match lands.
class FeatureOverlayPainter extends CustomPainter {
  FeatureOverlayPainter({
    required this.detections,
    required this.imageSize,
    required this.previewSize,
    required this.sensorOrientation,
    required this.animationValue,
    this.snapEvents = const [],
  });

  final List<TextDetection> detections;
  final Size imageSize;
  final Size previewSize;
  final int sensorOrientation;

  /// 0.0–1.0 pulsing animation for the brackets.
  final double animationValue;

  /// Active snap events — draws trailing borders for captures in progress.
  final List<SnapEvent> snapEvents;

  // Colors
  static const _matchedColor = Color(0xFF10B981); // success green
  static const _ambientColor = Color(0xFFD97706); // warm amber

  @override
  void paint(Canvas canvas, Size size) {
    // Draw snap ripple effects (underneath everything)
    for (final snap in snapEvents) {
      final age = snap.ageMs;
      if (age > 500) continue; // expire after 500ms
      final rect = _transformRect(snap.boundingBox, size);
      _drawSnapRipple(canvas, rect, age / 500.0);
    }

    if (detections.isEmpty) return;

    // Draw ambient detections first (underneath)
    for (final detection in detections) {
      if (detection.type == DetectionType.ambient) {
        final rect = _transformRect(detection.boundingBox, size);
        _drawAmbientBrackets(canvas, rect);
      }
    }

    // Draw matched detections on top
    for (final detection in detections) {
      if (detection.type == DetectionType.matched) {
        final rect = _transformRect(detection.boundingBox, size);
        _drawMatchedBrackets(canvas, rect);
        _drawLabel(canvas, rect, detection.label);
      }
    }
  }

  Rect _transformRect(Rect rect, Size widgetSize) {
    final Size rotatedSize;
    if (sensorOrientation == 90 || sensorOrientation == 270) {
      rotatedSize = Size(imageSize.height, imageSize.width);
    } else {
      rotatedSize = imageSize;
    }

    final scaleX = widgetSize.width / rotatedSize.width;
    final scaleY = widgetSize.height / rotatedSize.height;
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

  /// Draw expanding ripple brackets — 3 trailing copies at increasing scale,
  /// each fading as the animation progresses. Like a radar ping.
  void _drawSnapRipple(Canvas canvas, Rect rect, double progress) {
    for (var i = 1; i <= 3; i++) {
      final expand = i * 4.0 * progress; // pixels of expansion
      final opacity = (1.0 - progress) * (1.0 - i * 0.25); // fade with time + trail depth
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = _matchedColor.withValues(alpha: opacity * 0.8)
        ..strokeWidth = 2.0 - (i * 0.4) // thinner trails
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      _drawCorners(canvas, rect.inflate(4 + expand), paint);
    }
  }

  void _drawMatchedBrackets(Canvas canvas, Rect rect) {
    final opacity = 0.6 + 0.4 * animationValue;
    final paint = Paint()
      ..color = _matchedColor.withValues(alpha: opacity)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawCorners(canvas, rect.inflate(4), paint);
  }

  void _drawAmbientBrackets(Canvas canvas, Rect rect) {
    // Dim, thin, barely there — the scanner is reading
    final opacity = 0.15 + 0.1 * animationValue;
    final paint = Paint()
      ..color = _ambientColor.withValues(alpha: opacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawCorners(canvas, rect.inflate(2), paint);
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
    final cl = rect.shortestSide * 0.25;
    final l = rect.left;
    final t = rect.top;
    final r = rect.right;
    final b = rect.bottom;

    canvas.drawLine(Offset(l, t + cl), Offset(l, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l + cl, t), paint);
    canvas.drawLine(Offset(r - cl, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cl), paint);
    canvas.drawLine(Offset(l, b - cl), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + cl, b), paint);
    canvas.drawLine(Offset(r, b - cl), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r - cl, b), paint);
  }

  void _drawLabel(Canvas canvas, Rect rect, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: _matchedColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

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

    textPainter.paint(
        canvas, Offset(rect.left + 4, rect.top - textPainter.height - 4));
  }

  @override
  bool shouldRepaint(covariant FeatureOverlayPainter old) =>
      detections != old.detections ||
      animationValue != old.animationValue ||
      snapEvents.length != old.snapEvents.length;
}
