import 'dart:convert';

import 'package:btih_andriod_app/models/app_notification.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;

class NotificationInboxResult {
  final List<AppNotification> notifications;
  final int unreadCount;
  final int totalRecords;

  const NotificationInboxResult({
    required this.notifications,
    required this.unreadCount,
    required this.totalRecords,
  });
}

class NotificationApiService {
  Future<NotificationInboxResult> getInbox({
    required String mrNo,
    int pageNumber = 1,
    int pageSize = 100,
    String category = 'all',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Notification/inbox').replace(
      queryParameters: {
        'mrNo': mrNo,
        'pageNumber': '$pageNumber',
        'pageSize': '$pageSize',
        'category': category,
      },
    );

    final response = await ApiConfig.client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return const NotificationInboxResult(
          notifications: [],
          unreadCount: 0,
          totalRecords: 0,
        );
      }

      final rawData = json['data'];
      final notifications = rawData is List
          ? rawData
              .whereType<Map>()
              .map(
                (item) => AppNotification.fromApiJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : <AppNotification>[];

      final pagination = json['pagination'];
      final totalRecords = pagination is Map
          ? int.tryParse('${pagination['totalRecords']}') ?? notifications.length
          : notifications.length;

      return NotificationInboxResult(
        notifications: notifications,
        unreadCount: int.tryParse('${json['unreadCount']}') ?? 0,
        totalRecords: totalRecords,
      );
    }

    if (response.statusCode == 404) {
      return const NotificationInboxResult(
        notifications: [],
        unreadCount: 0,
        totalRecords: 0,
      );
    }

    throw Exception(_errorMessage(response, 'Failed to load notifications'));
  }

  Future<int> getUnreadCount({required String mrNo}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Notification/unread-count')
        .replace(queryParameters: {'mrNo': mrNo});

    final response = await ApiConfig.client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        return int.tryParse('${json['unreadCount']}') ?? 0;
      }
      return 0;
    }

    if (response.statusCode == 404) {
      return 0;
    }

    throw Exception(_errorMessage(response, 'Failed to load unread count'));
  }

  Future<void> markAsRead({
    required int notificationId,
    required String mrNo,
  }) async {
    final response = await ApiConfig.client.patch(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/Notification/$notificationId/read',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mrNo': mrNo}),
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 404) {
      return;
    }

    throw Exception(_errorMessage(response, 'Failed to mark notification read'));
  }

  Future<int> markAllAsRead({required String mrNo}) async {
    final response = await ApiConfig.client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/Notification/mark-all-read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mrNo': mrNo}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        return int.tryParse('${json['updatedCount']}') ?? 0;
      }
      return 0;
    }

    throw Exception(
      _errorMessage(response, 'Failed to mark all notifications read'),
    );
  }

  Future<int> recordNotification({
    required String mrNo,
    required String title,
    required String body,
    required String notificationType,
    String? category,
    String? priority,
    Map<String, dynamic>? payload,
  }) async {
    final response = await ApiConfig.client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/Notification/record'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mrNo': mrNo,
        'title': title,
        'body': body,
        'notificationType': notificationType,
        if (category != null) 'category': category,
        if (priority != null) 'priority': priority,
        if (payload != null)
          'payload': {
            for (final entry in payload.entries)
              entry.key: entry.value?.toString() ?? '',
          },
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return int.tryParse('${decoded['notificationId']}') ?? 0;
        }
      } catch (_) {}
      return 0;
    }

    throw Exception(
      _errorMessage(response, 'Failed to record notification'),
    );
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return '$fallback (HTTP ${response.statusCode})';
  }
}
