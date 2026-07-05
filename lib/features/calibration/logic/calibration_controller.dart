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
  String _statusText = 'Posisikan wajah Anda di dalam lingkaran';

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
  bool _isStreamingActive = false;

  // ── EAR Calibration Data ──────────────────────────────────────────
  final List<double> _earSamples = [];
  static const int _targetSamples = DetectionConfig.calibrationTargetSamples;
  double _currentEAR = 0.0;
  double get currentEAR => _currentEAR;

  List<Point<int>> _eyePoints = [];
  List<Point<int>> get eyePoints => _eyePoints;

  double _calibratedThreshold = 0.0;
  int _noFaceFrames = 0;
  static const int _noFaceTimeout = DetectionConfig.noFaceTimeoutFrames;

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
            ? ImageFormatGroup.nv21
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

    // Stop any existing stream before restarting
    if (_isStreamingActive) {
      try {
        _cameraController!.stopImageStream();
      } catch (_) {}
      _isStreamingActive = false;
    }

    // Reset all calibration state (including done flag for re-calibration)
    _isCalibrating = true;
    _isCalibrationDone = false;
    _progress = 0.0;
    _earSamples.clear();
    _noFaceFrames = 0;
    _isProcessingFrame = false;
    _statusText = 'Tatap lurus ke depan dan buka mata lebar…';
    notifyListeners();

    // Start processing camera frames for EAR measurement
    try {
      _cameraController!.startImageStream((CameraImage image) {
        _processCalibrationFrame(image);
      });
      _isStreamingActive = true;
    } catch (e) {
      debugPrint('startImageStream error: $e');
      _isCalibrating = false;
      _statusText = 'Gagal memulai kamera. Coba lagi.';
      notifyListeners();
    }
  }

  /// Process a single camera frame during calibration.
  Future<void> _processCalibrationFrame(CameraImage image) async {
    if (_isProcessingFrame || _isCalibrationDone || !_isCalibrating) return;
    _isProcessingFrame = true;

    try {
      final inputImage = CameraUtils.inputImageFromCameraImage(
        image,
        _cameraController,
      );
      if (inputImage == null) {
        // Log setiap 60 frame agar tidak spam
        if (_noFaceFrames % 60 == 0) {
          debugPrint('🔴 [Calibration] inputImage NULL — cek camera_utils (frame $_noFaceFrames)');
        }
        _noFaceFrames++;
        _isProcessingFrame = false;
        return;
      }

      final meshes = await _meshDetector.processImage(inputImage);

      if (meshes.isNotEmpty) {
        _noFaceFrames = 0;
        final faceMesh = meshes.first;

        // Calculate EAR using the same logic as MicrosleepController
        final rightEyeIndices = [33, 160, 158, 133, 153, 144];
        final leftEyeIndices = [362, 385, 387, 263, 373, 380];

        final rightEAR = _calculateEyeEAR(
          faceMesh.points,
          rightEyeIndices,
        );
        final leftEAR = _calculateEyeEAR(
          faceMesh.points,
          leftEyeIndices,
        );

        final avgEAR = (rightEAR + leftEAR) / 2.0;

        // Expose points for UI
        _eyePoints = [
          ...rightEyeIndices.map((i) => Point<int>(faceMesh.points[i].x.toInt(), faceMesh.points[i].y.toInt())),
          ...leftEyeIndices.map((i) => Point<int>(faceMesh.points[i].x.toInt(), faceMesh.points[i].y.toInt())),
        ];

        debugPrint('👁️ [Calibration] L=$leftEAR R=$rightEAR avg=$avgEAR samples=${_earSamples.length}');

        // Only accept reasonable EAR values (filter noise)
        // earSampleMin = 0.05, earSampleMax = 0.5
        if (avgEAR > DetectionConfig.earSampleMin && avgEAR < DetectionConfig.earSampleMax) {
          _earSamples.add(avgEAR);
          _currentEAR = avgEAR;
        } else {
          debugPrint('⚠️ [Calibration] EAR $avgEAR out of range [${DetectionConfig.earSampleMin}, ${DetectionConfig.earSampleMax}] — discarded');
        }

        _progress = (_earSamples.length / _targetSamples).clamp(0.0, 1.0);

        if (_progress < 0.3) {
          _statusText = 'Scanning posisi mata…';
        } else if (_progress < 0.6) {
          _statusText = 'Mengumpulkan data baseline…';
        } else if (_progress < 0.9) {
          _statusText = 'Hampir selesai…';
        }
        notifyListeners();

        // Check if we have enough samples
        if (_earSamples.length >= _targetSamples) {
          await _finishCalibration();
        }
      } else {
        _noFaceFrames++;
        if (_noFaceFrames % 60 == 0) {
          debugPrint('🟡 [Calibration] No face detected ($_noFaceFrames frames)');
        }
        if (_noFaceFrames > _noFaceTimeout) {
          _statusText = '⚠️ Wajah tidak terdeteksi — hadap kamera';
          _eyePoints.clear();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('🔴 [Calibration] Frame error: $e');
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
    if (_isStreamingActive) {
      try {
        _cameraController?.stopImageStream();
      } catch (_) {}
      _isStreamingActive = false;
    }

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
    if (_isStreamingActive) {
      try {
        _cameraController?.stopImageStream();
      } catch (_) {}
      _isStreamingActive = false;
    }
    _cameraController?.dispose();
    _meshDetector.close();
    super.dispose();
  }
}
