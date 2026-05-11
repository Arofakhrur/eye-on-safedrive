import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:eyeon/core/services/sos_service.dart';

class AccidentController extends ChangeNotifier {
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
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

  void _triggerAccidentResponse() {
    debugPrint('🚨 ACCIDENT DETECTED! 🚨 Magnitude: $_currentMagnitude rad/s');
    SOSService().triggerEmergencySOS(_currentMagnitude);
  }

  void resetAccidentState() {
    _isAccidentDetected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    super.dispose();
  }
}
