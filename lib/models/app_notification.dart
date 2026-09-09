import 'dart:convert';

enum NotificationCategory {
  appointments,
  lab,
  records,
  billing,
  general,
}

enum NotificationFilter {
  all,
  appointments,
  lab,
  records,
  billing,
}

enum NotificationType {
  appointmentConfirmed,
  appointmentCancelled,
  appointmentRescheduled,
  appointmentReminder,
  labReportAvailable,
  prescriptionAdded,
  gastroReportAvailable,
  radiologyReportAvailable,
  paymentConfirmed,
  paymentPending,
  hospitalAnnouncement,
  followUpReminder,
  hospitalPromotion,
}

enum NotificationPriority {
  high,
  normal,
  low,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final NotificationCategory category;
  final NotificationPriority priority;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? payload;

  const AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.payload,
  });

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      type: type,
      category: category,
      priority: priority,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'category': category.name,
      'priority': priority.name,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'payload': payload,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => NotificationType.hospitalAnnouncement,
      ),
      category: NotificationCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => NotificationCategory.general,
      ),
      priority: NotificationPriority.values.firstWhere(
        (value) => value.name == json['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
    );
  }

  static List<AppNotification> listFromJsonString(String raw) {
    if (raw.isEmpty) return [];
    final decoded = json.decode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static String listToJsonString(List<AppNotification> notifications) {
    return json.encode(notifications.map((item) => item.toJson()).toList());
  }
}

extension NotificationFilterX on NotificationFilter {
  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.appointments:
        return 'Appointments';
      case NotificationFilter.lab:
        return 'Lab';
      case NotificationFilter.records:
        return 'Records';
      case NotificationFilter.billing:
        return 'Billing';
    }
  }

  bool matches(AppNotification notification) {
    if (this == NotificationFilter.all) return true;
    switch (this) {
      case NotificationFilter.appointments:
        return notification.category == NotificationCategory.appointments;
      case NotificationFilter.lab:
        return notification.category == NotificationCategory.lab;
      case NotificationFilter.records:
        return notification.category == NotificationCategory.records;
      case NotificationFilter.billing:
        return notification.category == NotificationCategory.billing;
      case NotificationFilter.all:
        return true;
    }
  }
}
