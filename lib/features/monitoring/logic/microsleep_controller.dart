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
  
  // Task 14: State Management
  int _drowsyCount = 0;
  bool _isPaused = false;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Duration _microsleepDuration = const Duration(seconds: 2);
  bool _isAlarmPlaying = false;

  double get currentEAR => _currentEAR;
  bool get isDrowsy => _isDrowsy;
  List<FaceMesh> get currentMeshes => _currentMeshes;
  int get drowsyCount => _drowsyCount;
  bool get isPaused => _isPaused;

  void resumeMonitoring() {
    _isPaused = false;
    _isDrowsy = false;
    _drowsyStartTime = null;
    _stopAlarm();
    notifyListeners();
  }

  void resetDrowsyCount() {
    _drowsyCount = 0;
    notifyListeners();
  }

  /// Map alarm sound preference name to the actual asset file path.
  static const Map<String, String> _alarmSoundFiles = {
    'Sound 1': 'sounds/sound 1.mp3',
    'Sound 2': 'sounds/sound 2.mp3',
    'Sound 3': 'sounds/sound 3.mp3',
    'Sound 4': 'sounds/sound 4.mp3',
  };

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
    if (_isPaused) return;

    final threshold = PreferenceService().earThreshold;
    if (_currentEAR < threshold) {
      _drowsyStartTime ??= DateTime.now();
      
      final elapsed = DateTime.now().difference(_drowsyStartTime!);
      if (elapsed >= _microsleepDuration && !_isDrowsy) {
        _isDrowsy = true;
        _drowsyCount++;
        _isPaused = true;
        _triggerAlarm();
      }
    } else {
      _drowsyStartTime = null;
      if (_isDrowsy) {
        // Do not auto-reset here because the user must manually dismiss the alert via resumeMonitoring()
      }
    }
  }

  Future<void> _triggerAlarm() async {
    if (!PreferenceService().isAlarmEnabled) return;

    debugPrint('🚨 MICROSLEEP DETECTED! 🚨 Playing Alarm!');
    try {
      if (!_isAlarmPlaying) {
        _isAlarmPlaying = true;

        // Set volume based on drowsyCount (Level 1: 0.7, Level 2+: 1.0)
        double volume = _drowsyCount > 1 ? 1.0 : 0.7;
        await _audioPlayer.setVolume(volume);

        // Loop the alarm until eyes open
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);

        // Resolve the correct sound file from user preference
        final preferredSound = PreferenceService().alarmSound;
        final soundFile = _alarmSoundFiles[preferredSound] ?? _alarmSoundFiles['Sound 1']!;

        await _audioPlayer.play(AssetSource(soundFile));
      }
    } catch (e) {
      debugPrint('Audio play error: $e');
      _isAlarmPlaying = false;
    }
  }

  Future<void> _stopAlarm() async {
    if (_isAlarmPlaying) {
      try {
        await _audioPlayer.stop();
      } catch (e) {
        debugPrint('Audio stop error: $e');
      }
      _isAlarmPlaying = false;
    }
  }

  @override
  void dispose() {
    _meshDetector.close();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }
}
