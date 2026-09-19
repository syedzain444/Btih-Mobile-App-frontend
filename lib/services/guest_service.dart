import 'dart:convert';

import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';

class GuestService {
  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> saveProfile({
    required String fullName,
    required String mobileNumber,
    required DateTime dateOfBirth,
    required String gender,
  }) async {
    final response = await ApiConfig.client
        .post(
          _uri('/api/Guest/profile'),
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'fullName': fullName.trim(),
            'mobileNumber': GuestSession.normalizePhone(mobileNumber),
            'dateOfBirth': dateOfBirth.toIso8601String(),
            'gender': gender.trim(),
          }),
        )
        .timeout(ApiConfig.requestTimeout);

    final decoded = _decode(response.body);
    if (response.statusCode == 409) {
      throw GuestProfileConflictException(
        decoded?['message']?.toString() ??
            'This mobile number is already registered.',
        mrNo: decoded?['mrNo']?.toString(),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? {'success': true};
    }

    throw Exception(
      decoded?['message']?.toString() ??
          'Failed to save guest profile (HTTP ${response.statusCode})',
    );
  }

  Future<Map<String, dynamic>?> loadProfile(String mobileNumber) async {
    final response = await ApiConfig.client
        .get(
          _uri('/api/Guest/profile', {
            'mobileNumber': GuestSession.normalizePhone(mobileNumber),
          }),
          headers: {'accept': 'application/json'},
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 404) {
      return null;
    }

    final decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Exception(
      decoded?['message']?.toString() ??
          'Failed to load guest profile (HTTP ${response.statusCode})',
    );
  }

  Future<List<Map<String, dynamic>>> fetchAppointments(String phoneNumber) async {
    final response = await ApiConfig.client
        .get(
          _uri('/api/Guest/appointments', {
            'phoneNumber': GuestSession.normalizePhone(phoneNumber),
          }),
          headers: {'accept': 'application/json'},
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 404) {
      return [];
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry('$key', value)))
            .toList();
      }
      return [];
    }

    final decoded = _decode(response.body);
    throw Exception(
      decoded?['message']?.toString() ??
          'Failed to load guest appointments (HTTP ${response.statusCode})',
    );
  }

  Future<void> cancelAppointment({
    required String appointmentId,
    required String phoneNumber,
    required String reason,
  }) async {
    final response = await ApiConfig.client
        .put(
          _uri('/api/Guest/appointments/$appointmentId/cancel'),
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'phoneNumber': GuestSession.normalizePhone(phoneNumber),
            'reason': reason.trim(),
          }),
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 200) {
      return;
    }

    final decoded = _decode(response.body);
    throw Exception(
      decoded?['message']?.toString() ??
          'Failed to cancel appointment (HTTP ${response.statusCode})',
    );
  }

  Map<String, dynamic>? _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class GuestProfileConflictException implements Exception {
  final String message;
  final String? mrNo;

  GuestProfileConflictException(this.message, {this.mrNo});

  @override
  String toString() => message;
}
