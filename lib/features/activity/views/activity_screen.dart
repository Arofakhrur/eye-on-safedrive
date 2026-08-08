import 'package:eyeon/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:eyeon/core/utils/mock_data.dart';

import 'package:eyeon/features/activity/logic/activity_controller.dart';
import 'package:eyeon/features/activity/widgets/activity_widgets.dart';
import 'package:eyeon/research/realtime_logger/services/research_export_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivityController _controller = ActivityController();
  bool _isExporting = false;

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
                      const SizedBox(height: 16),
                      EyeOnHeader(),
                      const SizedBox(height: 8),
                      Text(
                        'Statistik Berkendara',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                        subtitle: 'Total menit berkendara minggu ini',
                      ),
                      const SizedBox(height: 16),
                      SmoothTrendChart(chartSpots: _controller.chartSpots),
                      const SizedBox(height: 32),
                      SectionHeader(
                        title: 'Pusat Edukasi',
                        subtitle: 'Pelajari lebih lanjut tentang keselamatan',
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _showMicrosleepInfo(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.info_outline_rounded, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Apa itu Microsleep?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kenali bahaya tertidur singkat saat berkendara.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildDownloadSection(logs),
                      const SizedBox(height: 32),
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

  /// Bagian download laporan penelitian untuk semua sesi dalam periode yang dipilih.
  Widget _buildDownloadSection(List<Map<String, dynamic>> rideLogs) {
    if (rideLogs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.download_rounded, size: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unduh Laporan Perjalanan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Laporan format CSV untuk ${_controller.selectedPeriod.toLowerCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isExporting ? null : () => _exportPeriodCsv(rideLogs),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isExporting)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  else
                    const Icon(Icons.download_rounded, size: 14, color: Colors.black),
                  const SizedBox(width: 6),
                  Text(
                    'Unduh',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
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

  Future<void> _exportPeriodCsv(List<Map<String, dynamic>> rideLogs) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await ResearchExportService().exportCsvForPeriod(
        rideLogs: rideLogs,
        periodLabel: _controller.selectedPeriod,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}