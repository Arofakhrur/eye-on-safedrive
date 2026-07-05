import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/widgets/eyeon_top_bar.dart';
import 'package:eyeon/core/widgets/eyeon_primary_button.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/utils/notification_helper.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:eyeon/features/setup/logic/emergency_contact_controller.dart';
import 'package:eyeon/features/setup/widgets/setup_contact_widgets.dart';

class SetupEmergencyContactScreen extends StatefulWidget {
  const SetupEmergencyContactScreen({super.key});

  @override
  State<SetupEmergencyContactScreen> createState() => _SetupEmergencyContactScreenState();
}

class _SetupEmergencyContactScreenState extends State<SetupEmergencyContactScreen> {
  final EmergencyContactController _controller = EmergencyContactController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.isInitialLoading == false && _controller.contacts.isEmpty) {
        // Just empty, no problem
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showContactDialog({
    String? prefillName,
    String? prefillPhone,
    String? prefillTelegramId,
    int? editIndex,
  }) {
    ContactDialog.show(
      context: context,
      prefillName: prefillName,
      prefillPhone: prefillPhone,
      prefillTelegramId: prefillTelegramId,
      editIndex: editIndex,
      onSendInvite: (phone, onError) {
        _controller.sendInviteLink(phone, onError);
      },
      onSave: (name, phone, telegramId, editIndex) {
        _controller.addOrUpdateContact(
          name: name,
          phone: phone,
          telegramId: telegramId,
          editIndex: editIndex,
        );
      },
    );
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
                const EyeonTopBar(),
                if (_controller.isInitialLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Siapa yang harus kami hubungi saat terjadi kecelakaan? (Maks. ${AppLimits.maxEmergencyContacts} kontak)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 24),
                            if (_controller.contacts.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _controller.contacts.length,
                                itemBuilder: (context, index) {
                                  final contact = _controller.contacts[index];
                                  return ContactCard(
                                    name: contact.name,
                                    phone: contact.phone,
                                    telegramChatId: contact.telegramChatId,
                                    onEdit: () => _showContactDialog(
                                      prefillName: contact.name,
                                      prefillPhone: contact.phone,
                                      prefillTelegramId: contact.telegramChatId,
                                      editIndex: index,
                                    ),
                                    onDelete: () => _controller.removeContact(index),
                                  );
                                },
                              ),
                            if (_controller.contacts.length < AppLimits.maxEmergencyContacts)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _controller.pickContact((name, phone) {
                                      if (mounted) {
                                        _showContactDialog(prefillName: name, prefillPhone: phone);
                                      }
                                    }, (msg) {
                                      if (mounted) {
                                        NotificationHelper.showTop(context, message: msg, type: NotificationType.warning);
                                      }
                                    });
                                  },
                                  icon: Icon(Icons.contacts_rounded, color: AppColors.textPrimary.withValues(alpha: 0.87)),
                                  label: Text(
                                    'Pilih dari Kontak',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary.withValues(alpha: 0.87),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.26)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: EyeonPrimaryButton(
                    label: 'Simpan',
                    isLoading: _controller.isLoading,
                    onTap: () async {
                      try {
                        await _controller.saveContacts(() {
                          if (context.mounted) {
                            final isCalibrated = PreferenceService().isCalibrated;
                            if (isCalibrated) {
                              Navigator.pop(context);
                            } else {
                              Navigator.of(context).pushReplacementNamed(AppRoutes.calibration);
                            }
                          }
                        });
                      } catch (e) {
                        if (context.mounted) {
                          NotificationHelper.showTop(
                            context,
                            message: e.toString(),
                            type: NotificationType.error,
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
