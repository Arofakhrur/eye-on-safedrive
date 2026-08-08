import 'dart:math';

/// Jenis event yang dicatat selama sesi monitoring berlangsung.
enum ResearchEventType {
  /// Sistem mendeteksi EAR di bawah threshold selama > blink window → drowsy candidate.
  eyeCloseStart,

  /// EAR kembali di atas threshold setelah sustained close.
  eyeOpen,

  /// EAR turun-naik cepat (< 500ms) → kedipan normal, bukan drowsy.
  /// Ini adalah ground truth TN otomatis.
  normalBlink,

  /// Alarm dibunyikan secara otomatis oleh MicrosleepController.
  alarmTriggered,

  /// Alarm dihentikan (user tekan resume, atau sesi berakhir).
  alarmStopped,

  /// Speed-Gate menolak trigger akselerometer (guncangan > threshold
  /// tapi kecepatan masih di atas batas → bukan kecelakaan, TN).
  speedGateRejected,
}

/// Klasifikasi hasil deteksi — True/False Positive/Negative.
enum OutcomeClass {
  /// True Positive: alarm berbunyi AND ada ground truth mata tertutup.
  tp,

  /// False Positive: alarm berbunyi TANPA ground truth mata tertutup
  /// (sistem salah deteksi — bisa karena kedipan normal).
  fp,

  /// True Negative: tidak ada alarm, tidak ada ground truth mata tertutup
  /// (interval normal termasuk kedipan normal).
  tn,

  /// False Negative: ground truth mata tertutup ADA, tetapi alarm tidak berbunyi.
  fn,

  /// Belum diklasifikasikan (window 5 detik belum berlalu).
  pending,

  /// Event ini tidak menghasilkan klasifikasi langsung (misalnya eye_open, alarm_stopped).
  notApplicable,
}

extension ResearchEventTypeExt on ResearchEventType {
  String get label {
    switch (this) {
      case ResearchEventType.eyeCloseStart:
        return 'eye_close_start';
      case ResearchEventType.eyeOpen:
        return 'eye_open';
      case ResearchEventType.normalBlink:
        return 'normal_blink';
      case ResearchEventType.alarmTriggered:
        return 'alarm_triggered';
      case ResearchEventType.alarmStopped:
        return 'alarm_stopped';
      case ResearchEventType.speedGateRejected:
        return 'speed_gate_rejected';
    }
  }

  static ResearchEventType fromLabel(String label) {
    switch (label) {
      case 'eye_close_start':
        return ResearchEventType.eyeCloseStart;
      case 'eye_open':
        return ResearchEventType.eyeOpen;
      case 'normal_blink':
        return ResearchEventType.normalBlink;
      case 'alarm_triggered':
        return ResearchEventType.alarmTriggered;
      case 'alarm_stopped':
        return ResearchEventType.alarmStopped;
      case 'speed_gate_rejected':
        return ResearchEventType.speedGateRejected;
      default:
        return ResearchEventType.alarmTriggered;
    }
  }
}

extension OutcomeClassExt on OutcomeClass {
  String get label {
    switch (this) {
      case OutcomeClass.tp:
        return 'TP';
      case OutcomeClass.fp:
        return 'FP';
      case OutcomeClass.tn:
        return 'TN';
      case OutcomeClass.fn:
        return 'FN';
      case OutcomeClass.pending:
        return 'pending';
      case OutcomeClass.notApplicable:
        return '-';
    }
  }
}

/// Model satu event log penelitian selama sesi monitoring.
class ResearchEventModel {
  /// UUID unik event ini.
  final String id;

  /// ID ride yang sedang aktif (dari Supabase ride_logs).
  final String rideId;

  /// Waktu absolut event terjadi (UTC).
  final DateTime timestamp;

  /// Waktu relatif dari ride start (dalam milidetik).
  final int videoTimestampMs;

  /// Jenis event.
  final ResearchEventType eventType;

  /// Klasifikasi TP/FP/TN/FN hasil analisis korelasi.
  final OutcomeClass classifiedAs;

  /// Latency alarm sejak eye_close_start (hanya untuk TP).
  final int? alarmLatencyMs;

  /// Catatan tambahan (opsional).
  final String? note;

  ResearchEventModel({
    String? id,
    required this.rideId,
    required this.timestamp,
    required this.videoTimestampMs,
    required this.eventType,
    this.classifiedAs = OutcomeClass.notApplicable,
    this.alarmLatencyMs,
    this.note,
  }) : id = id ?? _generateId();

  /// Generates a pseudo-unique ID without external dependencies.
  static String _generateId() {
    final rand = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final suffix = rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$ts-$suffix';
  }

  ResearchEventModel copyWith({
    OutcomeClass? classifiedAs,
    int? alarmLatencyMs,
    String? note,
  }) {
    return ResearchEventModel(
      id: id,
      rideId: rideId,
      timestamp: timestamp,
      videoTimestampMs: videoTimestampMs,
      eventType: eventType,
      classifiedAs: classifiedAs ?? this.classifiedAs,
      alarmLatencyMs: alarmLatencyMs ?? this.alarmLatencyMs,
      note: note ?? this.note,
    );
  }

  /// Header CSV.
  static String get csvHeader =>
      'id,ride_id,timestamp_utc,video_time_s,event_type,classified_as,alarm_latency_ms,note';

  /// Konversi ke baris CSV.
  String toCsvRow() {
    final videoTimeSec = (videoTimestampMs / 1000.0).toStringAsFixed(2);
    return [
      id,
      rideId,
      timestamp.toIso8601String(),
      videoTimeSec,
      eventType.label,
      classifiedAs.label,
      alarmLatencyMs?.toString() ?? '',
      (note ?? '').replaceAll(',', ';'),
    ].join(',');
  }

  /// Konversi ke Map untuk Supabase insert.
  Map<String, dynamic> toJson() => {
        'id': id,
        'ride_id': rideId,
        'timestamp': timestamp.toIso8601String(),
        'video_timestamp_ms': videoTimestampMs,
        'event_type': eventType.label,
        'classified_as': classifiedAs.label,
        'alarm_latency_ms': alarmLatencyMs,
        'note': note,
      };

  /// Buat dari Map Supabase.
  factory ResearchEventModel.fromJson(Map<String, dynamic> json) {
    return ResearchEventModel(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      videoTimestampMs: (json['video_timestamp_ms'] as num).toInt(),
      eventType: ResearchEventTypeExt.fromLabel(json['event_type'] as String),
      classifiedAs: _parseOutcome(json['classified_as'] as String?),
      alarmLatencyMs: json['alarm_latency_ms'] as int?,
      note: json['note'] as String?,
    );
  }

  static OutcomeClass _parseOutcome(String? label) {
    switch (label) {
      case 'TP':
        return OutcomeClass.tp;
      case 'FP':
        return OutcomeClass.fp;
      case 'TN':
        return OutcomeClass.tn;
      case 'FN':
        return OutcomeClass.fn;
      case 'pending':
        return OutcomeClass.pending;
      default:
        return OutcomeClass.notApplicable;
    }
  }
}
