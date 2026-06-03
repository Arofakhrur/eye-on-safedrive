class EmergencyContact {
  final String? id;
  final String userId;
  final String name;
  final String phone;
  final String? telegramChatId;

  EmergencyContact({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.telegramChatId,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id']?.toString(),
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      telegramChatId: json['telegram_chat_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      if (telegramChatId != null) 'telegram_chat_id': telegramChatId,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create a copy with modified fields.
  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? telegramChatId,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      telegramChatId: telegramChatId ?? this.telegramChatId,
    );
  }
}
