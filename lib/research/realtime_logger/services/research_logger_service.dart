import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:eyeon/research/realtime_logger/models/research_event_model.dart';
import 'package:eyeon/core/services/supabase_service.dart';

/// Durasi maksimal EAR di bawah threshold yang masih dianggap kedipan normal.
/// Di atas ini dianggap mata tertutup (drowsy candidate).
const int _kBlinkMaxMs = 500; // 500ms ≈ kedipan biasa

/// Service yang **sepenuhnya otomatis** mencatat klasifikasi TP/FP/TN/FN
/// berdasarkan data EAR real-time dari [MicrosleepController].
///
/// ## Logika Klasifikasi Otomatis
///
/// ```
/// EAR < threshold mulai:
///   → catat waktu mulai tutup
///
/// EAR > threshold lagi (mata buka):
///   → hitung durasi tutup
///   → durasi < [_kBlinkMaxMs] → BLINK NORMAL
///       → jika tidak ada alarm → TN
///       → jika ada alarm dalam window → FP (sistem salah deteksi kedipan)
///   → durasi >= [_kBlinkMaxMs] → SUSTAINED CLOSE (ground truth drowsy)
///       → jika alarm berbunyi → TP
///       → jika tidak ada alarm → FN
///
/// Alarm berbunyi (dari sistem):
///   → cek apakah sedang dalam sustained close → TP
///   → jika tidak → FP
/// ```
///
/// TIDAK ada interaksi manual dari pengemudi.
class ResearchLoggerService extends ChangeNotifier {
  /// Window korelasi alarm ↔ sustained EAR close (ms).
  static const int _windowMs = 5000;

  String? _currentRideId;
  DateTime? _rideStartTime;

  final List<ResearchEventModel> _events = [];

  // ── Tracking state EAR ─────────────────────────────────────────────────────
  double _earThreshold = 0.25; // akan di-update dari PreferenceService
  bool _isEarBelowThreshold = false;
  DateTime? _eyeCloseStartTime; // kapan EAR mulai turun di bawah threshold
  bool _isSustainedClose = false; // true jika durasi > _kBlinkMaxMs

  // Timer yang mendeteksi apakah ini sustained close atau sekadar kedipan
  Timer? _blinkClassifyTimer;

  // Alarm sedang aktif atau tidak
  bool _alarmActive = false;

  // Hitungan klasifikasi
  int _tp = 0;
  int _fp = 0;
  int _tn = 0;
  int _fn = 0;

  // Untuk mencegah double-count FN ketika alarm sudah trigger di satu sesi close
  bool _alarmOccurredDuringCurrentClose = false;

  List<ResearchEventModel> get events => List.unmodifiable(_events);
  int get tp => _tp;
  int get fp => _fp;
  int get tn => _tn;
  int get fn => _fn;
  int get totalBlinks => _events.where((e) => e.eventType == ResearchEventType.normalBlink).length;
  int get totalSustainedClose => _events.where((e) => e.eventType == ResearchEventType.eyeCloseStart).length;
  bool get hasData => _events.isNotEmpty;

  double get precision => _tp + _fp > 0 ? _tp / (_tp + _fp) : 0.0;
  double get recall => _tp + _fn > 0 ? _tp / (_tp + _fn) : 0.0;
  double get f1Score {
    final p = precision;
    final r = recall;
    return p + r > 0 ? 2 * p * r / (p + r) : 0.0;
  }
  double get accuracy {
    final total = _tp + _fp + _tn + _fn;
    return total > 0 ? (_tp + _tn) / total : 0.0;
  }

  /// Inisialisasi session baru ketika ride dimulai.
  void startSession(String rideId, DateTime rideStartTime, {double earThreshold = 0.25}) {
    _currentRideId = rideId;
    _rideStartTime = rideStartTime;
    _earThreshold = earThreshold;
    _events.clear();
    _tp = 0; _fp = 0; _tn = 0; _fn = 0;
    _isEarBelowThreshold = false;
    _eyeCloseStartTime = null;
    _isSustainedClose = false;
    _alarmActive = false;
    _alarmOccurredDuringCurrentClose = false;
    _blinkClassifyTimer?.cancel();
    debugPrint('🔬 [ResearchLogger] Session started: $rideId | threshold=$_earThreshold');
    notifyListeners();
  }

  // ── Update EAR (dipanggil setiap frame dari MicrosleepController) ──────────

  /// Dipanggil setiap kali ada nilai EAR baru dari kamera.
  ///
  /// Method ini sepenuhnya otomatis — tidak memerlukan interaksi pengemudi.
  void updateEAR(double ear) {
    if (_currentRideId == null || _rideStartTime == null) return;

    final now = DateTime.now();
    final wasBelowThreshold = _isEarBelowThreshold;
    _isEarBelowThreshold = ear < _earThreshold;

    if (!wasBelowThreshold && _isEarBelowThreshold) {
      // ── EAR baru saja turun di bawah threshold ─────────────────────────────
      _eyeCloseStartTime = now;
      _isSustainedClose = false;
      _alarmOccurredDuringCurrentClose = false;

      // Set timer: setelah _kBlinkMaxMs, jika EAR masih di bawah → ini sustained close
      _blinkClassifyTimer?.cancel();
      _blinkClassifyTimer = Timer(Duration(milliseconds: _kBlinkMaxMs), () {
        if (_isEarBelowThreshold) {
          // Masih di bawah threshold setelah blink window → SUSTAINED CLOSE
          _isSustainedClose = true;
          _logEyeCloseStart(now);
          debugPrint('🔬 [ResearchLogger] Sustained close detected (>${_kBlinkMaxMs}ms)');
        }
      });

    } else if (wasBelowThreshold && !_isEarBelowThreshold) {
      // ── EAR naik kembali di atas threshold (mata buka) ─────────────────────
      _blinkClassifyTimer?.cancel();

      final closeStart = _eyeCloseStartTime;
      if (closeStart == null) return;

      final closeDuration = now.difference(closeStart).inMilliseconds;

      if (!_isSustainedClose) {
        // Durasi pendek → ini kedipan normal
        _logNormalBlink(closeStart, now, closeDuration);

        if (!_alarmOccurredDuringCurrentClose) {
          // Kedipan normal tanpa alarm → TN
          _tn++;
          debugPrint('🔬 [ResearchLogger] TN: blink ${closeDuration}ms, no alarm');
        }
        // Jika ada alarm selama blink → sudah di-handle di onAlarmTriggered sebagai FP
      } else {
        // Sustained close berakhir
        _logEyeOpen(now);

        if (!_alarmOccurredDuringCurrentClose) {
          // Mata tertutup lama tapi tidak ada alarm → FN
          _fn++;
          _updateLastSustainedCloseOutcome(OutcomeClass.fn);
          debugPrint('🔬 [ResearchLogger] FN: sustained close ${closeDuration}ms, no alarm');
        }
        // TP sudah di-handle di onAlarmTriggered
      }

      _isSustainedClose = false;
      _eyeCloseStartTime = null;
      _alarmOccurredDuringCurrentClose = false;
      notifyListeners();
    }
  }

  // ── Alarm events (otomatis dari MicrosleepController) ──────────────────────

  /// Dipanggil otomatis ketika alarm berbunyi.
  void onAlarmTriggered() {
    if (_currentRideId == null || _rideStartTime == null) return;

    final now = DateTime.now();
    _alarmActive = true;
    _alarmOccurredDuringCurrentClose = true;

    OutcomeClass outcome;
    int? latencyMs;
    // Pre-generate ID untuk event ini (dipakai juga di pending case)
    final eventId = '${now.millisecondsSinceEpoch}-alrm';

    if (_isSustainedClose && _eyeCloseStartTime != null) {
      // Alarm terjadi saat ada sustained EAR close → TP
      outcome = OutcomeClass.tp;
      latencyMs = now.difference(_eyeCloseStartTime!).inMilliseconds;
      _tp++;
      debugPrint('🔬 [ResearchLogger] TP: alarm during sustained close (${latencyMs}ms)');
    } else if (_isEarBelowThreshold && _eyeCloseStartTime != null) {
      // Alarm terjadi saat EAR turun tapi belum sustained (masih dalam blink window)
      // Tandai pending — akan di-resolve setelah window berlalu
      outcome = OutcomeClass.pending;
      latencyMs = now.difference(_eyeCloseStartTime!).inMilliseconds;
      debugPrint('🔬 [ResearchLogger] Alarm during blink window (${latencyMs}ms) — pending');

      // Tunggu sebentar untuk tahu apakah ini akhirnya sustained
      final capturedLatency = latencyMs;
      Timer(Duration(milliseconds: _kBlinkMaxMs + 100), () {
        if (_isSustainedClose) {
          _tp++;
          _updateAlarmEventById(eventId, OutcomeClass.tp, capturedLatency);
        } else {
          _fp++;
          _updateAlarmEventById(eventId, OutcomeClass.fp, capturedLatency);
        }
        notifyListeners();
      });
    } else {
      // Alarm terjadi tanpa ada EAR close yang aktif → FP (sistem false alarm)
      outcome = OutcomeClass.fp;
      _fp++;
      debugPrint('🔬 [ResearchLogger] FP: alarm without sustained close');
    }

    final event = ResearchEventModel(
      id: eventId,
      rideId: _currentRideId!,
      timestamp: now,
      videoTimestampMs: now.difference(_rideStartTime!).inMilliseconds,
      eventType: ResearchEventType.alarmTriggered,
      classifiedAs: outcome,
      alarmLatencyMs: latencyMs,
    );
    _events.add(event);
    notifyListeners();
  }

  /// Dipanggil otomatis ketika user membatalkan peringatan kecelakaan (False Positive Kecelakaan)
  void onFalseEmergencyTriggered() {
    if (_currentRideId == null || _rideStartTime == null) return;
    
    _fp++; // Log sebagai FP di metrics
    final now = DateTime.now();
    
    final event = ResearchEventModel(
      rideId: _currentRideId!,
      timestamp: now,
      videoTimestampMs: now.difference(_rideStartTime!).inMilliseconds,
      eventType: ResearchEventType.alarmTriggered,
      classifiedAs: OutcomeClass.fp,
    );
    _events.add(event);
    notifyListeners();
    debugPrint('🔬 [ResearchLogger] FP: False emergency (accident) canceled by user');
  }

  /// Dipanggil otomatis ketika alarm dihentikan.
  void onAlarmStopped() {
    if (_currentRideId == null || _rideStartTime == null) return;
    _alarmActive = false;

    final event = ResearchEventModel(
      rideId: _currentRideId!,
      timestamp: DateTime.now(),
      videoTimestampMs: DateTime.now().difference(_rideStartTime!).inMilliseconds,
      eventType: ResearchEventType.alarmStopped,
      classifiedAs: OutcomeClass.notApplicable,
    );
    _events.add(event);
    notifyListeners();
  }

  /// Dipanggil ketika Speed-Gate menolak trigger akselerometer
  /// (guncangan > threshold tapi kecepatan >= 2 km/h → bukan kecelakaan).
  /// Dicatat sebagai TN untuk evaluasi efektivitas Speed-Gate.
  void onSpeedGateRejected(double magnitude, double speedKmH) {
    if (_currentRideId == null || _rideStartTime == null) return;

    final now = DateTime.now();

    final event = ResearchEventModel(
      rideId: _currentRideId!,
      timestamp: now,
      videoTimestampMs: now.difference(_rideStartTime!).inMilliseconds,
      eventType: ResearchEventType.speedGateRejected,
      classifiedAs: OutcomeClass.tn,
      note: 'magnitude: ${magnitude.toStringAsFixed(2)} m/s², speed: ${speedKmH.toStringAsFixed(2)} km/h',
    );
    _events.add(event);
    notifyListeners();
    debugPrint(
      '🔬 [ResearchLogger] TN: Speed-Gate rejected '
      '(mag=${magnitude.toStringAsFixed(2)}, speed=${speedKmH.toStringAsFixed(2)} km/h)',
    );
  }

  // ── Internal log helpers ───────────────────────────────────────────────────

  void _logEyeCloseStart(DateTime startTime) {
    if (_currentRideId == null || _rideStartTime == null) return;
    final event = ResearchEventModel(
      rideId: _currentRideId!,
      timestamp: startTime,
      videoTimestampMs: startTime.difference(_rideStartTime!).inMilliseconds,
      eventType: ResearchEventType.eyeCloseStart,
      classifiedAs: OutcomeClass.pending,
    );
    _events.add(event);
    notifyListeners();
  }

  void _logEyeOpen(DateTime now) {
    if (_currentRideId == null || _rideStartTime == null) return;
    final event = ResearchEventModel(
      rideId: _currentRideId!,
      timestamp: now,
      videoTimestampMs: now.difference(_rideStartTime!).inMilliseconds,
      eventType: ResearchEventType.eyeOpen,
      classifiedAs: OutcomeClass.notApplicable,
    );
    _events.add(event);
    notifyListeners();
  }

  void _logNormalBlink(DateTime start, DateTime end, int durationMs) {
    if (_currentRideId == null || _rideStartTime == null) return;
    final event = ResearchEventModel(
      rideId: _currentRideId!,
      timestamp: start,
      videoTimestampMs: start.difference(_rideStartTime!).inMilliseconds,
      eventType: ResearchEventType.normalBlink,
      classifiedAs: OutcomeClass.tn, // default; bisa jadi FP jika ada alarm
      note: 'durasi: ${durationMs}ms',
    );
    _events.add(event);
    notifyListeners();
  }

  void _updateLastSustainedCloseOutcome(OutcomeClass outcome) {
    // Cari eye_close_start terakhir dan update klasifikasinya
    for (int i = _events.length - 1; i >= 0; i--) {
      if (_events[i].eventType == ResearchEventType.eyeCloseStart) {
        _events[i] = _events[i].copyWith(classifiedAs: outcome);
        return;
      }
    }
  }

  void _updateAlarmEventById(String eventId, OutcomeClass outcome, int? latencyMs) {
    for (int i = _events.length - 1; i >= 0; i--) {
      if (_events[i].id == eventId) {
        _events[i] = _events[i].copyWith(classifiedAs: outcome, alarmLatencyMs: latencyMs);
        return;
      }
    }
  }

  // ── Simpan ke Database ─────────────────────────────────────────────────────

  /// Simpan semua event dan metrik evaluasi ke Supabase.
  /// Dipanggil otomatis saat [MonitoringController.stopRide].
  Future<void> saveToDatabase() async {
    if (_events.isEmpty || _currentRideId == null) return;

    try {
      await SupabaseService().saveResearchEvents(_currentRideId!, _events);

      final total = _tp + _fp + _tn + _fn;
      final p = precision;
      final r = recall;
      final f1 = f1Score;
      final acc = accuracy;

      await SupabaseService().saveEvaluationMetrics(
        rideId: _currentRideId!,
        tp: _tp,
        fp: _fp,
        tn: _tn,
        fn: _fn,
        precision: p,
        recall: r,
        f1Score: f1,
        accuracy: acc,
      );

      debugPrint(
        '✅ [ResearchLogger] DB saved: TP=$_tp FP=$_fp TN=$_tn FN=$_fn | '
        'total=$total P=${p.toStringAsFixed(2)} R=${r.toStringAsFixed(2)} '
        'F1=${f1.toStringAsFixed(2)} Acc=${acc.toStringAsFixed(2)}',
      );
    } catch (e) {
      debugPrint('🔴 [ResearchLogger] Save failed: $e');
    }
  }

  @override
  void dispose() {
    _blinkClassifyTimer?.cancel();
    super.dispose();
  }
}
