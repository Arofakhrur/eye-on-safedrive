import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/telegram_service.dart';
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
  String _medicalNotes = '';

  // Preferences
  double _earThreshold = PreferenceService().earThreshold;
  double _shockSensitivity = PreferenceService().shockSensitivity;
  String _alarmSound = PreferenceService().alarmSound;
  bool _saveToGallery = PreferenceService().saveToGallery;

  // Telegram
  List<String> _telegramChatIds = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _telegramChatIds = PreferenceService().telegramChatIds;
  }

  Future<void> _loadUserProfile() async {
    final user = SupabaseService().currentUser;
    if (user != null) {
      setState(() {
        _email = user.email ?? 'rider@eyeon.app';
        if (user.userMetadata != null) {
          _userName = user.userMetadata!['full_name'] ?? user.userMetadata!['name'] ?? 'Rider';
          _avatarUrl = user.userMetadata!['avatar_url'] ?? user.userMetadata!['picture'];
        }
      });

      // Load from profiles table (Task 9)
      final profile = await SupabaseService().getProfile();
      if (profile != null && mounted) {
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
    final addressController = TextEditingController(text: _address == 'Not set' ? '' : _address);
    String selectedBloodType = _bloodType == 'Not set' ? 'A' : _bloodType;
    final originController = TextEditingController(text: _origin == 'Not set' ? '' : _origin);
    final medicalNotesController = TextEditingController(text: _medicalNotes);

    final List<String> bloodTypes = ['A', 'B', 'AB', 'O', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final List<String> suggestions = [
                        'Jakarta, Indonesia',
                        'Bandung, Jawa Barat',
                        'Surabaya, Jawa Timur',
                        'Medan, Sumatera Utara',
                        'Semarang, Jawa Tengah',
                        'Makassar, Sulawesi Selatan',
                        'Yogyakarta, DIY',
                        'Malang, Jawa Timur',
                      ];
                      return suggestions.where((option) {
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
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
                  ),

                  const SizedBox(height: 16),

                  // Origin
                  _buildSectionLabel('Asal Daerah'),
                  TextField(
                    controller: originController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: _buildInputDecoration(Icons.public_rounded, 'Masukkan asal daerah...'),
                  ),

                  const SizedBox(height: 16),

                  // Medical Notes
                  _buildSectionLabel('Catatan Medis'),
                  TextField(
                    controller: medicalNotesController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: _buildInputDecoration(Icons.medical_information_rounded, 'Alergi, kondisi khusus, dll...'),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Batal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.black45)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Save to profiles table
                            await SupabaseService().updateProfile({
                              'full_name': _userName,
                              'address': addressController.text,
                              'blood_type': selectedBloodType,
                              'origin': originController.text,
                              'emergency_medical_notes': medicalNotesController.text,
                            });

                            // Also update auth metadata
                            await SupabaseService().updateUserMetadata({
                              'address': addressController.text,
                              'blood_type': selectedBloodType,
                              'origin': originController.text,
                            });

                            await _loadUserProfile();
                            if (ctx.mounted) Navigator.pop(ctx);
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

  // ── Telegram Chat ID management (Task 6) ──────────────────────────
  Future<void> _showTelegramSetupSheet() async {
    final chatIdController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Integrasi Telegram',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hubungkan bot EYE-ON! untuk mengirim SOS ke Telegram.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black45),
                  ),
                  const SizedBox(height: 20),

                  // Step 1: Open bot — uses tg:// protocol for direct Telegram launch
                  _buildStepCard(
                    step: '1',
                    title: 'Buka Bot Telegram',
                    subtitle: 'Ketuk tombol di bawah untuk membuka bot dan tekan /start.',
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Try tg:// protocol first for direct Telegram app launch
                        final tgUrl = Uri.parse('tg://resolve?domain=EyeOnSafeDriveBot');
                        final httpsUrl = Uri.parse('https://t.me/EyeOnSafeDriveBot');

                        if (await canLaunchUrl(tgUrl)) {
                          await launchUrl(tgUrl);
                        } else if (await canLaunchUrl(httpsUrl)) {
                          await launchUrl(httpsUrl, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text('Buka Bot', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0088CC),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Step 2: Enter Chat ID
                  _buildStepCard(
                    step: '2',
                    title: 'Masukkan Chat ID',
                    subtitle: 'Kontak darurat Anda mengirim /start ke bot, lalu bot memberi Chat ID.',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatIdController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration(Icons.tag_rounded, 'Chat ID'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final id = chatIdController.text.trim();
                            if (id.isNotEmpty) {
                              await PreferenceService().addTelegramChatId(id);
                              setModalState(() {
                                _telegramChatIds = PreferenceService().telegramChatIds;
                              });
                              setState(() {
                                _telegramChatIds = PreferenceService().telegramChatIds;
                              });
                              chatIdController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD7F454),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Registered chat IDs list
                  if (_telegramChatIds.isNotEmpty) ...[
                    Text(
                      'Chat ID Terdaftar',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_telegramChatIds.length, (i) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.telegram_rounded, color: Color(0xFF0088CC), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _telegramChatIds[i],
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await PreferenceService().removeTelegramChatId(_telegramChatIds[i]);
                                setModalState(() {
                                  _telegramChatIds = PreferenceService().telegramChatIds;
                                });
                                setState(() {
                                  _telegramChatIds = PreferenceService().telegramChatIds;
                                });
                              },
                              child: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Status indicator
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TelegramService().isConfigured
                          ? const Color(0xFFD7F454).withValues(alpha: 0.15)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          TelegramService().isConfigured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          size: 16,
                          color: TelegramService().isConfigured ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            TelegramService().isConfigured
                                ? 'Bot terhubung • ${_telegramChatIds.length} chat ID terdaftar'
                                : 'Bot token belum dikonfigurasi di .env',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────

  Widget _buildStepCard({
    required String step,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFD7F454),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(step, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 12),
          child,
        ],
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
              _buildSectionTitle('INTEGRASI TELEGRAM'),
              _buildMenuItem(
                icon: Icons.telegram_rounded,
                title: 'Pengaturan Bot Telegram',
                subtitle: '${_telegramChatIds.length} chat ID terdaftar',
                onTap: _showTelegramSetupSheet,
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
            activeTrackColor: const Color(0xFFD7F454),
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