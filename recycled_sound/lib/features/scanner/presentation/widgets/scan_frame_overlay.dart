import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Viewfinder overlay with corner brackets, similar to Google Lens.
class ScanFrameOverlay extends StatelessWidget {
  const ScanFrameOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    const frameSize = 240.0;
    const cornerLength = 32.0;
    const strokeWidth = 3.0;

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: CustomPaint(
        painter: _FramePainter(
          color: AppColors.primary,
          cornerLength: cornerLength,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  final Color color;
  final double cornerLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cl = cornerLength;

    // Top-left
    canvas.drawLine(Offset(0, cl), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(cl, 0), paint);

    // Top-right
    canvas.drawLine(Offset(w - cl, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cl), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h - cl), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(cl, h), paint);

    // Bottom-right
    canvas.drawLine(Offset(w, h - cl), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w - cl, h), paint);
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      color != old.color ||
      cornerLength != old.cornerLength ||
      strokeWidth != old.strokeWidth;
}
