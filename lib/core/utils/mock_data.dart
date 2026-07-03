import 'package:eyeon/core/models/emergency_contact.dart';

class MockData {
  static final List<Map<String, dynamic>> fakeRideLogs = List.generate(
    3,
    (index) => {
      'id': 'fake-id-$index',
      'start_time': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
      'end_time': DateTime.now()
          .subtract(Duration(days: index))
          .add(const Duration(minutes: 45))
          .toIso8601String(),
      'distance': 15.4,
      'microsleep_alerts': index % 2 == 0 ? 2 : 0,
      'accident_alerts': index == 1 ? 1 : 0,
      'video_url': null,
      'latitude': -6.2,
      'longitude': 106.8,
    },
  );

  static final List<EmergencyContact> fakeContacts = List.generate(
    2,
    (index) => EmergencyContact(
      id: 'fake-$index',
      userId: 'fake',
      name: 'Nama Kontak Palsu $index',
      phone: '081234567890',
      telegramChatId: '123456',
    ),
  );
}
