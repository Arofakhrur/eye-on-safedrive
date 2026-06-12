import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/constants/app_data.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/widgets/eyeon_primary_button.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:eyeon/core/widgets/eyeon_address_autocomplete.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isLoading = false;

  // Step 1: Profil Pengendara (merged)
  final TextEditingController _usernameController = TextEditingController();
  String _selectedBloodType = 'A';
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _medicalNotesController = TextEditingController();

  // Step 2: Emergency Contact
  final List<EmergencyContact> _selectedContacts = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill username from current user email
    final user = SupabaseService().currentUser;
    if (user != null && user.email != null) {
      _usernameController.text = user.email!.split('@').first;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _addressController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSetup();
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);
    try {
      // Save Emergency Contacts
      if (_selectedContacts.isNotEmpty) {
        await SupabaseService().saveEmergencyContacts(_selectedContacts);
      }

      // Save Profile Data
      final profileData = {
        'address': _addressController.text,
        'blood_type': _selectedBloodType,
        'username': _usernameController.text,
        'medical_notes': _medicalNotesController.text,
      };
      await SupabaseService().updateProfile(profileData);
      await SupabaseService().updateUserMetadata(profileData);

      await PreferenceService().setContactSetup(true);

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.calibration);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving setup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickContact() async {
    if (_selectedContacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 3 kontak darurat.')),
      );
      return;
    }

    final status = await Permission.contacts.request();
    if (status.isGranted) {
      final contactId = await FlutterContacts.native.showPicker();
      if (contactId != null) {
        final fullContact = await FlutterContacts.get(
          contactId,
          properties: {ContactProperty.phone, ContactProperty.name},
        );
        if (fullContact != null && fullContact.phones.isNotEmpty) {
          String phone = fullContact.phones.first.number
              .replaceAll(RegExp(r'\s+'), '')
              .replaceAll('-', '')
              .replaceAll('(', '')
              .replaceAll(')', '');

          if (!phone.startsWith('+')) {
            if (phone.startsWith('0')) {
              phone = '+62${phone.substring(1)}';
            } else {
              phone = '+$phone';
            }
          }

          // Show dialog to input Telegram ID before adding
          if (mounted) {
            _showContactDialog(
              prefillName: fullContact.displayName ?? '',
              prefillPhone: phone,
            );
          }
        }
      }
    }
  }

  void _showContactDialog({
    String? prefillName,
    String? prefillPhone,
    String? prefillTelegramId,
    int? editIndex,
  }) {
    final nameController = TextEditingController(text: prefillName);
    final phoneController = TextEditingController(text: prefillPhone);
    final telegramController = TextEditingController(text: prefillTelegramId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          editIndex == null ? 'Tambah Kontak' : 'Edit Kontak',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: _buildInputDecoration(Icons.person_rounded, 'Nama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: _buildInputDecoration(Icons.phone_rounded, 'Nomor HP'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telegramController,
                decoration: _buildInputDecoration(
                  Icons.telegram_rounded,
                  'Chat ID Telegram (Opsional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final phone = phoneController.text.trim();
                  if (phone.isNotEmpty) {
                    _sendInviteLink(phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Isi nomor HP terlebih dahulu')),
                    );
                  }
                },
                icon: const Icon(Icons.share_rounded, size: 14),
                label: Text(
                  'Dapatkan ID (Kirim via WA)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kirim link ke kontak ini. Minta mereka klik START di bot, lalu tempelkan angka balasannya ke kolom di atas.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(color: Colors.black45),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final telegramId = telegramController.text.trim();

              if (name.isNotEmpty && phone.isNotEmpty) {
                final newContact = EmergencyContact(
                  userId: SupabaseService().currentUser?.id ?? '',
                  name: name,
                  phone: phone,
                  telegramChatId: telegramId.isEmpty ? null : telegramId,
                );

                setState(() {
                  if (editIndex != null) {
                    final oldContact = _selectedContacts[editIndex];
                    _selectedContacts[editIndex] = EmergencyContact(
                      id: oldContact.id,
                      userId: oldContact.userId,
                      name: name,
                      phone: phone,
                      telegramChatId: telegramId.isEmpty ? null : telegramId,
                    );
                  } else {
                    _selectedContacts.add(newContact);
                  }
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Simpan',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _sendInviteLink(String phone) async {
    const text =
        'Halo! Saya menggunakan aplikasi keselamatan berkendara EYE-ON! dan menjadikanmu sebagai kontak darurat saya. Tolong klik link ini: https://t.me/EyeonEmergency_bot lalu tekan tombol START. Setelah itu, tolong kirimkan angka Chat ID balasan dari bot tersebut ke saya ya! Terima kasih.';
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final smsUrl = Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka aplikasi pesan')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator — now 3 steps instead of 4
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: index <= _currentIndex ? AppColors.primary : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  _buildProfileStep(),
                  _buildEmergencyStep(),
                  _buildFinishStep(),
                ],
              ),
            ),

            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: EyeonPrimaryButton(
                label: _currentIndex == 2 ? 'Selesaikan Setup' : 'Lanjutkan',
                isLoading: _isLoading,
                onTap: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStep() {
    final user = SupabaseService().currentUser;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profil Pengendara',
              style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Lengkapi data diri Anda untuk keselamatan berkendara.',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary,
                child: Text(
                  user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                  style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Username
            _buildFieldLabel('Nama Pengguna'),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: _buildInputDecoration(Icons.person_outline_rounded, 'Masukkan nama pengguna...'),
            ),
            const SizedBox(height: 20),

            // Blood Type
            _buildFieldLabel('Golongan Darah'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedBloodType,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 28),
              items: AppData.bloodTypes.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              )).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedBloodType = val);
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.bloodtype_rounded, color: Colors.black45),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 20),

            // Address (using EyeonAddressAutocomplete)
            _buildFieldLabel('Alamat & Asal Daerah'),
            const SizedBox(height: 8),
            EyeonAddressAutocomplete(
              initialValue: _addressController.text,
              hintText: 'Cari alamat dari OpenStreetMap...',
              icon: Icons.location_on_rounded,
              externalController: _addressController,
            ),
            const SizedBox(height: 20),

            // Medical Notes
            _buildFieldLabel('Catatan Medis / Alergi'),
            const SizedBox(height: 4),
            Text(
              '(Opsional)',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.black38),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _medicalNotesController,
              maxLines: 3,
              decoration: _buildInputDecoration(
                Icons.medical_information_rounded,
                'Contoh: Alergi penisilin, asma...',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildEmergencyStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kontak Darurat',
              style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Siapa yang harus kami hubungi saat terjadi kecelakaan? (Maks. 3 kontak)',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (_selectedContacts.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedContacts.length,
                itemBuilder: (context, index) {
                  final contact = _selectedContacts[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Colors.black87),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(contact.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                              Text(contact.phone, style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 13)),
                              if (contact.telegramChatId != null && contact.telegramChatId!.isNotEmpty)
                                Text(
                                  'Telegram ID: ${contact.telegramChatId}',
                                  style: GoogleFonts.plusJakartaSans(color: AppColors.telegramBlue, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showContactDialog(
                                prefillName: contact.name,
                                prefillPhone: contact.phone,
                                prefillTelegramId: contact.telegramChatId,
                                editIndex: index,
                              ),
                              icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedContacts.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (_selectedContacts.length < 3)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickContact,
                  icon: const Icon(Icons.contacts_rounded, color: Colors.black87),
                  label: Text(
                    'Pilih dari Kontak',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Text(
            'Langkah Terakhir!',
            style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            'Data Anda telah tersimpan. Langkah selanjutnya adalah kalibrasi kamera untuk mendeteksi wajah Anda.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }
}
