import 'package:eyeon/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:eyeon/features/calibration/logic/calibration_controller.dart';
import 'package:eyeon/features/calibration/widgets/calibration_widgets.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  final CalibrationController _controller = CalibrationController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      return Column(
                        children: [
                          CalibrationTopBar(),
                          const Spacer(),
                          CalibrationViewfinder(
                            controller: _controller,
                            pulseAnimation: _pulseAnimation,
                          ),
                          const SizedBox(height: 32),
                          CalibrationStatusBadge(controller: _controller),
                          const SizedBox(height: 24),
                          CalibrationTitleSection(controller: _controller),
                          const Spacer(),
                          CalibrationActionButton(controller: _controller),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}