import 'package:flutter/material.dart';

import '../data/section.dart';

/// Badge showing the current slide reference (e.g. "SLIDE 6").
class SectionIndicator extends StatelessWidget {
  const SectionIndicator({super.key, required this.section});

  final SpeakingSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        section.slideRef,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
