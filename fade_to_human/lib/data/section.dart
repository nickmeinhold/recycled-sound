import 'package:flutter/material.dart';

/// A single speaking section of the presentation.
///
/// Each section maps to one or more slides and contains the full speaking
/// text, pre-tokenised into words for the karaoke and swiss-cheese modes.
class SpeakingSection {
  const SpeakingSection({
    required this.index,
    required this.slideRef,
    required this.text,
    required this.emoji,
    required this.keyword,
    required this.color,
    this.backgroundImages = const [],
  });

  final int index;
  final String slideRef;
  final String text;
  final String emoji;
  final String keyword;
  final Color color;

  /// Slide images for memory palace backgrounds. Multiple images cycle
  /// or composite to anchor spatial memory.
  final List<String> backgroundImages;

  /// Pre-tokenised words, preserving punctuation attached to each word.
  List<String> get words => text.split(RegExp(r'\s+'));

  int get wordCount => words.length;

  /// Estimated speaking duration at the given WPM.
  Duration speakingDuration({double wpm = 130}) =>
      Duration(milliseconds: (wordCount / wpm * 60000).round());
}
