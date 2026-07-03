import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/widgets/video_player_dialog.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eyeon/core/constants/app_data.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:eyeon/core/utils/mock_data.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedCategory = 'Semua';
  final List<String> _categories = AppData.historyCategories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Riwayat Perjalanan',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          const EyeOnHeader(),
          _buildCategoryFilter(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService().streamRideHistory(),
              builder: (context, snapshot) {
                final bool isLoading = !snapshot.hasData;
                final logs = isLoading ? MockData.fakeRideLogs : snapshot.data!;
                
                final filteredLogs = isLoading 
                    ? logs
                    : logs.where((log) {
                  if (_selectedCategory == 'Semua') return true;
                  if (_selectedCategory == 'Microsleep') {
                    return (log['microsleep_alerts'] ?? 0) > 0;
                  }
                  if (_selectedCategory == 'Kecelakaan') {
                    return (log['accident_alerts'] ?? 0) > 0;
                  }
                  return true;
                }).toList();

                if (!isLoading && filteredLogs.isEmpty) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      alignment: Alignment.center,
                      child: _buildEmptyState(),
                    ),
                  );
                }

                return Skeletonizer(
                  enabled: isLoading,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      return HistoryCard(log: filteredLogs[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.grey.shade50,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.black54,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey.shade200,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade200),
        const SizedBox(height: 16),
        Text(
          'Belum ada riwayat',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}

class HistoryCard extends StatefulWidget {
  final Map<String, dynamic> log;
  const HistoryCard({super.key, required this.log});

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  bool _isExpanded = false;
  List<Map<String, dynamic>>? _incidents;
  bool _isLoadingIncidents = false;

  /// Load incidents linked to this ride (Task 8).
  Future<void> _loadIncidents() async {
    final rideId = widget.log['id']?.toString();
    if (rideId == null || _incidents != null) return;

    setState(() => _isLoadingIncidents = true);
    try {
      final incidents = await SupabaseService().getIncidentsForRide(rideId);
      if (mounted) {
        setState(() {
          _incidents = incidents;
          _isLoadingIncidents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingIncidents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final bool isAccident = (log['accident_alerts'] ?? 0) > 0;
    final bool isMicrosleep = (log['microsleep_alerts'] ?? 0) > 0;
    final startTime = DateTime.parse(log['start_time'].toString());

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAccident
                      ? Colors.red.shade50
                      : isMicrosleep
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAccident
                      ? Icons.warning_rounded
                      : isMicrosleep
                          ? Icons.visibility_rounded
                          : Icons.check_circle_rounded,
                  color: isAccident
                      ? Colors.red
                      : isMicrosleep
                          ? Colors.orange
                          : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAccident
                          ? 'Kecelakaan Terdeteksi'
                          : isMicrosleep
                              ? 'Peringatan Microsleep'
                              : 'Sesi Berkendara Aman',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(startTime)} • ${DateFormat('HH:mm').format(startTime)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactStat(
                Icons.timer_outlined,
                _formatDuration(log['start_time'], log['end_time']),
              ),
              _buildCompactStat(
                Icons.route_outlined,
                '${(log['distance'] ?? 0.0).toStringAsFixed(1)} km',
              ),
              _buildCompactStat(
                Icons.visibility_outlined,
                '${log['microsleep_alerts'] ?? 0} Alert',
              ),
            ],
          ),

          // Expandable Section
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildDetailGrid(log),

                // Incident drill-down (Task 8)
                if (_isLoadingIncidents)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                else if (_incidents != null && _incidents!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Insiden dalam Perjalanan Ini',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_incidents!.length, (i) {
                    final incident = _incidents![i];
                    final time = DateTime.tryParse(
                        incident['timestamp']?.toString() ?? '');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  time != null
                                      ? DateFormat('HH:mm:ss').format(time)
                                      : 'N/A',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'G-Force: ${(incident['magnitude'] ?? 0.0).toStringAsFixed(1)} rad/s',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _openMap(
                              incident['latitude'] ?? 0.0,
                              incident['longitude'] ?? 0.0,
                            ),
                            child: const Icon(Icons.map_rounded,
                                size: 18, color: Colors.black45),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                if (isAccident) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Bukti Insiden',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: log['video_url'] != null
                        ? () => _playVideo(context, log['video_url'])
                        : null,
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: log['video_url'] != null
                          ? const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.videocam_off_rounded,
                                    color: Colors.white24,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Video Tidak Tersedia',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white24,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Video',
                          onTap: log['video_url'] != null
                              ? () => _playVideo(context, log['video_url'])
                              : () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.map_rounded,
                          label: 'Peta',
                          onTap: () => _openMap(
                            log['latitude'] ?? 0.0,
                            log['longitude'] ?? 0.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                setState(() => _isExpanded = !_isExpanded);
                if (_isExpanded) _loadIncidents();
              },
              style: TextButton.styleFrom(
                backgroundColor: _isExpanded
                    ? Colors.black
                    : Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isExpanded ? 'Tutup' : 'Selengkapnya',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isExpanded ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic start, dynamic end) {
    if (start == null || end == null) return '0s';
    try {
      final startTime = DateTime.parse(start.toString());
      final endTime = DateTime.parse(end.toString());
      final diff = endTime.difference(startTime);
      if (diff.inHours > 0) return '${diff.inHours}j ${diff.inMinutes % 60}m';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
      return '${diff.inSeconds}s';
    } catch (e) {
      return '0s';
    }
  }

  Widget _buildCompactStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGrid(Map<String, dynamic> log) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildDetailItem(
          'Durasi',
          _formatDuration(log['start_time'], log['end_time']),
          Icons.timer_rounded,
        ),
        _buildDetailItem(
          'Jarak',
          '${(log['distance'] ?? 0.0).toStringAsFixed(1)} km',
          Icons.route_rounded,
        ),
        _buildDetailItem(
          'Microsleep',
          '${log['microsleep_alerts'] ?? 0} Alert',
          Icons.visibility_rounded,
        ),
        _buildDetailItem(
          'Insiden',
          '${log['accident_alerts'] ?? 0} Event',
          Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Play video in-app using VideoPlayerDialog (Task 12)
  void _playVideo(BuildContext context, String url) {
    VideoPlayerDialog.show(context, url);
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
