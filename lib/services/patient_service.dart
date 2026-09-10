import 'dart:convert';

import 'package:btih_andriod_app/models/patient_model.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;

class PatientService {
  Future<PatientProfileData?> fetchProfile(String mrNo) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Patient').replace(
      queryParameters: {'MR_NO': mrNo.trim()},
    );

    final response = await ApiConfig.client
        .get(uri, headers: {'accept': '*/*'})
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AuthApiException(
        _readMessage(response),
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final profile = decoded['profile'];
    if (profile is Map<String, dynamic>) {
      return PatientProfileData.fromJson(profile);
    }
    if (profile is Map) {
      return PatientProfileData.fromJson(
        profile.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return null;
  }

  Future<Map<String, dynamic>> setupProfile({
    required String mrNo,
    String? firstName,
    String? lastName,
    required String cnic,
    required DateTime dateOfBirth,
    required String gender,
    required String bloodGroup,
    String? email,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Patient/setup');
    final body = jsonEncode({
      'mrNo': mrNo.trim(),
      if (firstName != null && firstName.trim().isNotEmpty)
        'firstName': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'lastName': lastName.trim(),
      'cnic': cnic.trim(),
      'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
      'gender': gender,
      'bloodGroup': bloodGroup,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    });

    final response = await ApiConfig.client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'accept': 'application/json',
          },
          body: body,
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'success': true};
    }

    throw AuthApiException(
      _readMessage(response),
      statusCode: response.statusCode,
    );
  }

  Future<void> updateProfile({
    required String mrNo,
    String? firstName,
    String? lastName,
    String? gender,
    String? cnic,
    String? contactNo,
    String? bloodGroup,
    String? emailAddress,
    DateTime? dateOfBirth,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Patient/profile');
    final body = jsonEncode({
      'mrNo': mrNo.trim(),
      if (firstName != null) 'firstName': firstName.trim(),
      if (lastName != null) 'lastName': lastName.trim(),
      'gender': ?gender,
      if (cnic != null) 'cnic': cnic.trim(),
      if (contactNo != null) 'contactNo': contactNo.trim(),
      'bloodGroup': ?bloodGroup,
      if (emailAddress != null) 'emailAddress': emailAddress.trim(),
      if (dateOfBirth != null)
        'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
    });

    var response = await ApiConfig.client
        .put(uri,
            headers: {
              'Content-Type': 'application/json',
              'accept': 'application/json',
            },
            body: body)
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 405) {
      response = await ApiConfig.client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: body,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    throw AuthApiException(
      _readMessage(response),
      statusCode: response.statusCode,
    );
  }

  String _readMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}
