import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_data.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.textPrimary.withValues(alpha: 0.38),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class CustomPillFilter extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodSelected;
  final List<String> periods = AppData.activityPeriods;

  const CustomPillFilter({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => onPeriodSelected(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  period,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.textPrimary.withValues(alpha: 0.87)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompactHighlightGrid extends StatelessWidget {
  final double totalDurationHours;
  final double totalDistance;
  final int totalMicrosleep;
  final int totalIncidents;

  const CompactHighlightGrid({
    super.key,
    required this.totalDurationHours,
    required this.totalDistance,
    required this.totalMicrosleep,
    required this.totalIncidents,
  });

  @override
  Widget build(BuildContext context) {
    String durationText = '';
    if (totalDurationHours < 1) {
      durationText = '${(totalDurationHours * 60).toInt()}m';
    } else {
      durationText = '${totalDurationHours.floor()}j ${((totalDurationHours - totalDurationHours.floor()) * 60).toInt()}m';
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Durasi',
                value: durationText,
                icon: Icons.timer_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Jarak',
                value: '${totalDistance.toStringAsFixed(1)} km',
                icon: Icons.route_rounded,
                color: const Color(0xFFE3F2FD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Microsleep',
                value: '$totalMicrosleep Alert',
                icon: Icons.visibility_rounded,
                color: const Color(0xFFFFF3E0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Insiden',
                value: '$totalIncidents Event',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFFEBEE),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SmoothTrendChart extends StatelessWidget {
  final List<FlSpot> chartSpots;

  const SmoothTrendChart({super.key, required this.chartSpots});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 24, right: 24, left: 0, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  return LineTooltipItem(
                    '${touchedSpot.y.toStringAsFixed(0)} mnt',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final style = TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.38),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  );
                  int day = value.toInt();
                  String text = '';
                  switch (day) {
                    case 1: text = 'Sen'; break;
                    case 2: text = 'Sel'; break;
                    case 3: text = 'Rab'; break;
                    case 4: text = 'Kam'; break;
                    case 5: text = 'Jum'; break;
                    case 6: text = 'Sab'; break;
                    case 7: text = 'Min'; break;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(text, style: style),
                  );
                },
                interval: 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: chartSpots.isEmpty ? [FlSpot(0, 0)] : chartSpots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF81C784)],
              ),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minX: 1,
          maxX: 7,
          minY: 0,
        ),
      ),
    );
  }
}


class MicrosleepInfoSheet extends StatelessWidget {
  const MicrosleepInfoSheet({super.key});

  Widget _buildInfoItem(IconData icon, String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.textPrimary.withValues(alpha: 0.87), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Tentang Microsleep',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Informasi penting untuk keselamatan berkendara Anda.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildInfoItem(
                    Icons.visibility_off_rounded,
                    'Apa itu Microsleep?',
                    'Kejadian tertidur singkat (biasanya 1-10 detik) yang terjadi tanpa disadari. Ini sangat berbahaya saat mengemudi.',
                    const Color(0xFFFFF3E0),
                  ),
                  _buildInfoItem(
                    Icons.warning_amber_rounded,
                    'Kenapa Berbahaya?',
                    'Dalam 5 detik pada kecepatan 100 km/jam, kendaraan Anda menempuh jarak sejauh lapangan sepak bola tanpa kendali.',
                    const Color(0xFFFFEBEE),
                  ),
                  _buildInfoItem(
                    Icons.lightbulb_outline_rounded,
                    'Cara Pencegahan',
                    'Pastikan tidur cukup (7-9 jam), istirahat setiap 2 jam berkendara, atau konsumsi kafein jika diperlukan.',
                    const Color(0xFFE3F2FD),
                  ),
                  _buildInfoItem(
                    Icons.remove_red_eye_rounded,
                    'Peran EYE-ON!',
                    'Kami memantau pola kedipan mata (EAR) secara real-time untuk mendeteksi kelelahan sebelum menjadi fatal.',
                    const Color(0xFFF1F8E9),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Saya Mengerti',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}