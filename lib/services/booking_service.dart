import 'dart:convert';
import 'package:btih_andriod_app/utils/ip_file.dart';

class BookingService {
  Future<Map<String, dynamic>> insertChallan({
    required String name,
    required String phoneNo,
    required String mrno,
    required String email,
    required int weekId,
    required String appointmentTime,
    required String status,
    required int doctorId,
    required int departmentId,
    required String purpose,
    required bool isActive,
  }) async {
    final Map<String, dynamic> requestBody = {
      "name": name,
      "phoneNo": phoneNo,
      "mrno": mrno,
      "email": email,
      "weekId": weekId,
      "appointment_time": appointmentTime,
      "status": status,
      "doctorId": doctorId,
      "departmentId": departmentId,
      "purpose": purpose,
      "createdAt": DateTime.now().toIso8601String(),
      "isActive": isActive ? "Y" : "N",
      "entryDate": DateTime.now().toIso8601String(),
    };

    try {
      final response = await ApiConfig.client.post(
        Uri.parse("${ApiConfig.baseUrl}/api/Patient/insertchallan"),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      Map<String, dynamic> decoded = {};
      if (response.body.trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(response.body);
          if (parsed is Map<String, dynamic>) {
            decoded = parsed;
          }
        } catch (_) {
          // Non-JSON body — fall through to status handling.
        }
      }

      if (response.statusCode == 200) {
        return decoded;
      }

      final serverMessage = decoded['message']?.toString().trim();
      if (serverMessage != null && serverMessage.isNotEmpty) {
        throw Exception(serverMessage);
      }

      throw Exception('Booking failed (${response.statusCode})');
    } catch (e) {
      final text = e.toString();
      if (text.startsWith('Exception: ')) {
        throw Exception(text.substring('Exception: '.length));
      }
      throw Exception('Unable to reach booking server. Please try again.');
    }
  }
}
