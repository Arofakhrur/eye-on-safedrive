import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:eyeon/core/utils/math_utils.dart';

class MicrosleepController extends ChangeNotifier {
  final FaceMeshDetector _meshDetector = FaceMeshDetector(
    option: FaceMeshDetectorOptions.faceMesh,
  );

  bool _isProcessing = false;
  double _currentEAR = 0.0;
  bool _isDrowsy = false;
  DateTime? _drowsyStartTime;
  List<FaceMesh> _currentMeshes = [];
  
  final double _earThreshold = 0.25;
  final Duration _microsleepDuration = const Duration(seconds: 2);

  double get currentEAR => _currentEAR;
  bool get isDrowsy => _isDrowsy;
  List<FaceMesh> get currentMeshes => _currentMeshes;

  Future<void> processImage(InputImage inputImage) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final meshes = await _meshDetector.processImage(inputImage);
      _currentMeshes = meshes;
      
      if (meshes.isNotEmpty) {
        final faceMesh = meshes.first; // Process primary face
        
        // MediaPipe Face Mesh indices for eyes:
        // Right Eye: 33, 160, 158, 133, 153, 144
        // Left Eye: 362, 385, 387, 263, 373, 380
        
        double rightEAR = _calculateEyeEAR(
          faceMesh.points,
          [33, 160, 158, 133, 153, 144]
        );

        double leftEAR = _calculateEyeEAR(
          faceMesh.points,
          [362, 385, 387, 263, 373, 380]
        );

        // Average EAR
        _currentEAR = (rightEAR + leftEAR) / 2.0;

        _evaluateDrowsiness();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error processing face mesh: $e');
    } finally {
      _isProcessing = false;
    }
  }

  double _calculateEyeEAR(List<FaceMeshPoint> allPoints, List<int> indices) {
    if (allPoints.length < 468) return 0.0;

    final p1 = Point<int>(allPoints[indices[0]].x.toInt(), allPoints[indices[0]].y.toInt());
    final p2 = Point<int>(allPoints[indices[1]].x.toInt(), allPoints[indices[1]].y.toInt());
    final p3 = Point<int>(allPoints[indices[2]].x.toInt(), allPoints[indices[2]].y.toInt());
    final p4 = Point<int>(allPoints[indices[3]].x.toInt(), allPoints[indices[3]].y.toInt());
    final p5 = Point<int>(allPoints[indices[4]].x.toInt(), allPoints[indices[4]].y.toInt());
    final p6 = Point<int>(allPoints[indices[5]].x.toInt(), allPoints[indices[5]].y.toInt());

    return MathUtils.calculateEAR(p1: p1, p2: p2, p3: p3, p4: p4, p5: p5, p6: p6);
  }

  void _evaluateDrowsiness() {
    if (_currentEAR < _earThreshold) {
      _drowsyStartTime ??= DateTime.now();
      
      final elapsed = DateTime.now().difference(_drowsyStartTime!);
      if (elapsed >= _microsleepDuration && !_isDrowsy) {
        _isDrowsy = true;
        _triggerAlarm();
      }
    } else {
      _drowsyStartTime = null;
      _isDrowsy = false;
    }
  }

  void _triggerAlarm() {
    // TODO: Play high-pitch audio alarm in < 200ms
    debugPrint('🚨 MICROSLEEP DETECTED! 🚨 Playing Alarm!');
  }

  @override
  void dispose() {
    _meshDetector.close();
    super.dispose();
  }
}
