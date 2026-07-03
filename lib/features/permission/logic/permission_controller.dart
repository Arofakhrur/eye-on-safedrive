import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eyeon/core/services/preference_service.dart';

class PermissionController extends ChangeNotifier with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationGranted = false;
  bool _contactsGranted = false;
  bool _microphoneGranted = false;
  bool _storageGranted = false;
  bool _phoneGranted = false;
  bool _isRequesting = false;

  bool get locationGranted => _locationGranted;
  bool get cameraGranted => _cameraGranted;
  bool get notificationGranted => _notificationGranted;
  bool get contactsGranted => _contactsGranted;
  bool get microphoneGranted => _microphoneGranted;
  bool get storageGranted => _storageGranted;
  bool get phoneGranted => _phoneGranted;
  bool get isRequesting => _isRequesting;

  bool get allGranted =>
      _locationGranted &&
      _cameraGranted &&
      _notificationGranted &&
      _contactsGranted &&
      _microphoneGranted &&
      _storageGranted &&
      _phoneGranted;

  PermissionController() {
    WidgetsBinding.instance.addObserver(this);
    checkCurrentPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkCurrentPermissions();
    }
  }

  Future<void> checkCurrentPermissions() async {
    final locationStatus = await Permission.location.status;
    final cameraStatus = await Permission.camera.status;
    final notificationStatus = await Permission.notification.status;
    final contactsStatus = await Permission.contacts.status;
    final microphoneStatus = await Permission.microphone.status;
    final phoneStatus = await Permission.phone.status;
    
    final storageStatus = await Permission.storage.status;
    final videoStatus = await Permission.videos.status;
    
    _locationGranted = locationStatus.isGranted;
    _cameraGranted = cameraStatus.isGranted;
    _notificationGranted = notificationStatus.isGranted;
    _contactsGranted = contactsStatus.isGranted;
    _microphoneGranted = microphoneStatus.isGranted;
    _storageGranted = storageStatus.isGranted || videoStatus.isGranted;
    _phoneGranted = phoneStatus.isGranted;

    notifyListeners();
  }

  Future<void> requestSinglePermission(Permission permission, Function(Permission) onPermanentlyDenied) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) {
      onPermanentlyDenied(permission);
    }
    await checkCurrentPermissions();
  }

  Future<void> grantAllPermissions(
    Function(Permission) onPermanentlyDenied,
    VoidCallback onSuccess
  ) async {
    _isRequesting = true;
    notifyListeners();

    if (!_locationGranted) await requestSinglePermission(Permission.location, onPermanentlyDenied);
    if (!_cameraGranted) await requestSinglePermission(Permission.camera, onPermanentlyDenied);
    if (!_microphoneGranted) await requestSinglePermission(Permission.microphone, onPermanentlyDenied);
    if (!_storageGranted) {
      await requestSinglePermission(Permission.videos, onPermanentlyDenied);
      await requestSinglePermission(Permission.storage, onPermanentlyDenied);
    }
    if (!_notificationGranted) await requestSinglePermission(Permission.notification, onPermanentlyDenied);
    if (!_contactsGranted) await requestSinglePermission(Permission.contacts, onPermanentlyDenied);
    if (!_phoneGranted) await requestSinglePermission(Permission.phone, onPermanentlyDenied);

    await checkCurrentPermissions();
    
    _isRequesting = false;
    notifyListeners();

    if (allGranted) {
      PreferenceService().setPermissionsGranted(true);
      onSuccess();
    }
  }
}
