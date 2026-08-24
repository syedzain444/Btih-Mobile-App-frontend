import 'dart:convert';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;
import '../models/patient_report_model.dart';

class PatientReportService {

  Future<List<PatientReport>> getPatientReportHistory(String mrNo) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/PatientReport/history/$mrNo"),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => PatientReport.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load patient report history');
      }
    } catch (e) {
      print('Error loading patient report history: $e');
      rethrow;
    }
  }
}