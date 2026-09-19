import 'dart:convert';
import 'dart:io';

import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/utils/doctor_image_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class ProfilePhotoService {
  Future<String?> uploadPhoto({
    required String mrNo,
    required File file,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Patient/profile/photo?mrNo=${Uri.encodeQueryComponent(mrNo)}',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(AuthSession.authHeaders);
    // Let multipart set its own boundary Content-Type.
    request.headers.remove('Content-Type');

    var extension = p.extension(file.path).toLowerCase().replaceFirst('.', '');
    if (extension.isEmpty) {
      extension = 'jpg';
    }
    final mediaType = switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };

    final filename = p.basename(file.path);
    final safeName = filename.contains('.')
        ? filename
        : 'profile_$mrNo.$extension';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: safeName,
        contentType: mediaType,
      ),
    );

    final streamed = await request.send().timeout(ApiConfig.requestTimeout);
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final url = decoded?['profileImageUrl']?.toString();
      final resolved = DoctorImageHelper.resolve(url);
      await AuthSession.updateProfileImageUrl(resolved);
      return resolved;
    }

    throw Exception(
      decoded?['message']?.toString() ??
          'Failed to upload photo (HTTP ${response.statusCode})',
    );
  }

  Future<void> removePhoto({required String mrNo}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Patient/profile/photo?mrNo=${Uri.encodeQueryComponent(mrNo)}',
    );
    final request = http.Request('DELETE', uri);
    request.headers.addAll({
      'accept': 'application/json',
      ...AuthSession.authHeaders,
    });

    final streamed =
        await ApiConfig.client.send(request).timeout(ApiConfig.requestTimeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await AuthSession.updateProfileImageUrl(null);
      return;
    }

    final decoded = _decode(response.body);
    throw Exception(
      decoded?['message']?.toString() ??
          'Failed to remove photo (HTTP ${response.statusCode})',
    );
  }

  Future<String?> syncFromPatientApi(String mrNo) async {
    final response = await ApiConfig.client
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/Patient?MR_NO=${Uri.encodeQueryComponent(mrNo)}&visitPageNumber=1&visitPageSize=1',
          ),
          headers: {'accept': '*/*'},
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode != 200) {
      return AuthSession.profileImageUrl;
    }

    final decoded = _decode(response.body);
    final profile = decoded?['profile'];
    String? raw;
    if (profile is Map) {
      raw = profile['profileImageUrl']?.toString() ??
          profile['ProfileImageUrl']?.toString();
    }

    final resolved = DoctorImageHelper.resolve(raw);
    await AuthSession.updateProfileImageUrl(resolved);
    return resolved;
  }

  Map<String, dynamic>? _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
