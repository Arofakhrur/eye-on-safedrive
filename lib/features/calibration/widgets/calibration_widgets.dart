import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/features/calibration/logic/calibration_controller.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

class CalibrationTopBar extends StatelessWidget {
  const CalibrationTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/EYE-ON!_Logo.webp',
              height: 28, width: 28),
          const SizedBox(width: 8),
          Text(
            'EYE-ON!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class CalibrationViewfinder extends StatelessWidget {
  final CalibrationController controller;
  final Animation<double> pulseAnimation;

  const CalibrationViewfinder({
    super.key,
    required this.controller,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        final scale = controller.isCalibrating ? pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: controller.isCalibrationDone
                        ? AppColors.primary
                        : Colors.grey.shade200,
                    width: 3,
                  ),
                ),
              ),
              ClipOval(
                child: SizedBox(
                  width: 270,
                  height: 270,
                  child: controller.isCameraReady && controller.cameraController != null
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.cameraController!.value.previewSize?.height ?? 480,
                            height: controller.cameraController!.value.previewSize?.width ?? 640,
                            child: CameraPreview(controller.cameraController!),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 100,
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                ),
              ),
              SizedBox(
                width: 290,
                height: 290,
                child: CircularProgressIndicator(
                  value: controller.isCalibrating
                      ? controller.progress
                      : (controller.isCalibrationDone ? 1.0 : 0.0),
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  backgroundColor: Colors.transparent,
                ),
              ),
              if (controller.isCalibrating)
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(controller.progress * 100).toInt()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (controller.currentEAR > 0)
                          Text(
                            'EAR: ${controller.currentEAR.toStringAsFixed(3)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (controller.isCalibrationDone)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.black, size: 32),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CalibrationStatusBadge extends StatelessWidget {
  final CalibrationController controller;

  const CalibrationStatusBadge({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(controller.statusText),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: controller.isCalibrationDone
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.isCalibrating)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.black.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            Text(
              controller.statusText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: controller.isCalibrationDone ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalibrationTitleSection extends StatelessWidget {
  final CalibrationController controller;

  const CalibrationTitleSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            'Kalibrasi Wajah',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Posisikan wajah Anda di dalam lingkaran dan tatap lurus ke '
            'depan. Hal ini membantu EYE-ON! mempelajari pola dasar mata '
            'Anda untuk deteksi kantuk yang akurat.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          if (controller.isCalibrationDone)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Personal threshold set',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Baseline EAR: ${(controller.earSamples.isNotEmpty ? controller.earSamples.reduce((a, b) => a + b) / controller.earSamples.length : 0.0).toStringAsFixed(3)}  •  '
                      'Threshold: ${controller.calibratedThreshold.toStringAsFixed(3)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.black54,
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
}

class CalibrationActionButton extends StatelessWidget {
  final CalibrationController controller;

  const CalibrationActionButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          if (controller.isCalibrationDone) {
            PreferenceService().setCalibrated(true);
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          } else if (!controller.isCalibrating) {
            if (!controller.isCameraReady) {
              NotificationHelper.showTop(
                context,
                message: 'Camera is not ready yet',
                type: NotificationType.warning,
              );
            } else {
              controller.startCalibration();
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: controller.isCalibrating
                ? Colors.grey.shade300
                : AppColors.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              if (!controller.isCalibrating)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                controller.isCalibrating
                    ? 'Calibrating…'
                    : (controller.isCalibrationDone
                        ? 'Selesai Kalibrasi'
                        : 'Mulai Kalibrasi'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: controller.isCalibrating ? Colors.black38 : Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                controller.isCalibrationDone
                    ? Icons.check_circle_outline_rounded
                    : (controller.isCalibrating
                        ? Icons.hourglass_top_rounded
                        : Icons.play_circle_outline_rounded),
                color: controller.isCalibrating ? Colors.black38 : Colors.black,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
