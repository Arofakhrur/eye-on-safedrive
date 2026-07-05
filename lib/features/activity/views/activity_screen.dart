import 'package:eyeon/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:eyeon/core/utils/mock_data.dart';

import 'package:eyeon/features/activity/logic/activity_controller.dart';
import 'package:eyeon/features/activity/widgets/activity_widgets.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivityController _controller = ActivityController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMicrosleepInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const MicrosleepInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _controller.getRideHistoryStream(),
        builder: (context, snapshot) {
          final bool isLoading = !snapshot.hasData;
          final logs = isLoading ? MockData.fakeRideLogs : snapshot.data!;

          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              _controller.processData(logs);

              return Skeletonizer(
                enabled: isLoading,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      EyeOnHeader(),
                      const SizedBox(height: 16),
                      Text(
                        'Statistik Berkendara',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomPillFilter(
                        selectedPeriod: _controller.selectedPeriod,
                        onPeriodSelected: _controller.setSelectedPeriod,
                      ),
                      const SizedBox(height: 24),
                      CompactHighlightGrid(
                        totalDurationHours: _controller.totalDurationHours,
                        totalDistance: _controller.totalDistance,
                        totalMicrosleep: _controller.totalMicrosleep,
                        totalIncidents: _controller.totalIncidents,
                      ),
                      const SizedBox(height: 32),
                      SectionHeader(
                        title: 'Waktu Berkendara',
                        subtitle: 'Total jam berkendara minggu ini',
                      ),
                      const SizedBox(height: 16),
                      SmoothTrendChart(chartSpots: _controller.chartSpots),
                      const SizedBox(height: 32),
                      SectionHeader(
                        title: 'Pencapaian Rider',
                        subtitle: 'Progress keamanan ${_controller.selectedPeriod.toLowerCase()}',
                      ),
                      const SizedBox(height: 16),
                      ModernAchievementCard(
                        totalMicrosleep: _controller.totalMicrosleep,
                        onInfoTap: () => _showMicrosleepInfo(context),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}