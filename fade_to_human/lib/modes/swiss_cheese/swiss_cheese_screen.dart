import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/section.dart';
import '../../data/sections.dart' as data;
import '../../widgets/section_indicator.dart';
import '../../widgets/slide_background.dart';

/// Mode 2 — Progressive erasure.
///
/// Each time you complete a run-through, more words vanish (replaced with
/// dots). Tap a gap to peek at the hidden word for 500ms.
class SwissCheeseScreen extends StatefulWidget {
  const SwissCheeseScreen({super.key});

  @override
  State<SwissCheeseScreen> createState() => _SwissCheeseScreenState();
}

class _SwissCheeseScreenState extends State<SwissCheeseScreen> {
  late PageController _pageController;

  /// For each section: a list of bools — true = visible, false = erased.
  late List<List<bool>> _visibility;

  /// Current erasure level per section (0 = full text, increases each pass).
  late List<int> _erasureLevels;

  /// Index of a word currently being "peeked" at, per section.
  /// -1 means no active peek.
  late List<int> _peekingAt;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _visibility = data.sections
        .map((s) => List.filled(s.words.length, true))
        .toList();
    _erasureLevels = List.filled(data.sections.length, 0);
    _peekingAt = List.filled(data.sections.length, -1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Erase ~20% more words, avoiding first/last word of the section.
  void _increaseErasure(int sectionIndex) {
    final section = data.sections[sectionIndex];
    final vis = _visibility[sectionIndex];
    _erasureLevels[sectionIndex]++;

    // Candidates: currently visible, not first or last word.
    final candidates = <int>[];
    for (var i = 1; i < vis.length - 1; i++) {
      if (vis[i]) candidates.add(i);
    }

    final toErase = (section.words.length * 0.20).round().clamp(1, candidates.length);
    candidates.shuffle(Random());
    for (final i in candidates.take(toErase)) {
      vis[i] = false;
    }
    setState(() {});
  }

  void _peek(int sectionIndex, int wordIndex) {
    setState(() => _peekingAt[sectionIndex] = wordIndex);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _peekingAt[sectionIndex] == wordIndex) {
        setState(() => _peekingAt[sectionIndex] = -1);
      }
    });
  }

  void _resetSection(int sectionIndex) {
    final section = data.sections[sectionIndex];
    setState(() {
      _visibility[sectionIndex] = List.filled(section.words.length, true);
      _erasureLevels[sectionIndex] = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: data.sections.length,
        onPageChanged: (i) => setState(() {}),
        itemBuilder: (context, index) {
          final section = data.sections[index];
          return SlideBackground(
            section: section,
            overlayOpacity: 0.7,
            child: SafeArea(
              child: Column(
                children: [
                  // Header
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
                        // Erasure level badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Level ${_erasureLevels[index]}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Swiss cheese text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Center(
                        child: SingleChildScrollView(
                          child: _buildSwissCheeseText(
                            section,
                            _visibility[index],
                            _peekingAt[index],
                            index,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom controls
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => _resetSection(index),
                          icon: const Icon(Icons.refresh,
                              color: Colors.white54),
                          label: const Text('Reset',
                              style: TextStyle(color: Colors.white54)),
                        ),
                        const SizedBox(width: 32),
                        FilledButton.icon(
                          onPressed: () => _increaseErasure(index),
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(
                            _erasureLevels[index] == 0
                                ? 'Start Erasing'
                                : 'Erase More',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
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

  Widget _buildSwissCheeseText(
    SpeakingSection section,
    List<bool> visibility,
    int peekingAt,
    int sectionIndex,
  ) {
    final words = section.words;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 10,
      children: words.asMap().entries.map((entry) {
        final i = entry.key;
        final word = entry.value;
        final isVisible = visibility[i];
        final isPeeking = peekingAt == i;

        if (isVisible || isPeeking) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isPeeking ? 1.0 : (isVisible ? 0.9 : 0.0),
            child: Text(
              word,
              style: TextStyle(
                color: isPeeking ? Colors.amber : Colors.white,
                fontSize: 26,
                fontWeight:
                    isPeeking ? FontWeight.bold : FontWeight.normal,
                height: 1.7,
              ),
            ),
          );
        } else {
          // Erased — show dots, tappable to peek.
          return GestureDetector(
            onTap: () => _peek(sectionIndex, i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
              child: Text(
                '\u2022' * (word.length ~/ 2 + 1),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 26,
                  height: 1.7,
                  letterSpacing: 2,
                ),
              ),
            ),
          );
        }
      }).toList(),
    );
  }
}
