import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/foundation.dart';

class HealthStatus {
  final bool healthy;
  final String status;
  final String? database;
  final String? environment;
  final DateTime? checkedAt;
  final String? message;

  const HealthStatus({
    required this.healthy,
    required this.status,
    this.database,
    this.environment,
    this.checkedAt,
    this.message,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'Unknown';
    return HealthStatus(
      healthy: status.toLowerCase() == 'healthy',
      status: status,
      database: json['database']?.toString(),
      environment: json['environment']?.toString(),
      checkedAt: DateTime.tryParse(json['checkedAt']?.toString() ?? ''),
      message: json['message']?.toString(),
    );
  }
}

class HealthService {
  HealthService._();

  static final HealthService instance = HealthService._();

  HealthStatus? lastStatus;
  bool get isOnline => lastStatus?.healthy ?? true;

  /// Probe `GET /api/Health`. Returns false on network/5xx failures.
  Future<bool> check({bool force = false}) async {
    try {
      final response = await ApiConfig.client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/Health'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          lastStatus = HealthStatus.fromJson(body);
        } else {
          lastStatus = const HealthStatus(healthy: true, status: 'Healthy');
        }
        return lastStatus!.healthy;
      }

      lastStatus = HealthStatus(
        healthy: false,
        status: 'Unhealthy',
        message: 'HTTP ${response.statusCode}',
      );
      return false;
    } catch (e) {
      debugPrint('HealthService.check failed: $e');
      lastStatus = HealthStatus(
        healthy: false,
        status: 'Offline',
        message: e.toString(),
      );
      return false;
    }
  }

  /// Dev/debug: schema inventory from `GET /api/Health/schema`.
  Future<Map<String, dynamic>?> fetchSchema() async {
    try {
      final response = await ApiConfig.client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/Health/schema'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return null;
    } catch (_) {
      return null;
    }
  }
}
