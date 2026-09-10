import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';

class AppointmentService {
  Future<Map<String, dynamic>> cancelAppointment({
    required String appointmentId,
    required String mrNo,
    required String reason,
  }) async {
    final response = await ApiConfig.client.put(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/Patient/appointments/$appointmentId/cancel',
      ),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mrNo': mrNo,
        'reason': reason.trim(),
      }),
    );

    final body = response.body.trim();
    Map<String, dynamic> decoded = {};
    if (body.isNotEmpty) {
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } catch (_) {}
    }

    if (response.statusCode == 200) {
      return decoded.isNotEmpty
          ? decoded
          : {'message': 'Appointment cancelled successfully'};
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Failed to cancel appointment (HTTP ${response.statusCode})',
    );
  }

  Future<Map<String, dynamic>> requestReschedule({
    required String appointmentId,
    required String mrNo,
    required String reason,
    required int weekId,
    required String appointmentTime,
    int? doctorId,
    int? departmentId,
  }) async {
    final response = await ApiConfig.client.put(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/Patient/appointments/$appointmentId/reschedule',
      ),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mrNo': mrNo,
        'reason': reason.trim(),
        'weekId': weekId,
        'appointmentTime': appointmentTime,
        if (doctorId != null) 'doctorId': doctorId,
        if (departmentId != null) 'departmentId': departmentId,
      }),
    );

    final body = response.body.trim();
    Map<String, dynamic> decoded = {};
    if (body.isNotEmpty) {
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } catch (_) {}
    }

    if (response.statusCode == 200) {
      return decoded.isNotEmpty
          ? decoded
          : {'message': 'Reschedule request submitted. Awaiting admin approval.'};
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Failed to submit reschedule request (HTTP ${response.statusCode})',
    );
  }
}
