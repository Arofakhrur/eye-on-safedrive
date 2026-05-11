class EmergencyContact {
  final String? id;
  final String userId;
  final String name;
  final String phone;

  EmergencyContact({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id']?.toString(),
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
