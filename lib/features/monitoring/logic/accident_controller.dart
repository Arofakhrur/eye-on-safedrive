import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/location_service.dart';

class AccidentController extends ChangeNotifier {
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isAccidentDetected = false;
  bool _isCheckingSpeed = false;
  double _currentMagnitude = 0.0;
  double _filteredMagnitude = 0.0;
  double _peakMagnitude = 0.0; // Menyimpan nilai puncak tertinggi saat crash
  
  // Faktor Low-Pass Filter (LPF). Diset 0.5 agar responsif terhadap kecelakaan.
  final double _alpha = DetectionConfig.accelLpfAlpha; 

  /// Callback saat Speed-Gate menolak trigger akselerometer (false alarm jalan rusak).
  /// Parameter: (magnitude m/s², kecepatan km/h).
  void Function(double magnitude, double speedKmH)? onSpeedGateRejected;

  int _sensorDetectionLatencyMs = 0;
  int get sensorDetectionLatencyMs => _sensorDetectionLatencyMs;

  Timer? _speedCheckTimer;
  
  double get _accidentThreshold => PreferenceService().shockSensitivity; // dynamically from user preference

  bool get isAccidentDetected => _isAccidentDetected;
  
  // Tampilkan nilai peak jika sedang dalam fase kecelakaan, jika tidak tampilkan real-time
  double get currentMagnitude => (_isCheckingSpeed || _isAccidentDetected) ? _peakMagnitude : _currentMagnitude;

  void startMonitoring() {
    _accelSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      if (_isAccidentDetected) return; // Hanya berhenti membaca jika SOS sudah fix dikirim

      final rawMagnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      
      // Menerapkan Low-Pass Filter (LPF) untuk meredam noise getaran jalan/mesin.
      // Rumus: (alpha * Guncangan_Baru) + ((1 - alpha) * Guncangan_Sebelumnya)
      _filteredMagnitude = (_alpha * rawMagnitude) + ((1.0 - _alpha) * _filteredMagnitude);
      _currentMagnitude = _filteredMagnitude;
      
      if (_isCheckingSpeed) {
        // Jika sedang dalam masa 4 detik Speed-Gate, terus pantau nilai puncaknya!
        if (_currentMagnitude > _peakMagnitude) {
          _peakMagnitude = _currentMagnitude;
          notifyListeners();
        }
      } else {
        if (_currentMagnitude > _accidentThreshold) {
          _peakMagnitude = _currentMagnitude;
          _verifyAccidentWithSpeedGate();
        } else {
          notifyListeners();
        }
      }
    });
  }

  void stopMonitoring() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _speedCheckTimer?.cancel();
    _stopAlarm();
  }

  Future<void> _verifyAccidentWithSpeedGate() async {
    _isCheckingSpeed = true;
    notifyListeners();
    debugPrint('⚠️ Guncangan terdeteksi (LPF: ${_currentMagnitude.toStringAsFixed(2)} m/s²). Menunggu 4 detik untuk verifikasi Speed-Gate...');

    final stopwatch = Stopwatch()..start();
    bool tiltTriggered = false;

    // Memantau kemiringan (tilt) motor selama Speed-Gate berjalan.
    // Jika kemiringan > 60 derajat (motor rebah), abaikan Speed-Gate dan langsung kirim SOS.
    StreamSubscription<AccelerometerEvent>? tiltSubscription;
    tiltSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (tiltTriggered) return;
      final gx = event.x;
      final gy = event.y;
      final gz = event.z;
      final totalG = sqrt(gx * gx + gy * gy + gz * gz);
      if (totalG < DetectionConfig.minGravityMagnitude) return; // Hindari divide-by-zero

      final tiltDeg = acos((gz.abs() / totalG).clamp(0.0, 1.0)) * (180.0 / pi);

      if (tiltDeg > DetectionConfig.tiltThresholdDegrees) {
        tiltTriggered = true;
        debugPrint('🔄 TILT DETECTED: ${tiltDeg.toStringAsFixed(1)}° — Motor rebah! Bypass Speed-Gate.');
        tiltSubscription?.cancel();
        _speedCheckTimer?.cancel();
        _sensorDetectionLatencyMs = stopwatch.elapsedMilliseconds;
        _isAccidentDetected = true;
        _isCheckingSpeed = false;
        _triggerAccidentResponse();
        notifyListeners();
      }
    });

    _speedCheckTimer?.cancel();
    _speedCheckTimer = Timer(Duration(seconds: DetectionConfig.speedGateSeconds), () async {
      tiltSubscription?.cancel(); // Bersihkan stream tilt setelah timer habis

      if (tiltTriggered) return; // Sudah di-trigger oleh tilt, skip speed check

      try {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          final speedKmH = position.speed * 3.6;
          debugPrint('🏍️ SPEED CHECK: ${speedKmH.toStringAsFixed(2)} km/h');

          // Logika Speed-Gate (Anti False-Alarm):
          // Jika kecepatan < 2 km/h (motor berhenti) -> Kecelakaan nyata (Kirim SOS).
          // Jika kecepatan >= 2 km/h (motor melaju) -> Guncangan jalan rusak (Batal SOS).
          if (speedKmH < DetectionConfig.speedGateThresholdKmH) {
            _sensorDetectionLatencyMs = stopwatch.elapsedMilliseconds;
            _isAccidentDetected = true;
            _triggerAccidentResponse();
          } else {
            debugPrint('✅ FALSE ALARM: Motor masih melaju stabil. SOS dibatalkan.');
            onSpeedGateRejected?.call(_peakMagnitude, speedKmH);
          }
        }
      } catch (e) {
        debugPrint('Gagal verifikasi kecepatan: $e. Memaksa SOS demi keamanan.');
        _sensorDetectionLatencyMs = stopwatch.elapsedMilliseconds;
        _isAccidentDetected = true;
        _triggerAccidentResponse();
      } finally {
        _isCheckingSpeed = false;
        notifyListeners();
      }
    });
  }

  Future<void> _triggerAccidentResponse() async {
    debugPrint('🚨 ACCIDENT DETECTED! 🚨 Peak Magnitude: $_peakMagnitude m/s²');
    
    // Auto-Play Alarm on Max Volume
    try {
      final alarmSound = PreferenceService().alarmSound;
      final audioPath = AppAssets.alarmAudioFiles[alarmSound] ?? AppAssets.alarmAudioFiles.values.first;
      await _audioPlayer.setVolume(DetectionConfig.alarmVolumeMax);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(audioPath));
    } catch (e) {
      debugPrint('Error playing alarm: $e');
    }
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

  void testCrash() {
    _isAccidentDetected = true;
    _peakMagnitude = 99.9;
    _triggerAccidentResponse();
    notifyListeners();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _speedCheckTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
