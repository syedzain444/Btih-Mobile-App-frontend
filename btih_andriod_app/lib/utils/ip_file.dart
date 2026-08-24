import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the HMIS API base URL automatically and remembers what worked.
class ApiConfig {
  ApiConfig._();

  static const int port = 8080;
  static const Duration probeTimeout = Duration(seconds: 2);
  static const Duration requestTimeout = Duration(seconds: 20);

  static const _savedUrlKey = 'api_base_url';
  static const _customUrlKey = 'api_custom_url';

  static String? _resolvedBaseUrl;
  static String? _lastProbeError;
  static bool _initialized = false;

  static String get baseUrl => _resolvedBaseUrl ?? 'http://127.0.0.1:$port';

  static String? get lastProbeError => _lastProbeError;

  static bool get isResolved => _resolvedBaseUrl != null;

  static String get connectionHelpMessage =>
      _lastProbeError ??
      'Cannot reach the HMIS API server.\n\n'
          'Quick fix: double-click start-mobile-dev.bat in the project folder, '
          'then hot restart the app (R).\n\n'
          'That script starts the API, sets up USB forwarding, and opens the '
          'firewall on port $port.';

  /// Call once from main() before runApp.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await ensureResolved();
  }

  static void invalidate() {
    _resolvedBaseUrl = null;
  }

  static Future<void> setCustomBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim() ?? '';

    if (trimmed.isEmpty) {
      await prefs.remove(_customUrlKey);
    } else {
      await prefs.setString(_customUrlKey, _normalize(trimmed));
    }

    invalidate();
    await ensureResolved(force: true);
  }

  static Future<String?> getCustomBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customUrlKey);
  }

  static Future<bool> ensureResolved({bool force = false}) async {
    if (!force && _resolvedBaseUrl != null) {
      if (await _probe(_resolvedBaseUrl!)) {
        return true;
      }
      invalidate();
    }

    _lastProbeError = null;

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_savedUrlKey);
    final customUrl = prefs.getString(_customUrlKey);
    final candidates = await _buildCandidates(
      savedUrl: savedUrl,
      customUrl: customUrl,
    );

    if (savedUrl != null && await _probe(savedUrl)) {
      _resolvedBaseUrl = _normalize(savedUrl);
      return true;
    }

    if (customUrl != null && await _probe(customUrl)) {
      _resolvedBaseUrl = _normalize(customUrl);
      await prefs.setString(_savedUrlKey, _resolvedBaseUrl!);
      return true;
    }

    final working = await _probeFirstMatch(candidates);
    if (working != null) {
      _resolvedBaseUrl = working;
      await prefs.setString(_savedUrlKey, working);
      return true;
    }

    _lastProbeError =
        'Cannot reach the HMIS API server.\n\n'
        'Tried ${candidates.length} addresses including USB, emulator, and '
        'your Wi‑Fi network.\n\n'
        '1. Run start-mobile-dev.bat (starts API + USB setup)\n'
        '2. Hot restart the app (R)\n'
        '3. Same Wi‑Fi: phone and PC must be on the same network\n'
        '4. USB: keep the phone connected while testing';

    return false;
  }

  static Future<List<String>> _buildCandidates({
    String? savedUrl,
    String? customUrl,
  }) async {
    final ordered = <String>[];
    final seen = <String>{};

    void add(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final normalized = _normalize(raw.trim());
      if (seen.add(normalized)) {
        ordered.add(normalized);
      }
    }

    add(customUrl);
    add(savedUrl);
    add('http://127.0.0.1:$port');
    add('http://10.0.2.2:$port');

    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) {
      add(envHost);
    }

    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        final parts = wifiIp.split('.');
        if (parts.length == 4) {
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          for (final host in _subnetHosts) {
            add('http://$prefix.$host:$port');
          }
        }
      }
    } catch (_) {}

    return ordered;
  }

  static const List<int> _subnetHosts = [
    1, 2, 10, 20, 30, 40, 50, 51, 52, 53, 54, 55, 100, 101, 102, 200, 254,
  ];

  static Future<String?> _probeFirstMatch(List<String> candidates) async {
    if (candidates.isEmpty) return null;

    final controller = StreamController<String>();

    for (final candidate in candidates) {
      unawaited(() async {
        if (await _probe(candidate) && !controller.isClosed) {
          controller.add(_normalize(candidate));
        }
      }());
    }

    try {
      return await controller.stream.first.timeout(probeTimeout);
    } catch (_) {
      return null;
    } finally {
      await controller.close();
    }
  }

  static Future<bool> _probe(String base) async {
    final normalized = _normalize(base);
    final uri = Uri.parse('$normalized/api/Health');

    try {
      final response = await http.get(uri).timeout(probeTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _normalize(String base) {
    var value = base.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    return value;
  }
}
