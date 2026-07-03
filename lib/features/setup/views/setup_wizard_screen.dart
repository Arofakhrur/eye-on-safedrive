import 'package:flutter/material.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/widgets/eyeon_primary_button.dart';
import 'package:eyeon/core/utils/notification_helper.dart';

import 'package:eyeon/features/setup/logic/setup_wizard_controller.dart';
import 'package:eyeon/features/setup/widgets/setup_wizard_steps.dart';
import 'package:eyeon/features/setup/widgets/setup_contact_widgets.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final SetupWizardController _controller = SetupWizardController();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _medicalNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameController.text = _controller.username;
    _addressController.text = _controller.address;
    _medicalNotesController.text = _controller.medicalNotes;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _addressController.dispose();
    _medicalNotesController.dispose();
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              children: [
                // Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          decoration: BoxDecoration(
                            color: index <= _controller.currentIndex ? AppColors.primary : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _controller.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _controller.setCurrentIndex,
                    children: [
                      SetupWizardProfileStep(
                        controller: _controller,
                        usernameController: _usernameController,
                        addressController: _addressController,
                        medicalNotesController: _medicalNotesController,
                      ),
                      SetupWizardEmergencyStep(
                        controller: _controller,
                        onPickContact: () {
                          _controller.pickContact(
                            (name, phone) {
                              if (mounted) {
                                _showContactDialog(prefillName: name, prefillPhone: phone);
                              }
                            },
                            (msg) {
                              if (mounted) {
                                NotificationHelper.showTop(context, message: msg, type: NotificationType.warning);
                              }
                            }
                          );
                        },
                        onShowContactDialog: (name, phone, telegramId, editIndex) {
                          _showContactDialog(
                            prefillName: name,
                            prefillPhone: phone,
                            prefillTelegramId: telegramId,
                            editIndex: editIndex,
                          );
                        },
                      ),
                      const SetupWizardFinishStep(),
                    ],
                  ),
                ),

                // Bottom Navigation
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: EyeonPrimaryButton(
                    label: _controller.currentIndex == 2 ? 'Selesaikan Setup' : 'Lanjutkan',
                    isLoading: _controller.isLoading,
                    onTap: () async {
                      try {
                        await _controller.nextPage(() {
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, AppRoutes.calibration);
                          }
                        });
                      } catch (e) {
                        if (context.mounted) {
                          NotificationHelper.showTop(
                            context,
                            message: 'Error saving setup: $e',
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
