import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../data/brand_classifier.dart';
import '../data/brand_matcher.dart';
import '../data/colour_classifier.dart';
import 'widgets/capture_stack.dart';
import 'widgets/feature_overlay_painter.dart';
import 'widgets/progress_rail.dart';
import 'widgets/scan_hud.dart';

/// Debug log for scanner — compiled out in release builds.
void _log(String message) {
  if (kDebugMode) debugPrint('SCANNER: $message');
}

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

  // ── On-device brand classifier (EfficientNet-B0, TFLite) ────────────
  final _brandClassifier = BrandClassifier();

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

  // ── Colour detection ─────────────────────────────────────────────────
  String? _detectedColour;
  Color? _detectedColourRgb;
  double _colourConfidence = 0.0;
  bool _colourConfirmed = false;
  final ColourStabiliser _colourStabiliser = ColourStabiliser();

  // ── Captures & upload ──────────────────────────────────────────────
  final List<CapturedFeature> _captures = [];
  final List<SnapEvent> _snapEvents = [];
  bool _isCapturing = false;

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
    // Pre-load model during boot sequence — catch errors so it doesn't
    // crash the app if the TFLite runtime is incompatible
    _brandClassifier.load().catchError((e) {
      _log('brand classifier failed to load: $e');
    });

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
    _brandClassifier.dispose();
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

      // Log all available cameras to find the ultra-wide (macro-capable)
      for (final cam in cameras) {
        _log('camera: ${cam.name}, '
            'direction=${cam.lensDirection}, '
            'sensor=${cam.sensorOrientation}');
      }

      // On iPhone 13 Pro+, the ultra-wide back camera supports macro (2cm focus).
      // The main wide camera can't focus closer than ~15cm.
      // Try to find the ultra-wide (typically the second back-facing camera).
      final backCameras = cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();
      _log('${backCameras.length} back cameras found');

      // Use the main wide camera for live preview.
      // The neural net doesn't need macro focus — it identifies brands
      // from visual appearance at normal viewing distance.
      // cameras.first is the default back camera (main wide lens).
      _camera = cameras.first;
      _log('selected camera: ${_camera!.name}');
      _cameraController = CameraController(
        _camera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (_disposed) return;

      // Enable continuous autofocus with centre focus point.
      // setFocusPoint tells the camera to prioritise the centre of frame,
      // which helps it lock focus on the hearing aid.
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setFocusPoint(const Offset(0.5, 0.5));
      } catch (e) {
        _log('focus setup: $e');
      }

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

  int _frameCount = 0;

  void _onCameraFrame(CameraImage image) {
    _frameCount++;
    if (_frameCount == 1 || _frameCount % 100 == 0) {
      _log('frame #$_frameCount received '
          '(${image.width}x${image.height}, format=${image.format.group}, '
          'raw=${image.format.raw}, planes=${image.planes.length}, '
          'sensor=${_camera?.sensorOrientation})');
    }
    if (_isProcessing || _disposed) return;
    _isProcessing = true;
    _processFrame(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      // Colour sampling — runs on raw bytes, sub-millisecond.
      // Runs before ML Kit so colour updates even on frames where OCR is slow.
      if (Platform.isIOS &&
          image.planes.isNotEmpty &&
          !_colourConfirmed) {
        final sampled = ColourClassifier.sampleFromBgra8888(
          bytes: image.planes[0].bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: image.planes[0].bytesPerRow,
        );
        final match = ColourClassifier.classify(sampled);
        _colourStabiliser.push(match.name, match.reference);
      }

      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _log('_buildInputImage returned null — frame skipped');
        return;
      }

      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (_disposed || !mounted) return;

      // Debug: log what ML Kit sees
      if (recognizedText.blocks.isEmpty) {
        if (_frameCount % 50 == 0) {
          _log('ML Kit returned 0 blocks (frame #$_frameCount)');
        }
      }
      if (recognizedText.blocks.isNotEmpty) {
        final texts = recognizedText.blocks
            .expand((b) => b.lines)
            .map((l) => l.text)
            .join(' | ');
        _log('ML Kit found ${recognizedText.blocks.length} blocks: $texts');
      }

      final detections = <TextDetection>[];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty || text.length < 2) continue;

          bool wasMatched = false;

          // Log every text line ML Kit reads (throttled)
          if (_frameCount % 30 == 0) {
            final modelCheck = BrandMatcher.matchModelAnyBrand(text);
            final brandCheck = BrandMatcher.matchBrandDetailed(text);
            _log('text="$text" '
                'modelMatch=${modelCheck != null ? "${modelCheck.brand}/${modelCheck.model}" : "none"} '
                'brandMatch=${brandCheck?.displayName ?? "none"}');
          }

          // Model-first detection: check if text matches a known model
          // from ANY brand. This handles cases where the model name is
          // visible but the brand name isn't (e.g., "moxi2 kiss" → Unitron).
          if (_detectedModel == null && !wasMatched) {
            final reverse = BrandMatcher.matchModelAnyBrand(text);
            if (reverse != null) {
              // Model found — also sets brand if not already detected
              detections.add(TextDetection(
                boundingBox: line.boundingBox,
                label: 'MODEL: ${reverse.model}',
                type: DetectionType.matched,
              ));
              _detectedModel = reverse.model;
              HapticFeedback.mediumImpact();
              _captureSnapshot('MODEL', reverse.model, line.boundingBox);
              wasMatched = true;

              if (_detectedBrand == null) {
                // Infer brand from model
                _detectedBrand = reverse.brand;
                _brandConfidence = 'FROM MODEL';
                HapticFeedback.mediumImpact();
                _showCrossReference(reverse.brand);
                // No separate snapshot for brand — the model capture covers it
              }
            }
          }

          // Try brand matching (only if model-first didn't already find it)
          if (_detectedBrand == null && !wasMatched) {
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
              _captureSnapshot('MAKE', result.displayName, line.boundingBox);
              wasMatched = true;
            }
          } else if (_detectedBrand != null && !wasMatched) {
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

          // Try model matching against known brand (if brand found first)
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
              _captureSnapshot('MODEL', model, line.boundingBox);
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
        // Update colour — show immediately, confidence builds over frames
        if (!_colourConfirmed) {
          _detectedColour = _colourStabiliser.leadingColour;
          _detectedColourRgb = _colourStabiliser.leadingRgb;
          _colourConfidence = _colourStabiliser.confidence;

          // Auto-confirm once stabiliser reaches consensus
          if (_colourStabiliser.isStable && !_colourConfirmed) {
            _colourConfirmed = true;
            HapticFeedback.lightImpact();
            _captures.add(CapturedFeature(
              id: 'COLOUR_${DateTime.now().millisecondsSinceEpoch}',
              label: _detectedColour!,
              field: 'COLOUR',
            )..state = CaptureState.done);

            // Colour locked → auto-capture a full-res still for OCR.
            // The live stream at 720x1280 can't read tiny hearing aid text,
            // but a 12MP still can.
            _autoCapturForOcr();
          }
        }
      });
    } catch (e, st) {
      _log('_processFrame error: $e\n$st');
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_camera == null) {
      _log('_camera is null');
      return null;
    }

    final sensorOrientation = _camera!.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) {
      _log('rotation null for sensorOrientation=$sensorOrientation');
      return null;
    }

    // On iOS, image.format.raw may not cast cleanly to int.
    // BGRA8888 on iOS = format value 1111970369.
    final int rawFormat;
    try {
      rawFormat = image.format.raw as int;
    } catch (e) {
      _log('format.raw cast failed: ${image.format.raw} (${image.format.raw.runtimeType})');
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(rawFormat);
    if (format == null) {
      _log('format null for rawFormat=$rawFormat (group=${image.format.group})');
      return null;
    }

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

  // ── Snapshot capture & background upload ────────────────────────────

  /// Capture a still frame and upload it in the background.
  /// Camera stream pauses briefly (~200ms) then resumes.
  Future<void> _captureSnapshot(String field, String label, Rect bbox) async {
    if (_isCapturing || _cameraController == null) return;
    _isCapturing = true;

    // Record snap event for the ripple animation
    _snapEvents.add(SnapEvent(boundingBox: bbox, label: label));

    // Create the capture entry
    final capture = CapturedFeature(
      id: '${field}_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      field: field,
    );
    setState(() => _captures.add(capture));

    try {
      // Brief stream pause to take a high-quality still
      await _cameraController!.stopImageStream();
      final xFile = await _cameraController!.takePicture();
      capture.imagePath = xFile.path;

      // Resume stream immediately
      if (mounted && _cameraController != null) {
        await _cameraController!.startImageStream(_onCameraFrame);
      }

      // Upload in background while camera keeps scanning
      _uploadInBackground(capture);
    } catch (_) {
      // If capture fails, just resume the stream
      if (mounted && _cameraController != null) {
        try {
          await _cameraController!.startImageStream(_onCameraFrame);
        } catch (_) {}
      }
    } finally {
      _isCapturing = false;
    }
  }

  /// Upload a captured image to Firebase Storage with progress tracking.
  Future<void> _uploadInBackground(CapturedFeature capture) async {
    if (capture.imagePath == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => capture.state = CaptureState.done);
      return;
    }

    setState(() => capture.state = CaptureState.uploading);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('scans/${user.uid}/${timestamp}_${capture.field}.jpg');

      final uploadTask = ref.putFile(File(capture.imagePath!));

      // Track upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        final progress =
            snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() => capture.uploadProgress = progress);
      });

      await uploadTask;
      if (!mounted) return;

      setState(() => capture.state = CaptureState.done);
    } catch (_) {
      if (!mounted) return;
      setState(() => capture.state = CaptureState.error);
    }
  }

  /// Overall upload progress across all captures.
  double get _overallProgress {
    if (_captures.isEmpty) return 0.0;
    var total = 0.0;
    for (final c in _captures) {
      total += switch (c.state) {
        CaptureState.done => 1.0,
        CaptureState.uploading => c.uploadProgress,
        CaptureState.error => 1.0,
        _ => 0.0,
      };
    }
    return total / _captures.length;
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

  // ── Colour picker ────────────────────────────────────────────────────

  void _showColourPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CORRECT COLOUR',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0x99FFFFFF),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ColourClassifier.palette.map((entry) {
                final isDetected = entry.name == _detectedColour;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _confirmColour(entry.name, entry.color);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: entry.color,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDetected
                                ? AppColors.success
                                : const Color(0x33FFFFFF),
                            width: isDetected ? 2 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight:
                              isDetected ? FontWeight.w700 : FontWeight.w500,
                          color: isDetected
                              ? AppColors.success
                              : const Color(0x88FFFFFF),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Called when the user corrects the auto-detected colour via the picker.
  void _confirmColour(String name, Color rgb) {
    HapticFeedback.mediumImpact();
    setState(() {
      _detectedColour = name;
      _detectedColourRgb = rgb;
      _colourConfirmed = true;
    });

    // Update existing colour capture label, or add one if somehow missing
    final existing = _captures.where((c) => c.field == 'COLOUR').firstOrNull;
    if (existing != null) {
      existing.label = name;
    } else {
      _captures.add(CapturedFeature(
        id: 'COLOUR_${DateTime.now().millisecondsSinceEpoch}',
        label: name,
        field: 'COLOUR',
      )..state = CaptureState.done);
    }
  }

  // ── Auto-capture: full-res OCR ───────────────────────────────────────

  bool _ocrCaptureInProgress = false;

  /// Take a full-resolution still and run both the neural net brand classifier
  /// AND ML Kit OCR on it. Triggered when colour stabilises.
  ///
  /// Two parallel identification signals:
  /// 1. EfficientNet-B0 → brand classification from visual appearance (~10ms)
  /// 2. ML Kit OCR → brand/model from text on the device (if readable)
  /// Neural net result is primary; OCR can override or add model info.
  Future<void> _autoCapturForOcr() async {
    if (_ocrCaptureInProgress || _cameraController == null) return;
    _ocrCaptureInProgress = true;

    _log('auto-capture triggered — running neural net + OCR');

    try {
      // Brief pause to capture a sharp still
      await _cameraController!.stopImageStream();
      final xFile = await _cameraController!.takePicture();

      // Resume stream immediately — don't block the live view
      if (mounted && _cameraController != null) {
        await _cameraController!.startImageStream(_onCameraFrame);
      }

      if (_disposed || !mounted) return;

      // ── Signal 1: Neural net brand classification ────────────────────
      // Runs on Neural Engine (iOS) or GPU (Android), ~10ms
      if (_brandClassifier.isLoaded && _detectedBrand == null) {
        try {
          final prediction = await _brandClassifier.classifyFile(xFile.path);
          _log('neural net → ${prediction.brand} '
              '(${(prediction.confidence * 100).toStringAsFixed(1)}%)');

          // Log top 3 for debugging
          for (final p in prediction.topN(3)) {
            _log('  ${p.brand}: ${(p.probability * 100).toStringAsFixed(1)}%');
          }

          if (prediction.confidence >= 0.4 && mounted) {
            setState(() {
              _detectedBrand = prediction.brand;
              _brandConfidence =
                  '${(prediction.confidence * 100).round()}% AI';
            });
            HapticFeedback.mediumImpact();
            _showCrossReference(prediction.brand);
          }
        } catch (e) {
          _log('neural net error: $e');
        }
      }

      // ── Signal 2: ML Kit OCR (text on the device) ───────────────────
      final inputImage = InputImage.fromFilePath(xFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (_disposed || !mounted) return;

      _log('full-res OCR found '
          '${recognizedText.blocks.length} blocks');

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty || text.length < 2) continue;

          _log('full-res text: "$text"');

          // Model-first detection (can also override neural net brand)
          if (_detectedModel == null) {
            final reverse = BrandMatcher.matchModelAnyBrand(text);
            if (reverse != null) {
              _log('OCR MODEL MATCH: '
                  '${reverse.brand} / ${reverse.model}');
              setState(() {
                _detectedModel = reverse.model;
                // OCR model match is very reliable — override neural net
                // brand if different
                if (_detectedBrand != reverse.brand) {
                  _log('OCR overriding neural net brand '
                      '$_detectedBrand → ${reverse.brand}');
                  _detectedBrand = reverse.brand;
                  _brandConfidence = 'FROM MODEL';
                }
              });
              HapticFeedback.mediumImpact();
              _showCrossReference(_detectedBrand!);
            }
          }

          // Brand matching from OCR (if neural net didn't find it)
          if (_detectedBrand == null) {
            final result = BrandMatcher.matchBrandDetailed(text);
            if (result != null) {
              _log('OCR BRAND MATCH: ${result.displayName}');
              setState(() {
                _detectedBrand = result.displayName;
                _brandConfidence = result.confidenceLabel;
              });
              HapticFeedback.mediumImpact();
              _showCrossReference(result.displayName);
            }
          }

          // Brand-specific model matching
          if (_detectedBrand != null && _detectedModel == null) {
            final model = BrandMatcher.matchModel(text, _detectedBrand!);
            if (model != null) {
              _log('OCR MODEL MATCH '
                  '(brand-specific): $model');
              setState(() => _detectedModel = model);
              HapticFeedback.mediumImpact();
            }
          }
        }
      }

      // Upload the captured image in background
      _uploadInBackground(CapturedFeature(
        id: 'SCAN_${DateTime.now().millisecondsSinceEpoch}',
        label: _detectedBrand ?? 'scan',
        field: 'SCAN',
      )..imagePath = xFile.path);

      // Check completion
      if (_detectedBrand != null && !_completionFired) {
        // Brand alone is enough to show completion — model is a bonus
        _completionFired = true;
        _fireCompletion();
      }
    } catch (e) {
      _log('auto-capture error: $e');
      // Resume stream if it failed
      if (mounted && _cameraController != null) {
        try {
          await _cameraController!.startImageStream(_onCameraFrame);
        } catch (_) {}
      }
    } finally {
      _ocrCaptureInProgress = false;
    }
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

            // Feature overlay (green + amber boxes + snap ripples)
            // Always show when scanning — the overlay IS the T2 experience
            if (_phase != _ScanPhase.booting)
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
                      snapEvents: _snapEvents,
                    ),
                  ),
                ),
              ),

            // Progress rail (left edge)
            if (_captures.isNotEmpty)
              Positioned(
                left: 12,
                top: MediaQuery.of(context).padding.top + 60,
                child: ProgressRail(
                  progress: _overallProgress,
                  captureCount: _captures.length,
                  totalExpected: 2, // brand + model
                ),
              ),

            // Capture stack (right edge)
            if (_captures.isNotEmpty)
              Positioned(
                right: 12,
                top: MediaQuery.of(context).padding.top + 60,
                child: CaptureStack(captures: _captures),
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
                      detectedColour: _detectedColour,
                      detectedColourRgb: _detectedColourRgb,
                      colourConfidence: _colourConfidence,
                      colourConfirmed: _colourConfirmed,
                      onColourTap: _showColourPicker,
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
