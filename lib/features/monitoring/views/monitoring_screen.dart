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
import 'package:eyeon/features/monitoring/widgets/monitoring_top_bar.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_bottom_bar.dart';
import 'package:gal/gal.dart';

enum ScreenMode { split, fullCamera, fullMap }

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
  ScreenMode _currentMode = ScreenMode.split;

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
    final size = MediaQuery.of(context).size;
    final totalHeight = size.height;

    double cameraTop = 0;
    double cameraHeight = totalHeight / 2;
    double mapBottom = 0;
    double mapHeight = totalHeight / 2;

    if (_currentMode == ScreenMode.fullCamera) {
      cameraHeight = totalHeight;
      mapHeight = 0;
    } else if (_currentMode == ScreenMode.fullMap) {
      cameraHeight = 0;
      mapHeight = totalHeight;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            top: cameraTop,
            left: 0,
            right: 0,
            height: cameraHeight,
            child: ClipRRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    CameraPreview(_cameraController!, child: _buildFaceMeshOverlay())
                  else
                    const Center(child: CircularProgressIndicator(color: Color(0xFFD7F454))),
                  
                  // Toggle Fullscreen Camera
                  if (_isRideStarted)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 80,
                      right: 16,
                      child: _buildScreenToggleButton(
                        isFull: _currentMode == ScreenMode.fullCamera,
                        onTap: () {
                          setState(() {
                            _currentMode = _currentMode == ScreenMode.fullCamera
                                ? ScreenMode.split
                                : ScreenMode.fullCamera;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Map Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            bottom: mapBottom,
            left: 0,
            right: 0,
            height: mapHeight,
            child: ClipRRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isRideStarted)
                    Container(
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
                  
                  // Toggle Fullscreen Map
                  if (_isRideStarted)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: _buildScreenToggleButton(
                        isFull: _currentMode == ScreenMode.fullMap,
                        onTap: () {
                          setState(() {
                            _currentMode = _currentMode == ScreenMode.fullMap
                                ? ScreenMode.split
                                : ScreenMode.fullMap;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Top Bar
          if (_isRideStarted)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: MonitoringTopBar(
                  isDrowsy: _microsleepController.isDrowsy,
                  isAccident: _accidentController.isAccidentDetected,
                  currentSpeed: _currentSpeed,
                  formattedDuration: _formatDuration(_rideDuration),
                  totalDistance: _totalDistance,
                ),
              ),
            ),

          // Bottom Bar
          if (_isRideStarted)
            Positioned(
              bottom: 120, // Above the stop button
              left: 16,
              right: 16,
              child: MonitoringBottomBar(
                currentSpeed: _currentSpeed,
                currentEAR: _microsleepController.currentEAR,
                currentGForce: _accidentController.currentMagnitude,
                isAccident: _accidentController.isAccidentDetected,
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
          if (_isRideStarted)
            _buildAlertOverlay(),
        ],
      ),
    );
  }

  Widget _buildScreenToggleButton({required bool isFull, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFull ? 'COLLAPSE SCREEN' : 'VIEW FULL SCREEN',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isFull ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
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

  Widget _buildAlertOverlay() {
    if (_accidentController.isAccidentDetected) {
      return Container(color: Colors.red.withValues(alpha: 0.5));
    }

    if (_microsleepController.isPaused) {
      int count = _microsleepController.drowsyCount;
      if (count == 1) return _buildLevel1Overlay();
      if (count == 2) return _buildLevel2Overlay();
      if (count >= 3) return _buildLevel3Overlay();
    }
    return const SizedBox.shrink();
  }

  Widget _buildLevel1Overlay() {
    return Container(
      color: Colors.orange.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
            const SizedBox(height: 16),
            Text(
              'PERHATIAN!\nAnda terdeteksi mengantuk',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 48),
            _InteractiveSwipeButton(
              onStarted: () => _microsleepController.resumeMonitoring(),
              label: 'SWIPE UP TO RESUME',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevel2Overlay() {
    return _BlinkingOverlay(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dangerous_rounded, color: Colors.white, size: 100),
            const SizedBox(height: 16),
            Text(
              'BAHAYA!\nSegera Menepi!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onLongPress: () => _microsleepController.resumeMonitoring(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  'TEHAN LAMA UNTUK LANJUT',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevel3Overlay() {
    bool canUnlock = _currentSpeed < 1.0; // Close to 0 km/h
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 100),
            const SizedBox(height: 16),
            Text(
              'SISTEM TERKUNCI\nWajib Istirahat',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            Text(
              canUnlock
                  ? 'Kecepatan 0 km/h.\nKetuk untuk melanjutkan.'
                  : 'Berhentikan kendaraan Anda\nuntuk membuka kunci.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            if (canUnlock)
              ElevatedButton(
                onPressed: () {
                  _microsleepController.resetDrowsyCount();
                  _microsleepController.resumeMonitoring();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD7F454),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  'LANJUTKAN PERJALANAN',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
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
  final String label;
  const _InteractiveSwipeButton({
    required this.onStarted,
    this.label = 'SWIPE UP TO START',
  });

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
          widget.label,
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

class _BlinkingOverlay extends StatefulWidget {
  final Widget child;
  const _BlinkingOverlay({required this.child});
  @override
  State<_BlinkingOverlay> createState() => _BlinkingOverlayState();
}

class _BlinkingOverlayState extends State<_BlinkingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: Colors.red.withValues(alpha: 0.6 + (_controller.value * 0.4)),
          child: widget.child,
        );
      },
    );
  }
}
