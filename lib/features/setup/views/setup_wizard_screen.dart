import 'dart:async';
import 'dart:convert';
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
import 'package:http/http.dart' as http;
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

  // Step 1: Address
  final TextEditingController _addressController = TextEditingController();
  List<dynamic> _addressResults = [];
  Timer? _debounce;
  String _selectedAddress = '';

  // Step 3: Emergency Contact
  final List<EmergencyContact> _selectedContacts = [];

  // Step 2: Profile Additional
  String _selectedBloodType = 'A';
  final TextEditingController _originController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _addressController.dispose();
    _originController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < 3) {
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
      // Save Emergency Contact
      if (_selectedContacts.isNotEmpty) {
        await SupabaseService().saveEmergencyContacts(_selectedContacts);
      }
      
      // Save Profile Data
      await SupabaseService().updateProfile({
        'address': _selectedAddress,
        'blood_type': _selectedBloodType,
        'origin': _originController.text,
      });
      await SupabaseService().updateUserMetadata({
        'address': _selectedAddress,
        'blood_type': _selectedBloodType,
        'origin': _originController.text,
      });

      await PreferenceService().setContactSetup(true);

      if (mounted) {
        // Go to calibration screen as the final technical step
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
        final fullContact = await FlutterContacts.get(contactId, properties: {ContactProperty.phone, ContactProperty.name});
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
          setState(() {
            _selectedContacts.add(EmergencyContact(
              userId: SupabaseService().currentUser?.id ?? '',
              name: fullContact.displayName ?? '',
              phone: phone,
            ));
          });
        }
      }
    }
  }

  void _onAddressSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() => _addressResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final url = Uri.parse(AppUrls.nominatimSearchUrl(query));
        final response = await http.get(url, headers: {'User-Agent': 'EyeOnSafeDrive/1.0'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) setState(() => _addressResults = data);
        }
      } catch (e) {
        debugPrint('Address search error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(4, (index) {
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
                  _buildAddressStep(),
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
                label: _currentIndex == 3 ? 'Selesaikan Setup' : 'Lanjutkan',
                isLoading: _isLoading,
                onTap: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alamat Utama',
            style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Tentukan lokasi alamat tempat tinggal Anda saat ini.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _addressController,
            onChanged: _onAddressSearch,
            decoration: InputDecoration(
              hintText: 'Ketik alamat...',
              prefixIcon: const Icon(Icons.location_on_rounded),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedAddress.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedAddress, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600))),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _addressResults.length,
                itemBuilder: (context, index) {
                  final item = _addressResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_city_rounded),
                    title: Text(item['display_name'] ?? ''),
                    onTap: () {
                      setState(() {
                        _selectedAddress = item['display_name'];
                        _addressController.text = _selectedAddress;
                        _addressResults = [];
                      });
                    },
                  );
                },
              ),
            ),
        ],
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
              'Verifikasi informasi data diri Anda dan lengkapi data berikut.',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 32),
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
            _buildInfoRow('Email', user?.email ?? 'Unknown'),
            const Divider(height: 24),
            Text(
              'Golongan Darah',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedBloodType,
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
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Asal Daerah',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            EyeonAddressAutocomplete(
              initialValue: _originController.text,
              hintText: 'Masukkan asal daerah...',
              icon: Icons.public_rounded,
              externalController: _originController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 16)),
        Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16, color: color ?? Colors.black)),
      ],
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
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedContacts.removeAt(index);
                            });
                          },
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
