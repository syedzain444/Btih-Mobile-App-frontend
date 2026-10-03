import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';

/// Appointment confirmation QR resolve (hospital check-in) — REQ-2026-014.
class AppointmentConfirmationService {
  Future<Map<String, dynamic>> resolveQr(String qrTokenOrPayload) async {
    final token = extractToken(qrTokenOrPayload);
    if (token == null || token.isEmpty) {
      throw Exception('Invalid appointment confirmation QR.');
    }

    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/AppointmentConfirmation/qr/$token'),
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 404) {
      throw Exception('Appointment QR not found or invalid.');
    }
    throw Exception(
      'Failed to resolve appointment QR: ${response.statusCode} - ${response.body}',
    );
  }

  static String? extractToken(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    const apiMarker = '/api/AppointmentConfirmation/qr/';
    final apiIdx = value.indexOf(apiMarker);
    if (apiIdx >= 0) {
      var token = value.substring(apiIdx + apiMarker.length);
      final cut = token.indexOf(RegExp(r'[?#/&]'));
      if (cut >= 0) token = token.substring(0, cut);
      return token;
    }

    const deep = 'btihapp://appointment/qr/';
    if (value.toLowerCase().startsWith(deep)) {
      var token = value.substring(deep.length);
      final cut = token.indexOf(RegExp(r'[?#/&]'));
      if (cut >= 0) token = token.substring(0, cut);
      return token;
    }

    if (RegExp(r'^[0-9a-fA-F]{16,64}$').hasMatch(value)) {
      return value;
    }
    return value;
  }
}
