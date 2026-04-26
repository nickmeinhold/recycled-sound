import 'package:flutter/material.dart';

/// Compact WPM speed control — tap to cycle through presets.
class SpeedControl extends StatelessWidget {
  const SpeedControl({
    super.key,
    required this.wpm,
    required this.onChanged,
  });

  final double wpm;
  final ValueChanged<double> onChanged;

  static const _presets = [100.0, 115.0, 130.0, 145.0, 160.0];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Cycle to next preset.
        final currentIndex = _presets.indexWhere((p) => p >= wpm);
        final next = (currentIndex + 1) % _presets.length;
        onChanged(_presets[next]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${wpm.round()} WPM',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
