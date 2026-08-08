import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:gal/gal.dart';

import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/utils/notification_helper.dart';
import 'package:eyeon/core/services/sos_service.dart';
import 'package:eyeon/core/services/preference_service.dart';

import 'package:eyeon/features/monitoring/logic/monitoring_controller.dart';
import 'package:eyeon/features/monitoring/widgets/live_map_widget.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_top_bar.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_bottom_bar.dart';
import 'package:eyeon/features/monitoring/views/native_face_mesh_painter.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_overlays.dart';

enum ScreenMode { split, fullCamera, fullMap }

class MonitoringScreen extends StatefulWidget {
  final LatLng? destination;
  final String? destinationName;

  const MonitoringScreen({super.key, this.destination, this.destinationName});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MonitoringController _controller = MonitoringController();

  ScreenMode _currentMode = ScreenMode.split;
  bool _isCameraInitialized = false;

  // ── Circular Reveal Animation ──
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showRevealOverlay = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only request gallery access if user has enabled the save-to-gallery setting
    if (PreferenceService().saveToGallery) {
      Gal.requestAccess();
    }

    _controller.onNotification = (context, message, type) {
      if (mounted) {
        NotificationHelper.showTop(context, message: message, type: type);
      }
    };

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

    setState(() {
      _showRevealOverlay = true;
      _isCameraInitialized = true;
    });

    _revealController.forward().then((_) {
      _controller.startRide();

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _fadeController.forward().then((_) {
            if (mounted) {
              setState(() {
                _showRevealOverlay = false;
                _isTransitioning = false;
              });
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealController.dispose();
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _controller.saveRideDataOnExit();
    }
  }

  Future<void> _onStopRide() async {
    await _controller.stopRide();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    _controller.currentContext = context;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (!_controller.isRideStarted && !_showRevealOverlay) {
          return _buildPreRideState();
        }
        return _buildActiveRideState();
      },
    );
  }

  Widget _buildPreRideState() {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: DrivingGuideCard(),
                ),
                const Spacer(flex: 1),
                InteractiveSwipeButton(onStarted: _onSwipeToStart),
                const SizedBox(height: 40),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.background,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideState() {
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
      backgroundColor: AppColors.textPrimary,
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
                            height: size.width * (4.0 / 3.0),
                            child: CustomPaint(
                              foregroundPainter:
                                  _controller.showFaceMesh &&
                                  _controller.facePoints != null &&
                                      _controller.facePoints!.isNotEmpty
                                  ? NativeFaceMeshPainter(
                                      _controller.facePoints!,
                                      Size(
                                        _controller.imageWidth.toDouble(),
                                        _controller.imageHeight.toDouble(),
                                      ),
                                      _controller.imageRotation,
                                      _controller.microsleepController.isDrowsy,
                                    )
                                  : null,
                              child: AndroidView(
                                viewType: 'eyeon_native_camera',
                                creationParamsCodec:
                                    const StandardMessageCodec(),
                                onPlatformViewCreated: (id) async {
                                  _controller.initializeCameraEvents();
                                  await _controller.startNativeCamera();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
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
                      positionStream: _controller.positionStream,
                      initialPosition: _controller.initialPosition,
                      destination: widget.destination,
                    ),
                  ),

                ],
              ),
            ),
          ),

          // Top Bar
          if (_controller.isRideStarted && !_showRevealOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: MonitoringTopBar(
                  isDrowsy: _controller.microsleepController.isDrowsy,
                  isAccident: _controller.accidentController.isAccidentDetected,
                  currentSpeed: _controller.currentSpeed,
                  formattedDuration: _formatDuration(_controller.rideDuration),
                  totalDistance: _controller.totalDistance,
                  showFaceMesh: _controller.showFaceMesh,
                  onToggleFaceMesh: () {
                    if (_currentMode != ScreenMode.fullMap) {
                      _controller.toggleFaceMesh();
                    }
                  },
                  isFullScreen: _currentMode != ScreenMode.split,
                  onToggleFullScreen: () {
                    setState(() {
                      if (_currentMode == ScreenMode.split) {
                        _currentMode = ScreenMode.fullMap;
                      } else if (_currentMode == ScreenMode.fullMap) {
                        _currentMode = ScreenMode.fullCamera;
                      } else {
                        _currentMode = ScreenMode.split;
                      }
                      _controller.updateNativeFacePointsState(
                          _currentMode != ScreenMode.fullMap && _controller.showFaceMesh);
                    });
                  },
                ),
              ),
            ),

          // Bottom Bar
          Positioned(
            bottom: 120 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: MonitoringBottomBar(
              currentSpeed: _controller.currentSpeed,
              currentEAR: _controller.microsleepController.currentEAR,
              currentGForce: _controller.accidentController.currentMagnitude,
              isAccident: _controller.accidentController.isAccidentDetected,
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
                child: MonitoringStopButton(),
              ),
            ),
          ),

          // Alert overlay
          _buildAlertOverlay(),

          // No-face warning overlay
          if (_controller.noFaceWarning &&
              _controller.isRideStarted &&
              !_showRevealOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 24,
              right: 24,
              child: const NoFaceWarningOverlay(),
            ),


          // Circular Reveal Overlay
          if (_showRevealOverlay) _buildCircularRevealOverlay(),
        ],
      ),
    );
  }

  Widget _buildAlertOverlay() {
    if (_controller.accidentController.isAccidentDetected) {
      return AlertOverlay(
        currentMagnitude: _controller.accidentController.currentMagnitude,
        countdown: _controller.isEmergencySOSPending ? _controller.emergencyCountdown : 0,
        onResetAccident: () => _controller.cancelEmergencySOS(),
        onCallEmergency: () => SOSService().showEmergencyContactSheet(context),
      );
    }

    if (_controller.microsleepController.isPaused) {
      int count = _controller.microsleepController.drowsyCount;
      if (count == 1) {
        return Level1Overlay(
          onResume: () => _controller.microsleepController.resumeMonitoring(),
        );
      }
      if (count == 2) {
        return Level2Overlay(
          onResume: () => _controller.microsleepController.resumeMonitoring(),
        );
      }
      if (count >= 3) {
        bool canUnlock =
            _controller.currentSpeed < DetectionConfig.level3UnlockSpeedKmH;
        return Level3Overlay(
          canUnlock: canUnlock,
          onResume: () {
            _controller.microsleepController.resetDrowsyCount();
            _controller.microsleepController.resumeMonitoring();
          },
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildCircularRevealOverlay() {
    final size = MediaQuery.of(context).size;
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);

    return AnimatedBuilder(
      animation: _revealAnimation,
      builder: (context, child) {
        final currentRadius = _revealAnimation.value * maxRadius;
        final fadeValue =
            _fadeController.isAnimating || _fadeController.isCompleted
            ? (1.0 - _fadeAnimation.value)
            : 1.0;

        return IgnorePointer(
          child: Opacity(
            opacity: fadeValue,
            child: ClipPath(
              clipper: CircularRevealClipper(
                center: Offset(size.width / 2, size.height - 140),
                radius: currentRadius,
              ),
              child: Container(color: AppColors.primary),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}