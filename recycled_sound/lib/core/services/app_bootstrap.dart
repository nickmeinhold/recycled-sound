import 'dart:async';

/// Tracks the async initialisation Future kicked off in `main()` so the boot
/// screen can await it without re-running it. Singleton-by-static so we don't
/// have to thread it through Riverpod just for this.
class AppBootstrap {
  static Future<void>? _ready;
  static String? _error;

  /// Start the init task. Safe to call exactly once from `main()`.
  static void start(Future<void> Function() initialiser) {
    _ready = initialiser().catchError((Object e, StackTrace s) {
      _error = e.toString();
    });
  }

  /// Resolves when init succeeds (or has already succeeded). Surfaces nothing
  /// useful — callers just need the `await`.
  static Future<void> get ready async {
    if (_ready == null) return;
    await _ready;
  }

  static String? get error => _error;
}
