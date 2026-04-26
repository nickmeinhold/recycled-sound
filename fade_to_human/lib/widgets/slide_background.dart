import 'package:flutter/material.dart';

import '../data/section.dart';

/// Renders the slide image(s) as a dimmed background for memory palace anchoring.
///
/// If the section has multiple images, they're shown side by side.
/// A dark overlay ensures text remains readable on top.
class SlideBackground extends StatelessWidget {
  const SlideBackground({
    super.key,
    required this.section,
    this.overlayOpacity = 0.65,
    required this.child,
  });

  final SpeakingSection section;
  final double overlayOpacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: slide image(s) or solid color fallback.
        if (section.backgroundImages.isNotEmpty)
          _buildImageBackground()
        else
          Container(color: section.color),

        // Dark overlay for readability.
        Container(
          color: section.color.withValues(alpha: overlayOpacity),
        ),

        // Content on top.
        child,
      ],
    );
  }

  Widget _buildImageBackground() {
    final images = section.backgroundImages;
    if (images.length == 1) {
      return Image.asset(
        images[0],
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }

    // Multiple images: show side by side.
    return Row(
      children: images
          .map((path) => Expanded(
                child: Image.asset(
                  path,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ))
          .toList(),
    );
  }
}
