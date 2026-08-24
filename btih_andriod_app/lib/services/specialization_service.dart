// lib/services/specialization_service.dart
import 'dart:convert';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;
import '../models/specialization_model.dart';

class SpecializationService {

  Future<List<Specialization>> getSpecializations() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/Doctor/specialization'), // Replace with your actual endpoint
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Specialization.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load specializations');
      }
    } catch (e) {
      throw Exception('Error loading specializations: $e');
    }
  }
}