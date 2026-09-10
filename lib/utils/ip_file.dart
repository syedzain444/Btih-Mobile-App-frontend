import 'dart:async';
import 'dart:io' show HttpClient, Platform;

import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the HMIS API base URL automatically and remembers what worked.
///
/// Platform-specific cache keys prevent Chrome from reusing an Android URL
/// (and vice versa). Use `--dart-define=API_MODE=local` in dev scripts so
/// debug builds never auto-switch to production when the hospital LAN is up.
class ApiConfig {
  ApiConfig._();

  /// Local development API (`dotnet run --launch-profile http`).
  static const String localDevBaseUrl = 'http://localhost:8080';
  static const String localDevSwaggerUrl =
      '$localDevBaseUrl/swagger/index.html';

  /// Deployed HMIS API — hospital LAN.
  static const String productionApiHost = '10.101.1.93';
  static const String productionBaseUrl = 'http://$productionApiHost:7078';
  static const String productionSwaggerUrl =
      '$productionBaseUrl/Swagger/index.html';

  /// Default when no local API is reachable (production).
  static const String defaultBaseUrl = productionBaseUrl;
  static const String swaggerUrl = localDevSwaggerUrl;

  /// USB tunnel via adb reverse (phone not on hospital Wi‑Fi).
  static const String usbTunnelBaseUrl = 'http://127.0.0.1:8080';

  static const int localDevPort = 8080;
  static const int productionPort = 7078;
  static const int port = localDevPort;
  static const Duration probeTimeout = Duration(seconds: 4);
  static const Duration fastProbeTimeout = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 20);

  static const _legacySavedUrlKey = 'api_base_url';
  static const _legacyCustomUrlKey = 'api_custom_url';

  static String? _resolvedBaseUrl;
  static String? _activeEnvironment;
  static String? _lastProbeError;
  static bool _initialized = false;

  /// `production`, `local`, `custom`, or `override` after [ensureResolved].
  static String? get activeEnvironment => _activeEnvironment;
  static http.Client? _rawHttpClient;
  static http.Client? _authHttpClient;

  static String get _platformId {
    if (kIsWeb) return 'web';
    if (!kIsWeb && Platform.isAndroid) return 'android';
    if (!kIsWeb && Platform.isIOS) return 'ios';
    return 'desktop';
  }

  static String get _savedUrlKey => 'api_base_url_$_platformId';
  static String get _customUrlKey => 'api_custom_url_$_platformId';

  /// Best default when [ensureResolved] has not run yet (debug builds).
  static String get defaultDebugBaseUrl => _preferredLocalDevUrl();

  static String get baseUrl =>
      _resolvedBaseUrl ?? (kDebugMode ? defaultDebugBaseUrl : defaultBaseUrl);

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
      _lastProbeError ?? _buildConnectionError(0);

  /// Call once from main() before runApp.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await ensureResolved();
  }

  static void invalidate() {
    _resolvedBaseUrl = null;
    _activeEnvironment = null;
  }

  /// Clears cached API URL for every platform (use after switching environments).
  static Future<void> clearCachedApiUrl() async {
    invalidate();
    _lastProbeError = null;
    final prefs = await SharedPreferences.getInstance();
    for (final id in ['web', 'android', 'ios', 'desktop']) {
      await prefs.remove('api_base_url_$id');
      await prefs.remove('api_custom_url_$id');
    }
    await prefs.remove(_legacySavedUrlKey);
    await prefs.remove(_legacyCustomUrlKey);
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
    await _migrateLegacyKeys(prefs);
    return prefs.getString(_customUrlKey);
  }

  static Future<bool> ensureResolved({bool force = false}) async {
    if (!force && _resolvedBaseUrl != null) {
      if (await _probeFast(_resolvedBaseUrl!)) {
        return true;
      }
      invalidate();
    }

    _lastProbeError = null;
    _activeEnvironment = null;

    const envHost = String.fromEnvironment('API_HOST');
    const apiMode = String.fromEnvironment('API_MODE', defaultValue: 'auto');

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyKeys(prefs);

    var savedUrl = prefs.getString(_savedUrlKey);
    var customUrl = prefs.getString(_customUrlKey);

    await _purgeStaleSavedUrls(prefs, savedUrl, customUrl);
    savedUrl = prefs.getString(_savedUrlKey);
    customUrl = prefs.getString(_customUrlKey);

    // 1. Explicit build-time override (run-*-local-dev.bat sets this).
    if (envHost.isNotEmpty) {
      final url = _normalize(envHost);
      if (await _probeFast(url)) {
        return _saveResolved(url, 'override', prefs);
      }
      if (kDebugMode) {
        return _saveResolved(url, 'override', prefs, persist: false);
      }
    }

    final localOnly = apiMode == 'local' || (kDebugMode && apiMode == 'auto');
    final productionOnly = apiMode == 'production';

    // 2. Local dev — Chrome, AnyDesk Chrome, Android USB, emulator.
    if (localOnly) {
      if (customUrl != null && await _probeFast(customUrl)) {
        return _saveResolved(customUrl, 'custom', prefs);
      }

      for (final localUrl in _localDevCandidates()) {
        if (await _probeFast(localUrl)) {
          return _saveResolved(localUrl, 'local', prefs);
        }
      }

      if (savedUrl != null &&
          _isLocalDevUrl(savedUrl) &&
          await _probeFast(savedUrl)) {
        return _saveResolved(savedUrl, 'local', prefs, persist: false);
      }

      if (kDebugMode) {
        final fallback = _preferredLocalDevUrl();
        return _saveResolved(fallback, 'local', prefs, persist: false);
      }
    }

    // 3. Production-only mode (release builds against hospital server).
    if (productionOnly) {
      if (await _resolveProduction(prefs)) {
        return true;
      }
    }

    // 4. Release auto — production first, then local fallbacks.
    if (!kDebugMode && apiMode == 'auto') {
      if (await _resolveProduction(prefs)) {
        return true;
      }

      for (final localUrl in _localDevCandidates()) {
        if (await _probeFast(localUrl)) {
          return _saveResolved(localUrl, 'local', prefs);
        }
      }
    }

    // 5. Saved / custom URLs (non-debug auto, or explicit custom host).
    if (customUrl != null && await _probeFast(customUrl)) {
      return _saveResolved(customUrl, 'custom', prefs);
    }

    if (savedUrl != null && await _probeFast(savedUrl)) {
      return _saveResolved(savedUrl, 'custom', prefs, persist: false);
    }

    // 6. Broad probe list (release builds only reach here in auto mode).
    if (!localOnly) {
      if (await _resolveProduction(prefs)) {
        return true;
      }
    }

    final candidates = _buildCandidates(
      savedUrl: savedUrl,
      customUrl: customUrl,
      includeProduction: !localOnly,
    );

    final working = await _probeFirstMatch(candidates);
    if (working != null) {
      final env = _environmentForUrl(working);
      return _saveResolved(working, env, prefs);
    }

    if (kDebugMode && localOnly) {
      final fallback = _preferredLocalDevUrl();
      return _saveResolved(fallback, 'local', prefs, persist: false);
    }

    _lastProbeError = _buildConnectionError(candidates.length);
    return false;
  }

  static Future<bool> _resolveProduction(SharedPreferences prefs) async {
    if (await _probeFast(productionBaseUrl) &&
        await _productionHasNewAuthApis(productionBaseUrl)) {
      return _saveResolved(productionBaseUrl, 'production', prefs);
    }

    if (await _probeFast(productionBaseUrl)) {
      return _saveResolved(productionBaseUrl, 'production', prefs);
    }

    if (!kIsWeb) {
      final usbProdTunnel = 'http://127.0.0.1:$productionPort';
      if (await _probeFast(usbProdTunnel)) {
        return _saveResolved(usbProdTunnel, 'production', prefs);
      }
    }

    return false;
  }

  static String _preferredLocalDevUrl() {
    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) {
      return _normalize(envHost);
    }
    if (kIsWeb) {
      return localDevBaseUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$localDevPort';
    }
    return localDevBaseUrl;
  }

  static bool _isLocalDevUrl(String url) {
    final normalized = _normalize(url);
    if (_localDevCandidates().contains(normalized)) {
      return true;
    }
    return normalized.endsWith(':$localDevPort');
  }

  static String _buildConnectionError(int triedCount) {
    if (kIsWeb) {
      return 'Cannot reach the HMIS API server.\n\n'
          '1. Start API: cd Btih-Mobile-App-backend && dotnet run --launch-profile http\n'
          '2. Open $localDevSwaggerUrl in Chrome (must show Swagger UI)\n'
          '3. Run run-dev.bat and choose Chrome (option 1)\n'
          '   (sets API_HOST + API_MODE=local automatically)\n'
          '4. Hot restart (R)\n\n'
          'Works the same on AnyDesk — localhost is the remote PC.\n'
          'Tried $triedCount addresses.';
    }
    final platformHint = _platformConnectionHint();
    return 'Cannot reach the HMIS API server.\n\n'
        'Local dev: $localDevSwaggerUrl\n'
        'Production: $productionSwaggerUrl\n'
        'Tried $triedCount addresses.\n\n'
        '$platformHint';
  }

  static String _platformConnectionHint() {
    if (kIsWeb) {
      return 'Chrome / web:\n'
          '1. Run run-dev.bat → option 1 Chrome (repo root)\n'
          '2. Or: flutter run -d chrome '
          '--dart-define=API_HOST=http://localhost:8080 '
          '--dart-define=API_MODE=local\n'
          '3. Hot restart (R) — not just hot reload';
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'Android emulator:\n'
          '1. Backend: dotnet run --launch-profile http (listens on 0.0.0.0:8080)\n'
          '2. App uses http://10.0.2.2:8080 automatically\n'
          '3. Hot restart (R)\n\n'
          'Android physical device (USB):\n'
          '1. Run run-dev.bat → option 2 Android (repo root)\n'
          '   (starts local API + adb reverse tcp:8080)\n'
          '2. Or manually: adb reverse tcp:8080 tcp:8080\n'
          '   then flutter run '
          '--dart-define=API_HOST=http://127.0.0.1:8080 '
          '--dart-define=API_MODE=local';
    }
    return 'Local dev (PC):\n'
        '1. cd Btih-Mobile-App-backend && dotnet run --launch-profile http\n'
        '2. Open $localDevSwaggerUrl\n'
        '3. Hot restart the app (R)';
  }

  static Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
    final legacySaved = prefs.getString(_legacySavedUrlKey);
    final legacyCustom = prefs.getString(_legacyCustomUrlKey);
    if (legacySaved == null && legacyCustom == null) {
      return;
    }

    if (legacySaved != null && !prefs.containsKey(_savedUrlKey)) {
      if (_isUrlCompatibleWithCurrentPlatform(legacySaved)) {
        await prefs.setString(_savedUrlKey, legacySaved);
      }
    }

    if (legacyCustom != null && !prefs.containsKey(_customUrlKey)) {
      if (_isUrlCompatibleWithCurrentPlatform(legacyCustom)) {
        await prefs.setString(_customUrlKey, legacyCustom);
      }
    }

    await prefs.remove(_legacySavedUrlKey);
    await prefs.remove(_legacyCustomUrlKey);
  }

  static bool _isUrlCompatibleWithCurrentPlatform(String url) {
    final lower = url.toLowerCase();
    if (kIsWeb) {
      return true;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return !lower.contains('localhost');
    }
    return true;
  }

  static Future<bool> _saveResolved(
    String url,
    String environment,
    SharedPreferences prefs, {
    bool persist = true,
  }) async {
    _resolvedBaseUrl = _normalize(url);
    _activeEnvironment = environment;
    if (persist) {
      await prefs.setString(_savedUrlKey, _resolvedBaseUrl!);
    }
    return true;
  }

  static String _environmentForUrl(String url) {
    final normalized = _normalize(url);
    if (normalized.contains(productionApiHost) ||
        normalized.endsWith(':$productionPort')) {
      return 'production';
    }
    if (_isLocalDevUrl(normalized)) {
      return 'local';
    }
    return 'custom';
  }

  /// True when production Swagger exposes the new registration auth endpoints.
  static Future<bool> _productionHasNewAuthApis(String baseUrl) async {
    const markers = [
      'send-registration-otp',
      'SendRegistrationOtp',
      'profileSetupRequired',
    ];

    final normalized = _normalize(baseUrl);
    const swaggerPaths = [
      '/swagger/v1/swagger.json',
      '/Swagger/v1/swagger.json',
    ];

    for (final path in swaggerPaths) {
      try {
        final response = await _probeClient
            .get(Uri.parse('$normalized$path'))
            .timeout(probeTimeout);
        if (response.statusCode != 200) continue;
        final body = response.body;
        if (markers.any(body.contains)) return true;
      } catch (_) {}
    }
    return false;
  }

  static List<String> _localDevCandidates() {
    final candidates = <String>[];
    const lanHost = String.fromEnvironment('API_LAN_HOST');

    if (!kIsWeb && Platform.isAndroid) {
      candidates.add('http://10.0.2.2:$localDevPort');
      candidates.add(usbTunnelBaseUrl);
      if (lanHost.isNotEmpty) {
        candidates.add('http://$lanHost:$localDevPort');
      }
    }

    if (kIsWeb || (!kIsWeb && !Platform.isAndroid)) {
      candidates.add(localDevBaseUrl);
      candidates.add(localDevBaseUrl.replaceFirst('localhost', '127.0.0.1'));
    }

    if (!kIsWeb && !Platform.isAndroid) {
      candidates.add(usbTunnelBaseUrl);
    }

    return candidates;
  }

  static List<String> _buildCandidates({
    String? savedUrl,
    String? customUrl,
    bool includeProduction = true,
  }) {
    final ordered = <String>[];
    final seen = <String>{};

    void add(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final normalized = _normalize(raw.trim());
      if (seen.add(normalized)) {
        ordered.add(normalized);
      }
    }

    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) {
      add(envHost);
    }

    add(customUrl);
    add(savedUrl);
    for (final localUrl in _localDevCandidates()) {
      add(localUrl);
    }

    if (includeProduction) {
      add(productionBaseUrl);
      add(productionBaseUrl.replaceFirst('http://', 'https://'));

      if (!kIsWeb) {
        add(usbTunnelBaseUrl);
        add('http://127.0.0.1:7078');
      }
    }

    return ordered;
  }

  static Future<String?> _probeFirstMatch(List<String> candidates) async {
    for (final candidate in candidates) {
      if (await _probeFast(candidate)) {
        return _normalize(candidate);
      }
    }
    return null;
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
    if (url.contains('127.0.0.1') ||
        url.contains('localhost') ||
        url.contains(productionApiHost)) {
      return false;
    }
    return url.contains('172.16.40') ||
        url.contains('172.16.50.68') ||
        url.contains('172.20.10.');
  }

  static Future<bool> _probeFast(String base) async {
    final normalized = _normalize(base);
    const probePaths = [
      '/swagger/v1/swagger.json',
      '/swagger/index.html',
      '/Swagger/index.html',
    ];

    for (final path in probePaths) {
      final uri = Uri.parse('$normalized$path');
      try {
        final response =
            await _probeClient.get(uri).timeout(fastProbeTimeout);
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
