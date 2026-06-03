import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/utils/camera_utils.dart';
import 'package:eyeon/features/monitoring/logic/microsleep_controller.dart';
import 'package:eyeon/features/monitoring/logic/accident_controller.dart';
import 'package:eyeon/features/monitoring/views/face_mesh_painter.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:eyeon/core/services/video_buffer_service.dart';
import 'package:eyeon/features/monitoring/widgets/live_map_widget.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_stats_bar.dart';
import 'package:gal/gal.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  CameraController? _cameraController;
  final MicrosleepController _microsleepController = MicrosleepController();
  final AccidentController _accidentController = AccidentController();

  bool _isCameraInitialized = false;
  bool _isRideStarted = false;

  bool _wasDrowsy = false;
  bool _wasAccident = false;
  int _microsleepAlertsCount = 0;
  int _accidentAlertsCount = 0;
  final DateTime _rideStartTime = DateTime.now();

  // Ride ID for incident linking (Task 8)
  String? _currentRideId;

  // Ride Metrics
  Timer? _timer;
  Duration _rideDuration = Duration.zero;
  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  Position? _lastPosition;

  // GPS stream for live map (Task 11)
  final StreamController<Position> _positionStreamController =
      StreamController<Position>.broadcast();
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _microsleepController.addListener(_onUpdate);
    _accidentController.addListener(_onUpdate);
    
    // Request gallery access early
    Gal.requestAccess();
  }

  void _startRide() {
    setState(() {
      _isRideStarted = true;
    });
    _accidentController.startMonitoring();
    _startRideTracking();
  }

  void _startRideTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _rideDuration = DateTime.now().difference(_rideStartTime);
        });
      }
    });

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
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
        });
      }
      _lastPosition = position;

      // Feed the live map stream (Task 11)
      _positionStreamController.add(position);
    });
  }

  void _onUpdate() {
    if (mounted) {
      if (_microsleepController.isDrowsy && !_wasDrowsy) {
        _microsleepAlertsCount++;
      }
      _wasDrowsy = _microsleepController.isDrowsy;

      if (_accidentController.isAccidentDetected && !_wasAccident) {
        _accidentAlertsCount++;
        // Trigger SOS flow with ride ID for incident linking
        _triggerSOS();
      }
      _wasAccident = _accidentController.isAccidentDetected;

      setState(() {});
    }
  }

  Future<void> _triggerSOS() async {
    final result = await SOSService().triggerEmergencySOS(
      _accidentController.currentMagnitude,
      rideId: _currentRideId,
    );
    
    if (mounted) {
      if (result['gallerySaved'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Video insiden berhasil disimpan ke Galeri!')),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (result['telegramSent'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.telegram_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('SOS terkirim via Telegram!')),
              ],
            ),
            backgroundColor: const Color(0xFF0088CC),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    int cameraIndex = -1;
    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == CameraLensDirection.front) {
        cameraIndex = i;
        break;
      }
    }
    if (cameraIndex == -1 && cameras.isNotEmpty) cameraIndex = 0;

    if (cameraIndex != -1) {
      _cameraController = CameraController(
        cameras[cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      _cameraController!.startImageStream((CameraImage image) {
        // Feed rolling video buffer for incident evidence
        VideoBufferService().addFrame(image);
        
        final inputImage = CameraUtils.inputImageFromCameraImage(image, _cameraController);
        if (inputImage != null) _microsleepController.processImage(inputImage);
      });

      setState(() => _isCameraInitialized = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _positionStreamController.close();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _accidentController.dispose();
    _microsleepController.dispose();
    super.dispose();
  }

  Future<void> _onStopRide() async {
    // Log ride and get the ride UUID for incident linking
    _currentRideId = await SupabaseService().logRide(
      startTime: _rideStartTime,
      endTime: DateTime.now(),
      totalMicrosleepAlerts: _microsleepAlertsCount,
      totalAccidentAlerts: _accidentAlertsCount,
      distance: _totalDistance,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Split view: camera (top 60%) + map (bottom 40%)
          Column(
            children: [
              // Camera preview — top portion
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isCameraInitialized && _cameraController != null)
                      CameraPreview(_cameraController!, child: _buildFaceMeshOverlay())
                    else
                      const Center(child: CircularProgressIndicator(color: Color(0xFFD7F454))),
                  ],
                ),
              ),

              // Live map — bottom portion (Task 11)
              if (_isRideStarted)
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFD7F454).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    child: LiveMapWidget(
                      positionStream: _positionStreamController.stream,
                      initialPosition: _lastPosition,
                    ),
                  ),
                ),
            ],
          ),

          // Stats bar overlay
          if (_isRideStarted)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: MonitoringStatsBar(
                isDrowsy: _microsleepController.isDrowsy,
                isAccident: _accidentController.isAccidentDetected,
                currentSpeed: _currentSpeed,
                rideDuration: _rideDuration,
                totalDistance: _totalDistance,
                currentEAR: _microsleepController.currentEAR,
                currentGForce: _accidentController.currentMagnitude,
                formattedDuration: _formatDuration(_rideDuration),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _isRideStarted
                  ? GestureDetector(
                      onTap: _onStopRide,
                      child: _buildStopButton(),
                    )
                  : _buildSwipeToStart(),
            ),
          ),

          // Alert overlay
          if (_isRideStarted && (_microsleepController.isDrowsy || _accidentController.isAccidentDetected))
            IgnorePointer(child: Container(color: Colors.red.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildSwipeToStart() {
    return _InteractiveSwipeButton(
      onStarted: _startRide,
    );
  }

  Widget _buildStopButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Text(
            'STOP RIDE',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceMeshOverlay() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return const SizedBox();
    final size = MediaQuery.of(context).size;
    var rotation = InputImageRotation.rotation0deg;
    if (Platform.isAndroid) {
      rotation = InputImageRotationValue.fromRawValue(_cameraController!.description.sensorOrientation) ?? InputImageRotation.rotation270deg;
    }
    return CustomPaint(
      painter: FaceMeshPainter(
        _microsleepController.currentMeshes,
        _cameraController!.value.previewSize ?? const Size(480, 640),
        rotation,
        _microsleepController.isDrowsy,
      ),
      size: size,
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

class _InteractiveSwipeButton extends StatefulWidget {
  final VoidCallback onStarted;
  const _InteractiveSwipeButton({required this.onStarted});

  @override
  State<_InteractiveSwipeButton> createState() => _InteractiveSwipeButtonState();
}

class _InteractiveSwipeButtonState extends State<_InteractiveSwipeButton> {
  double _dragOffset = 0.0;
  static const double _maxDrag = 120.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _dragOffset -= details.delta.dy;
              if (_dragOffset < 0) _dragOffset = 0;
              if (_dragOffset > _maxDrag) _dragOffset = _maxDrag;
            });
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset >= _maxDrag * 0.8) {
              widget.onStarted();
            } else {
              setState(() {
                _dragOffset = 0;
              });
            }
          },
          child: Container(
            width: 80,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Track indicators
                Positioned(
                  top: 20,
                  child: Opacity(
                    opacity: 1.0 - (_dragOffset / _maxDrag),
                    child: Column(
                      children: const [
                        Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white38, size: 24),
                        Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white24, size: 24),
                        Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white12, size: 24),
                      ],
                    ),
                  ),
                ),
                // Draggable Button
                Positioned(
                  bottom: 10 + _dragOffset,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7F454),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD7F454).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.black, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'SWIPE UP TO START',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
          ),
        ),
      ],
    );
  }
}
