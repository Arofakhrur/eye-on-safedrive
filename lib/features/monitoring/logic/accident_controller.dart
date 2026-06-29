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
  double _peakMagnitude = 0.0; // Menyimpan nilai puncak tertinggi saat crash
  
  // LPF (Low-Pass Filter) factor. 
  // Ditingkatkan menjadi 0.5 agar lebih responsif terhadap kecelakaan nyata.
  final double _alpha = 0.5; 

  int _sensorDetectionLatencyMs = 0;
  int get sensorDetectionLatencyMs => _sensorDetectionLatencyMs;

  Timer? _speedCheckTimer;
  
  double get _accidentThreshold => PreferenceService().shockSensitivity; // dynamically from user preference

  bool get isAccidentDetected => _isAccidentDetected;
  
  // Tampilkan nilai peak jika sedang dalam fase kecelakaan, jika tidak tampilkan real-time
  double get currentMagnitude => (_isCheckingSpeed || _isAccidentDetected) ? _peakMagnitude : _currentMagnitude;

  void startMonitoring() {
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
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
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _speedCheckTimer?.cancel();
    _stopAlarm();
  }

  Future<void> _verifyAccidentWithSpeedGate() async {
    _isCheckingSpeed = true;
    notifyListeners();
    debugPrint('⚠️ Guncangan terdeteksi (LPF: ${_currentMagnitude.toStringAsFixed(2)}). Menunggu 4 detik untuk verifikasi Speed-Gate...');

    final stopwatch = Stopwatch()..start();

    _speedCheckTimer?.cancel();
    _speedCheckTimer = Timer(const Duration(seconds: 4), () async {
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
          if (speedKmH < 2.0) {
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
    debugPrint('🚨 ACCIDENT DETECTED! 🚨 Peak Magnitude: $_peakMagnitude rad/s');
    
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
