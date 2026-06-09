import 'package:flutter/material.dart';
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

class SetupEmergencyContactScreen extends StatefulWidget {
  const SetupEmergencyContactScreen({super.key});

  @override
  State<SetupEmergencyContactScreen> createState() => _SetupEmergencyContactScreenState();
}

class _SetupEmergencyContactScreenState extends State<SetupEmergencyContactScreen> {
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
      // Silent fail or show snackbar
    }
  }

  Future<void> _handleSave() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one emergency contact.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().saveEmergencyContacts(_contacts);
      await PreferenceService().setContactSetup(true);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.calibration);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save contacts: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addContact(String name, String phone) {
    setState(() {
      _contacts.add(EmergencyContact(
        userId: SupabaseService().currentUser?.id ?? '',
        name: name,
        phone: phone,
      ));
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  Future<void> _showAddContactSheet() async {
    if (_contacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maksimal 3 kontak darurat.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final contact = await _pickContact();
    if (contact != null) {
      _addContact(contact['name']!, contact['phone']!);
    }
  }

  Future<Map<String, String>?> _pickContact() async {
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
                    child: CircularProgressIndicator(color: AppColors.primary)),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: _buildEmptyState(),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                return _buildContactCard(_contacts[index], index);
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
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.contact_phone_outlined, size: 48, color: Colors.grey.shade300),
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
          IconButton(
            onPressed: () => _removeContact(index),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
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
