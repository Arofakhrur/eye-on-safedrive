import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/constants/app_data.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/widgets/eyeon_address_autocomplete.dart';
import 'package:eyeon/features/setup/logic/setup_wizard_controller.dart';
import 'package:eyeon/features/setup/widgets/setup_contact_widgets.dart';
import 'package:eyeon/core/services/supabase_service.dart';

class SetupWizardProfileStep extends StatelessWidget {
  final SetupWizardController controller;
  final TextEditingController usernameController;
  final TextEditingController addressController;
  final TextEditingController medicalNotesController;

  const SetupWizardProfileStep({
    super.key,
    required this.controller,
    required this.usernameController,
    required this.addressController,
    required this.medicalNotesController,
  });

  InputDecoration _buildInputDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20, color: AppColors.textPrimary.withValues(alpha: 0.45)),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary.withValues(alpha: 0.26)),
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
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary.withValues(alpha: 0.87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            SizedBox(height: 8),
            Text(
              'Lengkapi data diri Anda untuk keselamatan berkendara.',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary,
                child: Text(
                  user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                  style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Username
            _buildFieldLabel('Nama Pengguna'),
            const SizedBox(height: 8),
            TextField(
              controller: usernameController,
              decoration: _buildInputDecoration(Icons.person_outline_rounded, 'Masukkan nama pengguna...'),
              onChanged: (val) => controller.username = val,
            ),
            const SizedBox(height: 20),

            // Blood Type
            _buildFieldLabel('Golongan Darah'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: controller.selectedBloodType,
              dropdownColor: AppColors.background,
              icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 28),
              items: AppData.bloodTypes.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary.withValues(alpha: 0.87))),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  controller.selectedBloodType = val;
                }
              },
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.bloodtype_rounded, color: AppColors.textPrimary.withValues(alpha: 0.45)),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            SizedBox(height: 20),

            // Address
            _buildFieldLabel('Alamat & Asal Daerah'),
            const SizedBox(height: 8),
            EyeonAddressAutocomplete(
              initialValue: addressController.text,
              hintText: 'Cari alamat dari OpenStreetMap...',
              icon: Icons.location_on_rounded,
              externalController: addressController,
            ),
            const SizedBox(height: 20),

            // Medical Notes
            _buildFieldLabel('Catatan Medis / Alergi'),
            const SizedBox(height: 4),
            Text(
              '(Opsional)',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary.withValues(alpha: 0.38)),
            ),
            SizedBox(height: 8),
            TextField(
              controller: medicalNotesController,
              maxLines: 3,
              decoration: _buildInputDecoration(
                Icons.medical_information_rounded,
                'Contoh: Alergi penisilin, asma...',
              ),
              onChanged: (val) => controller.medicalNotes = val,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class SetupWizardEmergencyStep extends StatelessWidget {
  final SetupWizardController controller;
  final VoidCallback onPickContact;
  final Function(String?, String?, String?, int?) onShowContactDialog;

  const SetupWizardEmergencyStep({
    super.key,
    required this.controller,
    required this.onPickContact,
    required this.onShowContactDialog,
  });

  @override
  Widget build(BuildContext context) {
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
              'Siapa yang harus kami hubungi saat terjadi kecelakaan? (Maks. ${AppLimits.maxEmergencyContacts} kontak)',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (controller.selectedContacts.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.selectedContacts.length,
                itemBuilder: (context, index) {
                  final contact = controller.selectedContacts[index];
                  return ContactCard(
                    name: contact.name,
                    phone: contact.phone,
                    telegramChatId: contact.telegramChatId,
                    onEdit: () => onShowContactDialog(
                      contact.name,
                      contact.phone,
                      contact.telegramChatId,
                      index,
                    ),
                    onDelete: () => controller.removeContact(index),
                  );
                },
              ),
            if (controller.selectedContacts.length < AppLimits.maxEmergencyContacts)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPickContact,
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
            SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pesan SOS akan dikirimkan beserta lokasi Live GPS dan video rekaman insiden.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.blue.shade800),
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
}

class SetupWizardFinishStep extends StatelessWidget {
  const SetupWizardFinishStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 80),
          ),
          const SizedBox(height: 32),
          Text(
            'Langkah Terakhir!',
            style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Data Anda telah tersimpan.\nSelanjutnya, mari kalibrasi deteksi wajah agar sistem mengenali kantuk Anda dengan akurat.',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
