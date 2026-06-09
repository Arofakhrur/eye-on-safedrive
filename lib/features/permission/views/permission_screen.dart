import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/theme/app_theme.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationGranted = false;
  bool _contactsGranted = false;
  bool _microphoneGranted = false;
  bool _storageGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCurrentPermissions();
    }
  }

  Future<void> _checkCurrentPermissions() async {
    final locationStatus = await Permission.location.status;
    final cameraStatus = await Permission.camera.status;
    final notificationStatus = await Permission.notification.status;
    final contactsStatus = await Permission.contacts.status;
    final microphoneStatus = await Permission.microphone.status;
    
    // For storage, we check videos on newer Android or storage on older
    final storageStatus = await Permission.storage.status;
    final videoStatus = await Permission.videos.status;
    
    if (mounted) {
      setState(() {
        _locationGranted = locationStatus.isGranted;
        _cameraGranted = cameraStatus.isGranted;
        _notificationGranted = notificationStatus.isGranted;
        _contactsGranted = contactsStatus.isGranted;
        _microphoneGranted = microphoneStatus.isGranted;
        _storageGranted = storageStatus.isGranted || videoStatus.isGranted;
      });
    }
  }

  Future<void> _requestSinglePermission(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog(permission);
      }
    }
    await _checkCurrentPermissions();
  }

  Future<void> _grantAllPermissions() async {
    setState(() => _isRequesting = true);

    if (!_locationGranted) await _requestSinglePermission(Permission.location);
    if (!_cameraGranted) await _requestSinglePermission(Permission.camera);
    if (!_microphoneGranted) await _requestSinglePermission(Permission.microphone);
    if (!_storageGranted) {
      // Try videos first for Android 13+
      await _requestSinglePermission(Permission.videos);
      await _requestSinglePermission(Permission.storage);
    }
    if (!_notificationGranted) await _requestSinglePermission(Permission.notification);
    if (!_contactsGranted) await _requestSinglePermission(Permission.contacts);

    await _checkCurrentPermissions();
    setState(() => _isRequesting = false);

    if (_allGranted && mounted) {
      PreferenceService().setPermissionsGranted(true);
      
      // If user is already logged in (e.g. they granted permissions after login), 
      // we shouldn't send them back to login. Let splash screen figure out the next step.
      if (SupabaseService.client.auth.currentUser != null) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.splash);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  void _showSettingsDialog(Permission permission) {
    String permName = permission.toString().split('.').last.toUpperCase();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$permName Permission Required', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('Please enable $permName permission in Settings to continue.', style: GoogleFonts.plusJakartaSans(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.black54))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text('Open Settings', style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  bool get _allGranted =>
      _locationGranted && _cameraGranted && _notificationGranted && _contactsGranted && _microphoneGranted && _storageGranted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 20),
            Text(
              'Rider Privacy &\nPermission',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black, height: 1.2),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildPermissionCard(
                    icon: Icons.location_searching_rounded,
                    title: 'Location Service',
                    subtitle: 'For incident detection & support',
                    isGranted: _locationGranted,
                    onToggle: () => _requestSinglePermission(Permission.location),
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard(
                    icon: Icons.visibility_outlined,
                    title: 'Camera Access',
                    subtitle: 'For active rider eye-tracking',
                    isGranted: _cameraGranted,
                    onToggle: () => _requestSinglePermission(Permission.camera),
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard(
                    icon: Icons.mic_rounded,
                    title: 'Microphone',
                    subtitle: 'For audio alerts & video recording',
                    isGranted: _microphoneGranted,
                    onToggle: () => _requestSinglePermission(Permission.microphone),
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Storage & Gallery',
                    subtitle: 'To save incident video copies',
                    isGranted: _storageGranted,
                    onToggle: () async {
                      await _requestSinglePermission(Permission.videos);
                      await _requestSinglePermission(Permission.storage);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard(
                    icon: Icons.notification_important_rounded,
                    title: 'Notification',
                    subtitle: 'Immediate alert for dangerous situation',
                    isGranted: _notificationGranted,
                    onToggle: () => _requestSinglePermission(Permission.notification),
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard(
                    icon: Icons.contact_phone_rounded,
                    title: 'Contacts',
                    subtitle: 'Quickly pick your emergency contact',
                    isGranted: _contactsGranted,
                    onToggle: () => _requestSinglePermission(Permission.contacts),
                  ),
                ],
              ),
            ),
            _buildGrantButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/EYE-ON!_Logo.webp', height: 28, width: 28),
          const SizedBox(width: 8),
          Text('EYE-ON!', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isGranted ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isGranted ? AppColors.primary : Colors.grey.shade200, shape: BoxShape.circle),
            child: Icon(icon, color: isGranted ? Colors.black : Colors.black38, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.black54, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: isGranted,
            onChanged: (_) => onToggle(),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade200,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _isRequesting ? null : () {
          if (_allGranted) {
            PreferenceService().setPermissionsGranted(true);
            if (SupabaseService.client.auth.currentUser != null) {
              Navigator.of(context).pushReplacementNamed(AppRoutes.splash);
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.login);
            }
          } else {
            _grantAllPermissions();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _isRequesting ? Colors.grey.shade300 : AppColors.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [if (!_isRequesting) BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRequesting)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black38)))
              else ...[
                Text(_allGranted ? 'Continue' : 'Grant All Permissions', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(width: 12),
                Icon(_allGranted ? Icons.arrow_circle_right_outlined : Icons.security_rounded, color: Colors.black, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
