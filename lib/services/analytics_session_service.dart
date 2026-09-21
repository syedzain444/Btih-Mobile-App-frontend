import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks patient engagement sessions via `/api/analytics/session/*`.
class AnalyticsSessionService {
  AnalyticsSessionService._();

  static final AnalyticsSessionService instance = AnalyticsSessionService._();

  static const _guidKey = 'analytics_session_guid';
  static const _startedAtKey = 'analytics_session_started_at';

  String? _sessionGuid;
  DateTime? _startedAt;
  bool _starting = false;

  Future<void> startIfLoggedIn() async {
    if (!AuthSession.isLoggedIn || AuthSession.token == null) return;
    if (_starting) return;
    if (_sessionGuid != null && _sessionGuid!.isNotEmpty) return;

    _starting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final platform = kIsWeb
          ? 'web'
          : Platform.isIOS
              ? 'ios'
              : 'android';

      final response = await ApiConfig.client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/analytics/session/start'),
        headers: {
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({
          'sessionGuid': _newGuid(),
          'platform': platform,
          'appVersion': '2.1.0',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body is Map && body['data'] is Map) {
          final data = Map<String, dynamic>.from(body['data'] as Map);
          _sessionGuid = data['sessionGuid']?.toString();
          _startedAt = DateTime.tryParse(data['startedAt']?.toString() ?? '') ??
              DateTime.now();
          if (_sessionGuid != null) {
            await prefs.setString(_guidKey, _sessionGuid!);
            await prefs.setString(
              _startedAtKey,
              _startedAt!.toIso8601String(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('AnalyticsSessionService.start failed: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> endIfActive() async {
    if (_sessionGuid == null || _sessionGuid!.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_guidKey);
        if (stored == null || stored.isEmpty) return;
        _sessionGuid = stored;
        _startedAt = DateTime.tryParse(prefs.getString(_startedAtKey) ?? '');
      } catch (_) {
        return;
      }
    }

    if (!AuthSession.isLoggedIn || AuthSession.token == null) {
      await _clearLocal();
      return;
    }

    final activeGuid = _sessionGuid;
    if (activeGuid == null || activeGuid.isEmpty) return;

    final started = _startedAt ?? DateTime.now();
    final duration = DateTime.now().difference(started).inSeconds;

    try {
      await ApiConfig.client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/analytics/session/end'),
        headers: {
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({
          'sessionGuid': activeGuid,
          'durationSeconds': duration < 0 ? 0 : duration,
        }),
      );
    } catch (e) {
      debugPrint('AnalyticsSessionService.end failed: $e');
    } finally {
      await _clearLocal();
    }
  }

  Future<void> _clearLocal() async {
    _sessionGuid = null;
    _startedAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guidKey);
      await prefs.remove(_startedAtKey);
    } catch (_) {}
  }

  static String _newGuid() {
    final r = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
    return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
  }
}
