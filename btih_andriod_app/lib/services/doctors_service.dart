// import 'dart:convert';
// import 'package:btih_andriod_app/utils/ip_file.dart';
// import 'package:http/http.dart' as http;
// import '../models/doctors_model.dart';
// import '../models/doctor_schedule_model.dart';

// class DoctorService {
//   Future<List<Doctor>> getDoctors() async {
//     final response = await http.get(
//       Uri.parse("${ApiConfig.baseUrl}/api/Doctor"),
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> jsonData = jsonDecode(response.body);

//       print("Raw API Response: $jsonData"); // 👈 Debug

//       return jsonData.map((e) => Doctor.fromJson(e)).toList();
//     } else {
//       throw Exception('Failed to load doctors');
//     }
//   }
//   Future<List<DoctorSchedule>> getDoctorSchedule(int doctorId) async {
//   final response = await http.get(
//     Uri.parse("${ApiConfig.baseUrl}/api/Doctor/$doctorId/schedule"),
//   );

//   if (response.statusCode == 200) {
//     final List<dynamic> jsonData = jsonDecode(response.body);
//     return jsonData.map((e) => DoctorSchedule.fromJson(e)).toList();
//   } else {
//     throw Exception('Failed to load schedule');
//   }
// }

// }


// doctors_service.dart - Updated with pagination methods

import 'dart:convert';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;
import '../models/doctors_model.dart';
import '../models/doctor_schedule_model.dart';

class DoctorService {
  // New method with pagination
  Future<DoctorResponse> getDoctorsPaginated({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/Doctor?pageNumber=$pageNumber&pageSize=$pageSize"),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      print("Loaded page $pageNumber: ${jsonData['data'].length} doctors");
      return DoctorResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load doctors');
    }
  }

  // Keep old method for backward compatibility (optional)
  Future<List<Doctor>> getDoctors() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/Doctor"),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      print("Raw API Response: $jsonData");
      return jsonData.map((e) => Doctor.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load doctors');
    }
  }
  
  Future<List<DoctorSchedule>> getDoctorSchedule(int doctorId) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/Doctor/$doctorId/schedule"),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((e) => DoctorSchedule.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load schedule');
    }
  }
}