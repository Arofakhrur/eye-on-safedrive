import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';

/// ------------------------------------------------------------------
/// CalibrationScreen
/// ------------------------------------------------------------------
/// This screen captures the front-camera feed, runs a simulated
/// calibration pass, and is structured so that a TFLite / TensorFlow
/// Lite model can be plugged in later.
///
/// HOW TO INTEGRATE YOUR MODEL:
///   1. Add `tflite_flutter: ^0.11.0` (or latest) to pubspec.yaml.
///   2. Place your `.tflite` model file in `assets/models/`.
///   3. Register the asset path in pubspec.yaml under `flutter.assets`.
///   4. Uncomment the `_loadModel()` and `_runInference()` stubs below
///      and replace the placeholder logic with your own pipeline
///      (e.g. EAR calculation, face-mesh landmark extraction, etc.).
/// ------------------------------------------------------------------

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  // ── UI state ──────────────────────────────────────────────────────
  bool _isCalibrating = false;
  bool _isCalibrationDone = false;
  double _progress = 0.0;
  String _statusText = 'Position your face inside the circle';
  Timer? _calibrationTimer;

  // ── Camera ────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // ── TFLite Model (placeholder) ────────────────────────────────────
  // Interpreter? _interpreter;          // from tflite_flutter
  // List<double>? _baselineEAR;         // baseline Eye Aspect Ratio
  bool _isModelLoaded = false;

  // ── Animation ─────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initCamera();
    _loadModel();
  }

  // ── Camera initialisation ─────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Model loading stub ────────────────────────────────────────────
  Future<void> _loadModel() async {
    // ┌──────────────────────────────────────────────────────────┐
    // │  REPLACE THIS with your real TFLite model loading code  │
    // │                                                         │
    // │  Example:                                               │
    // │    _interpreter = await Interpreter.fromAsset(           │
    // │      'assets/models/microsleep_model.tflite',           │
    // │    );                                                   │
    // │    _interpreter!.allocateTensors();                     │
    // │    setState(() => _isModelLoaded = true);               │
    // └──────────────────────────────────────────────────────────┘
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isModelLoaded = true);
  }

  // ── Inference stub ────────────────────────────────────────────────
  // Future<Map<String, dynamic>> _runInference(CameraImage image) async {
  //   // 1. Convert CameraImage → input tensor
  //   // 2. Run _interpreter!.run(input, output)
  //   // 3. Parse output → EAR, blink count, yawn ratio, etc.
  //   return {'ear': 0.0, 'blink': false};
  // }

  // ── Calibration logic ─────────────────────────────────────────────
  void _startCalibration() {
    if (!_isCameraReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera is not ready yet',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isCalibrating = true;
      _progress = 0.0;
      _statusText = 'Scanning face…';
    });

    // ┌──────────────────────────────────────────────────────────────┐
    // │  During calibration you can start the image stream and run  │
    // │  inference on each frame to collect baseline EAR values.    │
    // │                                                             │
    // │  Example:                                                   │
    // │    _cameraController!.startImageStream((image) {            │
    // │      final result = await _runInference(image);             │
    // │      _baselineEAR!.add(result['ear']);                      │
    // │    });                                                      │
    // └──────────────────────────────────────────────────────────────┘

    _calibrationTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.01;

        // Update status text at milestones
        if (_progress > 0.25 && _progress < 0.5) {
          _statusText = 'Analyzing eye position…';
        } else if (_progress >= 0.5 && _progress < 0.75) {
          _statusText = 'Collecting baseline data…';
        } else if (_progress >= 0.75) {
          _statusText = 'Almost done…';
        }

        if (_progress >= 1.0) {
          _progress = 1.0;
          _isCalibrating = false;
          _isCalibrationDone = true;
          _statusText = 'Calibration complete ✓';
          _calibrationTimer?.cancel();

          // Stop image stream if it was started
          // _cameraController?.stopImageStream();
        }
      });
    });
  }

  @override
  void dispose() {
    _calibrationTimer?.cancel();
    _pulseController.dispose();
    _cameraController?.dispose();
    // _interpreter?.close();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildViewfinder(),
            const SizedBox(height: 32),
            _buildStatusBadge(),
            const SizedBox(height: 24),
            _buildTitleSection(),
            const Spacer(),
            _buildActionButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/EYE-ON!_Logo.webp',
              height: 28, width: 28),
          const SizedBox(width: 8),
          Text(
            'EYE-ON!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ── Viewfinder ────────────────────────────────────────────────────
  Widget _buildViewfinder() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale =
            _isCalibrating ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isCalibrationDone
                        ? const Color(0xFFD7F454)
                        : Colors.grey.shade200,
                    width: 3,
                  ),
                ),
              ),

              // Camera preview
              ClipOval(
                child: SizedBox(
                  width: 270,
                  height: 270,
                  child: _isCameraReady
                      ? CameraPreview(_cameraController!)
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 100,
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                ),
              ),

              // Progress ring overlay
              SizedBox(
                width: 290,
                height: 290,
                child: CircularProgressIndicator(
                  value: _isCalibrating
                      ? _progress
                      : (_isCalibrationDone ? 1.0 : 0.0),
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFD7F454)),
                  backgroundColor: Colors.transparent,
                ),
              ),

              // Percentage overlay while calibrating
              if (_isCalibrating)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(_progress * 100).toInt()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Checkmark when done
              if (_isCalibrationDone)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD7F454),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.black, size: 32),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Status badge ──────────────────────────────────────────────────
  Widget _buildStatusBadge() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_statusText),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isCalibrationDone
              ? const Color(0xFFD7F454).withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isCalibrating)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.black.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            Text(
              _statusText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isCalibrationDone ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Title section ─────────────────────────────────────────────────
  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            'Face Calibration',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Align your face within the circle and look straight '
            'ahead. This helps EYE-ON! learn your baseline eye '
            'pattern for accurate drowsiness detection.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          if (_isModelLoaded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: const Color(0xFFD7F454), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Detection model ready',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Action button ─────────────────────────────────────────────────
  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          if (_isCalibrationDone) {
            PreferenceService().setCalibrated(true);
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          } else if (!_isCalibrating) {
            _startCalibration();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _isCalibrating
                ? Colors.grey.shade300
                : const Color(0xFFD7F454),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              if (!_isCalibrating)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isCalibrating
                    ? 'Calibrating…'
                    : (_isCalibrationDone
                        ? 'Finish Calibration'
                        : 'Start Calibration'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _isCalibrating ? Colors.black38 : Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                _isCalibrationDone
                    ? Icons.check_circle_outline_rounded
                    : (_isCalibrating
                        ? Icons.hourglass_top_rounded
                        : Icons.play_circle_outline_rounded),
                color: _isCalibrating ? Colors.black38 : Colors.black,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
