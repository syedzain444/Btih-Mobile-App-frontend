import 'dart:convert';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;

class BookingService {

  Future<Map<String, dynamic>> insertChallan({
    required String name,
    required String phoneNo, // Changed to String
    required String mrno,
    required String email,
    required int weekId,
    required String appointmentTime, // Changed to String
    required String status,
    required int doctorId,
    required int departmentId,
    required String purpose,
    required bool isActive,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        "name": name,
        "phoneNo": phoneNo, // Now sending as string
        "mrno": mrno,
        "email": email,
        "weekId": weekId,
        "appointment_time": appointmentTime, // Now sending as string
        "status": status,
        "doctorId": doctorId,
        "departmentId": departmentId,
        "purpose": purpose,
        "createdAt": DateTime.now().toIso8601String(),
        "isActive": isActive ? "Y" : "N",
        "entryDate": DateTime.now().toIso8601String(),
      };

      print('Sending request: ${jsonEncode(requestBody)}'); // Debug print

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/Patient/insertchallan"),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to book appointment: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Booking Error: $e');
      throw Exception('Failed to connect to server: $e');
    }
  }
}