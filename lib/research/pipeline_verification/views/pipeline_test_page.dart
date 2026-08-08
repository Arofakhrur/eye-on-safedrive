import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/research/pipeline_verification/models/pipeline_result_model.dart';
import 'package:eyeon/research/pipeline_verification/services/pipeline_test_service.dart';

const _kPrefDddPath = 'pipeline_last_ddd_path';

/// Pipeline Verification Page — Research tool for verifying the EAR detection
/// pipeline against the DDD (Driver Drowsiness Dataset).
///
/// This page is intentionally isolated under `lib/research/` and is only
/// accessible via Profile → OPSI DEVELOPER → Pipeline Verification.
/// It has zero impact on any production EYE-ON features.
class PipelineTestPage extends StatefulWidget {
  const PipelineTestPage({super.key});

  @override
  State<PipelineTestPage> createState() => _PipelineTestPageState();
}

class _PipelineTestPageState extends State<PipelineTestPage>
    with SingleTickerProviderStateMixin {
  final PipelineTestService _service = PipelineTestService();

  String? _selectedFolderPath;
  bool _isProcessing = false;
  bool _isDone = false;
  String? _exportError;

  // Progress state (updated from stream)
  int _total = 0;
  int _processed = 0;
  int _successful = 0;
  int _failedFace = 0;
  int _failedLandmark = 0;
  String? _currentFile;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Do NOT repeat pulse on init — only start when verification is running
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _service.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _total = progress.total;
        _processed = progress.processed;
        _successful = progress.successful;
        _failedFace = progress.failedFace;
        _failedLandmark = progress.failedLandmark;
        _currentFile = progress.currentFile;
        if (progress.isDone && _isProcessing) {
          _isProcessing = false;
          _isDone = true;
          _pulseController.stop();
        }
      });
    });

    // Restore last-used folder path (no auto-run — user must click Mulai Verifikasi)
    _loadSavedPath();
  }

  /// Loads the last-used DDD folder path from SharedPreferences.
  /// If found and valid, restores the path so user can immediately start verification.
  /// Verification does NOT auto-start — user must press "Mulai Verifikasi".
  Future<void> _loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefDddPath);
    if (saved != null && Directory(saved).existsSync() && mounted) {
      setState(() {
        _selectedFolderPath = saved;
        _isDone = false;
        _processed = 0;
        _total = 0;
        _successful = 0;
        _failedFace = 0;
        _failedLandmark = 0;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Returns true if the app has permission to read images from storage.
  ///
  /// Uses [Permission.photos] which permission_handler maps to:
  ///   - READ_MEDIA_IMAGES on Android 13+ (API 33+)
  ///   - READ_EXTERNAL_STORAGE on Android ≤12
  ///
  /// These are the same permissions granted when user allows gallery access.
  /// No redirect to Settings needed — just a normal runtime dialog if not yet granted.
  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Check current status first — no need to re-request if already granted
    var status = await Permission.photos.status;
    debugPrint('📂 Permission.photos status: $status');

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      // User blocked the permission — must open settings
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Izin galeri diblokir. Buka Settings → Izin Aplikasi → aktifkan Foto/File.',
              style: GoogleFonts.plusJakartaSans(),
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    // Not yet requested — ask once via system dialog
    status = await Permission.photos.request();
    debugPrint('📂 Permission.photos after request: $status');
    return status.isGranted || status.isLimited;
  }

  Future<void> _pickFolder() async {
    // _ensureStoragePermission already shows feedback if denied
    final hasPermission = await _ensureStoragePermission();
    if (!hasPermission) return;

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih Folder Root: Driver Drowsiness Dataset (DDD)',
    );

    debugPrint('📂 Picked path: $result');

    if (result != null && mounted) {
      // Resolve real filesystem path — on Android content URIs are converted
      // but sometimes need to be mapped to /storage/emulated/0/
      String resolvedPath = result;
      if (result.startsWith('content://')) {
        // Extract path from content URI if not already resolved
        final uri = Uri.tryParse(result);
        final pathSegments = uri?.pathSegments ?? [];
        if (pathSegments.isNotEmpty) {
          final lastSegment = Uri.decodeComponent(pathSegments.last);
          resolvedPath = '/storage/emulated/0/$lastSegment';
        }
      }

      final dir = Directory(resolvedPath);
      final exists = await dir.exists();
      debugPrint('📂 Resolved path: $resolvedPath');
      debugPrint('📂 Directory exists: $exists');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefDddPath, resolvedPath);

      setState(() {
        _selectedFolderPath = resolvedPath;
        _isDone = false;
        _processed = 0;
        _total = 0;
        _successful = 0;
        _failedFace = 0;
        _failedLandmark = 0;
      });
      // Verifikasi TIDAK otomatis berjalan. User harus klik "Mulai Verifikasi"
    }
  }

  Future<void> _startVerification() async {
    if (_selectedFolderPath == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isDone = false;
      _exportError = null;
    });
    _pulseController.repeat(reverse: true);

    await _service.runVerification(_selectedFolderPath!);

    if (mounted && _service.errorMessage != null) {
      setState(() {
        _isProcessing = false;
        _isDone = false;
      });
      _showError(_service.errorMessage!);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exportError = null);
    try {
      await _service.exportCsv();
    } catch (e) {
      if (mounted) setState(() => _exportError = 'Export gagal: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResearchBadge(),
              const SizedBox(height: 20),
              _buildFolderCard(),
              const SizedBox(height: 16),
              _buildRunButton(),
              if (_isProcessing || _isDone || _processed > 0) ...[
                const SizedBox(height: 20),
                _buildProgressCard(),
              ],
              if (_isProcessing && _currentFile != null) ...[
                const SizedBox(height: 12),
                _buildCurrentFileIndicator(),
              ],
              if (_service.errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorCard(_service.errorMessage!),
              ],
              if (_isDone && _service.results.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildExportButton(),
                if (_exportError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _exportError!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildResultsPreview(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F1117),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pipeline Verification',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          Text(
            'EAR · ML Kit · DDD Dataset',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.biotech_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'RESEARCH MODE — Bukan bagian dari fitur produksi EYE-ON',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard() {
    final hasPath = _selectedFolderPath != null;
    return _ResearchCard(
      title: '1. Dataset DDD',
      icon: Icons.folder_open_rounded,
      child: hasPath
          // ── Compact: path sudah tersimpan / auto-loaded ──
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent.shade400, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFolderPath!.split('/').last.isEmpty
                            ? _selectedFolderPath!.split('\\').last
                            : _selectedFolderPath!.split('/').last,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _isProcessing ? null : _pickFolder,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: Text(
                        'Ganti',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedFolderPath!,
                  style: GoogleFonts.sourceCodePro(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          // ── Full picker: belum ada path tersimpan ──
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Struktur folder yang diharapkan:',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Driver Drowsiness Dataset (DDD)/\n'
                    '  Drowsy/          (28 orang)\n'
                    '    Person1/ ... Person28/\n'
                    '      image.png\n'
                    '  Non Drowsy/      (27 orang)\n'
                    '    Person1/ ... Person27/\n'
                    '      image.png',
                    style: GoogleFonts.sourceCodePro(
                      color: Colors.green.shade300,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickFolder,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: Text(
                      'Pilih Folder DDD (Tersimpan otomatis)',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '💡 Folder hanya perlu dipilih sekali — akan diingat otomatis.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white30,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRunButton() {
    final canRun = _selectedFolderPath != null && !_isProcessing;

    if (_isProcessing) {
      // ── Processing: show run (disabled) + cancel button side by side ──
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black38,
                ),
              ),
              label: Text(
                'Memproses... ($_processed / $_total)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white38,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _service.cancelVerification(),
              icon: const Icon(Icons.stop_rounded, size: 20),
              label: Text(
                'Batal',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      );
    }

    // ── Idle: single run button ──
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canRun ? _startVerification : null,
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          _isDone ? 'Jalankan Ulang' : 'Mulai Verifikasi',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canRun ? AppColors.primary : Colors.white12,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: Colors.white10,
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: canRun ? 4 : 0,
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = _total == 0 ? 0.0 : _processed / _total;
    return _ResearchCard(
      title: '2. Progress Verifikasi',
      icon: Icons.analytics_rounded,
      child: Column(
        children: [
          // Progress bar
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 8,
                width: (MediaQuery.of(context).size.width - 96) * progress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Colors.greenAccent.shade200],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_processed / $_total gambar',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              _StatChip(
                label: 'Total',
                value: '$_total',
                color: Colors.white60,
                icon: Icons.image_rounded,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Berhasil',
                value: '$_successful',
                color: Colors.greenAccent.shade400,
                icon: Icons.check_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatChip(
                label: 'Gagal Wajah',
                value: '$_failedFace',
                color: Colors.redAccent.shade200,
                icon: Icons.face_retouching_off_rounded,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Gagal Landmark',
                value: '$_failedLandmark',
                color: Colors.orangeAccent.shade200,
                icon: Icons.visibility_off_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentFileIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Memproses: $_currentFile',
              style: GoogleFonts.sourceCodePro(
                color: Colors.white38,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.redAccent.shade100,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return _ResearchCard(
      title: '3. Export Hasil',
      icon: Icons.ios_share_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Format: Subject, Label, Image, EAR, Baseline_EAR, Relative_EAR, '
            'Face_Detected, Landmark_Found, Note',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(
                'Export CSV (${_service.results.length} rows)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.lightBlueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPreview() {
    final results = _service.results;

    return _ResearchCard(
      title: 'Preview Hasil (${results.length} total)',
      icon: Icons.table_chart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stats
          _buildSummaryStats(results),
          const SizedBox(height: 16),
          // Table header — always visible, outside scroll area
          _buildTableRow(
            subject: 'SUBJECT',
            label: 'LABEL',
            ear: 'EAR',
            relEar: 'REL',
            isHeader: true,
          ),
          const Divider(color: Colors.white12, height: 12),
          // ── Scrollable table body — fixed height card ──
          Stack(
            children: [
              SizedBox(
                height: 360,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: results.map((r) => _buildTableRow(
                          subject: r.subject,
                          label: r.label,
                          ear: r.faceDetected && r.landmarkFound
                              ? r.ear.toStringAsFixed(3)
                              : '—',
                          relEar: r.faceDetected && r.landmarkFound
                              ? r.relativeEar.toStringAsFixed(2)
                              : '—',
                          earVal: r.ear,
                          isHeader: false,
                          failed: !r.faceDetected,
                        )).toList(),
                  ),
                ),
              ),
              // Fade gradient at bottom to hint scrollability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1A1D27).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.swipe_vertical_rounded,
                  size: 13, color: Colors.white24),
              const SizedBox(width: 4),
              Text(
                'Scroll untuk lihat semua ${results.length} hasil · Export CSV untuk data lengkap',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white24,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(List<PipelineResultModel> results) {
    // Compute summary by label
    final groups = <String, List<double>>{};
    for (final r in results) {
      if (r.faceDetected && r.landmarkFound && r.ear > 0) {
        groups.putIfAbsent(r.label, () => []).add(r.ear);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan EAR per Label',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...groups.entries.map((entry) {
          final ears = entry.value;
          final avg = ears.reduce((a, b) => a + b) / ears.length;
          final max = ears.reduce((a, b) => a > b ? a : b);
          final min = ears.reduce((a, b) => a < b ? a : b);
          final isNonDrowsy = entry.key == 'non_drowsy';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNonDrowsy
                  ? Colors.greenAccent.withValues(alpha: 0.07)
                  : Colors.orangeAccent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isNonDrowsy
                    ? Colors.greenAccent.withValues(alpha: 0.25)
                    : Colors.orangeAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isNonDrowsy ? Icons.visibility_rounded : Icons.bedtime_rounded,
                  color: isNonDrowsy
                      ? Colors.greenAccent.shade400
                      : Colors.orangeAccent.shade200,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Avg: ${avg.toStringAsFixed(3)}  '
                        'Max: ${max.toStringAsFixed(3)}  '
                        'Min: ${min.toStringAsFixed(3)}  '
                        'n=${ears.length}',
                        style: GoogleFonts.sourceCodePro(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTableRow({
    required String subject,
    required String label,
    required String ear,
    required String relEar,
    double? earVal,
    required bool isHeader,
    bool failed = false,
  }) {
    final rowColor = failed
        ? Colors.redAccent.withValues(alpha: 0.08)
        : Colors.transparent;

    final textColor =
        isHeader ? Colors.white54 : failed ? Colors.redAccent.shade100 : Colors.white70;

    // Color-code EAR value
    Color earColor = Colors.white70;
    if (!isHeader && !failed && earVal != null) {
      if (earVal < 0.15) {
        earColor = Colors.redAccent.shade200;
      } else if (earVal < 0.25) {
        earColor = Colors.orangeAccent.shade200;
      } else {
        earColor = Colors.greenAccent.shade400;
      }
    }

    return Container(
      color: rowColor,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              subject,
              style: isHeader
                  ? GoogleFonts.plusJakartaSans(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )
                  : GoogleFonts.sourceCodePro(color: textColor, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label == 'non_drowsy' ? 'awake' : label,
              style: GoogleFonts.plusJakartaSans(
                color: isHeader
                    ? Colors.white54
                    : label == 'non_drowsy'
                        ? Colors.greenAccent.shade400
                        : Colors.orangeAccent.shade200,
                fontSize: 10,
                fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              ear,
              style: isHeader
                  ? GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )
                  : GoogleFonts.sourceCodePro(color: earColor, fontSize: 10),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              relEar,
              style: GoogleFonts.sourceCodePro(
                color: isHeader ? Colors.white54 : Colors.white38,
                fontSize: 10,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Research UI Components ─────────────────────────────────────────

class _ResearchCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ResearchCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
