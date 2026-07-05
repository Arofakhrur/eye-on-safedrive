import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/utils/validators.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

class ContactDialog {
  static void show({
    required BuildContext context,
    String? prefillName,
    String? prefillPhone,
    String? prefillTelegramId,
    int? editIndex,
    required void Function(String phone, void Function(String) onError) onSendInvite,
    required void Function(String name, String phone, String telegramId, int? editIndex) onSave,
  }) {
    final nameController = TextEditingController(text: prefillName);
    final phoneController = TextEditingController(text: prefillPhone);
    final telegramController = TextEditingController(text: prefillTelegramId);

    InputDecoration buildInputDecoration(IconData icon, String hint) {
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
                decoration: buildInputDecoration(Icons.person_rounded, 'Nama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: buildInputDecoration(Icons.phone_rounded, 'Nomor HP (contoh: +6281234567890)'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+]'))],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telegramController,
                decoration: buildInputDecoration(
                  Icons.telegram_rounded,
                  'Chat ID Telegram (Wajib untuk Notif SOS)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final phone = phoneController.text.trim();

                  if (phone.isEmpty) {
                    NotificationHelper.showTop(
                      ctx,
                      message: 'Isi nomor HP terlebih dahulu',
                      type: NotificationType.warning,
                    );
                    return;
                  }

                  final phoneError = AppValidators.validatePhone(phone);
                  if (phoneError != null) {
                    NotificationHelper.showTop(
                      ctx,
                      message: phoneError,
                      type: NotificationType.warning,
                    );
                    return;
                  }

                  onSendInvite(phone, (errorMsg) {
                    if (ctx.mounted) {
                      NotificationHelper.showTop(
                        ctx,
                        message: errorMsg,
                        type: NotificationType.error,
                      );
                    }
                  });
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
                'Kirim tautan ke kontak ini. Minta mereka menekan START di bot, lalu tempelkan ID Chat balasannya ke kolom di atas.',
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

              // Per-field validation — show only the first missing/invalid field
              if (name.isEmpty) {
                NotificationHelper.showTop(
                  ctx,
                  message: 'Nama kontak wajib diisi',
                  type: NotificationType.warning,
                );
                return;
              }

              if (phone.isEmpty) {
                NotificationHelper.showTop(
                  ctx,
                  message: 'Nomor HP wajib diisi',
                  type: NotificationType.warning,
                );
                return;
              }

              final phoneError = AppValidators.validatePhone(phone);
              if (phoneError != null) {
                NotificationHelper.showTop(
                  ctx,
                  message: phoneError,
                  type: NotificationType.warning,
                );
                return;
              }

              if (telegramId.isEmpty) {
                NotificationHelper.showTop(
                  ctx,
                  message: 'Chat ID Telegram wajib diisi untuk sistem SOS',
                  type: NotificationType.warning,
                );
                return;
              }

              onSave(name, phone, telegramId, editIndex);
              Navigator.pop(ctx);
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
}

class ContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String telegramChatId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContactCard({
    super.key,
    required this.name,
    required this.phone,
    required this.telegramChatId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                Text(
                  phone,
                  style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 13),
                ),
                if (telegramChatId.isNotEmpty)
                  Text(
                    'Telegram ID: $telegramChatId',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.telegramBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
