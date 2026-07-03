import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:eyeon/features/ride_setup/logic/ride_setup_controller.dart';
import 'package:eyeon/features/ride_setup/widgets/ride_setup_widgets.dart';

class RideSetupScreen extends StatefulWidget {
  const RideSetupScreen({super.key});

  @override
  State<RideSetupScreen> createState() => _RideSetupScreenState();
}

class _RideSetupScreenState extends State<RideSetupScreen> {
  final RideSetupController _controller = RideSetupController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _controller.fetchCurrentLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Map Background ──
              Positioned.fill(
                child: RideSetupMap(
                  controller: _controller,
                  mapController: _mapController,
                ),
              ),

              // ── Back Button ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: const RideSetupBackButton(),
              ),

              // ── Bottom Sheet ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RideSetupBottomSheet(
                  controller: _controller,
                  bottomPadding: bottomPadding,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
