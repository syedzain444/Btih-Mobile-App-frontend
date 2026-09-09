import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;

import '../models/specialization_model.dart';

class SpecializationService {
  Future<List<Specialization>> getSpecializations() async {
    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Doctor/specialization'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is! List) return [];
      return body.map((json) => Specialization.fromJson(json)).toList();
    }

    if (response.statusCode == 404) {
      return [];
    }

    throw Exception(_errorMessage(response));
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return 'Failed to load specializations (HTTP ${response.statusCode})';
  }
}
