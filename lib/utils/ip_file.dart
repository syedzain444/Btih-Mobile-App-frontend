import 'dart:async';
import 'dart:io' show HttpClient;

import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the HMIS API base URL automatically and remembers what worked.
class ApiConfig {
  ApiConfig._();

  /// Deployed HMIS API — hospital LAN.
  static const String productionApiHost = '10.101.1.93';
  static const String defaultBaseUrl = 'http://$productionApiHost:7078';
  static const String swaggerUrl = '$defaultBaseUrl/Swagger/index.html';

  /// USB tunnel via adb reverse + PC portproxy (phone not on hospital Wi‑Fi).
  static const String usbTunnelBaseUrl = 'http://127.0.0.1:7078';

  static const int port = 7078;
  static const Duration probeTimeout = Duration(seconds: 4);
  static const Duration requestTimeout = Duration(seconds: 20);

  static const _savedUrlKey = 'api_base_url';
  static const _customUrlKey = 'api_custom_url';

  static String? _resolvedBaseUrl;
  static String? _lastProbeError;
  static bool _initialized = false;
  static http.Client? _rawHttpClient;
  static http.Client? _authHttpClient;

  static String get baseUrl => _resolvedBaseUrl ?? defaultBaseUrl;

  static String? get lastProbeError => _lastProbeError;

  static bool get isResolved => _resolvedBaseUrl != null;

  static HttpClient _createHttpClient() {
    return HttpClient()..badCertificateCallback = (_, __, ___) => true;
  }

  static http.Client get _probeClient {
    if (kIsWeb) {
      return http.Client();
    }
    _rawHttpClient ??= IOClient(_createHttpClient());
    return _rawHttpClient!;
  }

  /// Shared HTTP client — TLS bypass + JWT Authorization on API calls.
  static http.Client get client {
    if (kIsWeb) {
      _authHttpClient ??= _AuthHttpClient(http.Client());
      return _authHttpClient!;
    }
    _rawHttpClient ??= IOClient(_createHttpClient());
    _authHttpClient ??= _AuthHttpClient(_rawHttpClient!);
    return _authHttpClient!;
  }

  /// Dio client with TLS bypass, JWT header, and 401 handling.
  static Dio createDio() {
    final dio = Dio();
    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: _createHttpClient,
      );
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers.addAll(AuthSession.authHeaders);
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 && AuthSession.isLoggedIn) {
            unawaited(AuthSession.handleUnauthorized());
          }
          handler.next(error);
        },
      ),
    );
    return dio;
  }

  static String get connectionHelpMessage =>
      _lastProbeError ??
      'Cannot reach the HMIS API server.\n\n'
          'Physical device (USB):\n'
          '1. Run start-mobile-dev.bat (or run-physical-device.bat)\n'
          '2. Keep phone connected by USB\n'
          '3. Hot restart the app (R)\n\n'
          'Hospital Wi‑Fi:\n'
          '1. PC and phone on hospital network\n'
          '2. Open $defaultBaseUrl/Swagger/index.html in Chrome\n'
          '3. Hot restart the app (R)';

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
    // Chrome/web: use deployed API directly (no dart:io probing).
    if (kIsWeb) {
      _resolvedBaseUrl = _normalize(defaultBaseUrl);
      return true;
    }

    if (!force && _resolvedBaseUrl != null) {
      if (await _probe(_resolvedBaseUrl!)) {
        return true;
      }
      invalidate();
    }

    _lastProbeError = null;

    final prefs = await SharedPreferences.getInstance();
    var savedUrl = prefs.getString(_savedUrlKey);
    final customUrl = prefs.getString(_customUrlKey);

    await _purgeStaleSavedUrls(prefs, savedUrl, customUrl);
    savedUrl = prefs.getString(_savedUrlKey);
    final refreshedCustomUrl = prefs.getString(_customUrlKey);

    // Prefer the configured production API first.
    if (await _probe(defaultBaseUrl)) {
      _resolvedBaseUrl = _normalize(defaultBaseUrl);
      await prefs.setString(_savedUrlKey, _resolvedBaseUrl!);
      return true;
    }

    if (refreshedCustomUrl != null && await _probe(refreshedCustomUrl)) {
      _resolvedBaseUrl = _normalize(refreshedCustomUrl);
      await prefs.setString(_savedUrlKey, _resolvedBaseUrl!);
      return true;
    }

    if (savedUrl != null && await _probe(savedUrl)) {
      _resolvedBaseUrl = _normalize(savedUrl);
      return true;
    }

    final httpsFallback = defaultBaseUrl.replaceFirst('http://', 'https://');
    if (httpsFallback != defaultBaseUrl && await _probe(httpsFallback)) {
      _resolvedBaseUrl = _normalize(httpsFallback);
      await prefs.setString(_savedUrlKey, _resolvedBaseUrl!);
      return true;
    }

    // USB tunnel: phone -> adb reverse -> PC portproxy -> hospital API
    if (!kIsWeb) {
      if (await _probe(usbTunnelBaseUrl)) {
        _resolvedBaseUrl = _normalize(usbTunnelBaseUrl);
        await prefs.setString(_savedUrlKey, _resolvedBaseUrl!);
        return true;
      }
      final usbHttps = usbTunnelBaseUrl.replaceFirst('http://', 'https://');
      if (usbHttps != usbTunnelBaseUrl && await _probe(usbHttps)) {
        _resolvedBaseUrl = _normalize(usbHttps);
        await prefs.setString(_savedUrlKey, _resolvedBaseUrl!);
        return true;
      }
    }

    final candidates = await _buildCandidates(
      savedUrl: savedUrl,
      customUrl: refreshedCustomUrl,
    );

    final working = await _probeFirstMatch(candidates);
    if (working != null) {
      _resolvedBaseUrl = working;
      await prefs.setString(_savedUrlKey, working);
      return true;
    }

    _lastProbeError =
        'Cannot reach the HMIS API server.\n\n'
        'Default: $defaultBaseUrl\n'
        'Tried ${candidates.length} addresses.\n\n'
        'Chrome / PC on hospital network:\n'
        '1. Open $defaultBaseUrl/Swagger/index.html in Chrome\n'
        '2. Hot restart the app (R)\n\n'
        'Physical device (USB, no Wi‑Fi):\n'
        '1. Run run-physical-device.bat (or start-mobile-dev.bat)\n'
        '2. Keep phone connected by USB\n'
        '3. Hot restart the app (R)';

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
    add(defaultBaseUrl);
    add(defaultBaseUrl.replaceFirst('http://', 'https://'));

    if (!kIsWeb) {
      add(usbTunnelBaseUrl);
      add(usbTunnelBaseUrl.replaceFirst('http://', 'https://'));
    }

    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) {
      add(envHost);
    }

    return ordered;
  }

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

  static Future<void> _purgeStaleSavedUrls(
    SharedPreferences prefs,
    String? savedUrl,
    String? customUrl,
  ) async {
    if (savedUrl != null && _isLegacyApiUrl(savedUrl)) {
      await prefs.remove(_savedUrlKey);
    }
    if (customUrl != null && _isLegacyApiUrl(customUrl)) {
      await prefs.remove(_customUrlKey);
    }
  }

  static bool _isLegacyApiUrl(String url) {
    if (url.contains('127.0.0.1') || url.contains('localhost')) {
      return false;
    }
    if (url.contains(productionApiHost)) {
      return false;
    }
    return url.contains(':8080') ||
        url.contains('172.16.40') ||
        url.contains('172.16.50.68') ||
        url.contains('172.20.10.');
  }

  static Future<bool> _probe(String base) async {
    final normalized = _normalize(base);
    const probePaths = [
      '/Swagger/index.html',
      '/swagger/index.html',
      '/api/Health',
      '/swagger/v1/swagger.json',
    ];

    for (final path in probePaths) {
      final uri = Uri.parse('$normalized$path');
      try {
        final response = await _probeClient.get(uri).timeout(probeTimeout);
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  static String _normalize(String base) {
    var value = base.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.host.isNotEmpty) {
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      value = '${uri.scheme}://${uri.host}$portPart';
    }
    return value;
  }
}

class _AuthHttpClient extends http.BaseClient {
  _AuthHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authHeaders = AuthSession.authHeaders;
    authHeaders.forEach((key, value) {
      request.headers[key] = value;
    });

    final response = await _inner.send(request);

    if (response.statusCode == 401 &&
        AuthSession.isLoggedIn &&
        !_isAuthEndpoint(request.url)) {
      unawaited(AuthSession.handleUnauthorized());
    }

    return response;
  }

  bool _isAuthEndpoint(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.contains('/api/auth/');
  }
}
