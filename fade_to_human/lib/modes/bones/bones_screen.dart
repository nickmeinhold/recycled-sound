import 'package:flutter/material.dart';

import '../../data/sections.dart' as data;
import '../../widgets/section_indicator.dart';
import '../../widgets/slide_background.dart';

/// Mode 4 — Bones. Just emoji + keyword per section.
///
/// The absolute minimum prompt — forces full recall from the visual
/// anchors built up through earlier modes.
class BonesScreen extends StatelessWidget {
  const BonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        itemCount: data.sections.length,
        itemBuilder: (context, index) {
          final section = data.sections[index];
          return SlideBackground(
            section: section,
            overlayOpacity: 0.5,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        SectionIndicator(section: section),
                        const Spacer(),
                        const SizedBox(width: 48), // balance
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Emoji story
                  Text(
                    section.emoji,
                    style: const TextStyle(fontSize: 40, letterSpacing: 8),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // Keyword
                  Text(
                    section.keyword,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  // Hint
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      'Swipe for next section',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
