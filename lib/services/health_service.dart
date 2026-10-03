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

  /// Probe `GET /api/Health`.
  /// Returns false only when the API is unreachable (network error).
  /// HTTP 200–599 means the host responded — including Degraded (503).
  Future<bool> check({bool force = false}) async {
    try {
      final response = await ApiConfig.client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/Health'))
          .timeout(const Duration(seconds: 6));

      // Any HTTP response = reachable (online for connectivity UI).
      if (response.statusCode >= 200 && response.statusCode < 600) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            lastStatus = HealthStatus.fromJson(body);
            // Treat Degraded as online — API is up, DB marking may be soft.
            if (!lastStatus!.healthy &&
                lastStatus!.status.toLowerCase().contains('degrad')) {
              lastStatus = HealthStatus(
                healthy: true,
                status: lastStatus!.status,
                database: lastStatus!.database,
                environment: lastStatus!.environment,
                checkedAt: lastStatus!.checkedAt,
                message: lastStatus!.message,
              );
            }
          } else {
            lastStatus = const HealthStatus(healthy: true, status: 'Healthy');
          }
        } catch (_) {
          lastStatus = const HealthStatus(healthy: true, status: 'Reachable');
        }
        return true;
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
