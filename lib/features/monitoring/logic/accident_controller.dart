import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:eyeon/core/services/preference_service.dart';

class AccidentController extends ChangeNotifier {
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isAccidentDetected = false;
  double _currentMagnitude = 0.0;
  
  final double _accidentThreshold = 5.0; // rad/s

  bool get isAccidentDetected => _isAccidentDetected;
  double get currentMagnitude => _currentMagnitude;

  void startMonitoring() {
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _currentMagnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      
      if (_currentMagnitude > _accidentThreshold && !_isAccidentDetected) {
        _isAccidentDetected = true;
        _triggerAccidentResponse();
      }
      
      notifyListeners();
    });
  }

  Future<void> _triggerAccidentResponse() async {
    debugPrint('🚨 ACCIDENT DETECTED! 🚨 Magnitude: $_currentMagnitude rad/s');
    
    // Auto-Play Alarm on Max Volume
    try {
      final alarmSound = PreferenceService().alarmSound;
      String audioPath = 'audio/sound1.mp3';
      switch (alarmSound) {
        case 'Sound 1': audioPath = 'audio/sound1.mp3'; break;
        case 'Sound 2': audioPath = 'audio/sound2.mp3'; break;
        case 'Sound 3': audioPath = 'audio/sound3.mp3'; break;
        case 'Sound 4': audioPath = 'audio/sound4.mp3'; break;
      }
      await _audioPlayer.setVolume(1.0); // Force Max Volume
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(audioPath));
    } catch (e) {
      debugPrint('Error playing alarm: $e');
    }

    SOSService().triggerEmergencySOS(_currentMagnitude);
  }

  void _stopAlarm() {
    _audioPlayer.stop();
  }

  void resetAccidentState() {
    _isAccidentDetected = false;
    _stopAlarm();
    notifyListeners();
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
