import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/object_capture_channel.dart';

/// 3D capture screen — uses LiDAR Object Capture to build a USDZ model.
///
/// Flow:
/// 1. Check device support
/// 2. Start capture session — user orbits the hearing aid
/// 3. Guidance text helps the user ("move closer", "slow down")
/// 4. When enough shots are taken, finish and reconstruct
/// 5. Navigate to model viewer with the USDZ file
class Capture3dScreen extends StatefulWidget {
  const Capture3dScreen({super.key, this.deviceName});

  /// Optional device name from the scanner, e.g. "Oticon Nera2 Pro".
  final String? deviceName;

  @override
  State<Capture3dScreen> createState() => _Capture3dScreenState();
}

class _Capture3dScreenState extends State<Capture3dScreen> {
  final _capture = ObjectCaptureChannel.instance;

  String _state = 'idle';
  String _guidance = 'Point at the hearing aid';
  int _shotsTaken = 0;
  bool _isComplete = false;
  double _reconstructionProgress = 0.0;
  String? _modelPath;
  bool _isSupported = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _capture.startListening();
    _capture.onStateChanged = (state) {
      if (mounted) setState(() => _state = state);
    };
    _capture.onProgress = (shots, complete) {
      if (mounted) {
        setState(() {
          _shotsTaken = shots;
          _isComplete = complete;
        });
      }
    };
    _capture.onGuidance = (guidance) {
      if (mounted) setState(() => _guidance = guidance);
    };
    _capture.onReconstructionProgress = (progress) {
      if (mounted) setState(() => _reconstructionProgress = progress);
    };
    _capture.onModelReady = (path) {
      if (mounted) {
        setState(() {
          _modelPath = path;
          _state = 'done';
        });
      }
    };

    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await _capture.isSupported();
    if (mounted) {
      setState(() {
        _isSupported = supported;
        _checking = false;
      });
      if (supported) _startCapture();
    }
  }

  Future<void> _startCapture() async {
    try {
      await _capture.startSession();
    } catch (e) {
      if (mounted) {
        setState(() => _state = 'error');
      }
    }
  }

  Future<void> _finishCapture() async {
    setState(() => _state = 'reconstructing');
    try {
      await _capture.finish();
    } catch (e) {
      if (mounted) {
        setState(() => _state = 'error');
      }
    }
  }

  @override
  void dispose() {
    _capture.cancel();
    _capture.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3D CAPTURE',
                          style: AppTypography.h4.copyWith(
                            color: AppColors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                        if (widget.deviceName != null)
                          Text(
                            widget.deviceName!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.white.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main content area
            Expanded(
              child: _checking
                  ? _buildChecking()
                  : !_isSupported
                      ? _buildNotSupported()
                      : _state == 'reconstructing'
                          ? _buildReconstructing()
                          : _state == 'done'
                              ? _buildDone()
                              : _state == 'error'
                                  ? _buildError()
                                  : _buildCapturing(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecking() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'CHECKING LIDAR...',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0x99FFFFFF),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotSupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              '3D Capture Not Available',
              style: AppTypography.h3.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature requires a LiDAR-equipped iPhone (12 Pro or later) running iOS 17+.',
              style: AppTypography.body.copyWith(
                color: AppColors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturing() {
    return Column(
      children: [
        // The AR view would go here — for now showing guidance
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated orbit indicator
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _shotsTaken / 30, // ~30 shots for full orbit
                      strokeWidth: 3,
                      color: AppColors.success,
                      backgroundColor: const Color(0x22FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$_shotsTaken SHOTS',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _guidance.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0x99FFFFFF),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _state.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: _state == 'capturing'
                          ? AppColors.success
                          : const Color(0x66FFFFFF),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom controls
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              if (_isComplete || _shotsTaken >= 20)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _finishCapture,
                    icon: const Icon(Icons.view_in_ar, size: 18),
                    label: const Text('Build 3D Model'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  'Slowly orbit the hearing aid',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReconstructing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _reconstructionProgress > 0
                  ? _reconstructionProgress
                  : null,
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'BUILDING 3D MODEL',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _reconstructionProgress > 0
                ? '${(_reconstructionProgress * 100).round()}%'
                : 'Processing...',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0x99FFFFFF),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_in_ar, color: AppColors.success, size: 64),
          const SizedBox(height: 16),
          const Text(
            '3D MODEL READY',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 24),
          if (_modelPath != null)
            FilledButton.icon(
              onPressed: () {
                // TODO: Open USDZ viewer or QuickLook
                context.pop(_modelPath);
              },
              icon: const Icon(Icons.threed_rotation, size: 18),
              label: const Text('View Model'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'Capture failed',
            style: AppTypography.h3.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() => _state = 'idle');
              _startCapture();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
