import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../data/point_cloud.dart';

/// Paints accumulated 3D points directly onto the live AR camera view.
///
/// Each frame, projects world-space points through the current camera
/// matrices to screen coordinates. Points appear anchored to the real
/// surface — move the camera and they stay on the object.
class ArPointOverlayPainter extends CustomPainter {
  ArPointOverlayPainter({
    required this.points,
    required this.viewMatrix,
    required this.projectionMatrix,
    this.pointSize = 3.0,
    this.opacity = 0.85,
  });

  final List<CloudPoint> points;

  /// Inverse of the camera's world transform (pointOfViewTransform).
  final Matrix4 viewMatrix;

  /// The camera's projection matrix (perspective).
  final Matrix4 projectionMatrix;

  final double pointSize;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final viewProj = projectionMatrix.multiplied(viewMatrix);
    final halfW = size.width / 2;
    final halfH = size.height / 2;

    for (final p in points) {
      // Transform world point to clip space
      final world = Vector4(p.x, p.y, p.z, 1.0);
      final clip = viewProj.transform(world);

      // Skip points behind camera
      if (clip.w <= 0.001) continue;

      // Perspective divide → NDC (-1 to 1)
      final ndcX = clip.x / clip.w;
      final ndcY = clip.y / clip.w;
      final ndcZ = clip.z / clip.w;

      // Skip points outside frustum
      if (ndcX < -1.2 || ndcX > 1.2 || ndcY < -1.2 || ndcY > 1.2) continue;
      if (ndcZ < 0 || ndcZ > 1) continue;

      // NDC to screen pixels
      // Note: NDC Y is flipped (up is positive in GL, down in screen)
      final screenX = (1.0 + ndcX) * halfW;
      final screenY = (1.0 - ndcY) * halfH;

      // Depth-based sizing: closer = slightly larger
      final depthFactor = (1.0 - ndcZ * 0.5).clamp(0.5, 1.5);
      final dotSize = pointSize * depthFactor;

      // Depth-based brightness: closer = brighter
      final alpha = opacity * (0.4 + 0.6 * (1.0 - ndcZ)).clamp(0.2, 1.0);

      canvas.drawCircle(
        Offset(screenX, screenY),
        dotSize,
        Paint()
          ..color = Color.fromRGBO(p.r, p.g, p.b, alpha)
          ..style = PaintingStyle.fill,
      );
    }

    // Point count overlay
    final tp = TextPainter(
      text: TextSpan(
        text: '${points.length} POINTS',
        style: const TextStyle(
          color: Color(0xAAFFFFFF),
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background pill for readability
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, size.height - 80, tp.width + 16, tp.height + 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(pillRect, Paint()..color = const Color(0x88000000));
    tp.paint(canvas, Offset(20, size.height - 76));
  }

  @override
  bool shouldRepaint(covariant ArPointOverlayPainter old) => true;
}
