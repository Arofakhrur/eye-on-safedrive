import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';

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

  /// Re-check permissions when user returns from Settings
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
    
    if (mounted) {
      setState(() {
        _locationGranted = locationStatus.isGranted;
        _cameraGranted = cameraStatus.isGranted;
        _notificationGranted = notificationStatus.isGranted;
        _contactsGranted = contactsStatus.isGranted;
      });
    }
  }

  Future<void> _requestSinglePermission(Permission permission) async {
    final status = await permission.request();
    print('Permission ${permission.toString()} status: $status');
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog(permission);
      }
    }
    await _checkCurrentPermissions();
  }

  Future<void> _grantAllPermissions() async {
    setState(() => _isRequesting = true);

    // Request each permission sequentially
    if (!_locationGranted) {
      await _requestSinglePermission(Permission.location);
    }
    if (!_cameraGranted) {
      await _requestSinglePermission(Permission.camera);
    }
    if (!_notificationGranted) {
      await _requestSinglePermission(Permission.notification);
    }
    if (!_contactsGranted) {
      await _requestSinglePermission(Permission.contacts);
    }

    // Re-check after all requests
    await _checkCurrentPermissions();

    setState(() => _isRequesting = false);

    // Navigate if all granted
    if (_locationGranted && _cameraGranted && _notificationGranted && _contactsGranted && mounted) {
      PreferenceService().setPermissionsGranted(true);
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  void _showSettingsDialog(Permission permission) {
    String permName = '';
    if (permission == Permission.location) {
      permName = 'Location';
    } else if (permission == Permission.camera) {
      permName = 'Camera';
    } else if (permission == Permission.notification) {
      permName = 'Notification';
    } else if (permission == Permission.contacts) {
      permName = 'Contacts';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$permName Permission Required',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Please enable $permName permission in Settings to continue.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text(
              'Open Settings',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _allGranted =>
      _locationGranted && _cameraGranted && _notificationGranted && _contactsGranted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            const SizedBox(height: 40),

            // Title
            Text(
              'Rider Privacy &\nPermission',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 40),

            // Permission Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildPermissionCard(
                    icon: Icons.location_searching_rounded,
                    title: 'Location Service',
                    subtitle: 'For incident detection\n& support',
                    isGranted: _locationGranted,
                    onToggle: () =>
                        _requestSinglePermission(Permission.location),
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionCard(
                    icon: Icons.visibility_outlined,
                    title: 'Camera Access',
                    subtitle: 'For active rider\neye-tracking',
                    isGranted: _cameraGranted,
                    onToggle: () =>
                        _requestSinglePermission(Permission.camera),
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionCard(
                    icon: Icons.notification_important_rounded,
                    title: 'Notification',
                    subtitle: 'Immediate alert for\ndangerous situation',
                    isGranted: _notificationGranted,
                    onToggle: () =>
                        _requestSinglePermission(Permission.notification),
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionCard(
                    icon: Icons.contact_phone_rounded,
                    title: 'Contacts',
                    subtitle: 'Quickly pick your\nemergency contact',
                    isGranted: _contactsGranted,
                    onToggle: () =>
                        _requestSinglePermission(Permission.contacts),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom Button
            _buildGrantButton(),

            const SizedBox(height: 32),
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
          Image.asset('assets/images/EYE-ON!_Logo.webp',
              height: 28, width: 28),
          const SizedBox(width: 8),
          Text(
            'EYE-ON!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
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
        border: Border.all(
          color: isGranted
              ? const Color(0xFFD7F454).withValues(alpha: 0.5)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Circle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFFD7F454)
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isGranted ? Colors.white : Colors.black38, size: 24),
          ),
          const SizedBox(width: 16),
          // Text Content
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
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Toggle Switch — tapping it requests the permission
          Switch(
            value: isGranted,
            onChanged: (_) => onToggle(),
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFD7F454),
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
        onTap: _isRequesting
            ? null
            : () {
                if (_allGranted) {
                  PreferenceService().setPermissionsGranted(true);
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                } else {
                  _grantAllPermissions();
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _isRequesting
                ? Colors.grey.shade300
                : const Color(0xFFD7F454),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              if (!_isRequesting)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRequesting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black38),
                  ),
                )
              else ...[
                Text(
                  _allGranted ? 'Continue' : 'Grant All Permission',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _allGranted
                      ? Icons.arrow_circle_right_outlined
                      : Icons.security_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
