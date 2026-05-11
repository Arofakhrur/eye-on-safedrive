import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/utils/camera_utils.dart';
import 'package:eyeon/features/monitoring/logic/microsleep_controller.dart';
import 'package:eyeon/features/monitoring/logic/accident_controller.dart';
import 'package:eyeon/features/monitoring/views/face_mesh_painter.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _accidentController.startMonitoring();
    _microsleepController.addListener(_onUpdate);
    _accidentController.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    int cameraIndex = -1;

    // Find front camera
    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == CameraLensDirection.front) {
        cameraIndex = i;
        break;
      }
    }

    // fallback to first camera if no front camera found
    if (cameraIndex == -1 && cameras.isNotEmpty) {
      cameraIndex = 0;
    }

    if (cameraIndex != -1) {
      _cameraController = CameraController(
        cameras[cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      _cameraController!.startImageStream((CameraImage image) {
        final inputImage = CameraUtils.inputImageFromCameraImage(
          image,
          _cameraController,
        );
        if (inputImage != null) {
          _microsleepController.processImage(inputImage);
        }
      });

      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _accidentController.dispose();
    _microsleepController.dispose();
    super.dispose();
  }

  void _onStopRide() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            CameraPreview(_cameraController!, child: _buildFaceMeshOverlay())
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFD7F454)),
            ),

          // 2. Overlay Stats (Glassmorphism)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildStatsOverlay(),
          ),

          // 3. Stop Ride Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onStopRide,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
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
                      const Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'STOP RIDE',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Alert Warning Flashes
          if (_microsleepController.isDrowsy || _accidentController.isAccidentDetected)
            IgnorePointer(
              child: Container(color: Colors.red.withValues(alpha: 0.3)),
            ),
        ],
      ),
    );
  }

  Widget _buildFaceMeshOverlay() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox();
    }

    final size = MediaQuery.of(context).size;
    var rotation = InputImageRotation.rotation0deg;

    // We assume CameraUtils maps device orientation correctly
    if (Platform.isAndroid) {
      rotation =
          InputImageRotationValue.fromRawValue(
            _cameraController!.description.sensorOrientation,
          ) ??
          InputImageRotation.rotation270deg;
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

  Widget _buildStatsOverlay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATUS',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Icon(
                    _microsleepController.isDrowsy ||
                            _accidentController.isAccidentDetected
                        ? Icons.warning_rounded
                        : Icons.check_circle_rounded,
                    color:
                        _microsleepController.isDrowsy ||
                            _accidentController.isAccidentDetected
                        ? Colors.redAccent
                        : const Color(0xFFD7F454),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _accidentController.isAccidentDetected
                    ? 'SOS TRIGGERED'
                    : _microsleepController.isDrowsy
                    ? 'WAKE UP!'
                    : 'MONITORING ACTIVE',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    label: 'EYE RATIO',
                    value: _microsleepController.currentEAR.toStringAsFixed(2),
                    isDanger: _microsleepController.currentEAR < 0.25,
                  ),
                  _buildStatItem(
                    label: 'G-FORCE',
                    value: _accidentController.currentMagnitude.toStringAsFixed(
                      1,
                    ),
                    isDanger: _accidentController.isAccidentDetected,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required bool isDanger,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: isDanger ? Colors.redAccent : const Color(0xFFD7F454),
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
