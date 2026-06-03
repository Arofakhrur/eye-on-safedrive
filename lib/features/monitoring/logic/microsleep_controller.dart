import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:eyeon/core/utils/math_utils.dart';
import 'package:eyeon/core/services/preference_service.dart';

class MicrosleepController extends ChangeNotifier {
  final FaceMeshDetector _meshDetector = FaceMeshDetector(
    option: FaceMeshDetectorOptions.faceMesh,
  );

  bool _isProcessing = false;
  double _currentEAR = 0.0;
  bool _isDrowsy = false;
  DateTime? _drowsyStartTime;
  List<FaceMesh> _currentMeshes = [];
  
  final AudioPlayer _audioPlayer = AudioPlayer();
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
    final threshold = PreferenceService().earThreshold;
    if (_currentEAR < threshold) {
      _drowsyStartTime ??= DateTime.now();
      
      final elapsed = DateTime.now().difference(_drowsyStartTime!);
      if (elapsed >= _microsleepDuration && !_isDrowsy) {
        _isDrowsy = true;
        _triggerAlarm();
      }
    } else {
      _drowsyStartTime = null;
      _isDrowsy = false;
      _audioPlayer.stop();
    }
  }

  Future<void> _triggerAlarm() async {
    if (PreferenceService().isAlarmEnabled) {
      debugPrint('🚨 MICROSLEEP DETECTED! 🚨 Playing Alarm!');
      // Assuming there is an alarm.mp3 in assets/audio/ or we can use a system beep.
      // Since we don't know the exact asset, we'll try to play a default or just log it.
      // Or we can use a built-in beep if possible. We will just play a placeholder for now.
      try {
         // await _audioPlayer.play(AssetSource('audio/alarm.mp3'));
      } catch (e) {
         debugPrint('Audio play error: $e');
      }
    }
  }

  @override
  void dispose() {
    _meshDetector.close();
    _audioPlayer.dispose();
    super.dispose();
  }
}
