import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;

import '../models/doctors_model.dart';
import '../models/doctor_schedule_model.dart';

class DoctorService {
  Future<DoctorResponse> getDoctorsPaginated({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await ApiConfig.client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/Doctor?pageNumber=$pageNumber&pageSize=$pageSize',
      ),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;
      return DoctorResponse.fromJson(jsonData);
    }

    if (response.statusCode == 404) {
      return DoctorResponse.empty(pageNumber: pageNumber, pageSize: pageSize);
    }

    throw Exception(_errorMessage(response, 'Failed to load doctors'));
  }

  Future<List<Doctor>> getDoctors() async {
    final paginated = await getDoctorsPaginated(pageNumber: 1, pageSize: 500);
    return paginated.data;
  }

  Future<List<DoctorSchedule>> getDoctorSchedule(int doctorId) async {
    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Doctor/$doctorId/schedule'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is! List) return [];
      return body.map((e) => DoctorSchedule.fromJson(e)).toList();
    }

    if (response.statusCode == 404) {
      return [];
    }

    throw Exception(_errorMessage(response, 'Failed to load schedule'));
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
