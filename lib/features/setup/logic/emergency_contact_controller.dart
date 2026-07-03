import 'package:flutter/material.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/models/emergency_contact.dart';
import 'package:eyeon/core/services/supabase_service.dart';
import 'package:eyeon/core/services/preference_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactController extends ChangeNotifier {
  final List<EmergencyContact> _contacts = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;

  List<EmergencyContact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;

  EmergencyContactController() {
    loadExistingContacts();
  }

  Future<void> loadExistingContacts() async {
    try {
      final fetchedContacts = await SupabaseService().getEmergencyContacts();
      _contacts.addAll(fetchedContacts);
      _isInitialLoading = false;
      notifyListeners();
    } catch (e) {
      _isInitialLoading = false;
      notifyListeners();
      throw Exception('Gagal memuat kontak. Periksa koneksi internet Anda.');
    }
  }

  Future<void> saveContacts(VoidCallback onSuccess) async {
    if (_contacts.isEmpty) {
      throw Exception('Please add at least one emergency contact.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService().saveEmergencyContacts(_contacts);
      await PreferenceService().setContactSetup(true);
      onSuccess();
    } catch (e) {
      debugPrint('Failed to save contacts: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickContact(Function(String, String) onShowDialog, Function(String) onWarning) async {
    if (_contacts.length >= AppLimits.maxEmergencyContacts) {
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
    notifyListeners();
  }

  void removeContact(int index) {
    _contacts.removeAt(index);
    notifyListeners();
  }

  Future<void> sendInviteLink(String phone, Function(String) onError) async {
    const text = AppUrls.telegramInviteMessage;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
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
}
