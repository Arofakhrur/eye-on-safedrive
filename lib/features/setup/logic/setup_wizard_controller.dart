import 'package:flutter/material.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SetupWizardController extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentIndex = 0;
  bool _isLoading = false;

  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;

  // Step 1: Profil Pengendara
  String username = '';
  String selectedBloodType = 'A';
  String address = '';
  String medicalNotes = '';

  // Step 2: Emergency Contact
  final List<EmergencyContact> _selectedContacts = [];
  List<EmergencyContact> get selectedContacts => _selectedContacts;

  SetupWizardController() {
    // Pre-fill username from current user email
    final user = SupabaseService().currentUser;
    if (user != null && user.email != null) {
      username = user.email!.split('@').first;
    }
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> nextPage(VoidCallback onComplete) async {
    if (_currentIndex < 2) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await finishSetup(onComplete);
    }
  }

  Future<void> finishSetup(VoidCallback onComplete) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Save Emergency Contacts
      if (_selectedContacts.isNotEmpty) {
        await SupabaseService().saveEmergencyContacts(_selectedContacts);
      }

      // Save Profile Data
      final profileData = {
        'address': address,
        'blood_type': selectedBloodType,
        'full_name': username,
        'emergency_medical_notes': medicalNotes,
      };
      await SupabaseService().updateProfile(profileData);
      await SupabaseService().updateUserMetadata(profileData);

      await PreferenceService().setContactSetup(true);

      onComplete();
    } catch (e) {
      debugPrint('Error saving setup: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickContact(Function(String, String) onShowDialog, Function(String) onWarning) async {
    if (_selectedContacts.length >= AppLimits.maxEmergencyContacts) {
      onWarning('Maksimal ${AppLimits.maxEmergencyContacts} kontak darurat.');
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
              phone = '+${EmergencyConfig.indonesianCountryCode}${phone.substring(1)}';
            } else {
              phone = '+$phone';
            }
          }

          onShowDialog(fullContact.displayName ?? '', phone);
        }
      }
    }
  }

  void addOrUpdateContact({
    required String name,
    required String phone,
    required String telegramId,
    int? editIndex,
  }) {
    final newContact = EmergencyContact(
      userId: SupabaseService().currentUser?.id ?? '',
      name: name,
      phone: phone,
      telegramChatId: telegramId,
    );

    if (editIndex != null) {
      final oldContact = _selectedContacts[editIndex];
      _selectedContacts[editIndex] = EmergencyContact(
        id: oldContact.id,
        userId: oldContact.userId,
        name: name,
        phone: phone,
        telegramChatId: telegramId,
      );
    } else {
      _selectedContacts.add(newContact);
    }
    notifyListeners();
  }

  void removeContact(int index) {
    _selectedContacts.removeAt(index);
    notifyListeners();
  }

  Future<void> sendInviteLink(String phone, Function(String) onError) async {
    const text = AppUrls.telegramInviteMessage;

    // Normalize: keep only digits (strip +, spaces, dashes, parens)
    // wa.me expects digits only WITH country code, no leading +
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // If not already with country code (starts with 0), convert to +62
    if (!phone.startsWith('+') && cleanPhone.startsWith('0')) {
      cleanPhone = '${EmergencyConfig.indonesianCountryCode}${cleanPhone.substring(1)}';
    }

    if (cleanPhone.isEmpty) {
      onError('Nomor HP tidak valid');
      return;
    }

    final url = Uri.parse(
      '${AppUrls.whatsAppUrl(cleanPhone)}?text=${Uri.encodeComponent(text)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final smsUrl = Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        onError('Tidak dapat membuka aplikasi pesan');
      }
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
