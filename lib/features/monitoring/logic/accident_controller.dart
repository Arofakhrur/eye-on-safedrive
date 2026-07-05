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
  
  // LPF (Low-Pass Filter) factor. 
  // Ditingkatkan menjadi 0.5 agar lebih responsif terhadap kecelakaan nyata.
  final double _alpha = DetectionConfig.accelLpfAlpha; 

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
      
      // =====================================================================
      // DOKUMENTASI UNTUK SIDANG: ALGORITMA LOW-PASS FILTER (LPF)
      // =====================================================================
      // LPF digunakan untuk memfilter "noise" atau getaran frekuensi tinggi 
      // yang terjadi terus-menerus (misal: getaran mesin, jalan bebatuan/rusak).
      // 
      // Rumus: Filtered = (alpha * Raw) + ((1 - alpha) * Previous_Filtered)
      // 
      // Dengan alpha = 0.5, sistem mengambil 50% kekuatan guncangan asli saat ini,
      // dan mempertahankan 50% dari guncangan sebelumnya. Hal ini mencegah sensor 
      // melonjak tiba-tiba ke angka tinggi hanya karena satu lubang kecil, 
      // namun tetap responsif jika terjadi benturan kecelakaan yang berkelanjutan.
      // =====================================================================
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

    // =====================================================================
    // DOKUMENTASI UNTUK SIDANG: KOMPENSASI TILT (KEMIRINGAN)
    // =====================================================================
    // Selama 4 detik Speed-Gate berjalan, sistem juga memantau kemiringan
    // motor menggunakan accelerometerEventStream (mengandung gravitasi).
    //
    // Rumus Tilt: acos(gz / sqrt(gx² + gy² + gz²)) × (180/π)
    //
    // Jika tilt > 60°, artinya motor sudah rebah/terbalik (tidak mungkin
    // terjadi saat berkendara normal). Dalam kasus ini, syarat kecepatan
    // diabaikan dan SOS langsung dikirim.
    // =====================================================================
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

          // =====================================================================
          // DOKUMENTASI UNTUK SIDANG: LOGIKA SPEED-GATE (ANTI FALSE-ALARM)
          // =====================================================================
          // Jalanan yang rusak berat (misal: Gunung Salak / KKA) bisa menghasilkan
          // guncangan keras yang menembus batas LPF. Untuk mencegah Alarm Palsu,
          // sistem melakukan verifikasi cerdas berbasis GPS:
          //
          // Sistem di-delay 4 detik setelah guncangan keras terjadi. Setelah itu:
          // 1. Jika Kecepatan < 2.0 km/jam: Artinya motor membentur sesuatu dan 
          //    berhenti total (jatuh). Ini adalah KECELAKAAN NYATA -> Kirim SOS.
          // 2. Jika Kecepatan >= 2.0 km/jam: Artinya motor masih melaju normal. 
          //    Guncangan tadi hanyalah murni karena melindas lubang jalanan. 
          //    Ini adalah FALSE ALARM -> Batalkan SOS.
          // =====================================================================
          if (speedKmH < DetectionConfig.speedGateThresholdKmH) {
            _sensorDetectionLatencyMs = stopwatch.elapsedMilliseconds;
            _isAccidentDetected = true;
            _triggerAccidentResponse();
          } else {
            debugPrint('✅ FALSE ALARM: Motor masih melaju stabil. SOS dibatalkan.');
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
