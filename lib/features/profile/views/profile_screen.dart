import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/features/profile/widgets/user_profile_card.dart';
import 'package:eyeon/features/profile/widgets/personal_info_card.dart';
import 'package:eyeon/features/profile/widgets/detection_settings_card.dart';

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

  void _loadUserProfile() {
    final user = SupabaseService().currentUser;
    if (user != null) {
      setState(() {
        _email = user.email ?? 'rider@eyeon.app';
        if (user.userMetadata != null) {
          _userName = user.userMetadata!['full_name'] ?? user.userMetadata!['name'] ?? 'Rider';
          _avatarUrl = user.userMetadata!['avatar_url'] ?? user.userMetadata!['picture'];
          _address = user.userMetadata!['address'] ?? 'Not set';
          _bloodType = user.userMetadata!['blood_type'] ?? 'Not set';
          _origin = user.userMetadata!['origin'] ?? 'Not set';
        }
      });
    }
  }

  Future<void> _showEditPersonalInfoDialog() async {
    final addressController = TextEditingController(text: _address == 'Not set' ? '' : _address);
    String selectedBloodType = _bloodType == 'Not set' ? 'A' : _bloodType;
    final originController = TextEditingController(text: _origin == 'Not set' ? '' : _origin);

    final List<String> bloodTypes = ['A', 'B', 'AB', 'O', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black45),
                  ),
                  const SizedBox(height: 24),
                  
                  // Address with Autocomplete
                  _buildSectionLabel('Alamat Lengkap'),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: addressController.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') return const Iterable<String>.empty();
                      // This is where you'd call a Geocoding/Places API
                      // For now, providing a few mock examples for the user to see it working
                      final List<String> mockPredictions = [
                        'Jakarta, Indonesia',
                        'Bandung, Jawa Barat',
                        'Surabaya, Jawa Timur',
                        'Medan, Sumatera Utara',
                        'Semarang, Jawa Tengah',
                      ];
                      return mockPredictions.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      addressController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(Icons.location_on_rounded, 'Cari alamat...'),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  
                  // Blood Type with Dropdown
                  _buildSectionLabel('Golongan Darah'),
                  DropdownButtonFormField<String>(
                    value: bloodTypes.contains(selectedBloodType) ? selectedBloodType : 'A',
                    items: bloodTypes.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedBloodType = val);
                    },
                    decoration: _buildInputDecoration(Icons.bloodtype_rounded, 'Pilih golongan darah'),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),

                  const SizedBox(height: 16),
                  
                  _buildSectionLabel('Asal Kota'),
                  TextField(
                    controller: originController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: _buildInputDecoration(Icons.home_rounded, 'Contoh: Bandung'),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final newMetadata = {
                              'address': addressController.text,
                              'blood_type': selectedBloodType,
                              'origin': originController.text,
                            };
                            await SupabaseService().updateUserMetadata(newMetadata);
                            _loadUserProfile();
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD7F454),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'Simpan Perubahan',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
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
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black26),
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
        borderSide: const BorderSide(color: Color(0xFFD7F454), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.black45),
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
              borderSide: const BorderSide(color: Color(0xFFD7F454), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

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
              Text('Profil & Pengaturan', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 32),
              UserProfileCard(userName: _userName, email: _email, avatarUrl: _avatarUrl),
              const SizedBox(height: 24),
              
              _buildSectionHeader('INFORMASI PRIBADI', onEdit: _showEditPersonalInfoDialog),
              PersonalInfoCard(address: _address, bloodType: _bloodType, origin: _origin),
              
              const SizedBox(height: 24),
              _buildSectionTitle('PENGATURAN KESELAMATAN'),
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
                },
                onShockChanged: (val) {
                  setState(() => _shockSensitivity = val);
                  PreferenceService().setShockSensitivity(val);
                },
                onSoundChanged: (val) {
                  setState(() => _alarmSound = val);
                  PreferenceService().setAlarmSound(val);
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
                },
              ),
              _buildMenuItem(
                icon: Icons.sync_rounded,
                title: 'Sinkronisasi Data',
                subtitle: 'Sync logs with Supabase cloud',
                onTap: () {},
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
            decoration: BoxDecoration(color: const Color(0xFFD7F454), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, size: 12, color: Colors.black),
                const SizedBox(width: 4),
                Text('Edit', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
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
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1.2),
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
          color: isDestructive ? Colors.red.withValues(alpha: 0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDestructive ? Colors.red.withValues(alpha: 0.1) : Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.redAccent : Colors.black87, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: isDestructive ? Colors.redAccent : Colors.black87)),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDestructive ? Colors.redAccent.withValues(alpha: 0.6) : Colors.black45)),
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
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFD7F454),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await SupabaseService().signOut();
    await PreferenceService().clearAll();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }
}
