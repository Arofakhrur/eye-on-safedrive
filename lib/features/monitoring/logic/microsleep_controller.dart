import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';

class MicrosleepController extends ChangeNotifier {
  double _currentEAR = 0.0;
  double _filteredEAR = 0.0;
  bool _isDrowsy = false;
  
  // Task 14: State Management
  int _drowsyCount = 0;
  bool _isPaused = false;
  DateTime? _lastWarningTime;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;

  double get currentEAR => _currentEAR;
  bool get isDrowsy => _isDrowsy;
  int get drowsyCount => _drowsyCount;
  bool get isPaused => _isPaused;
  
  // For compatibility with any UI still checking meshes
  dynamic get currentMeshes => [];

  void resumeMonitoring() {
    _isPaused = false;
    _isDrowsy = false;
    _consecutiveDrowsyFrames = 0;
    _lastWarningTime = DateTime.now();
    _stopAlarm();
    notifyListeners();
  }

  void resetDrowsyCount() {
    _drowsyCount = 0;
    notifyListeners();
  }

  /// Map alarm sound preference name to the actual asset file path.
  static const Map<String, String> _alarmSoundFiles = AppAssets.alarmSoundFiles;

  int _consecutiveDrowsyFrames = 0;
  static const int _drowsyFrameThreshold = 30; // Approx 1.5s at ~20fps

  void updateEAR(double ear) {
    // Cooldown 10 detik setelah resume untuk mencegah spam
    if (_lastWarningTime != null &&
        DateTime.now().difference(_lastWarningTime!).inSeconds < 10) {
      _currentEAR = ear;
      notifyListeners();
      return;
    }

    // Low-Pass Filter pada EAR untuk memperhalus fluktuasi
    _filteredEAR = (0.4 * ear) + (0.6 * _filteredEAR);
    _currentEAR = ear;
    notifyListeners();

    if (_isPaused) return;

    final threshold = PreferenceService().earThreshold;
    if (_filteredEAR < threshold) {
      _consecutiveDrowsyFrames++;
      if (_consecutiveDrowsyFrames >= _drowsyFrameThreshold) {
        if (!_isDrowsy) {
          _isDrowsy = true;
          _drowsyCount++;
          _isPaused = true;
          _triggerAlarm();
          notifyListeners();
        }
      }
    } else {
      _consecutiveDrowsyFrames = 0;
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
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }
}
