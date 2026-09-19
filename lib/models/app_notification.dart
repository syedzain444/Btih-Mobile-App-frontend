import 'dart:convert';

enum NotificationCategory {
  appointments,
  medications,
  lab,
  records,
  billing,
  general,
}

enum NotificationType {
  appointmentConfirmed,
  appointmentCancelled,
  appointmentRescheduled,
  appointmentReminder,
  labReportAvailable,
  prescriptionAdded,
  medicationReminder,
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

  factory AppNotification.fromApiJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['notificationId'];
    final typeKey = (json['type'] ?? '').toString().toLowerCase();
    final categoryKey = (json['category'] ?? 'general').toString().toLowerCase();
    final priorityKey = (json['priority'] ?? 'normal').toString().toLowerCase();

    return AppNotification(
      id: rawId?.toString() ?? '',
      type: _mapApiType(typeKey, categoryKey),
      category: _mapApiCategory(categoryKey, typeKey),
      priority: _mapApiPriority(priorityKey),
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      createdAt: _parseApiDate(json['createdAt']),
      isRead: json['isRead'] == true,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = NotificationType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => NotificationType.hospitalAnnouncement,
    );
    final rawCategory = (json['category'] as String?) ?? '';
    return AppNotification(
      id: json['id'] as String,
      type: type,
      category: NotificationCategory.values.firstWhere(
        (value) => value.name == rawCategory,
        orElse: () => _mapApiCategory(rawCategory, type.name),
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

  static NotificationType _mapApiType(String typeKey, String categoryKey) {
    if (typeKey.contains('medication')) {
      return NotificationType.medicationReminder;
    }
    if (typeKey.contains('prescription')) {
      return NotificationType.prescriptionAdded;
    }
    if (typeKey.contains('appointment') && typeKey.contains('remind')) {
      return NotificationType.appointmentReminder;
    }
    if (typeKey.contains('appointment') && typeKey.contains('cancel')) {
      return NotificationType.appointmentCancelled;
    }
    if (typeKey.contains('appointment') && typeKey.contains('confirm')) {
      return NotificationType.appointmentConfirmed;
    }
    if (typeKey.contains('appointment') && typeKey.contains('resched')) {
      return NotificationType.appointmentRescheduled;
    }
    if (typeKey.contains('follow')) {
      return NotificationType.followUpReminder;
    }
    if (typeKey.contains('appointment')) {
      return NotificationType.appointmentReminder;
    }
    if (typeKey.contains('report')) {
      if (categoryKey == 'records') {
        return NotificationType.radiologyReportAvailable;
      }
      return NotificationType.labReportAvailable;
    }
    if (typeKey.contains('profile')) {
      return NotificationType.hospitalAnnouncement;
    }
    if (typeKey.contains('payment') && typeKey.contains('confirm')) {
      return NotificationType.paymentConfirmed;
    }
    if (typeKey.contains('payment') || typeKey.contains('bill')) {
      return NotificationType.paymentPending;
    }
    if (typeKey.contains('promo')) {
      return NotificationType.hospitalPromotion;
    }
    return NotificationType.hospitalAnnouncement;
  }

  static NotificationCategory _mapApiCategory(String categoryKey, [String typeKey = '']) {
    switch (categoryKey) {
      case 'appointments':
        return NotificationCategory.appointments;
      case 'medications':
        return NotificationCategory.medications;
      case 'lab':
        return NotificationCategory.lab;
      case 'records':
        return NotificationCategory.records;
      case 'billing':
        return NotificationCategory.billing;
      default:
        if (typeKey.contains('medication') || typeKey.contains('prescription')) {
          return NotificationCategory.medications;
        }
        if (typeKey.contains('appointment') || typeKey.contains('follow')) {
          return NotificationCategory.appointments;
        }
        if (typeKey.contains('payment') || typeKey.contains('bill')) {
          return NotificationCategory.billing;
        }
        if (typeKey.contains('lab')) {
          return NotificationCategory.lab;
        }
        return NotificationCategory.general;
    }
  }

  static NotificationPriority _mapApiPriority(String priorityKey) {
    switch (priorityKey) {
      case 'high':
        return NotificationPriority.high;
      case 'low':
        return NotificationPriority.low;
      default:
        return NotificationPriority.normal;
    }
  }

  static DateTime _parseApiDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
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

extension NotificationCategoryX on NotificationCategory {
  String get sectionTitle {
    switch (this) {
      case NotificationCategory.appointments:
        return 'Appointment Reminders';
      case NotificationCategory.medications:
        return 'Medication Reminders';
      case NotificationCategory.lab:
        return 'Lab Reports';
      case NotificationCategory.records:
        return 'Medical Records';
      case NotificationCategory.billing:
        return 'Payment Notifications';
      case NotificationCategory.general:
        return 'Hospital Updates';
    }
  }

  /// Display order for categorized inbox sections.
  static const List<NotificationCategory> sectionOrder = [
    NotificationCategory.appointments,
    NotificationCategory.medications,
    NotificationCategory.lab,
    NotificationCategory.records,
    NotificationCategory.billing,
    NotificationCategory.general,
  ];
}
