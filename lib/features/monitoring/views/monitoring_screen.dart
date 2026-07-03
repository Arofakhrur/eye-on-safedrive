import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/features/monitoring/logic/microsleep_controller.dart';
import 'package:eyeon/features/monitoring/logic/accident_controller.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:eyeon/features/monitoring/widgets/live_map_widget.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_top_bar.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_bottom_bar.dart';
import 'package:eyeon/features/monitoring/views/native_face_mesh_painter.dart';

import 'package:gal/gal.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

enum ScreenMode { split, fullCamera, fullMap }

class MonitoringScreen extends StatefulWidget {
  final LatLng? destination;
  final String? destinationName;

  const MonitoringScreen({
    super.key,
    this.destination,
    this.destinationName,
  });

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MethodChannel _cameraChannel = const MethodChannel('eyeon_native_camera_control');
  final EventChannel _cameraEventChannel = const EventChannel('eyeon_native_camera_events');
  StreamSubscription? _cameraEventSubscription;

  // Face Mesh Visuals
  List<double>? _facePoints;
  int _imageWidth = 0;
  int _imageHeight = 0;
  int _imageRotation = 0;

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

  // No-face warning
  bool _noFaceWarning = false;
  Timer? _noFaceTimer;

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

  LatLng? _destination;

  // ── Circular Reveal Animation (Task 48/49) ──
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showRevealOverlay = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    // Accept destination from RideSetupScreen
    _destination = widget.destination;

    // Task 47: DO NOT init camera here — defer to swipe start
    _microsleepController.addListener(_onUpdate);
    _accidentController.addListener(_onUpdate);
    WidgetsBinding.instance.addObserver(this);

    // Request gallery access early
    Gal.requestAccess();

    // Setup circular reveal animation
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _revealAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  void _onSwipeToStart() {
    if (_isTransitioning) return;
    _isTransitioning = true;

    // Task 48: Trigger circular reveal animation
    setState(() {
      _showRevealOverlay = true;
      _isCameraInitialized = true; // Mount AndroidView immediately for zero-latency start
    });

    _revealController.forward().then((_) {
      // Task 49: After reveal covers screen, start ride
      setState(() {
        _isRideStarted = true;
      });
      _accidentController.startMonitoring();
      _startRideTracking();

      // Create ride ID early so incident videos can be linked
      _createRideId();

      // Fade out the green overlay to reveal monitoring UI
      Future.delayed(const Duration(milliseconds: 200), () {
        _fadeController.forward().then((_) {
          if (mounted) {
            setState(() {
              _showRevealOverlay = false;
              _isTransitioning = false;
            });
          }
        });
      });
    });
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
        distanceFilter: LocationConfig.distanceFilterMeters,
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
        _cameraChannel.invokeMethod('setDrowsyState', {'isDrowsy': true});
      } else if (!_microsleepController.isDrowsy && _wasDrowsy) {
        _cameraChannel.invokeMethod('setDrowsyState', {'isDrowsy': false});
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
    // 1. Lock video buffer first to capture the incident accurately
    String? videoPath;
    final extractionStopwatch = Stopwatch()..start();
    try {
      videoPath = await _cameraChannel.invokeMethod('lockIncidentVideo');
    } catch (e) {
      debugPrint('Failed to lock incident video: $e');
    }
    final videoExtractionMs = extractionStopwatch.elapsedMilliseconds;

    // 2. Trigger SOS and pass the video path and latencies
    final result = await SOSService().triggerEmergencySOS(
      _accidentController.currentMagnitude,
      rideId: _currentRideId,
      videoPath: videoPath,
      sensorDetectionMs: _accidentController.sensorDetectionLatencyMs,
      videoExtractionMs: videoExtractionMs,
    );

    
    if (mounted) {
      if (result['gallerySaved'] == true) {
        NotificationHelper.showTop(
          context,
          message: 'Video insiden berhasil disimpan ke Galeri!',
          type: NotificationType.success,
        );
      }

      if (result['telegramSent'] == true) {
        NotificationHelper.showTop(
          context,
          message: 'SOS terkirim via Telegram!',
          type: NotificationType.info,
        );
      } else {
        NotificationHelper.showTop(
          context,
          message: 'Gagal mengirim SOS: ${result['telegramError'] ?? 'Unknown error'}',
          type: NotificationType.error,
        );
      }
    }
  }

  void _initializeCameraEvents() {
    debugPrint('[MonitoringScreen] _initializeCameraEvents: Setting up EventChannel listener');
    _cameraEventSubscription?.cancel();
    _cameraEventSubscription = _cameraEventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event != null && event is Map) {
          final type = event['type'];
          if (type == 'ear') {
            double ear = (event['value'] as num).toDouble();
            
            // Extract face mesh points array for CustomPaint
            List<double> points = [];
            if (event['points'] != null) {
              points = (event['points'] as List).map((e) => (e as num).toDouble()).toList();
            }
            int width = event['imageWidth'] ?? 0;
            int height = event['imageHeight'] ?? 0;
            int rotation = event['rotation'] ?? 0;

            _microsleepController.updateEAR(ear);
            
            if (mounted) {
              setState(() {
                _facePoints = points;
                _imageWidth = width;
                _imageHeight = height;
                _imageRotation = rotation;
              });
            }
          } else if (type == 'no_face') {
            if (mounted) {
              setState(() {
                _facePoints = null;
                _noFaceWarning = true;
              });
              _noFaceTimer?.cancel();
              _noFaceTimer = Timer(AppDurations.noFaceWarning, () {
                if (mounted) {
                  setState(() => _noFaceWarning = false);
                }
              });
            }
          } else if (type == 'incident_video_ready') {
            String path = event['path'] ?? '';
            debugPrint('[MonitoringScreen] Incident video ready at: $path');
            // Video upload is handled by _triggerSOS -> SOSService flow.
            // Do NOT upload here to avoid duplicate upload and premature file deletion.
          }
        }
      },
      onError: (error) {
        debugPrint('[MonitoringScreen] EventChannel error: $error');
      },
      onDone: () {
        debugPrint('[MonitoringScreen] EventChannel stream closed');
      },
    );
  }

  Future<void> _createRideId() async {
    try {
      _currentRideId = await SupabaseService().logRide(
        startTime: _rideStartTime,
        endTime: _rideStartTime, // Placeholder, will be updated on stop
        totalMicrosleepAlerts: 0,
        totalAccidentAlerts: 0,
        distance: 0,
      );
      debugPrint('[MonitoringScreen] Ride ID created: $_currentRideId');
    } catch (e) {
      debugPrint('[MonitoringScreen] Failed to create ride ID: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noFaceTimer?.cancel();
    _positionSubscription?.cancel();
    _positionStreamController.close();
    _cameraEventSubscription?.cancel();
    _accidentController.dispose();
    _microsleepController.dispose();
    _revealController.dispose();
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveRideDataOnExit();
    }
  }

  /// Save ride data when app is paused/force-closed to prevent dangling records.
  void _saveRideDataOnExit() {
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

  Future<void> _onStopRide() async {
    // Stop camera event stream
    _cameraEventSubscription?.cancel();
    _cameraEventSubscription = null;

    // Stop accident monitoring
    _accidentController.stopMonitoring();

    // Update the ride record with final data
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
        debugPrint('[MonitoringScreen] Failed to update ride: $e');
      }
    } else {
      // Fallback: create ride log if no ID was created earlier
      await SupabaseService().logRide(
        startTime: _rideStartTime,
        endTime: DateTime.now(),
        totalMicrosleepAlerts: _microsleepAlertsCount,
        totalAccidentAlerts: _accidentAlertsCount,
        distance: _totalDistance,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Pre-Ride State (Task 45): Black background + Guide + Swipe ──
    if (!_isRideStarted && !_showRevealOverlay) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Guide card + Swipe button
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  // Driving Guide Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildDrivingGuideCard(),
                  ),
                  const Spacer(flex: 1),
                  // Swipe to start
                  _buildSwipeToStart(),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Back button (Task 46)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: _buildBackButton(),
            ),
          ],
        ),
      );
    }

    // ── Ride Active State: Camera + Map + Overlays ──
    final size = MediaQuery.of(context).size;
    final totalHeight = size.height;

    double cameraHeight = totalHeight / 2;
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
            top: 0,
            left: 0,
            right: 0,
            height: cameraHeight,
            child: ClipRRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized)
                    ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: size.width,
                            height: size.width * (4.0 / 3.0), // Standard 4:3 native ratio
                            child: CustomPaint(
                              foregroundPainter: _facePoints != null && _facePoints!.isNotEmpty
                                  ? NativeFaceMeshPainter(
                                      _facePoints!,
                                      Size(_imageWidth.toDouble(), _imageHeight.toDouble()),
                                      _imageRotation,
                                      _microsleepController.isDrowsy,
                                    )
                                  : null,
                              child: AndroidView(
                                viewType: 'eyeon_native_camera',
                                creationParamsCodec: const StandardMessageCodec(),
                                onPlatformViewCreated: (id) async {
                                  // Subscribe to events AFTER the native view is created!
                                  _initializeCameraEvents();
                                  try {
                                    await _cameraChannel.invokeMethod('startCamera');
                                  } catch (e) {
                                    debugPrint('Failed to start native camera: $e');
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ],
              ),
            ),
          ),

          // Toggle Fullscreen Camera (Moved outside of ClipRRect to ensure it is always visible)
          if (_isRideStarted && !_showRevealOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
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

          // Map Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            bottom: 0,
            left: 0,
            right: 0,
            height: mapHeight,
            child: ClipRRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    child: LiveMapWidget(
                      positionStream: _positionStreamController.stream,
                      initialPosition: _lastPosition,
                      destination: _destination,
                    ),
                  ),
                  
                  // Toggle Fullscreen Map
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
          Positioned(
            bottom: 120 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: MonitoringBottomBar(
              currentSpeed: _currentSpeed,
              currentEAR: _microsleepController.currentEAR,
              currentGForce: _accidentController.currentMagnitude,
              isAccident: _accidentController.isAccidentDetected,
            ),
          ),

          // Stop button
          Positioned(
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onStopRide,
                child: _buildStopButton(),
              ),
            ),
          ),

          // Alert overlay
          _buildAlertOverlay(),

          // No-face warning overlay
          if (_noFaceWarning && _isRideStarted && !_showRevealOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.face_retouching_off, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Wajah tidak terdeteksi',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Circular Reveal Overlay (Task 48/49) ──
          if (_showRevealOverlay)
            _buildCircularRevealOverlay(),
        ],
      ),
    );
  }

  // ── Task 46: Back button ──
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  // ── Circular Reveal (Task 48/49) ──
  Widget _buildCircularRevealOverlay() {
    final size = MediaQuery.of(context).size;
    // Max radius to cover entire screen from bottom center
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);

    return AnimatedBuilder(
      animation: _revealAnimation,
      builder: (context, child) {
        final currentRadius = _revealAnimation.value * maxRadius;
        final fadeValue = _fadeController.isAnimating || _fadeController.isCompleted
            ? (1.0 - _fadeAnimation.value)
            : 1.0;

        return IgnorePointer(
          child: Opacity(
            opacity: fadeValue,
            child: ClipPath(
              clipper: _CircularRevealClipper(
                center: Offset(size.width / 2, size.height - 140),
                radius: currentRadius,
              ),
              child: Container(
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
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
      onStarted: _onSwipeToStart,
    );
  }

  Widget _buildDrivingGuideCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Ready to drive?',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PANDUAN SEBELUM BERKENDARA',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _guideItem('1', 'Helm SNI', 'Gunakan helm standar Nasional Indonesia.'),
          _guideItem('2', 'Sistem Rem', 'Tes fungsi rem depan dan belakang.'),
          _guideItem('3', 'Lampu & Sein', 'Pastikan semua lampu berfungsi.'),
          _guideItem('4', 'Tekanan Ban', 'Cek tekanan ban depan dan belakang.'),
          _guideItem('5', 'SIM & STNK', 'Pastikan dokumen berkendara terbawa.'),
          const SizedBox(height: 16),
          Text(
            'HATI-HATI DIJALAN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TEXT AFIRMASI TAMBAHAN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideItem(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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


  Widget _buildAlertOverlay() {
    if (_accidentController.isAccidentDetected) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BlinkingOverlay(
                  child: const Icon(Icons.emergency_rounded, color: Colors.red, size: 80),
                ),
                const SizedBox(height: 16),
                Text(
                  'INSIDEN TERDETEKSI!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.red, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sistem mendeteksi guncangan keras (${_accidentController.currentMagnitude.toStringAsFixed(1)} rad/s).\nSedang mengirim SOS ke kontak darurat...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Memproses rekaman video...',
                  style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _accidentController.resetAccidentState();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Saya Baik-Baik Saja (Matikan Alarm)',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SOSService().showEmergencyContactSheet(context);
                    },
                    icon: const Icon(Icons.call, color: Colors.white, size: 20),
                    label: Text(
                      'Hubungi Kontak Darurat',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
    bool canUnlock = _currentSpeed < DetectionConfig.level3UnlockSpeedKmH;
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
                  backgroundColor: AppColors.primary,
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

// ── Circular Reveal Clipper (Task 48) ──
class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _CircularRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
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
                // Track indicators — double chevron (Task 37)
                Positioned(
                  top: 24,
                  child: Opacity(
                    opacity: 1.0 - (_dragOffset / _maxDrag),
                    child: Column(
                      children: const [
                        Icon(Icons.expand_less_rounded, color: Colors.white54, size: 32),
                        Icon(Icons.expand_less_rounded, color: Colors.white24, size: 28),
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
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
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
