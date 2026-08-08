import 'package:eyeon/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

import 'package:eyeon/features/profile/logic/profile_controller.dart';
import 'package:eyeon/features/profile/widgets/user_profile_card.dart';
import 'package:eyeon/features/profile/widgets/personal_info_card.dart';
import 'package:eyeon/features/profile/widgets/detection_settings_card.dart';
import 'package:eyeon/features/profile/widgets/profile_menu_items.dart';
import 'package:eyeon/features/profile/widgets/edit_personal_info_sheet.dart';
import 'package:eyeon/features/monitoring/widgets/monitoring_overlays.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _controller = ProfileController();

  Future<void> _showEditPersonalInfoDialog() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => EditPersonalInfoSheet(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  EyeOnHeader(),
                  Text(
                    'Profil & Pengaturan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  UserProfileCard(
                    userName: _controller.userName,
                    email: _controller.email,
                    avatarUrl: _controller.avatarUrl,
                  ),
                  const SizedBox(height: 16),

                  ProfileSectionHeader(
                    title: 'INFORMASI PRIBADI',
                    onEdit: _showEditPersonalInfoDialog,
                  ),
                  PersonalInfoCard(
                    address: _controller.address,
                    bloodType: _controller.bloodType,
                    origin: _controller.origin,
                    medicalNotes: _controller.medicalNotes,
                  ),

                  const SizedBox(height: 16),
                  const ProfileSectionTitle(title: 'KEAMANAN & DETEKSI'),
                  ProfileMenuItem(
                    icon: Icons.camera_front_rounded,
                    title: 'Kalibrasi Ulang Kamera',
                    subtitle: 'Atur ulang posisi wajah Anda',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.calibration),
                  ),
                  ProfileMenuItem(
                    icon: Icons.contact_phone_rounded,
                    title: 'Kontak Darurat',
                    subtitle: 'Kelola penerima pesan SOS',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.setup),
                  ),
                  DetectionSettingsCard(
                    earThreshold: _controller.earThreshold,
                    shockSensitivity: _controller.shockSensitivity,
                    alarmSound: _controller.alarmSound,
                    onEarChanged: (val) {
                      // Handled by calibration flow usually, but we keep the callback for debugging slider
                    },
                    onShockChanged: (val) {
                      _controller.updateDetectionSettings(
                        shockSensitivity: val,
                        alarmSound: _controller.alarmSound,
                        saveToGallery: _controller.saveToGallery,
                      );
                    },
                    onSoundChanged: (val) {
                      _controller.updateDetectionSettings(
                        shockSensitivity: _controller.shockSensitivity,
                        alarmSound: val,
                        saveToGallery: _controller.saveToGallery,
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const ProfileSectionTitle(title: 'PENYIMPANAN & PERFORMA'),
                  ProfileToggleItem(
                    icon: Icons.face_retouching_natural_rounded,
                    title: 'Tampilkan Titik Wajah (Face Mesh)',
                    subtitle: 'Show tracking dots on camera (may cause lag)',
                    value: _controller.showFaceMesh,
                    onChanged: (val) {
                      _controller.updateShowFaceMesh(val);
                    },
                  ),
                  ProfileToggleItem(
                    icon: Icons.sd_storage_rounded,
                    title: 'Simpan Salinan ke Galeri',
                    subtitle: 'Auto-save accident videos to phone',
                    value: _controller.saveToGallery,
                    onChanged: (val) {
                      _controller.updateDetectionSettings(
                        shockSensitivity: _controller.shockSensitivity,
                        alarmSound: _controller.alarmSound,
                        saveToGallery: val,
                      );
                    },
                  ),
                  ProfileMenuItem(
                    icon: Icons.sync_rounded,
                    title: 'Sinkronisasi Data',
                    subtitle: 'Sync logs with Supabase cloud',
                    onTap: () async {
                      try {
                        final synced = await _controller.syncOfflineData();
                        if (context.mounted) {
                          NotificationHelper.showTop(
                            context,
                            message: synced > 0
                                ? '$synced data berhasil disinkronkan.'
                                : 'Tidak ada data offline untuk disinkronkan.',
                            type: NotificationType.success,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          NotificationHelper.showTop(
                            context,
                            message: 'Gagal menyinkronkan data: $e',
                            type: NotificationType.error,
                          );
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                  const ProfileSectionTitle(title: 'OPSI DEVELOPER'),
                  ProfileMenuItem(
                    icon: Icons.bug_report_rounded,
                    title: 'Simulasi Peringatan UI',
                    subtitle: 'Test tampilan overlay (Crash & Microsleep)',
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.background,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (ctx) {
                          return SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Test Overlay UI',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ListTile(
                                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                    title: const Text('Test Accident Alert (Crash)'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      showDialog(
                                        context: context,
                                        useSafeArea: false,
                                        barrierDismissible: false,
                                        builder: (_) => AlertOverlay(
                                          currentMagnitude: 99.9,
                                          onResetAccident: () => Navigator.pop(context),
                                          onCallEmergency: () => Navigator.pop(context),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.bedtime_rounded, color: Colors.orange),
                                    title: const Text('Test Microsleep Level 1'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      showDialog(
                                        context: context,
                                        useSafeArea: false,
                                        barrierDismissible: false,
                                        builder: (_) => Level1Overlay(onResume: () => Navigator.pop(context)),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.bedtime_rounded, color: Colors.deepOrange),
                                    title: const Text('Test Microsleep Level 2'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      showDialog(
                                        context: context,
                                        useSafeArea: false,
                                        barrierDismissible: false,
                                        builder: (_) => Level2Overlay(onResume: () => Navigator.pop(context)),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.bedtime_rounded, color: Colors.red),
                                    title: const Text('Test Microsleep Level 3'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      showDialog(
                                        context: context,
                                        useSafeArea: false,
                                        barrierDismissible: false,
                                        builder: (_) => Level3Overlay(
                                          onResume: () => Navigator.pop(context),
                                          canUnlock: true,
                                        ),
                                      );
                                    },
                                  ),
                                  const Divider(),
                                  ListTile(
                                    leading: const Icon(Icons.telegram, color: Colors.blue),
                                    title: const Text('Test Snackbar (Telegram)'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      NotificationHelper.showTop(
                                        context,
                                        message: 'Pesan darurat berhasil dikirim ke Telegram.',
                                        type: NotificationType.telegram,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.error_rounded, color: Colors.red),
                                    title: const Text('Test Snackbar (Gagal)'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      NotificationHelper.showTop(
                                        context,
                                        message: 'Gagal mengirim pesan ke kontak darurat.',
                                        type: NotificationType.error,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                    title: const Text('Test Snackbar (Peringatan)'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      NotificationHelper.showTop(
                                        context,
                                        message: 'Koneksi internet lambat, pesan tertunda.',
                                        type: NotificationType.warning,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // ── Research: Pipeline Verification (tidak mempengaruhi fitur produksi) ──
                  ProfileMenuItem(
                    icon: Icons.biotech_rounded,
                    title: 'Pipeline Verification',
                    subtitle: 'Verifikasi EAR pipeline vs. dataset DDD',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.pipelineTest),
                  ),

                  const SizedBox(height: 16),
                  const ProfileSectionTitle(title: 'AKUN'),
                  ProfileMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Keluar (Logout)',
                    subtitle: 'Keluar dari akun Anda',
                    isDestructive: true,
                    onTap: () async {
                      await _controller.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.login,
                          (route) => false,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}