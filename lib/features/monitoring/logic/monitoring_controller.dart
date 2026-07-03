import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:eyeon/features/monitoring/logic/microsleep_controller.dart';
import 'package:eyeon/features/monitoring/logic/accident_controller.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

class MonitoringController extends ChangeNotifier {
  final MicrosleepController microsleepController = MicrosleepController();
  final AccidentController accidentController = AccidentController();

  final MethodChannel _cameraChannel = const MethodChannel('eyeon_native_camera_control');
  final EventChannel _cameraEventChannel = const EventChannel('eyeon_native_camera_events');
  StreamSubscription? _cameraEventSubscription;

  // Face Mesh Visuals
  List<double>? _facePoints;
  int _imageWidth = 0;
  int _imageHeight = 0;
  int _imageRotation = 0;

  List<double>? get facePoints => _facePoints;
  int get imageWidth => _imageWidth;
  int get imageHeight => _imageHeight;
  int get imageRotation => _imageRotation;

  bool _isRideStarted = false;
  bool get isRideStarted => _isRideStarted;

  bool _wasDrowsy = false;
  bool _wasAccident = false;
  int _microsleepAlertsCount = 0;
  int _accidentAlertsCount = 0;
  DateTime _rideStartTime = DateTime.now();

  String? _currentRideId;

  // No-face warning
  bool _noFaceWarning = false;
  Timer? _noFaceTimer;
  bool get noFaceWarning => _noFaceWarning;

  // Ride Metrics
  Timer? _timer;
  Duration _rideDuration = Duration.zero;
  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  Position? _lastPosition;

  Duration get rideDuration => _rideDuration;
  double get totalDistance => _totalDistance;
  double get currentSpeed => _currentSpeed;

  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionStreamController.stream;
  StreamSubscription<Position>? _positionSubscription;
  
  Position? get initialPosition => _lastPosition;

  MonitoringController() {
    microsleepController.addListener(_onUpdate);
    accidentController.addListener(_onUpdate);
  }

  void startRide() {
    _isRideStarted = true;
    _rideStartTime = DateTime.now();
    accidentController.startMonitoring();
    _startRideTracking();
    _createRideId();
    notifyListeners();
  }

  void _startRideTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _rideDuration = DateTime.now().difference(_rideStartTime);
      notifyListeners();
    });

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: LocationConfig.distanceFilterMeters,
      ),
    ).listen((Position position) {
      _currentSpeed = position.speed * 3.6;
      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distance / 1000.0;
      }
      _lastPosition = position;
      _positionStreamController.add(position);
      notifyListeners();
    });
  }

  void _onUpdate() {
    if (microsleepController.isDrowsy && !_wasDrowsy) {
      _microsleepAlertsCount++;
      _cameraChannel.invokeMethod('setDrowsyState', {'isDrowsy': true});
    } else if (!microsleepController.isDrowsy && _wasDrowsy) {
      _cameraChannel.invokeMethod('setDrowsyState', {'isDrowsy': false});
    }
    _wasDrowsy = microsleepController.isDrowsy;

    if (accidentController.isAccidentDetected && !_wasAccident) {
      _accidentAlertsCount++;
      _triggerSOS();
    }
    _wasAccident = accidentController.isAccidentDetected;

    notifyListeners();
  }

  // A callback for UI to handle notification
  void Function(BuildContext, String, NotificationType)? onNotification;
  BuildContext? currentContext;

  Future<void> _triggerSOS() async {
    String? videoPath;
    final extractionStopwatch = Stopwatch()..start();
    try {
      videoPath = await _cameraChannel.invokeMethod('lockIncidentVideo');
    } catch (e) {
      debugPrint('Failed to lock incident video: $e');
    }
    final videoExtractionMs = extractionStopwatch.elapsedMilliseconds;

    final result = await SOSService().triggerEmergencySOS(
      accidentController.currentMagnitude,
      rideId: _currentRideId,
      videoPath: videoPath,
      sensorDetectionMs: accidentController.sensorDetectionLatencyMs,
      videoExtractionMs: videoExtractionMs,
    );

    if (currentContext != null && currentContext!.mounted && onNotification != null) {
      if (result['gallerySaved'] == true) {
        onNotification!(currentContext!, 'Video insiden berhasil disimpan ke Galeri!', NotificationType.success);
      }
      if (result['telegramSent'] == true) {
        onNotification!(currentContext!, 'SOS terkirim via Telegram!', NotificationType.info);
      } else {
        onNotification!(currentContext!, 'Gagal mengirim SOS: ${result['telegramError'] ?? 'Unknown error'}', NotificationType.error);
      }
    }
  }

  void initializeCameraEvents() {
    _cameraEventSubscription?.cancel();
    _cameraEventSubscription = _cameraEventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event != null && event is Map) {
          final type = event['type'];
          if (type == 'ear') {
            double ear = (event['value'] as num).toDouble();
            
            List<double> points = [];
            if (event['points'] != null) {
              points = (event['points'] as List).map((e) => (e as num).toDouble()).toList();
            }
            int width = event['imageWidth'] ?? 0;
            int height = event['imageHeight'] ?? 0;
            int rotation = event['rotation'] ?? 0;

            microsleepController.updateEAR(ear);
            
            _facePoints = points;
            _imageWidth = width;
            _imageHeight = height;
            _imageRotation = rotation;
            notifyListeners();
          } else if (type == 'no_face') {
            _facePoints = null;
            _noFaceWarning = true;
            notifyListeners();

            _noFaceTimer?.cancel();
            _noFaceTimer = Timer(const Duration(seconds: 2), () {
              _noFaceWarning = false;
              notifyListeners();
            });
          }
        }
      },
    );
  }

  Future<void> _createRideId() async {
    try {
      _currentRideId = await SupabaseService().logRide(
        startTime: _rideStartTime,
        endTime: _rideStartTime,
        totalMicrosleepAlerts: 0,
        totalAccidentAlerts: 0,
        distance: 0,
      );
    } catch (e) {
      debugPrint('Failed to create ride ID: $e');
    }
  }

  void saveRideDataOnExit() {
    if (!_isRideStarted) return;
    if (_currentRideId != null) {
      SupabaseService().updateRide(
        rideId: _currentRideId!,
        endTime: DateTime.now(),
        totalMicrosleepAlerts: _microsleepAlertsCount,
        totalAccidentAlerts: _accidentAlertsCount,
        distance: _totalDistance,
      );
    }
  }

  Future<void> stopRide() async {
    _cameraEventSubscription?.cancel();
    _cameraEventSubscription = null;
    accidentController.stopMonitoring();

    if (_currentRideId != null) {
      try {
        await SupabaseService().updateRide(
          rideId: _currentRideId!,
          endTime: DateTime.now(),
          totalMicrosleepAlerts: _microsleepAlertsCount,
          totalAccidentAlerts: _accidentAlertsCount,
          distance: _totalDistance,
        );
      } catch (e) {
        debugPrint('Failed to update ride: $e');
      }
    } else {
      await SupabaseService().logRide(
        startTime: _rideStartTime,
        endTime: DateTime.now(),
        totalMicrosleepAlerts: _microsleepAlertsCount,
        totalAccidentAlerts: _accidentAlertsCount,
        distance: _totalDistance,
      );
    }
  }

  Future<void> startNativeCamera() async {
    try {
      await _cameraChannel.invokeMethod('startCamera');
    } catch (e) {
      debugPrint('Failed to start native camera: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noFaceTimer?.cancel();
    _positionSubscription?.cancel();
    _positionStreamController.close();
    _cameraEventSubscription?.cancel();
    accidentController.dispose();
    microsleepController.dispose();
    super.dispose();
  }
}
