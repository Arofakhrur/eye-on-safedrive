import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/utils/math_utils.dart';
import 'package:eyeon/core/utils/camera_utils.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

/// ------------------------------------------------------------------
/// CalibrationScreen
/// ------------------------------------------------------------------
/// Captures the front-camera feed, detects face mesh landmarks,
/// and computes the user's personal EAR (Eye Aspect Ratio) baseline.
/// The calibrated threshold is saved to PreferenceService for use
/// during microsleep detection.
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

  // ── Camera ────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // ── Face Mesh Detection ───────────────────────────────────────────
  final FaceMeshDetector _meshDetector = FaceMeshDetector(
    option: FaceMeshDetectorOptions.faceMesh,
  );
  bool _isProcessingFrame = false;

  // ── EAR Calibration Data ──────────────────────────────────────────
  final List<double> _earSamples = [];
  static const int _targetSamples = DetectionConfig.calibrationTargetSamples;
  double _currentEAR = 0.0;
  double _calibratedThreshold = 0.0;
  int _noFaceFrames = 0;
  static const int _noFaceTimeout = DetectionConfig.noFaceTimeoutFrames;

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
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Calibration logic ─────────────────────────────────────────────
  void _startCalibration() {
    if (!_isCameraReady) {
      NotificationHelper.showTop(
        context,
        message: 'Camera is not ready yet',
        type: NotificationType.warning,
      );
      return;
    }

    setState(() {
      _isCalibrating = true;
      _progress = 0.0;
      _earSamples.clear();
      _noFaceFrames = 0;
      _statusText = 'Keep your eyes open and look straight ahead…';
    });

    // Start processing camera frames for EAR measurement
    _cameraController!.startImageStream((CameraImage image) {
      _processCalibrationFrame(image);
    });
  }

  /// Process a single camera frame during calibration.
  Future<void> _processCalibrationFrame(CameraImage image) async {
    if (_isProcessingFrame || _isCalibrationDone) return;
    _isProcessingFrame = true;

    try {
      final inputImage = CameraUtils.inputImageFromCameraImage(
        image,
        _cameraController,
      );
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final meshes = await _meshDetector.processImage(inputImage);

      if (meshes.isNotEmpty) {
        _noFaceFrames = 0;
        final faceMesh = meshes.first;

        // Calculate EAR using the same logic as MicrosleepController
        final rightEAR = _calculateEyeEAR(
          faceMesh.points,
          [33, 160, 158, 133, 153, 144],
        );
        final leftEAR = _calculateEyeEAR(
          faceMesh.points,
          [362, 385, 387, 263, 373, 380],
        );

        final avgEAR = (rightEAR + leftEAR) / 2.0;

        // Only accept reasonable EAR values (filter noise)
        if (avgEAR > DetectionConfig.earSampleMin && avgEAR < DetectionConfig.earSampleMax) {
          _earSamples.add(avgEAR);
          _currentEAR = avgEAR;
        }

        if (mounted) {
          setState(() {
            _progress = (_earSamples.length / _targetSamples).clamp(0.0, 1.0);

            if (_progress < 0.3) {
              _statusText = 'Scanning eye position…';
            } else if (_progress < 0.6) {
              _statusText = 'Collecting baseline data…';
            } else if (_progress < 0.9) {
              _statusText = 'Almost done…';
            }
          });
        }

        // Check if we have enough samples
        if (_earSamples.length >= _targetSamples) {
          _finishCalibration();
        }
      } else {
        _noFaceFrames++;
        if (_noFaceFrames > _noFaceTimeout && mounted) {
          setState(() {
            _statusText = '⚠️ No face detected — look at the camera';
          });
        }
      }
    } catch (e) {
      debugPrint('Calibration frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Calculate EAR for one eye given face mesh points and landmark indices.
  double _calculateEyeEAR(List<FaceMeshPoint> allPoints, List<int> indices) {
    if (allPoints.length < 468) return 0.0;

    final p1 = Point<int>(
      allPoints[indices[0]].x.toInt(),
      allPoints[indices[0]].y.toInt(),
    );
    final p2 = Point<int>(
      allPoints[indices[1]].x.toInt(),
      allPoints[indices[1]].y.toInt(),
    );
    final p3 = Point<int>(
      allPoints[indices[2]].x.toInt(),
      allPoints[indices[2]].y.toInt(),
    );
    final p4 = Point<int>(
      allPoints[indices[3]].x.toInt(),
      allPoints[indices[3]].y.toInt(),
    );
    final p5 = Point<int>(
      allPoints[indices[4]].x.toInt(),
      allPoints[indices[4]].y.toInt(),
    );
    final p6 = Point<int>(
      allPoints[indices[5]].x.toInt(),
      allPoints[indices[5]].y.toInt(),
    );

    return MathUtils.calculateEAR(
      p1: p1, p2: p2, p3: p3, p4: p4, p5: p5, p6: p6,
    );
  }

  /// Compute the personal EAR threshold and save it.
  Future<void> _finishCalibration() async {
    // Stop the camera stream
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}

    // Calculate average EAR from collected samples
    final averageEAR =
        _earSamples.reduce((a, b) => a + b) / _earSamples.length;

    // Remove outliers (values beyond 1.5 IQR) for more robust average
    final sorted = List<double>.from(_earSamples)..sort();
    final q1 = sorted[(sorted.length * 0.25).floor()];
    final q3 = sorted[(sorted.length * 0.75).floor()];
    final iqr = q3 - q1;
    final lower = q1 - 1.5 * iqr;
    final upper = q3 + 1.5 * iqr;
    final filtered = sorted.where((v) => v >= lower && v <= upper).toList();

    final robustAverage = filtered.isNotEmpty
        ? filtered.reduce((a, b) => a + b) / filtered.length
        : averageEAR;

    // Personal threshold = 75% of robust baseline average
    _calibratedThreshold = robustAverage * DetectionConfig.earThresholdMultiplier;

    // Clamp to reasonable range
    _calibratedThreshold = _calibratedThreshold.clamp(DetectionConfig.earThresholdMin, DetectionConfig.earThresholdMax);

    debugPrint(
      '✅ Calibration complete: '
      'avgEAR=${robustAverage.toStringAsFixed(3)}, '
      'threshold=${_calibratedThreshold.toStringAsFixed(3)}',
    );

    // Save to preferences
    await PreferenceService().setEarThreshold(_calibratedThreshold);

    // Upload to Supabase profiles
    try {
      await SupabaseService().updateProfile({
        'ear_threshold': _calibratedThreshold,
      });
    } catch (e) {
      debugPrint('Failed to upload calibrated threshold: $e');
    }

    if (mounted) {
      setState(() {
        _progress = 1.0;
        _isCalibrating = false;
        _isCalibrationDone = true;
        _statusText = 'Calibration complete ✓';
      });
    }
  }

  @override
  void dispose() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _pulseController.dispose();
    _cameraController?.dispose();
    _meshDetector.close();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
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
              ),
            );
          },
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
                        ? AppColors.primary
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
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? 480,
                            height: _cameraController!.value.previewSize?.width ?? 640,
                            child: CameraPreview(_cameraController!),
                          ),
                        )
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
                      AppColors.primary),
                  backgroundColor: Colors.transparent,
                ),
              ),

              // Percentage overlay while calibrating
              if (_isCalibrating)
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_currentEAR > 0)
                          Text(
                            'EAR: ${_currentEAR.toStringAsFixed(3)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Checkmark when done
              if (_isCalibrationDone)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
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
              ? AppColors.primary.withValues(alpha: 0.15)
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
          if (_isCalibrationDone)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Personal threshold set',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Baseline EAR: ${(_earSamples.isNotEmpty ? _earSamples.reduce((a, b) => a + b) / _earSamples.length : 0.0).toStringAsFixed(3)}  •  '
                      'Threshold: ${_calibratedThreshold.toStringAsFixed(3)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
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
                : AppColors.primary,
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
