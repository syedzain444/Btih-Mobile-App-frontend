import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';

/// Shared helpers for HMIS API requests and error handling.
class ApiResponseHelper {
  ApiResponseHelper._();

  static Map<String, dynamic> decodeBody(String body) {
    if (body.trim().isEmpty) return {};
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return {};
  }

  static Never throwFromResponse(
    int statusCode,
    Map<String, dynamic> decoded,
    String fallback,
  ) {
    if (statusCode == 403) {
      throw Exception(
        decoded['message']?.toString() ??
            'Access denied. You can only view records for your own MR number.',
      );
    }

    throw Exception(
      decoded['message']?.toString() ?? '$fallback (HTTP $statusCode)',
    );
  }

  static String encodePathSegment(String value) =>
      Uri.encodeComponent(value.trim());

  static Uri apiUri(String path, {Map<String, String>? query}) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return Uri.parse('$base$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value.trim()),
      ),
    );
  }
}
