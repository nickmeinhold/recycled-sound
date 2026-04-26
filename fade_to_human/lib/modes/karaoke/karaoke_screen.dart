import 'package:flutter/material.dart';

import '../../data/section.dart';
import '../../data/sections.dart' as data;
import '../../widgets/section_indicator.dart';
import '../../widgets/slide_background.dart';
import '../../widgets/speed_control.dart';
import 'word_timing_controller.dart';

/// Mode 1 — Full karaoke with word-by-word highlighting.
///
/// Words illuminate one at a time at speaking pace. Already-spoken words
/// fade to 20% opacity. The current word goes bold and full brightness.
/// Upcoming words sit at 55%.
class KaraokeScreen extends StatefulWidget {
  const KaraokeScreen({super.key});

  @override
  State<KaraokeScreen> createState() => _KaraokeScreenState();
}

class _KaraokeScreenState extends State<KaraokeScreen> {
  late PageController _pageController;
  int _currentSection = 0;
  late List<WordTimingController> _controllers;
  double _wpm = 130;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controllers = data.sections.map((s) {
      return WordTimingController(words: s.words, wordsPerMinute: _wpm);
    }).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onWpmChanged(double value) {
    _wpm = value;
    for (final c in _controllers) {
      c.wpm = value;
    }
  }

  void _goToSection(int index) {
    if (index < 0 || index >= data.sections.length) return;
    _controllers[_currentSection].pause();
    setState(() => _currentSection = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: data.sections.length,
        onPageChanged: (i) {
          _controllers[_currentSection].pause();
          setState(() => _currentSection = i);
        },
        itemBuilder: (context, index) {
          return _KaraokePage(
            section: data.sections[index],
            controller: _controllers[index],
            wpm: _wpm,
            onWpmChanged: _onWpmChanged,
            onNext: index < data.sections.length - 1
                ? () => _goToSection(index + 1)
                : null,
            onPrev: index > 0 ? () => _goToSection(index - 1) : null,
          );
        },
      ),
    );
  }
}

class _KaraokePage extends StatelessWidget {
  const _KaraokePage({
    required this.section,
    required this.controller,
    required this.wpm,
    required this.onWpmChanged,
    this.onNext,
    this.onPrev,
  });

  final SpeakingSection section;
  final WordTimingController controller;
  final double wpm;
  final ValueChanged<double> onWpmChanged;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;

  @override
  Widget build(BuildContext context) {
    return SlideBackground(
      section: section,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  SectionIndicator(section: section),
                  const Spacer(),
                  SpeedControl(wpm: wpm, onChanged: onWpmChanged),
                ],
              ),
            ),

            // Karaoke text — the main event
            Expanded(
              child: GestureDetector(
                onTap: controller.toggle,
                behavior: HitTestBehavior.opaque,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Center(
                        child: SingleChildScrollView(
                          child: _buildKaraokeText(
                            controller.currentIndex,
                            section.words,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (onPrev != null)
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.white54, size: 32),
                          onPressed: onPrev,
                        ),
                      const SizedBox(width: 16),
                      // Play/pause button
                      IconButton(
                        icon: Icon(
                          controller.isComplete
                              ? Icons.replay
                              : controller.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 56,
                        ),
                        onPressed: controller.isComplete
                            ? controller.reset
                            : controller.toggle,
                      ),
                      const SizedBox(width: 16),
                      if (onNext != null)
                        IconButton(
                          icon: Icon(
                            Icons.skip_next,
                            color: controller.isComplete
                                ? Colors.white
                                : Colors.white54,
                            size: 32,
                          ),
                          onPressed: onNext,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKaraokeText(int currentIndex, List<String> words) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final i = entry.key;
          final word = entry.value;

          final double opacity;
          final FontWeight weight;

          if (currentIndex == -1) {
            // Not started — all words at medium opacity.
            opacity = 0.55;
            weight = FontWeight.normal;
          } else if (i < currentIndex) {
            // Already spoken.
            opacity = 0.20;
            weight = FontWeight.normal;
          } else if (i == currentIndex) {
            // Current word — spotlight.
            opacity = 1.0;
            weight = FontWeight.bold;
          } else {
            // Upcoming.
            opacity = 0.55;
            weight = FontWeight.normal;
          }

          return TextSpan(
            text: '$word ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity),
              fontSize: 28,
              fontWeight: weight,
              height: 1.7,
              letterSpacing: 0.3,
            ),
          );
        }).toList(),
      ),
    );
  }
}
