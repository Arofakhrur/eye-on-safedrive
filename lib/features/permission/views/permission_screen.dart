import 'package:eyeon/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/features/permission/widgets/permission_widgets.dart';
import 'package:eyeon/features/permission/logic/permission_controller.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final PermissionController _controller = PermissionController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSettingsDialog(Permission permission) {
    String permName = permission.toString().split('.').last.toUpperCase();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$permName Permission Required', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('Harap izinkan akses $permName di Pengaturan untuk melanjutkan.', style: GoogleFonts.plusJakartaSans(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text('Open Settings', style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _onSuccess() {
    if (mounted) {
      if (SupabaseService.client.auth.currentUser != null) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.splash);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              children: [
                PermissionTopBar(),
                const SizedBox(height: 20),
                Text(
                  'Rider Privacy &\nPermission',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      PermissionCard(
                        icon: Icons.location_searching_rounded,
                        title: 'Location Service',
                        subtitle: 'For incident detection & support',
                        isGranted: _controller.locationGranted,
                        onToggle: () => _controller.requestSinglePermission(Permission.location, _showSettingsDialog),
                      ),
                      const SizedBox(height: 12),
                      PermissionCard(
                        icon: Icons.visibility_outlined,
                        title: 'Camera Access',
                        subtitle: 'For active rider eye-tracking',
                        isGranted: _controller.cameraGranted,
                        onToggle: () => _controller.requestSinglePermission(Permission.camera, _showSettingsDialog),
                      ),
                      const SizedBox(height: 12),
                      PermissionCard(
                        icon: Icons.mic_rounded,
                        title: 'Microphone',
                        subtitle: 'For audio alerts & video recording',
                        isGranted: _controller.microphoneGranted,
                        onToggle: () => _controller.requestSinglePermission(Permission.microphone, _showSettingsDialog),
                      ),
                      const SizedBox(height: 12),
                      PermissionCard(
                        icon: Icons.photo_library_rounded,
                        title: 'Storage & Gallery',
                        subtitle: 'To save incident video copies',
                        isGranted: _controller.storageGranted,
                        onToggle: () async {
                          await _controller.requestSinglePermission(Permission.videos, _showSettingsDialog);
                          await _controller.requestSinglePermission(Permission.storage, _showSettingsDialog);
                        },
                      ),
                      const SizedBox(height: 12),
                      PermissionCard(
                        icon: Icons.notification_important_rounded,
                        title: 'Notification',
                        subtitle: 'Immediate alert for dangerous situation',
                        isGranted: _controller.notificationGranted,
                        onToggle: () => _controller.requestSinglePermission(Permission.notification, _showSettingsDialog),
                      ),
                      const SizedBox(height: 12),
                      PermissionCard(
                        icon: Icons.contact_phone_rounded,
                        title: 'Contacts',
                        subtitle: 'Quickly pick your emergency contact',
                        isGranted: _controller.contactsGranted,
                        onToggle: () => _controller.requestSinglePermission(Permission.contacts, _showSettingsDialog),
                      ),
                      const SizedBox(height: 12),
                      PermissionCard(
                        icon: Icons.phone_in_talk_rounded,
                        title: 'Phone Call',
                        subtitle: 'Direct call to emergency contact',
                        isGranted: _controller.phoneGranted,
                        onToggle: () => _controller.requestSinglePermission(Permission.phone, _showSettingsDialog),
                      ),
                    ],
                  ),
                ),
                PermissionGrantButton(
                  isRequesting: _controller.isRequesting,
                  allGranted: _controller.allGranted,
                  onTap: () {
                    if (_controller.allGranted) {
                      PreferenceService().setPermissionsGranted(true);
                      _onSuccess();
                    } else {
                      _controller.grantAllPermissions(_showSettingsDialog, _onSuccess);
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],
            );
          }
        ),
      ),
    );
  }
}