import 'dart:convert';

import 'package:btih_andriod_app/models/app_notification.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _storagePrefix = 'app_notifications_';
  static const _maxStoredNotifications = 100;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  SharedPreferences? _prefs;
  String _activeMrNo = '';
  List<AppNotification> _notifications = [];
  bool _initialized = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _ensureAndroidNotificationChannel();
    await _requestPermissions();
    _initialized = true;
    await reloadForCurrentUser();
  }

  Future<void> reloadForCurrentUser() async {
    _activeMrNo = AuthSession.mrNo?.trim() ?? '';
    if (_activeMrNo.isEmpty) {
      _notifications = [];
      notifyListeners();
      return;
    }
    await _loadFromStorage(_activeMrNo);
  }

  Future<void> reloadForMrNo(String mrNo) async {
    _activeMrNo = mrNo.trim();
    if (_activeMrNo.isEmpty) {
      _notifications = [];
      notifyListeners();
      return;
    }
    await _loadFromStorage(_activeMrNo);
  }

  Future<void> clearForLogout() async {
    _activeMrNo = '';
    _notifications = [];
    notifyListeners();
  }

  /// Stores and displays a push notification received from Firebase Cloud Messaging.
  Future<void> ingestRemoteMessage(
    RemoteMessage message, {
    bool openedFromTray = false,
  }) async {
    final mrNo = (message.data['mrNo'] ??
            message.data['MR_NO'] ??
            AuthSession.mrNo ??
            '')
        .toString()
        .trim();

    if (mrNo.isEmpty) return;

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Hospital Update';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';

    if (body.isEmpty) return;

    final mapped = _mapRemoteNotification(
      title: title,
      body: body,
      data: message.data,
    );

    await _addNotification(
      mrNo: mrNo,
      type: mapped.type,
      category: mapped.category,
      priority: mapped.priority,
      title: title,
      body: body,
      payload: {
        ...message.data,
        if (openedFromTray) 'openedFromTray': true,
      },
    );
  }

  ({NotificationType type, NotificationCategory category, NotificationPriority priority})
      _mapRemoteNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final rawType = (data['type'] ??
            data['notificationType'] ??
            data['event'] ??
            title)
        .toString()
        .toLowerCase();

    if (rawType.contains('appointment') && rawType.contains('remind')) {
      return (
        type: NotificationType.appointmentReminder,
        category: NotificationCategory.appointments,
        priority: NotificationPriority.high,
      );
    }
    if (rawType.contains('appointment') && rawType.contains('cancel')) {
      return (
        type: NotificationType.appointmentCancelled,
        category: NotificationCategory.appointments,
        priority: NotificationPriority.high,
      );
    }
    if (rawType.contains('appointment') && rawType.contains('confirm')) {
      return (
        type: NotificationType.appointmentConfirmed,
        category: NotificationCategory.appointments,
        priority: NotificationPriority.high,
      );
    }
    if (rawType.contains('appointment')) {
      return (
        type: NotificationType.appointmentReminder,
        category: NotificationCategory.appointments,
        priority: NotificationPriority.high,
      );
    }
    if (rawType.contains('lab')) {
      return (
        type: NotificationType.labReportAvailable,
        category: NotificationCategory.lab,
        priority: NotificationPriority.high,
      );
    }
    if (rawType.contains('gastro')) {
      return (
        type: NotificationType.gastroReportAvailable,
        category: NotificationCategory.records,
        priority: NotificationPriority.normal,
      );
    }
    if (rawType.contains('radio')) {
      return (
        type: NotificationType.radiologyReportAvailable,
        category: NotificationCategory.records,
        priority: NotificationPriority.normal,
      );
    }
    if (rawType.contains('report')) {
      return (
        type: NotificationType.labReportAvailable,
        category: NotificationCategory.lab,
        priority: NotificationPriority.high,
      );
    }
    if (rawType.contains('payment') || rawType.contains('bill')) {
      return (
        type: NotificationType.paymentPending,
        category: NotificationCategory.billing,
        priority: NotificationPriority.high,
      );
    }

    return (
      type: NotificationType.hospitalAnnouncement,
      category: NotificationCategory.general,
      priority: NotificationPriority.normal,
    );
  }

  Future<void> _ensureAndroidNotificationChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    const channel = AndroidNotificationChannel(
      'hospital_app_notifications',
      'Hospital Notifications',
      description: 'Appointment, lab, billing and hospital updates',
      importance: Importance.high,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  List<AppNotification> filtered(NotificationFilter filter) {
    return _notifications.where(filter.matches).toList();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1 || _notifications[index].isRead) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    _notifications = _notifications.map((item) {
      if (item.isRead) return item;
      changed = true;
      return item.copyWith(isRead: true);
    }).toList();
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> notifyAppointmentConfirmed({
    required String mrNo,
    required String doctorName,
    String? appointmentTime,
    String? department,
  }) {
    final timeText = appointmentTime?.trim().isNotEmpty == true
        ? ' on $appointmentTime'
        : '';
    final deptText = department?.trim().isNotEmpty == true
        ? ' at $department'
        : '';
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.appointmentConfirmed,
      category: NotificationCategory.appointments,
      priority: NotificationPriority.high,
      title: 'Appointment Confirmed',
      body:
          'Your appointment with $doctorName$deptText has been confirmed$timeText.',
      payload: {
        'doctorName': doctorName,
        if (appointmentTime != null) 'appointmentTime': appointmentTime,
        if (department != null) 'department': department,
      },
    );
  }

  Future<void> notifyAppointmentCancelled({
    required String mrNo,
    required String doctorName,
    String? appointmentTime,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.appointmentCancelled,
      category: NotificationCategory.appointments,
      priority: NotificationPriority.high,
      title: 'Appointment Cancelled',
      body:
          'Your appointment with $doctorName${appointmentTime != null ? ' on $appointmentTime' : ''} has been cancelled.',
      payload: {
        'doctorName': doctorName,
        if (appointmentTime != null) 'appointmentTime': appointmentTime,
      },
    );
  }

  Future<void> notifyAppointmentRescheduled({
    required String mrNo,
    required String doctorName,
    required String newAppointmentTime,
    String? previousAppointmentTime,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.appointmentRescheduled,
      category: NotificationCategory.appointments,
      priority: NotificationPriority.high,
      title: 'Appointment Rescheduled',
      body:
          'Your appointment with $doctorName has been moved to $newAppointmentTime.',
      payload: {
        'doctorName': doctorName,
        'newAppointmentTime': newAppointmentTime,
        if (previousAppointmentTime != null)
          'previousAppointmentTime': previousAppointmentTime,
      },
    );
  }

  Future<void> notifyAppointmentReminder({
    required String mrNo,
    required String doctorName,
    required String appointmentTime,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.appointmentReminder,
      category: NotificationCategory.appointments,
      priority: NotificationPriority.high,
      title: 'Appointment Reminder',
      body: 'Reminder: You have an appointment with $doctorName on $appointmentTime.',
      payload: {
        'doctorName': doctorName,
        'appointmentTime': appointmentTime,
      },
    );
  }

  Future<void> notifyFollowUpReminder({
    required String mrNo,
    required String doctorName,
    String? followUpDate,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.followUpReminder,
      category: NotificationCategory.appointments,
      priority: NotificationPriority.normal,
      title: 'Follow-up Reminder',
      body:
          'Please schedule your follow-up visit with $doctorName${followUpDate != null ? ' by $followUpDate' : ''}.',
      payload: {
        'doctorName': doctorName,
        if (followUpDate != null) 'followUpDate': followUpDate,
      },
    );
  }

  Future<void> notifyLabReportAvailable({
    required String mrNo,
    required String testName,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.labReportAvailable,
      category: NotificationCategory.lab,
      priority: NotificationPriority.high,
      title: 'Lab Report Available',
      body: 'Your $testName report is now available.',
      payload: {'testName': testName},
    );
  }

  Future<void> notifyPrescriptionAdded({
    required String mrNo,
    String? doctorName,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.prescriptionAdded,
      category: NotificationCategory.records,
      priority: NotificationPriority.normal,
      title: 'Prescription Added',
      body: doctorName != null
          ? 'A new prescription from $doctorName has been added to your records.'
          : 'A new prescription has been added to your records.',
      payload: ifNotEmpty({'doctorName': doctorName}),
    );
  }

  Future<void> notifyGastroReportAvailable({
    required String mrNo,
    required String procedureName,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.gastroReportAvailable,
      category: NotificationCategory.records,
      priority: NotificationPriority.normal,
      title: 'Gastro Report Available',
      body: 'Your $procedureName report is now available.',
      payload: {'procedureName': procedureName},
    );
  }

  Future<void> notifyRadiologyReportAvailable({
    required String mrNo,
    required String studyName,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.radiologyReportAvailable,
      category: NotificationCategory.records,
      priority: NotificationPriority.normal,
      title: 'Radiology Report Available',
      body: 'Your $studyName report is now available.',
      payload: {'studyName': studyName},
    );
  }

  Future<void> notifyPaymentConfirmed({
    required String mrNo,
    String? amount,
    String? reference,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.paymentConfirmed,
      category: NotificationCategory.billing,
      priority: NotificationPriority.normal,
      title: 'Payment Successful',
      body: amount != null
          ? 'Your payment of $amount was successfully processed.'
          : 'Your payment was successfully processed.',
      payload: {
        if (amount != null) 'amount': amount,
        if (reference != null) 'reference': reference,
      },
    );
  }

  Future<void> notifyPaymentPending({
    required String mrNo,
    String? amount,
    String? dueDate,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.paymentPending,
      category: NotificationCategory.billing,
      priority: NotificationPriority.high,
      title: 'Payment Pending',
      body: amount != null
          ? 'A payment of $amount is pending${dueDate != null ? ' until $dueDate' : ''}.'
          : 'You have a pending payment in your account.',
      payload: {
        if (amount != null) 'amount': amount,
        if (dueDate != null) 'dueDate': dueDate,
      },
    );
  }

  Future<void> notifyHospitalAnnouncement({
    required String mrNo,
    required String title,
    required String message,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.hospitalAnnouncement,
      category: NotificationCategory.general,
      priority: NotificationPriority.high,
      title: title,
      body: message,
      payload: {'title': title},
    );
  }

  Future<void> notifyHospitalPromotion({
    required String mrNo,
    required String title,
    required String message,
  }) {
    return _addNotification(
      mrNo: mrNo,
      type: NotificationType.hospitalPromotion,
      category: NotificationCategory.general,
      priority: NotificationPriority.low,
      title: title,
      body: message,
      payload: {'title': title},
    );
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }
    if (_isSameDay(now, dateTime)) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_isSameDay(yesterday, dateTime)) {
      return 'Yesterday, ${_formatClock(dateTime)}';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }

  static String groupLabelFor(DateTime dateTime) {
    final now = DateTime.now();
    if (_isSameDay(now, dateTime)) return 'Today';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_isSameDay(yesterday, dateTime)) return 'Yesterday';
    return 'Earlier';
  }

  Future<void> _addNotification({
    required String mrNo,
    required NotificationType type,
    required NotificationCategory category,
    required NotificationPriority priority,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    final normalizedMrNo = mrNo.trim();
    if (normalizedMrNo.isEmpty) return;

    _prefs ??= await SharedPreferences.getInstance();

    final notification = AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.name}',
      type: type,
      category: category,
      priority: priority,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      payload: payload,
    );

    final storageKey = _storageKey(normalizedMrNo);
    final stored = AppNotification.listFromJsonString(
      _prefs!.getString(storageKey) ?? '',
    );
    stored.insert(0, notification);
    if (stored.length > _maxStoredNotifications) {
      stored.removeRange(_maxStoredNotifications, stored.length);
    }
    await _prefs!.setString(
      storageKey,
      AppNotification.listToJsonString(stored),
    );

    if (_activeMrNo == normalizedMrNo) {
      _notifications = stored;
      notifyListeners();
    }

    await _showDeviceNotification(notification);
  }

  Future<void> _loadFromStorage(String mrNo) async {
    _prefs ??= await SharedPreferences.getInstance();
    _notifications = AppNotification.listFromJsonString(
      _prefs!.getString(_storageKey(mrNo)) ?? '',
    );
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_activeMrNo.isEmpty) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
      _storageKey(_activeMrNo),
      AppNotification.listToJsonString(_notifications),
    );
  }

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }
  }

  Future<void> _showDeviceNotification(AppNotification notification) async {
    final androidDetails = AndroidNotificationDetails(
      'hospital_app_notifications',
      'Hospital Notifications',
      channelDescription: 'Appointment, lab, billing and hospital updates',
      importance: notification.priority == NotificationPriority.high
          ? Importance.high
          : Importance.defaultImportance,
      priority: notification.priority == NotificationPriority.high
          ? Priority.high
          : Priority.defaultPriority,
    );

    await _localNotifications.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails),
      payload: json.encode({
        'id': notification.id,
        'type': notification.type.name,
      }),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = json.decode(payload);
      if (decoded is Map && decoded['id'] is String) {
        markAsRead(decoded['id'] as String);
      }
    } catch (_) {}
  }

  static String _storageKey(String mrNo) => '$_storagePrefix$mrNo';

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatClock(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static Map<String, dynamic>? ifNotEmpty(Map<String, String?> values) {
    final filtered = <String, dynamic>{};
    values.forEach((key, value) {
      if (value != null && value.trim().isNotEmpty) {
        filtered[key] = value.trim();
      }
    });
    return filtered.isEmpty ? null : filtered;
  }
}
