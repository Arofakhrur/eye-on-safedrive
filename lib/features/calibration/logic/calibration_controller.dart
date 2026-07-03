import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/utils/math_utils.dart';
import 'package:eyeon/core/utils/camera_utils.dart';
import 'package:eyeon/core/services/supabase_service.dart';

class CalibrationController extends ChangeNotifier {
  // ── UI state ──────────────────────────────────────────────────────
  bool _isCalibrating = false;
  bool _isCalibrationDone = false;
  double _progress = 0.0;
  String _statusText = 'Position your face inside the circle';

  bool get isCalibrating => _isCalibrating;
  bool get isCalibrationDone => _isCalibrationDone;
  double get progress => _progress;
  String get statusText => _statusText;

  // ── Camera ────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraReady = false;
  
  CameraController? get cameraController => _cameraController;
  bool get isCameraReady => _isCameraReady;

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

  double get currentEAR => _currentEAR;
  double get calibratedThreshold => _calibratedThreshold;
  List<double> get earSamples => _earSamples;

  CalibrationController() {
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
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      _isCameraReady = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Calibration logic ─────────────────────────────────────────────
  void startCalibration() {
    if (!_isCameraReady || _cameraController == null) {
      // Handled by UI notification if not ready
      return;
    }

    _isCalibrating = true;
    _progress = 0.0;
    _earSamples.clear();
    _noFaceFrames = 0;
    _statusText = 'Keep your eyes open and look straight ahead…';
    notifyListeners();

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

        _progress = (_earSamples.length / _targetSamples).clamp(0.0, 1.0);

        if (_progress < 0.3) {
          _statusText = 'Scanning eye position…';
        } else if (_progress < 0.6) {
          _statusText = 'Collecting baseline data…';
        } else if (_progress < 0.9) {
          _statusText = 'Almost done…';
        }
        notifyListeners();

        // Check if we have enough samples
        if (_earSamples.length >= _targetSamples) {
          await _finishCalibration();
        }
      } else {
        _noFaceFrames++;
        if (_noFaceFrames > _noFaceTimeout) {
          _statusText = '⚠️ No face detected — look at the camera';
          notifyListeners();
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

    if (_earSamples.isEmpty) return;

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

    _progress = 1.0;
    _isCalibrating = false;
    _isCalibrationDone = true;
    _statusText = 'Calibration complete ✓';
    notifyListeners();
  }

  @override
  void dispose() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
    _meshDetector.close();
    super.dispose();
  }
}
