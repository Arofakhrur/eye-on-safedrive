import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/constants/app_data.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/features/profile/widgets/user_profile_card.dart';
import 'package:eyeon/features/profile/widgets/personal_info_card.dart';
import 'package:eyeon/features/profile/widgets/detection_settings_card.dart';
import 'package:eyeon/core/widgets/eyeon_header.dart';
import 'package:eyeon/core/widgets/eyeon_address_autocomplete.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Rider';
  String? _avatarUrl;
  String _email = 'rider@eyeon.app';

  String _address = 'Not set';
  String _bloodType = 'Not set';
  String _origin = 'Not set';
  String _medicalNotes = '';

  // Preferences
  double _earThreshold = PreferenceService().earThreshold;
  double _shockSensitivity = PreferenceService().shockSensitivity;
  String _alarmSound = PreferenceService().alarmSound;
  bool _saveToGallery = PreferenceService().saveToGallery;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = SupabaseService().currentUser;
    if (user != null) {
      setState(() {
        _email = user.email ?? 'rider@eyeon.app';
        if (user.userMetadata != null) {
          _userName =
              user.userMetadata!['full_name'] ??
              user.userMetadata!['name'] ??
              'Rider';
          _avatarUrl =
              (user.userMetadata!['avatar_url'] ?? user.userMetadata!['picture'])
                  ?.toString().replaceFirst('http://', 'https://');
        }
      });

      // Load from profiles table (Task 9)
      final profile = await SupabaseService().getProfile();
      if (profile != null && mounted) {
        // Restore ear_threshold if available
        if (profile['ear_threshold'] != null) {
          final cloudThreshold = (profile['ear_threshold'] as num).toDouble();
          await PreferenceService().setEarThreshold(cloudThreshold);
          _earThreshold = cloudThreshold;
        }

        // Restore preferences if available
        if (profile['shock_sensitivity'] != null) {
          final val = (profile['shock_sensitivity'] as num).toDouble();
          await PreferenceService().setShockSensitivity(val);
          _shockSensitivity = val;
        }
        if (profile['alarm_sound'] != null) {
          final val = profile['alarm_sound'] as String;
          await PreferenceService().setAlarmSound(val);
          _alarmSound = val;
        }
        if (profile['save_to_gallery'] != null) {
          final val = profile['save_to_gallery'] as bool;
          await PreferenceService().setSaveToGallery(val);
          _saveToGallery = val;
        }

        setState(() {
          if (profile['full_name'] != null) _userName = profile['full_name'];
          _address = profile['address'] ?? 'Not set';
          _bloodType = profile['blood_type'] ?? 'Not set';
          _origin = profile['origin'] ?? 'Not set';
          _medicalNotes = profile['emergency_medical_notes'] ?? '';
        });
      }
    }
  }

  // ── Edit Personal Info Dialog ──────────────────────────────────────
  Future<void> _showEditPersonalInfoDialog() async {
    final nameController = TextEditingController(text: _userName);
    final addressController = TextEditingController(
      text: _address == 'Not set' ? '' : _address,
    );
    String selectedBloodType = _bloodType == 'Not set' ? 'A' : _bloodType;
    final originController = TextEditingController(
      text: _origin == 'Not set' ? '' : _origin,
    );
    final medicalNotesController = TextEditingController(text: _medicalNotes);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ubah Informasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Perbarui detail profil pribadi Anda.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  _buildSectionLabel('Nama Lengkap'),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _buildInputDecoration(
                      Icons.person_outline_rounded,
                      'Masukkan nama lengkap...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address with Autocomplete
                  _buildSectionLabel('Alamat Lengkap'),
                  EyeonAddressAutocomplete(
                    initialValue: addressController.text,
                    hintText: 'Cari alamat...',
                    icon: Icons.location_on_rounded,
                    externalController: addressController,
                  ),

                  const SizedBox(height: 16),

                  // Blood Type with Dropdown
                  _buildSectionLabel('Golongan Darah'),
                  DropdownButtonFormField<String>(
                    initialValue: AppData.bloodTypes.contains(selectedBloodType)
                        ? selectedBloodType
                        : 'A',
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 28),
                    items: AppData.bloodTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedBloodType = val);
                      }
                    },
                    decoration: _buildInputDecoration(
                      Icons.bloodtype_rounded,
                      'Pilih golongan darah',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Origin
                  _buildSectionLabel('Asal Daerah'),
                  EyeonAddressAutocomplete(
                    initialValue: originController.text,
                    hintText: 'Masukkan asal daerah...',
                    icon: Icons.public_rounded,
                    externalController: originController,
                  ),

                  const SizedBox(height: 16),

                  // Medical Notes
                  _buildSectionLabel('Catatan Medis'),
                  TextField(
                    controller: medicalNotesController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _buildInputDecoration(
                      Icons.medical_information_rounded,
                      'Alergi, kondisi khusus, dll...',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Save to profiles table
                            await SupabaseService().updateProfile({
                              'full_name': nameController.text,
                              'address': addressController.text,
                              'blood_type': selectedBloodType,
                              'origin': originController.text,
                              'emergency_medical_notes':
                                  medicalNotesController.text,
                            });

                            // Also update auth metadata
                            await SupabaseService().updateUserMetadata({
                              'full_name': nameController.text,
                              'address': addressController.text,
                              'blood_type': selectedBloodType,
                              'origin': originController.text,
                            });

                            setState(() {
                              _userName = nameController.text;
                              _address = addressController.text;
                              _bloodType = selectedBloodType;
                              _origin = originController.text;
                              _medicalNotes = medicalNotesController.text;
                            });

                            await _loadUserProfile();
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Simpan Perubahan',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────



  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20, color: Colors.black45),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: Colors.black26,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ── Main Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
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
                userName: _userName,
                email: _email,
                avatarUrl: _avatarUrl,
              ),
              const SizedBox(height: 24),

              _buildSectionHeader(
                'INFORMASI PRIBADI',
                onEdit: _showEditPersonalInfoDialog,
              ),
              PersonalInfoCard(
                address: _address,
                bloodType: _bloodType,
                origin: _origin,
                medicalNotes: _medicalNotes,
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('PENGATURAN KESELAMATAN'),
              _buildMenuItem(
                icon: Icons.camera_front_rounded,
                title: 'Kalibrasi Ulang Kamera',
                subtitle: 'Setup ulang posisi wajah Anda',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.calibration),
              ),
              _buildMenuItem(
                icon: Icons.contact_phone_rounded,
                title: 'Kontak Darurat',
                subtitle: 'Manage recipients for SOS alerts',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.setup),
              ),
              DetectionSettingsCard(
                earThreshold: _earThreshold,
                shockSensitivity: _shockSensitivity,
                alarmSound: _alarmSound,
                onEarChanged: (val) {
                  setState(() => _earThreshold = val);
                  PreferenceService().setEarThreshold(val);
                  SupabaseService().updateProfile({'ear_threshold': val});
                },
                onShockChanged: (val) {
                  setState(() => _shockSensitivity = val);
                  PreferenceService().setShockSensitivity(val);
                  SupabaseService().updateProfile({'shock_sensitivity': val});
                },
                onSoundChanged: (val) {
                  setState(() => _alarmSound = val);
                  PreferenceService().setAlarmSound(val);
                  SupabaseService().updateProfile({'alarm_sound': val});
                },
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('PENYIMPANAN & DATA'),
              _buildToggleItem(
                icon: Icons.sd_storage_rounded,
                title: 'Simpan Salinan ke Galeri',
                subtitle: 'Auto-save accident videos to phone',
                value: _saveToGallery,
                onChanged: (val) {
                  setState(() => _saveToGallery = val);
                  PreferenceService().setSaveToGallery(val);
                  SupabaseService().updateProfile({'save_to_gallery': val});
                },
              ),
              _buildMenuItem(
                icon: Icons.sync_rounded,
                title: 'Sinkronisasi Data',
                subtitle: 'Sync logs with Supabase cloud',
                onTap: () async {
                  try {
                    final synced = await SupabaseService().syncOfflineData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            synced > 0
                                ? '$synced data berhasil disinkronkan.'
                                : 'Tidak ada data offline untuk disinkronkan.',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.black87,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Gagal menyinkronkan data: $e',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('AKUN'),
              _buildMenuItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Safely exit your account',
                isDestructive: true,
                onTap: _handleSignOut,
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onEdit}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, size: 12, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  'Edit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.black38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? Colors.redAccent : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDestructive
                          ? Colors.redAccent.withValues(alpha: 0.6)
                          : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await SupabaseService().signOut();
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }
}
