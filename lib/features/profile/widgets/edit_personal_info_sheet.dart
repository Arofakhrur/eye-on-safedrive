import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_data.dart';
import 'package:eyeon/core/widgets/eyeon_address_autocomplete.dart';
import 'package:eyeon/features/profile/logic/profile_controller.dart';

class EditPersonalInfoSheet extends StatefulWidget {
  final ProfileController controller;

  const EditPersonalInfoSheet({super.key, required this.controller});

  @override
  State<EditPersonalInfoSheet> createState() => _EditPersonalInfoSheetState();
}

class _EditPersonalInfoSheetState extends State<EditPersonalInfoSheet> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _originController;
  late TextEditingController _medicalNotesController;
  late String _selectedBloodType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.userName);
    _addressController = TextEditingController(
      text: widget.controller.address == 'Not set' ? '' : widget.controller.address,
    );
    _selectedBloodType = widget.controller.bloodType == 'Not set' ? 'A' : widget.controller.bloodType;
    _originController = TextEditingController(
      text: widget.controller.origin == 'Not set' ? '' : widget.controller.origin,
    );
    _medicalNotesController = TextEditingController(text: widget.controller.medicalNotes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _originController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
                controller: _nameController,
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
                initialValue: _addressController.text,
                hintText: 'Cari alamat...',
                icon: Icons.location_on_rounded,
                externalController: _addressController,
              ),

              const SizedBox(height: 16),

              // Blood Type with Dropdown
              _buildSectionLabel('Golongan Darah'),
              DropdownButtonFormField<String>(
                initialValue: _selectedBloodType,
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
                    setState(() => _selectedBloodType = val);
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
                initialValue: _originController.text,
                hintText: 'Masukkan asal daerah...',
                icon: Icons.public_rounded,
                externalController: _originController,
              ),

              const SizedBox(height: 16),

              // Medical Notes
              _buildSectionLabel('Catatan Medis'),
              TextField(
                controller: _medicalNotesController,
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
                      onPressed: widget.controller.isSaving
                          ? null
                          : () => Navigator.pop(context),
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
                      onPressed: widget.controller.isSaving
                          ? null
                          : () async {
                              try {
                                await widget.controller.updatePersonalInfo(
                                  name: _nameController.text.trim(),
                                  address: _addressController.text.trim(),
                                  bloodType: _selectedBloodType,
                                  origin: _originController.text.trim(),
                                  medicalNotes: _medicalNotesController.text.trim(),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Informasi berhasil disimpan!',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF4CAF50),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              }
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
                      child: widget.controller.isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                              ),
                            )
                          : Text(
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
    );
  }
}
