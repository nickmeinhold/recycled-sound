import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/brand_matcher.dart';
import 'widgets/feature_overlay_painter.dart';
import 'widgets/scan_hud.dart';

/// The scanner's lifecycle phases.
enum _ScanPhase { booting, scanning, complete }

/// Live scanner screen — the T2 HUD experience.
///
/// Lifecycle:
/// 1. **Boot** — system check animation while camera initializes
/// 2. **Scan** — live camera with ambient text detection + brand/model matching
/// 3. **Complete** — identification confirmed, review prompt
class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Camera ────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  CameraDescription? _camera;
  bool _cameraReady = false;
  String? _cameraError;

  // ── ML Kit ────────────────────────────────────────────────────────────
  final _textRecognizer = TextRecognizer();
  bool _isProcessing = false;

  // ── Detection state ───────────────────────────────────────────────────
  String? _detectedBrand;
  String? _detectedModel;
  String? _brandConfidence;
  List<TextDetection> _liveDetections = [];
  Size _imageSize = Size.zero;

  // ── Phase & animation ─────────────────────────────────────────────────
  _ScanPhase _phase = _ScanPhase.booting;
  late final AnimationController _pulseController;
  int _bootStep = -1; // -1 = not started, 0-3 = lines resolving
  bool _bootComplete = false;

  // ── Cross-reference flash ─────────────────────────────────────────────
  String? _crossRefText;
  Timer? _crossRefTimer;

  // ── Completion overlay ────────────────────────────────────────────────
  bool _showCompletion = false;
  bool _completionFired = false;

  // ── Timing ────────────────────────────────────────────────────────────
  Timer? _hintTimer;
  bool _showHint = false;
  bool _disposed = false;

  // ── Boot sequence lines ───────────────────────────────────────────────
  static const _bootLines = [
    ('CAMERA', 'READY'),
    ('OCR ENGINE', 'READY'),
    ('DEVICE DATABASE', '345 DEVICES'),
    ('', 'SCANNER ONLINE'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _runBootSequence();
    _initCamera();

    _hintTimer = Timer(const Duration(seconds: 15), () {
      if (_detectedBrand == null && mounted) {
        setState(() => _showHint = true);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    _crossRefTimer?.cancel();
    _pulseController.dispose();
    _stopCamera();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ── Boot sequence ─────────────────────────────────────────────────────

  Future<void> _runBootSequence() async {
    for (var i = 0; i < _bootLines.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (_disposed) return;
      setState(() => _bootStep = i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_disposed) return;
    setState(() => _bootComplete = true);
    _tryTransitionToScanning();
  }

  void _tryTransitionToScanning() {
    if (_bootComplete && _cameraReady && _phase == _ScanPhase.booting) {
      setState(() => _phase = _ScanPhase.scanning);
    }
  }

  // ── Camera setup ──────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras available');
      if (_disposed) return;

      _camera = cameras.first;
      _cameraController = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (_disposed) return;

      await _cameraController!.startImageStream(_onCameraFrame);
      setState(() => _cameraReady = true);
      _tryTransitionToScanning();
    } catch (e) {
      if (_disposed) return;
      setState(() => _cameraError = e.toString());
    }
  }

  void _stopCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    _cameraReady = false;
  }

  // ── Frame processing ──────────────────────────────────────────────────

  void _onCameraFrame(CameraImage image) {
    if (_isProcessing || _disposed) return;
    _isProcessing = true;
    _processFrame(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (_disposed || !mounted) return;

      final detections = <TextDetection>[];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty || text.length < 2) continue;

          bool wasMatched = false;

          // Try brand matching
          if (_detectedBrand == null) {
            final result = BrandMatcher.matchBrandDetailed(text);
            if (result != null) {
              detections.add(TextDetection(
                boundingBox: line.boundingBox,
                label: 'MAKE: ${result.displayName} [${result.confidenceLabel}]',
                type: DetectionType.matched,
              ));
              _detectedBrand = result.displayName;
              _brandConfidence = result.confidenceLabel;
              HapticFeedback.mediumImpact();
              _showCrossReference(result.displayName);
              wasMatched = true;
            }
          } else {
            // Brand already found — still highlight it
            final result = BrandMatcher.matchBrand(text);
            if (result != null) {
              detections.add(TextDetection(
                boundingBox: line.boundingBox,
                label: 'MAKE: $result',
                type: DetectionType.matched,
              ));
              wasMatched = true;
            }
          }

          // Try model matching
          if (_detectedBrand != null && _detectedModel == null && !wasMatched) {
            final model = BrandMatcher.matchModel(text, _detectedBrand!);
            if (model != null) {
              detections.add(TextDetection(
                boundingBox: line.boundingBox,
                label: 'MODEL: $model',
                type: DetectionType.matched,
              ));
              _detectedModel = model;
              HapticFeedback.mediumImpact();
              wasMatched = true;
            }
          }

          // Ambient detection — show the scanner reading everything
          if (!wasMatched && text.length >= 2) {
            detections.add(TextDetection(
              boundingBox: line.boundingBox,
              label: text,
              type: DetectionType.ambient,
            ));
          }
        }
      }

      // Check for completion
      if (_detectedBrand != null &&
          _detectedModel != null &&
          !_completionFired) {
        _completionFired = true;
        _fireCompletion();
      }

      setState(() {
        _liveDetections = detections;
        _imageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
        if (detections.any((d) => d.type == DetectionType.matched)) {
          _showHint = false;
        }
      });
    } catch (_) {
      // ML Kit can fail on corrupt frames — skip silently
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_camera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      _camera!.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(CameraImage image) {
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // ── Cross-reference flash ─────────────────────────────────────────────

  void _showCrossReference(String brand) {
    // TODO: use actual count from DeviceCatalog once loaded
    final count = switch (brand.toLowerCase()) {
      'oticon' => 23,
      'phonak' => 45,
      'signia' => 38,
      'widex' => 18,
      'resound' => 28,
      'unitron' => 22,
      'starkey' => 15,
      _ => 12,
    };

    setState(() {
      _crossRefText =
          'CROSS-REFERENCING... $count ${brand.toUpperCase()} DEVICES IN DATABASE';
    });

    _crossRefTimer?.cancel();
    _crossRefTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _crossRefText = null);
    });
  }

  // ── Completion sequence ───────────────────────────────────────────────

  void _fireCompletion() {
    HapticFeedback.heavyImpact();
    setState(() {
      _showCompletion = true;
      _phase = _ScanPhase.complete;
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showCompletion = false);
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _captureAndReview() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      await _cameraController!.stopImageStream();
      final xFile = await _cameraController!.takePicture();
      if (mounted) {
        context.push('/scan/analysing', extra: xFile.path);
      }
    } catch (e) {
      if (mounted && _cameraController != null) {
        _cameraController!.startImageStream(_onCameraFrame);
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      await _cameraController!.stopImageStream();
      final xFile = await _cameraController!.takePicture();
      if (mounted) {
        context.push('/scan/analysing', extra: xFile.path);
      }
    } catch (e) {
      if (mounted && _cameraController != null) {
        _cameraController!.startImageStream(_onCameraFrame);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (image != null && mounted) {
      context.push('/scan/analysing', extra: image.path);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview or fallback states
            if (_cameraReady && _cameraController != null)
              _buildCameraPreview()
            else if (_cameraError != null)
              _buildError()
            else
              Container(color: Colors.black),

            // Boot sequence overlay
            if (_phase == _ScanPhase.booting) _buildBootSequence(),

            // Back button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.white),
                onPressed: () => context.pop(),
              ),
            ),

            // Feature overlay (green + amber boxes)
            if (_phase != _ScanPhase.booting && _liveDetections.isNotEmpty)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => CustomPaint(
                    painter: FeatureOverlayPainter(
                      detections: _liveDetections,
                      imageSize: _imageSize,
                      previewSize: MediaQuery.of(context).size,
                      sensorOrientation: _camera?.sensorOrientation ?? 0,
                      animationValue: _pulseController.value,
                    ),
                  ),
                ),
              ),

            // Completion overlay
            if (_showCompletion) _buildCompletionOverlay(),

            // Bottom HUD + capture controls
            if (_phase != _ScanPhase.booting && _cameraReady)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScanHud(
                      detectedBrand: _detectedBrand,
                      detectedModel: _detectedModel,
                      brandConfidence: _brandConfidence,
                      crossRefText: _crossRefText,
                      showHint: _showHint,
                      onReview: _captureAndReview,
                      onFallback: _pickFromGallery,
                    ),
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library_outlined,
                                color: AppColors.white, size: 28),
                          ),
                          GestureDetector(
                            onTap: _takePhoto,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.white, width: 3),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Boot sequence UI ──────────────────────────────────────────────────

  Widget _buildBootSequence() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _bootLines.length; i++)
                if (i <= _bootStep) _buildBootLine(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBootLine(int index) {
    final (label, value) = _bootLines[index];

    // Final "SCANNER ONLINE" line — special treatment
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
            letterSpacing: 2.0,
          ),
        ),
      );
    }

    // Dotted leader line: "CAMERA .............. READY"
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0x99FFFFFF),
              letterSpacing: 0.5,
            ),
          ),
          Expanded(
            child: Text(
              ' ${'.' * 20} ',
              overflow: TextOverflow.clip,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0x33FFFFFF),
                letterSpacing: 1.0,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Completion overlay ────────────────────────────────────────────────

  Widget _buildCompletionOverlay() {
    return AnimatedOpacity(
      opacity: _showCompletion ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        color: const Color(0xBB000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.success, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'IDENTIFICATION COMPLETE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_detectedBrand $_detectedModel',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '\u25B6 PROCEED TO REVIEW',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0x88FFFFFF),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Camera preview ────────────────────────────────────────────────────

  Widget _buildCameraPreview() {
    final controller = _cameraController!;
    final mediaSize = MediaQuery.of(context).size;
    final scale =
        1 / (controller.value.aspectRatio * mediaSize.aspectRatio);

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'Camera not available',
              style: AppTypography.h3.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'You can still scan by selecting a photo.',
              style: AppTypography.body.copyWith(
                color: AppColors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose Photo'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
