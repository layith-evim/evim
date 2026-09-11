/// Enum representing notification categories
enum NotificationType {
  general,
  memberJoined,
  joinRequest,
  joinAccepted,
  joinRejected,
  bill,
  ikametExpiry,
  guide;

  static NotificationType fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'bill':
      case 'expense':
      case 'rent':
        return NotificationType.bill;
      case 'guide':
      case 'gov':
      case 'residency':
      case 'ikamet':
      case 'ikamet_expiry':
      case 'ikametexpiry':
        return NotificationType.ikametExpiry;
      case 'member_joined':
      case 'memberjoined':
      case 'member':
        return NotificationType.memberJoined;
      case 'join_request':
      case 'joinrequest':
        return NotificationType.joinRequest;
      case 'join_accepted':
      case 'joinaccepted':
        return NotificationType.joinAccepted;
      case 'join_rejected':
      case 'joinrejected':
        return NotificationType.joinRejected;
      default:
        return NotificationType.general;
    }
  }

  String get value {
    switch (this) {
      case NotificationType.bill:
        return 'bill';
      case NotificationType.guide:
      case NotificationType.ikametExpiry:
        return 'ikamet_expiry';
      case NotificationType.memberJoined:
        return 'member_joined';
      case NotificationType.joinRequest:
        return 'join_request';
      case NotificationType.joinAccepted:
        return 'join_accepted';
      case NotificationType.joinRejected:
        return 'join_rejected';
      case NotificationType.general:
        return 'general';
    }
  }
}

/// Model representing in-app notifications and smart reminders
class NotificationModel {
  final String id;
  final String userId;
  final String householdId;
  final String title;
  final String body;
  final NotificationType type;
  final String? relatedId;
  final String? requestId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.title,
    required this.body,
    this.type = NotificationType.general,
    this.relatedId,
    this.requestId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      householdId: json['household_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String? ?? 'general'),
      relatedId: json['related_id'] as String?,
      requestId: (json['request_id'] ?? json['requestId']) as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'title': title,
      'body': body,
      'type': type.value,
      'related_id': relatedId,
      'request_id': requestId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? householdId,
    String? title,
    String? body,
    NotificationType? type,
    String? relatedId,
    String? requestId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      requestId: requestId ?? this.requestId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
