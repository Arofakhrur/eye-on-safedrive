import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/location_service.dart';

class AccidentController extends ChangeNotifier {
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isAccidentDetected = false;
  bool _isCheckingSpeed = false;
  double _currentMagnitude = 0.0;
  double _filteredMagnitude = 0.0;
  final double _alpha = 0.2; // LPF factor
  Timer? _speedCheckTimer;
  
  double get _accidentThreshold => PreferenceService().shockSensitivity; // dynamically from user preference

  bool get isAccidentDetected => _isAccidentDetected;
  double get currentMagnitude => _currentMagnitude;

  void startMonitoring() {
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      if (_isAccidentDetected || _isCheckingSpeed) return;

      final rawMagnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      
      // Low-Pass Filter (LPF)
      _filteredMagnitude = (_alpha * rawMagnitude) + ((1.0 - _alpha) * _filteredMagnitude);
      _currentMagnitude = _filteredMagnitude;
      
      if (_currentMagnitude > _accidentThreshold) {
        _verifyAccidentWithSpeedGate();
      }
      
      notifyListeners();
    });
  }

  Future<void> _verifyAccidentWithSpeedGate() async {
    _isCheckingSpeed = true;
    notifyListeners();
    debugPrint('⚠️ Guncangan terdeteksi (LPF: ${_currentMagnitude.toStringAsFixed(2)}). Menunggu 4 detik untuk verifikasi Speed-Gate...');

    _speedCheckTimer?.cancel();
    _speedCheckTimer = Timer(const Duration(seconds: 4), () async {
      try {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          final speedKmH = position.speed * 3.6;
          debugPrint('🏍️ SPEED CHECK: ${speedKmH.toStringAsFixed(2)} km/h');

          if (speedKmH < 2.0) {
            _isAccidentDetected = true;
            _triggerAccidentResponse();
          } else {
            debugPrint('✅ FALSE ALARM: Motor masih melaju stabil. SOS dibatalkan.');
          }
        }
      } catch (e) {
        debugPrint('Gagal verifikasi kecepatan: $e. Memaksa SOS demi keamanan.');
        _isAccidentDetected = true;
        _triggerAccidentResponse();
      } finally {
        _isCheckingSpeed = false;
        notifyListeners();
      }
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
    _isCheckingSpeed = false;
    _speedCheckTimer?.cancel();
    _stopAlarm();
    notifyListeners();
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _speedCheckTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
