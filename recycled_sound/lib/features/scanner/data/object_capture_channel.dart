import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel client for Apple's Object Capture API.
///
/// Communicates with the native ObjectCapturePlugin via method channel.
/// All methods are no-ops on non-iOS platforms.
class ObjectCaptureChannel {
  ObjectCaptureChannel._();
  static final instance = ObjectCaptureChannel._();

  static const _channel = MethodChannel('recycled_sound/object_capture');

  /// Callbacks from native side.
  void Function(String state)? onStateChanged;
  void Function(int shotsTaken, bool isComplete)? onProgress;
  void Function(String guidance)? onGuidance;
  void Function(double progress)? onReconstructionProgress;
  void Function(String modelPath)? onModelReady;

  bool _listening = false;

  /// Start listening for native callbacks.
  void startListening() {
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      final args = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'onStateChanged':
          onStateChanged?.call(args?['state'] as String? ?? 'unknown');
        case 'onProgress':
          onProgress?.call(
            args?['shotsTaken'] as int? ?? 0,
            args?['isComplete'] as bool? ?? false,
          );
        case 'onGuidance':
          onGuidance?.call(args?['guidance'] as String? ?? '');
        case 'onReconstructionProgress':
          onReconstructionProgress
              ?.call((args?['progress'] as num?)?.toDouble() ?? 0.0);
        case 'onModelReady':
          onModelReady?.call(args?['path'] as String? ?? '');
      }
    });
  }

  /// Stop listening and clear callbacks.
  void stopListening() {
    _listening = false;
    _channel.setMethodCallHandler(null);
    onStateChanged = null;
    onProgress = null;
    onGuidance = null;
    onReconstructionProgress = null;
    onModelReady = null;
  }

  /// Whether Object Capture is supported on this device.
  /// Times out after 3 seconds — if the native plugin hasn't registered
  /// its handler yet, we fall back gracefully.
  Future<bool> isSupported() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('isSupported')
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('ObjectCapture: isSupported timed out');
        return false;
      });
      return result ?? false;
    } on MissingPluginException catch (e) {
      debugPrint('ObjectCapture: MissingPluginException — $e');
      return false;
    } catch (e) {
      debugPrint('ObjectCapture: isSupported error — $e');
      return false;
    }
  }

  /// Start an Object Capture session.
  Future<void> startSession() async {
    await _channel.invokeMethod<void>('startSession');
  }

  /// Request an image capture (one shot of the object).
  Future<void> captureImage() async {
    await _channel.invokeMethod<void>('startCapture');
  }

  /// Finish capturing and begin 3D reconstruction.
  Future<String?> finish() async {
    return _channel.invokeMethod<String>('finish');
  }

  /// Cancel the session.
  Future<void> cancel() async {
    await _channel.invokeMethod<void>('cancel');
  }

  /// Get the current session state.
  Future<String> getState() async {
    return await _channel.invokeMethod<String>('getState') ?? 'idle';
  }

  /// Get the path to the reconstructed USDZ model.
  Future<String?> getModelPath() async {
    return _channel.invokeMethod<String>('getModelPath');
  }
}
