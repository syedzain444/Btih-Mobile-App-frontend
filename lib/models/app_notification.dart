import 'dart:convert';

/// Inbox sections — vertical categories (no horizontal tabs).
enum NotificationCategory {
  appointments,
  medications,
  lab,
  records,
  billing,
  messaging,
  security,
  general,
}

enum NotificationType {
  // Appointments
  appointmentRequestReceived,
  appointmentConfirmed,
  appointmentCancelled,
  appointmentRescheduled,
  appointmentReminder,
  followUpReminder,

  // Reports / records
  labReportAvailable,
  gastroReportAvailable,
  radiologyReportAvailable,
  prescriptionAdded,
  dischargeSummaryReady,
  visitSummaryReady,

  // Medications
  medicationReminder,
  medicationScheduleUpdated,

  // Billing
  billGenerated,
  paymentPending,
  paymentConfirmed,

  // Messaging
  messageReceived,
  messageThreadClosed,

  // Profile / security
  profileUpdated,
  passwordChanged,
  appPinChanged,
  trustedDeviceAdded,
  trustedDeviceRemoved,
  newLoginAlert,

  // Hospital / general
  hospitalAnnouncement,
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
      'type': type.wireValue,
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
    final typeKey = (json['type'] ?? '').toString();
    final categoryKey = (json['category'] ?? '').toString();
    final priorityKey = (json['priority'] ?? 'normal').toString();

    final type = NotificationTypeX.fromWire(typeKey);
    return AppNotification(
      id: rawId?.toString() ?? '',
      type: type,
      category: NotificationCategoryX.fromWire(
        categoryKey,
        fallbackType: type,
      ),
      priority: NotificationPriorityX.fromWire(priorityKey),
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
    final type = NotificationTypeX.fromWire(
      (json['type'] as String?) ?? '',
    );
    return AppNotification(
      id: json['id'] as String,
      type: type,
      category: NotificationCategoryX.fromWire(
        (json['category'] as String?) ?? '',
        fallbackType: type,
      ),
      priority: NotificationPriorityX.fromWire(
        (json['priority'] as String?) ?? 'normal',
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

extension NotificationTypeX on NotificationType {
  /// Snake_case value stored in DB / sent on the wire.
  String get wireValue {
    switch (this) {
      case NotificationType.appointmentRequestReceived:
        return 'appointment_request_received';
      case NotificationType.appointmentConfirmed:
        return 'appointment_confirmed';
      case NotificationType.appointmentCancelled:
        return 'appointment_cancelled';
      case NotificationType.appointmentRescheduled:
        return 'appointment_rescheduled';
      case NotificationType.appointmentReminder:
        return 'appointment_reminder';
      case NotificationType.followUpReminder:
        return 'follow_up_reminder';
      case NotificationType.labReportAvailable:
        return 'lab_report_ready';
      case NotificationType.gastroReportAvailable:
        return 'gastro_report_ready';
      case NotificationType.radiologyReportAvailable:
        return 'radiology_report_ready';
      case NotificationType.prescriptionAdded:
        return 'prescription_added';
      case NotificationType.dischargeSummaryReady:
        return 'discharge_summary_ready';
      case NotificationType.visitSummaryReady:
        return 'visit_summary_ready';
      case NotificationType.medicationReminder:
        return 'medication_reminder';
      case NotificationType.medicationScheduleUpdated:
        return 'medication_schedule_updated';
      case NotificationType.billGenerated:
        return 'bill_generated';
      case NotificationType.paymentPending:
        return 'payment_pending';
      case NotificationType.paymentConfirmed:
        return 'payment_confirmed';
      case NotificationType.messageReceived:
        return 'message_received';
      case NotificationType.messageThreadClosed:
        return 'message_thread_closed';
      case NotificationType.profileUpdated:
        return 'profile_updated';
      case NotificationType.passwordChanged:
        return 'password_changed';
      case NotificationType.appPinChanged:
        return 'app_pin_changed';
      case NotificationType.trustedDeviceAdded:
        return 'trusted_device_added';
      case NotificationType.trustedDeviceRemoved:
        return 'trusted_device_removed';
      case NotificationType.newLoginAlert:
        return 'new_login_alert';
      case NotificationType.hospitalAnnouncement:
        return 'hospital_announcement';
      case NotificationType.hospitalPromotion:
        return 'hospital_promotion';
    }
  }

  NotificationCategory get defaultCategory {
    switch (this) {
      case NotificationType.appointmentRequestReceived:
      case NotificationType.appointmentConfirmed:
      case NotificationType.appointmentCancelled:
      case NotificationType.appointmentRescheduled:
      case NotificationType.appointmentReminder:
      case NotificationType.followUpReminder:
        return NotificationCategory.appointments;
      case NotificationType.labReportAvailable:
        return NotificationCategory.lab;
      case NotificationType.gastroReportAvailable:
      case NotificationType.radiologyReportAvailable:
      case NotificationType.dischargeSummaryReady:
      case NotificationType.visitSummaryReady:
        return NotificationCategory.records;
      case NotificationType.prescriptionAdded:
      case NotificationType.medicationReminder:
      case NotificationType.medicationScheduleUpdated:
        return NotificationCategory.medications;
      case NotificationType.billGenerated:
      case NotificationType.paymentPending:
      case NotificationType.paymentConfirmed:
        return NotificationCategory.billing;
      case NotificationType.messageReceived:
      case NotificationType.messageThreadClosed:
        return NotificationCategory.messaging;
      case NotificationType.profileUpdated:
      case NotificationType.passwordChanged:
      case NotificationType.appPinChanged:
      case NotificationType.trustedDeviceAdded:
      case NotificationType.trustedDeviceRemoved:
      case NotificationType.newLoginAlert:
        return NotificationCategory.security;
      case NotificationType.hospitalAnnouncement:
      case NotificationType.hospitalPromotion:
        return NotificationCategory.general;
    }
  }

  NotificationPriority get defaultPriority {
    switch (this) {
      case NotificationType.appointmentReminder:
      case NotificationType.appointmentCancelled:
      case NotificationType.labReportAvailable:
      case NotificationType.medicationReminder:
      case NotificationType.paymentPending:
      case NotificationType.messageReceived:
      case NotificationType.newLoginAlert:
      case NotificationType.passwordChanged:
        return NotificationPriority.high;
      case NotificationType.hospitalPromotion:
      case NotificationType.messageThreadClosed:
        return NotificationPriority.low;
      default:
        return NotificationPriority.normal;
    }
  }

  static NotificationType fromWire(String raw) {
    final key = raw.trim().toLowerCase().replaceAll('-', '_');
    for (final value in NotificationType.values) {
      if (value.wireValue == key || value.name.toLowerCase() == key) {
        return value;
      }
    }

    // Legacy / fuzzy fallbacks
    if (key.contains('medication') && key.contains('schedule')) {
      return NotificationType.medicationScheduleUpdated;
    }
    if (key.contains('medication')) return NotificationType.medicationReminder;
    if (key.contains('prescription')) return NotificationType.prescriptionAdded;
    if (key.contains('appointment') && key.contains('request')) {
      return NotificationType.appointmentRequestReceived;
    }
    if (key.contains('appointment') && key.contains('remind')) {
      return NotificationType.appointmentReminder;
    }
    if (key.contains('appointment') && key.contains('cancel')) {
      return NotificationType.appointmentCancelled;
    }
    if (key.contains('appointment') && key.contains('confirm')) {
      return NotificationType.appointmentConfirmed;
    }
    if (key.contains('appointment') && key.contains('resched')) {
      return NotificationType.appointmentRescheduled;
    }
    if (key.contains('follow')) return NotificationType.followUpReminder;
    if (key.contains('lab')) return NotificationType.labReportAvailable;
    if (key.contains('gastro')) return NotificationType.gastroReportAvailable;
    if (key.contains('radio')) return NotificationType.radiologyReportAvailable;
    if (key.contains('discharge')) return NotificationType.dischargeSummaryReady;
    if (key.contains('visit')) return NotificationType.visitSummaryReady;
    if (key.contains('bill_generated') || key == 'bill_generated') {
      return NotificationType.billGenerated;
    }
    if (key.contains('payment') && key.contains('confirm')) {
      return NotificationType.paymentConfirmed;
    }
    if (key.contains('payment') || key.contains('bill')) {
      return NotificationType.paymentPending;
    }
    if (key.contains('message') && key.contains('closed')) {
      return NotificationType.messageThreadClosed;
    }
    if (key.contains('message')) return NotificationType.messageReceived;
    if (key.contains('password')) return NotificationType.passwordChanged;
    if (key.contains('pin')) return NotificationType.appPinChanged;
    if (key.contains('trusted') && key.contains('removed')) {
      return NotificationType.trustedDeviceRemoved;
    }
    if (key.contains('trusted')) return NotificationType.trustedDeviceAdded;
    if (key.contains('login')) return NotificationType.newLoginAlert;
    if (key.contains('profile')) return NotificationType.profileUpdated;
    if (key.contains('promo')) return NotificationType.hospitalPromotion;
    if (key.contains('report')) return NotificationType.labReportAvailable;
    return NotificationType.hospitalAnnouncement;
  }
}

extension NotificationCategoryX on NotificationCategory {
  String get sectionTitle {
    switch (this) {
      case NotificationCategory.appointments:
        return 'Appointments';
      case NotificationCategory.medications:
        return 'Medications';
      case NotificationCategory.lab:
        return 'Lab Reports';
      case NotificationCategory.records:
        return 'Medical Records';
      case NotificationCategory.billing:
        return 'Billing';
      case NotificationCategory.messaging:
        return 'Messages';
      case NotificationCategory.security:
        return 'Security';
      case NotificationCategory.general:
        return 'Hospital Updates';
    }
  }

  String get sectionSubtitle {
    switch (this) {
      case NotificationCategory.appointments:
        return 'Bookings, reminders, and schedule changes';
      case NotificationCategory.medications:
        return 'Dose reminders and prescription updates';
      case NotificationCategory.lab:
        return 'Laboratory results ready to view';
      case NotificationCategory.records:
        return 'Imaging, gastro, discharge, and visits';
      case NotificationCategory.billing:
        return 'Bills, dues, and payment confirmations';
      case NotificationCategory.messaging:
        return 'Messages from hospital staff';
      case NotificationCategory.security:
        return 'Password, PIN, devices, and logins';
      case NotificationCategory.general:
        return 'Announcements and hospital news';
    }
  }

  static const List<NotificationCategory> sectionOrder = [
    NotificationCategory.appointments,
    NotificationCategory.medications,
    NotificationCategory.lab,
    NotificationCategory.records,
    NotificationCategory.billing,
    NotificationCategory.messaging,
    NotificationCategory.security,
    NotificationCategory.general,
  ];

  static NotificationCategory fromWire(
    String raw, {
    NotificationType? fallbackType,
  }) {
    final key = raw.trim().toLowerCase();
    for (final value in NotificationCategory.values) {
      if (value.name == key) return value;
    }
    return fallbackType?.defaultCategory ?? NotificationCategory.general;
  }
}

extension NotificationPriorityX on NotificationPriority {
  static NotificationPriority fromWire(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'high':
        return NotificationPriority.high;
      case 'low':
        return NotificationPriority.low;
      default:
        return NotificationPriority.normal;
    }
  }
}
