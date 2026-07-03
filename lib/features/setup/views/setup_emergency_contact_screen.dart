import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/widgets/eyeon_top_bar.dart';
import 'package:eyeon/core/widgets/eyeon_primary_button.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

class SetupEmergencyContactScreen extends StatefulWidget {
  const SetupEmergencyContactScreen({super.key});

  @override
  State<SetupEmergencyContactScreen> createState() =>
      _SetupEmergencyContactScreenState();
}

class _SetupEmergencyContactScreenState
    extends State<SetupEmergencyContactScreen> {
  final List<EmergencyContact> _contacts = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingContacts();
  }

  Future<void> _loadExistingContacts() async {
    try {
      final contacts = await SupabaseService().getEmergencyContacts();
      setState(() {
        _contacts.addAll(contacts);
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() => _isInitialLoading = false);
      if (mounted) {
        NotificationHelper.showTop(
          context,
          message: 'Gagal memuat kontak. Periksa koneksi internet Anda.',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (_contacts.isEmpty) {
      NotificationHelper.showTop(
        context,
        message: 'Please add at least one emergency contact.',
        type: NotificationType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().saveEmergencyContacts(_contacts);
      await PreferenceService().setContactSetup(true);

      if (mounted) {
        final isCalibrated = PreferenceService().isCalibrated;
        if (isCalibrated) {
          // User is editing from Profile → just go back
          Navigator.pop(context);
        } else {
          // New user setup flow → go to calibration
          Navigator.of(context).pushReplacementNamed(AppRoutes.calibration);
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showTop(
          context,
          message: 'Failed to save contacts: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  Future<void> _showAddContactSheet() async {
    if (_contacts.length >= AppLimits.maxEmergencyContacts) {
      NotificationHelper.showTop(
        context,
        message: 'Maksimal ${AppLimits.maxEmergencyContacts} kontak darurat.',
        type: NotificationType.warning,
      );
      return;
    }

    final contact = await _pickContact();
    if (contact != null) {
      await _showContactDialog(
        prefillName: contact['name'],
        prefillPhone: contact['phone'],
      );
    }
  }

  Future<void> _showContactDialog({
    String? prefillName,
    String? prefillPhone,
    String? prefillTelegramId,
    int? editIndex,
  }) async {
    final nameController = TextEditingController(text: prefillName);
    final phoneController = TextEditingController(text: prefillPhone);
    final telegramController = TextEditingController(text: prefillTelegramId);

    await showDialog(
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
                decoration: _buildInputDecoration(
                  Icons.phone_rounded,
                  'Nomor HP',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telegramController,
                decoration: _buildInputDecoration(
                  Icons.telegram_rounded,
                  'Chat ID Telegram (Wajib untuk Notif SOS)',
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
                    NotificationHelper.showTop(
                      context,
                      message: 'Isi nomor HP terlebih dahulu',
                      type: NotificationType.warning,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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

              if (name.isEmpty || phone.isEmpty || telegramId.isEmpty) {
                NotificationHelper.showTop(
                  context,
                  message: 'Nama, Nomor HP, dan Chat ID Telegram wajib diisi mutlak untuk sistem SOS!',
                  type: NotificationType.warning,
                );
                return;
              }

              if (name.isNotEmpty && phone.isNotEmpty && telegramId.isNotEmpty) {
                final newContact = EmergencyContact(
                  userId: SupabaseService().currentUser?.id ?? '',
                  name: name,
                  phone: phone,
                  telegramChatId: telegramId,
                );

                setState(() {
                  if (editIndex != null) {
                    final oldContact = _contacts[editIndex];
                    _contacts[editIndex] = EmergencyContact(
                      id: oldContact.id,
                      userId: oldContact.userId,
                      name: name,
                      phone: phone,
                      telegramChatId: telegramId,
                    );
                  } else {
                    _contacts.add(newContact);
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

  Future<Map<String, String>?> _pickContact() async {
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
              phone = '+${EmergencyConfig.indonesianCountryCode}${phone.substring(1)}';
            } else {
              phone = '+$phone';
            }
          }
          return {'name': fullContact.displayName ?? '', 'phone': phone};
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const EyeonTopBar(),
            if (_isInitialLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed Header Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Setup',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Who should we notify if something happens? You can add multiple people.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    // Scrollable List Section
                    Expanded(
                      child: _contacts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _buildEmptyState(),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                return _buildContactCard(
                                  _contacts[index],
                                  index,
                                );
                              },
                            ),
                    ),

                    // Fixed Bottom Section
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24), // Add space here
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildAddButton(),
                          ),
                          const SizedBox(height: 24),
                          EyeonPrimaryButton(
                            label: 'Save & Continue',
                            icon: Icons.arrow_forward_rounded,
                            isLoading: _isLoading,
                            onTap: _handleSave,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.contact_phone_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts added yet',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.black38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  contact.phone,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
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
                icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                tooltip: 'Edit Kontak',
              ),
              IconButton(
                onPressed: () => _removeContact(index),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
                tooltip: 'Hapus Kontak',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendInviteLink(String phone) async {
    const text = AppUrls.telegramInviteMessage;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final url = Uri.parse(
      '${AppUrls.whatsAppUrl(cleanPhone)}?text=${Uri.encodeComponent(text)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback SMS
      final smsUrl = Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        if (mounted) {
          NotificationHelper.showTop(
            context,
            message: 'Tidak dapat membuka aplikasi pesan',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _showAddContactSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              'Add New Contact',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
