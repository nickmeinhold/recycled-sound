import 'dart:async';
import 'dart:typed_data';

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/point_cloud.dart';
import 'widgets/ar_point_overlay_painter.dart';
import 'widgets/point_cloud_viewer.dart';

/// 3D capture screen — uses LiDAR depth tracking to build a real-time
/// point cloud of the hearing aid, rendered directly ON the AR camera view.
///
/// Points materialize on the surface of the real object as the LiDAR
/// captures depth data. Move the camera and the points stay anchored.
class Capture3dScreen extends StatefulWidget {
  const Capture3dScreen({super.key, this.deviceName});

  final String? deviceName;

  @override
  State<Capture3dScreen> createState() => _Capture3dScreenState();
}

enum _CapturePhase { scanning, viewing }

class _Capture3dScreenState extends State<Capture3dScreen> {
  ARKitController? _arkitController;
  // Fine voxel grid (0.5mm) for small objects at close range
  final _cloud = PointCloudBuilder(maxPoints: 80000, voxelSize: 0.0005);
  Timer? _captureTimer;
  Timer? _projectionTimer;
  _CapturePhase _phase = _CapturePhase.scanning;
  int _framesCaptured = 0;
  String _status = 'Initialising LiDAR...';
  bool _disposed = false;

  // Camera matrices for AR overlay projection
  Matrix4 _viewMatrix = Matrix4.identity();
  Matrix4 _projectionMatrix = Matrix4.identity();

  @override
  void dispose() {
    _disposed = true;
    _captureTimer?.cancel();
    _projectionTimer?.cancel();
    _arkitController?.dispose();
    super.dispose();
  }

  void _onARKitViewCreated(ARKitController controller) {
    _arkitController = controller;
    setState(() => _status = 'Point at the hearing aid and slowly orbit');

    // Capture depth frames every 200ms (~5 fps) — heavy, builds the cloud
    _captureTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _captureDepthFrame();
    });

    // Update projection every 66ms (~15 fps) — light, just matrix fetch + repaint
    _projectionTimer = Timer.periodic(const Duration(milliseconds: 66), (_) {
      _updateProjection();
    });
  }

  /// Fetch current camera matrices for AR overlay rendering.
  Future<void> _updateProjection() async {
    if (_disposed || _arkitController == null) return;
    if (_phase != _CapturePhase.scanning) return;

    try {
      final pov = await _arkitController!.pointOfViewTransform();
      final proj = await _arkitController!.cameraProjectionMatrix();

      if (pov != null && proj != null && mounted) {
        setState(() {
          // View matrix = inverse of camera world transform
          _viewMatrix = Matrix4.copy(pov)..invert();
          _projectionMatrix = proj;
        });
      }
    } catch (_) {}
  }

  Future<void> _captureDepthFrame() async {
    if (_disposed || _arkitController == null) return;
    if (_phase != _CapturePhase.scanning) return;

    try {
      final snapshot = await _arkitController!.snapshotWithDepthData();
      if (snapshot == null || _disposed) {
        if (mounted && _framesCaptured == 0 && !_disposed) {
          setState(() => _status = 'No depth data — is LiDAR available?');
        }
        return;
      }

      final depthList = snapshot['depthMap'];
      final depthWidth = snapshot['depthWidth'] as int?;
      final depthHeight = snapshot['depthHeight'] as int?;
      final intrinsics = snapshot['intrinsics'] as String?;

      if (depthList == null || depthWidth == null || depthHeight == null) return;

      final Float32List depthData;
      if (depthList is Float32List) {
        depthData = depthList;
      } else if (depthList is List) {
        depthData = Float32List.fromList(
          depthList.map((e) => (e as num).toDouble()).toList(),
        );
      } else {
        return;
      }

      double fx = 500, fy = 500;
      double cx = depthWidth / 2, cy = depthHeight / 2;
      if (intrinsics != null) {
        final parts = intrinsics.split(RegExp(r'[\s,]+'));
        if (parts.length >= 4) {
          final pfx = double.tryParse(parts[0]);
          final pfy = double.tryParse(parts[1]);
          final pcx = double.tryParse(parts[2]);
          final pcy = double.tryParse(parts[3]);
          if (pfx != null && pfx.isFinite && pfx > 0) fx = pfx;
          if (pfy != null && pfy.isFinite && pfy > 0) fy = pfy;
          if (pcx != null && pcx.isFinite) cx = pcx;
          if (pcy != null && pcy.isFinite) cy = pcy;
        }
      }

      final pov = await _arkitController!.pointOfViewTransform();
      final cameraPose = pov ?? Matrix4.identity();

      _cloud.addFrame(
        depthData: depthData,
        depthWidth: depthWidth,
        depthHeight: depthHeight,
        fx: fx,
        fy: fy,
        cx: cx,
        cy: cy,
        cameraPose: cameraPose,
      );

      if (!_disposed && mounted) {
        setState(() {
          _framesCaptured++;
          _status = '${_cloud.count} points from $_framesCaptured frames';
        });
      }
    } catch (e) {
      if (mounted && _framesCaptured == 0) {
        setState(() => _status = 'Depth error: $e');
      }
    }
  }

  void _finishScanning() {
    _captureTimer?.cancel();
    _projectionTimer?.cancel();
    setState(() {
      _phase = _CapturePhase.viewing;
      _status = '${_cloud.count} points — spin it!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // AR camera view (scanning) or interactive point cloud (viewing)
            if (_phase == _CapturePhase.scanning)
              ARKitSceneView(
                configuration: ARKitConfiguration.depthTracking,
                onARKitViewCreated: _onARKitViewCreated,
              )
            else
              PointCloudViewer(
                cloud: _cloud,
                pointSize: 2.5,
              ),

            // AR point cloud overlay — points rendered ON the real object
            if (_phase == _CapturePhase.scanning && _cloud.count > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ArPointOverlayPainter(
                      points: _cloud.points,
                      viewMatrix: _viewMatrix,
                      projectionMatrix: _projectionMatrix,
                    ),
                  ),
                ),
              ),

            // Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _phase == _CapturePhase.scanning
                            ? '3D SCAN'
                            : '3D MODEL',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      if (widget.deviceName != null)
                        Text(
                          widget.deviceName!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.white.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD000000)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _status.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0x99FFFFFF),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_phase == _CapturePhase.scanning) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (_cloud.count / 30000).clamp(0.0, 1.0),
                          backgroundColor: const Color(0x22FFFFFF),
                          color: _cloud.count > 10000
                              ? AppColors.success
                              : AppColors.primary,
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_phase == _CapturePhase.scanning &&
                        _cloud.count > 5000)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _finishScanning,
                          icon: const Icon(Icons.threed_rotation, size: 18),
                          label: Text(
                            'View 3D Model (${_cloud.count} points)',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    if (_phase == _CapturePhase.viewing)
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                _cloud.clear();
                                setState(() {
                                  _phase = _CapturePhase.scanning;
                                  _framesCaptured = 0;
                                  _status = 'Point at the hearing aid';
                                  _viewMatrix = Matrix4.identity();
                                  _projectionMatrix = Matrix4.identity();
                                });
                                _captureTimer = Timer.periodic(
                                  const Duration(milliseconds: 200),
                                  (_) => _captureDepthFrame(),
                                );
                                _projectionTimer = Timer.periodic(
                                  const Duration(milliseconds: 66),
                                  (_) => _updateProjection(),
                                );
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Rescan'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0x33FFFFFF),
                                foregroundColor: AppColors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Done'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
