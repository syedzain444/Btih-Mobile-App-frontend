import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:url_launcher/url_launcher.dart';

class TelemedSession {
  final int sessionId;
  final String mrNo;
  final int? appointmentId;
  final String? doctorId;
  final String? doctorName;
  final String roomId;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? joinUrl;
  final String? patientToken;

  const TelemedSession({
    required this.sessionId,
    required this.mrNo,
    this.appointmentId,
    this.doctorId,
    this.doctorName,
    required this.roomId,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.joinUrl,
    this.patientToken,
  });

  bool get canJoin {
    final s = status.toUpperCase();
    return s == 'SCHEDULED' || s == 'ACTIVE' || s == 'WAITING';
  }

  factory TelemedSession.fromJson(Map<String, dynamic> json) {
    return TelemedSession(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      mrNo: json['mrNo']?.toString() ?? '',
      appointmentId: (json['appointmentId'] as num?)?.toInt(),
      doctorId: json['doctorId']?.toString(),
      doctorName: json['doctorName']?.toString(),
      roomId: json['roomId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SCHEDULED',
      scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? ''),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
      joinUrl: json['joinUrl']?.toString(),
      patientToken: json['patientToken']?.toString(),
    );
  }
}

class TelemedicineService {
  Future<TelemedSession> createSession({
    required String mrNo,
    int? appointmentId,
    String? doctorId,
    String? doctorName,
    DateTime? scheduledAt,
  }) async {
    final response = await ApiConfig.client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/Telemedicine/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mrNo': mrNo,
        if (appointmentId != null) 'appointmentId': appointmentId,
        if (doctorId != null) 'doctorId': doctorId,
        if (doctorName != null) 'doctorName': doctorName,
        if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = body is Map ? body['message']?.toString() : null;
      throw Exception(msg ?? 'Unable to schedule telemedicine session');
    }
    if (body is Map && body['data'] is Map) {
      return TelemedSession.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    }
    throw Exception('Invalid telemedicine response');
  }

  Future<List<TelemedSession>> getSessions(String mrNo) async {
    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Telemedicine/sessions/$mrNo'),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to load telemedicine sessions');
    }
    final body = jsonDecode(response.body);
    if (body is Map && body['data'] is List) {
      return (body['data'] as List)
          .whereType<Map>()
          .map((e) => TelemedSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<TelemedSession?> getSession({
    required int sessionId,
    required String mrNo,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Telemedicine/sessions/detail/$sessionId',
    ).replace(queryParameters: {'mrNo': mrNo});
    final response = await ApiConfig.client.get(uri);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Unable to load session');
    }
    final body = jsonDecode(response.body);
    if (body is Map && body['data'] is Map) {
      return TelemedSession.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    }
    return null;
  }

  Future<TelemedSession> updateStatus({
    required int sessionId,
    required String mrNo,
    required String status,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Telemedicine/sessions/$sessionId/status',
    ).replace(queryParameters: {
      'mrNo': mrNo,
      'status': status,
    });
    final response = await ApiConfig.client.patch(uri);
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = body is Map ? body['message']?.toString() : null;
      throw Exception(msg ?? 'Unable to update session status');
    }
    if (body is Map && body['data'] is Map) {
      return TelemedSession.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    }
    throw Exception('Invalid status response');
  }

  Future<bool> openJoinUrl(String? joinUrl) async {
    if (joinUrl == null || joinUrl.trim().isEmpty) return false;
    final uri = Uri.tryParse(joinUrl.trim());
    if (uri == null) return false;
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
