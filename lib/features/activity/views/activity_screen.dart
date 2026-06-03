import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eyeon/core/services/supabase_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _selectedPeriod = 'Hari Ini';
  final List<String> _periods = ['Hari Ini', 'Minggu Ini', 'Bulan Ini'];

  List<Map<String, dynamic>> _allLogs = [];
  bool _isLoading = true;

  // Processed Data
  double _totalDurationHours = 0.0;
  double _totalDistance = 0.0;
  int _totalMicrosleep = 0;
  int _totalIncidents = 0;
  List<FlSpot> _chartSpots = [];

  @override
  void initState() {
    super.initState();
    _fetchAndProcessData();
  }

  Future<void> _fetchAndProcessData() async {
    setState(() => _isLoading = true);
    final logs = await SupabaseService().getRideHistory();
    _allLogs = logs;
    _processData();
    if (mounted) setState(() => _isLoading = false);
  }

  void _processData() {
    final now = DateTime.now();
    List<Map<String, dynamic>> filteredLogs = [];

    if (_selectedPeriod == 'Hari Ini') {
      filteredLogs = _allLogs.where((log) {
        final date = DateTime.parse(log['start_time']);
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }).toList();
    } else if (_selectedPeriod == 'Minggu Ini') {
      final weekAgo = now.subtract(const Duration(days: 7));
      filteredLogs = _allLogs.where((log) {
        final date = DateTime.parse(log['start_time']);
        return date.isAfter(weekAgo);
      }).toList();
    } else {
      final monthAgo = now.subtract(const Duration(days: 30));
      filteredLogs = _allLogs.where((log) {
        final date = DateTime.parse(log['start_time']);
        return date.isAfter(monthAgo);
      }).toList();
    }

    // Aggregate Metrics
    double durationSecs = 0;
    double dist = 0;
    int microsleep = 0;
    int incidents = 0;
    Map<int, int> hourlyMicrosleep = {};

    for (var log in filteredLogs) {
      final start = DateTime.parse(log['start_time']);
      final end = DateTime.parse(log['end_time']);
      durationSecs += end.difference(start).inSeconds;

      dist += (log['distance'] ?? 0.0);
      microsleep += (log['microsleep_alerts'] ?? 0) as int;
      incidents += (log['accident_alerts'] ?? 0) as int;

      // For chart: map to hour
      int hour = start.hour;
      hourlyMicrosleep[hour] =
          (hourlyMicrosleep[hour] ?? 0) + (log['microsleep_alerts'] as int);
    }

    _totalDurationHours = durationSecs / 3600.0;
    _totalDistance = dist;
    _totalMicrosleep = microsleep;
    _totalIncidents = incidents;

    // Build Chart Spots (0-23 hours)
    _chartSpots = [];
    for (int i = 0; i < 24; i++) {
      _chartSpots.add(
        FlSpot(i.toDouble(), (hourlyMicrosleep[i] ?? 0).toDouble()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Statistik Berkendara',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD7F454)),
            )
          : RefreshIndicator(
              onRefresh: _fetchAndProcessData,
              color: const Color(0xFFD7F454),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildCustomPillFilter(),
                    const SizedBox(height: 24),
                    _buildCompactHighlightGrid(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'Trend Kerawanan Microsleep',
                      'Data riwayat jam berkendara',
                    ),
                    const SizedBox(height: 16),
                    _buildSmoothTrendChart(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'Pencapaian Rider',
                      'Progress keamanan ${_selectedPeriod.toLowerCase()}',
                    ),
                    const SizedBox(height: 16),
                    _buildModernAchievementCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.black38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomPillFilter() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                  _processData();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
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
                    color: isSelected ? Colors.black : Colors.black38,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompactHighlightGrid() {
    String durationText = '';
    if (_totalDurationHours < 1) {
      durationText = '${(_totalDurationHours * 60).toInt()}m';
    } else {
      durationText =
          '${_totalDurationHours.floor()}j ${((_totalDurationHours - _totalDurationHours.floor()) * 60).toInt()}m';
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Durasi',
                durationText,
                Icons.timer_rounded,
                const Color(0xFFD7F454),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Jarak',
                '${_totalDistance.toStringAsFixed(1)} km',
                Icons.route_rounded,
                const Color(0xFFE3F2FD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Microsleep',
                '$_totalMicrosleep Alert',
                Icons.visibility_rounded,
                const Color(0xFFFFF3E0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Insiden',
                '$_totalIncidents Event',
                Icons.warning_amber_rounded,
                const Color(0xFFFFEBEE),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.black54,
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

  Widget _buildSmoothTrendChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 24, right: 24, left: 0, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
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
                  const style = TextStyle(
                    color: Colors.black38,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  );
                  int hour = value.toInt();
                  if (hour % 6 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: style,
                      ),
                    );
                  }
                  return const SizedBox();
                },
                interval: 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _chartSpots.isEmpty ? [const FlSpot(0, 0)] : _chartSpots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [Color(0xFFD7F454), Color(0xFF81C784)],
              ),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD7F454).withValues(alpha: 0.2),
                    const Color(0xFFD7F454).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minX: 0,
          maxX: 23,
          minY: 0,
        ),
      ),
    );
  }

  Widget _buildModernAchievementCard() {
    double progress = 1.0;
    if (_totalMicrosleep > 0) {
      progress = (10 - _totalMicrosleep).clamp(0, 10) / 10.0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFFD7F454),
                  strokeCap: StrokeCap.round,
                ),
              ),
              const Icon(Icons.stars_rounded, color: Colors.black, size: 28),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safe Rider Badge',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Text(
                  _totalMicrosleep == 0
                      ? 'Sangat bagus! Tidak ada microsleep terdeteksi.'
                      : 'Waspada! Terdeteksi $_totalMicrosleep microsleep. Tingkatkan waktu istirahat.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showMicrosleepInfo(context),
                  child: Row(
                    children: [
                      Text(
                        'Selengkapnya',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMicrosleepInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
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
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Informasi penting untuk keselamatan berkendara Anda.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.black54,
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
                  backgroundColor: const Color(0xFFD7F454),
                  foregroundColor: Colors.black,
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
      ),
    );
  }

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
            child: Icon(icon, color: Colors.black87, size: 24),
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
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.black54,
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
}
