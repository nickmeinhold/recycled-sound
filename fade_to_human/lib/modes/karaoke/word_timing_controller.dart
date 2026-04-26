import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives word-by-word advancement at a configurable speaking pace.
///
/// Notifies listeners on every word tick so the UI can update opacity/style
/// per word. Uses [Timer.periodic] rather than [AnimationController] because
/// we need discrete word steps, not continuous interpolation.
class WordTimingController extends ChangeNotifier {
  WordTimingController({
    required this.words,
    double wordsPerMinute = 130,
  }) : _wpm = wordsPerMinute;

  final List<String> words;
  double _wpm;
  int _currentIndex = -1; // -1 = not started
  Timer? _timer;
  bool _isComplete = false;

  int get currentIndex => _currentIndex;
  bool get isPlaying => _timer != null;
  bool get isComplete => _isComplete;

  double get wpm => _wpm;
  set wpm(double value) {
    _wpm = value;
    if (isPlaying) {
      // Restart timer with new interval.
      _timer?.cancel();
      _startTimer();
    }
  }

  Duration get _wordInterval =>
      Duration(milliseconds: (60000 / _wpm).round());

  /// Start or resume playback.
  void play() {
    if (_isComplete) return;
    if (isPlaying) return;
    if (_currentIndex == -1) _currentIndex = 0;
    notifyListeners();
    _startTimer();
  }

  /// Pause playback, keeping position.
  void pause() {
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Toggle play/pause.
  void toggle() => isPlaying ? pause() : play();

  /// Reset to beginning.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _currentIndex = -1;
    _isComplete = false;
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(_wordInterval, (_) {
      if (_currentIndex < words.length - 1) {
        _currentIndex++;
        notifyListeners();
      } else {
        _timer?.cancel();
        _timer = null;
        _isComplete = true;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
