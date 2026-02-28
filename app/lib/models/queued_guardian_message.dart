class QueuedGuardianMessage {
  QueuedGuardianMessage({
    required this.id,
    required this.phone,
    required this.message,
    required this.createdAt,
    this.sentAt,
    this.isSent = false,
  });

  final String id;
  final String phone;
  final String message;
  final DateTime createdAt;
  final DateTime? sentAt;
  final bool isSent;

  QueuedGuardianMessage copyWith({
    DateTime? sentAt,
    bool? isSent,
  }) {
    return QueuedGuardianMessage(
      id: id,
      phone: phone,
      message: message,
      createdAt: createdAt,
      sentAt: sentAt ?? this.sentAt,
      isSent: isSent ?? this.isSent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'isSent': isSent,
    };
  }

  factory QueuedGuardianMessage.fromMap(Map<dynamic, dynamic> map) {
    return QueuedGuardianMessage(
      id: map['id'] as String,
      phone: map['phone'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      sentAt: map['sentAt'] != null
          ? DateTime.parse(map['sentAt'] as String)
          : null,
      isSent: map['isSent'] as bool? ?? false,
    );
  }
}
