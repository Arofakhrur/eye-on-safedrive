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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const EyeOnHeader(),
                  Text(
                    'Profil & Pengaturan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 32),
                  UserProfileCard(
                    userName: _controller.userName,
                    email: _controller.email,
                    avatarUrl: _controller.avatarUrl,
                  ),
                  const SizedBox(height: 24),

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

                  const SizedBox(height: 24),
                  const ProfileSectionTitle(title: 'PENGATURAN KESELAMATAN'),
                  ProfileMenuItem(
                    icon: Icons.camera_front_rounded,
                    title: 'Kalibrasi Ulang Kamera',
                    subtitle: 'Setup ulang posisi wajah Anda',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.calibration),
                  ),
                  ProfileMenuItem(
                    icon: Icons.contact_phone_rounded,
                    title: 'Kontak Darurat',
                    subtitle: 'Manage recipients for SOS alerts',
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

                  const SizedBox(height: 24),
                  const ProfileSectionTitle(title: 'PENYIMPANAN & DATA'),
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
                      final messenger = ScaffoldMessenger.of(context);
                      final screenHeight = MediaQuery.of(context).size.height;
                      try {
                        final synced = await _controller.syncOfflineData();
                        if (mounted) {
                          NotificationHelper.showTopWithMessenger(
                            messenger,
                            screenHeight: screenHeight,
                            message: synced > 0
                                ? '$synced data berhasil disinkronkan.'
                                : 'Tidak ada data offline untuk disinkronkan.',
                            type: NotificationType.success,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          NotificationHelper.showTopWithMessenger(
                            messenger,
                            screenHeight: screenHeight,
                            message: 'Gagal menyinkronkan data: $e',
                            type: NotificationType.error,
                          );
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 24),
                  const ProfileSectionTitle(title: 'AKUN'),
                  ProfileMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Safely exit your account',
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

                  const SizedBox(height: 100),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
