import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/constants/app_data.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/widgets/video_player_dialog.dart';

class CategoryFilter extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final List<String> categories = AppData.historyCategories;

  const CategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => onCategorySelected(cat),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.grey.shade50,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
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
}

class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
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
  final Future<List<Map<String, dynamic>>?> Function(String) loadIncidents;

  const HistoryCard({
    super.key,
    required this.log,
    required this.loadIncidents,
  });

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  bool _isExpanded = false;
  List<Map<String, dynamic>>? _incidents;
  bool _isLoadingIncidents = false;
  String? _incidentVideoUrl; // video dari incident_logs

  Future<void> _handleLoadIncidents() async {
    final rideId = widget.log['id']?.toString();
    if (rideId == null || _incidents != null) return;

    setState(() => _isLoadingIncidents = true);
    try {
      final incidents = await widget.loadIncidents(rideId);
      if (mounted) {
        // Ambil video_url dari incident pertama yang ada videonya
        final videoIncident = incidents?.firstWhere(
          (i) => i['video_url'] != null && i['video_url'].toString().isNotEmpty,
          orElse: () => {},
        );
        setState(() {
          _incidents = incidents;
          _isLoadingIncidents = false;
          _incidentVideoUrl = videoIncident?['video_url']?.toString();
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: Offset(0, 4),
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
                        color: AppColors.textPrimary.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
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

                // Incident drill-down
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
                                    color: AppColors.textPrimary.withValues(alpha: 0.45),
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
                            child: Icon(Icons.map_rounded,
                                size: 18, color: AppColors.textPrimary.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                if (isAccident) ...[
                  SizedBox(height: 24),
                  Text(
                    'Bukti Insiden',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Thumbnail video — klik untuk putar
                  GestureDetector(
                    onTap: _incidentVideoUrl != null
                        ? () => _playVideo(context, _incidentVideoUrl!)
                        : null,
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _incidentVideoUrl != null
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  _VideoThumbnail(videoUrl: _incidentVideoUrl!),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.textPrimary.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.background.withValues(alpha: 0.24),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: AppColors.background,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.videocam_off_rounded,
                                      color: AppColors.background.withValues(alpha: 0.3),
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _isLoadingIncidents
                                          ? 'Memuat video…'
                                          : 'Video Tidak Tersedia',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.background.withValues(alpha: 0.30),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Putar Video',
                          enabled: _incidentVideoUrl != null,
                          onTap: _incidentVideoUrl != null
                              ? () => _playVideo(context, _incidentVideoUrl!)
                              : () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.map_rounded,
                          label: 'Peta',
                          enabled: true,
                          onTap: () {
                            final incident = _incidents?.firstOrNull;
                            _openMap(
                              incident?['latitude'] ?? log['latitude'] ?? 0.0,
                              incident?['longitude'] ?? log['longitude'] ?? 0.0,
                            );
                          },
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
                if (_isExpanded) _handleLoadIncidents();
              },
              style: TextButton.styleFrom(
                backgroundColor: _isExpanded
                    ? AppColors.textPrimary
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
                  color: _isExpanded ? AppColors.background : AppColors.textPrimary,
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
        Icon(icon, size: 14, color: AppColors.textPrimary.withValues(alpha: 0.45)),
        SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
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
          Icon(icon, size: 16, color: AppColors.textPrimary.withValues(alpha: 0.45)),
          SizedBox(width: 8),
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
                    color: AppColors.textPrimary.withValues(alpha: 0.45),
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
    bool enabled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? AppColors.textPrimary : Colors.grey.shade300,
        foregroundColor: enabled ? AppColors.background : AppColors.textPrimary.withValues(alpha: 0.38),
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: AppColors.textPrimary.withValues(alpha: 0.38),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _playVideo(BuildContext context, String url) {
    VideoPlayerDialog.show(context, url);
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = AppUrls.googleMapsQueryUrl(lat, lng);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}

/// Widget thumbnail video: inisialisasi player, ambil frame pertama,
/// lalu dispose — tidak auto-play, hanya preview static.
class _VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const _VideoThumbnail({required this.videoUrl});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await ctrl.initialize();
      // Seek ke frame pertama dan pause langsung
      await ctrl.seekTo(Duration.zero);
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _ready = true;
        });
      } else {
        await ctrl.dispose();
      }
    } catch (_) {
      // Gagal load thumbnail — tampilkan placeholder
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _controller == null) {
      return Container(
        color: AppColors.textPrimary,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.background.withValues(alpha: 0.30),
            ),
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
