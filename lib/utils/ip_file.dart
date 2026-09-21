import 'dart:async';
import 'dart:io' show HttpClient, Platform;

import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the HMIS API base URL automatically and remembers what worked.
///
/// Default target is the hospital production API on `.93:7078`.
/// Use `--dart-define=API_MODE=local` (and optional `API_HOST`) only when you
/// intentionally want the local `dotnet run` backend.
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

  /// Default API target (production on .93).
  static const String defaultBaseUrl = productionBaseUrl;
  static const String swaggerUrl = productionSwaggerUrl;

  /// USB tunnel via adb reverse for the **local** API (port 8080).
  static const String usbTunnelBaseUrl = 'http://127.0.0.1:8080';

  /// USB tunnel via adb reverse for the **hospital** API (port 7078).
  static const String productionUsbTunnelBaseUrl = 'http://127.0.0.1:7078';

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

  /// Best default before [ensureResolved] finishes — always production.
  static String get defaultDebugBaseUrl => defaultBaseUrl;

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
      _lastProbeError ?? _buildConnectionError(0);

  /// Call once from main() before runApp.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Wipe any stale localhost cache left by older APKs.
    await clearCachedApiUrl();
    await ensureResolved(force: true);
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
    const envHost = String.fromEnvironment('API_HOST');
    // Default is production (.93). Use API_MODE=local only for local API work.
    const apiMode =
        String.fromEnvironment('API_MODE', defaultValue: 'production');

    // Fast path: already pinned to a working URL.
    if (!force && _resolvedBaseUrl != null) {
      if (apiMode == 'production' &&
          (_resolvedBaseUrl == productionBaseUrl ||
              _resolvedBaseUrl == productionUsbTunnelBaseUrl)) {
        return true;
      }
      if (apiMode == 'local' && _isLocalDevUrl(_resolvedBaseUrl!)) {
        return true;
      }
      if (envHost.isNotEmpty &&
          _normalize(envHost) == _normalize(_resolvedBaseUrl!)) {
        return true;
      }
      if (await _probeFast(_resolvedBaseUrl!)) {
        return true;
      }
      invalidate();
    }

    _lastProbeError = null;
    _activeEnvironment = null;

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyKeys(prefs);

    var savedUrl = prefs.getString(_savedUrlKey);
    var customUrl = prefs.getString(_customUrlKey);

    await _purgeStaleSavedUrls(prefs, savedUrl, customUrl);
    savedUrl = prefs.getString(_savedUrlKey);
    customUrl = prefs.getString(_customUrlKey);

    // Drop cached *local-dev* (8080) URLs when targeting production APKs.
    // Keep production USB tunnel (127.0.0.1:7078) — that is intentional for
    // run-dev.bat option 3.
    if (apiMode != 'local') {
      if (savedUrl != null && _isLocalDevUrl(savedUrl)) {
        await prefs.remove(_savedUrlKey);
        savedUrl = null;
      }
      if (customUrl != null && _isLocalDevUrl(customUrl)) {
        await prefs.remove(_customUrlKey);
        customUrl = null;
      }
    }

    // 1. Explicit build-time override from run-dev.bat (options 1 / 2 / 3).
    if (envHost.isNotEmpty) {
      final url = _normalize(envHost);
      final envLabel = _environmentForUrl(url);
      final reachable = await _probeFast(url);
      if (reachable) {
        // ignore: avoid_print
        print('[ApiConfig] API_HOST override → $url (mode=$apiMode, env=$envLabel)');
        return _saveResolved(
          url,
          envLabel == 'local' ? 'override-local' : 'override',
          prefs,
        );
      }

      // USB tunnel dart-define is present but adb reverse / PC proxy is down.
      if (_isProductionUsbTunnelUrl(url)) {
        // Never pin a dead tunnel — use live hospital host instead.
        // ignore: avoid_print
        print(
          '[ApiConfig] USB tunnel unreachable — using $productionBaseUrl',
        );
        return _saveResolved(productionBaseUrl, 'production', prefs);
      }

      // Non-tunnel override (e.g. LAN IP): keep it even if Swagger probe is slow.
      // ignore: avoid_print
      print(
        '[ApiConfig] API_HOST override (probe failed, still using) → $url',
      );
      return _saveResolved(
        url,
        envLabel == 'local' ? 'override-local' : 'override',
        prefs,
      );
    }

    // 2. Production — prefer USB tunnel only when it actually responds.
    if (apiMode == 'production') {
      final target = await _pickProductionBaseUrl();
      // ignore: avoid_print
      print('[ApiConfig] production → $target');
      return _saveResolved(target, 'production', prefs);
    }

    final localOnly = apiMode == 'local';
    final productionPreferred = apiMode == 'auto';

    // 3. Local-only mode — never touch .93.
    if (localOnly) {
      if (customUrl != null && await _probeFast(customUrl)) {
        return _saveResolved(customUrl, 'custom', prefs);
      }

      for (final localUrl in await _localDevCandidates()) {
        if (await _probeFast(localUrl)) {
          // ignore: avoid_print
          print('[ApiConfig] local → $localUrl');
          return _saveResolved(localUrl, 'local', prefs);
        }
      }

      if (savedUrl != null &&
          _isLocalDevUrl(savedUrl) &&
          await _probeFast(savedUrl)) {
        return _saveResolved(savedUrl, 'local', prefs, persist: false);
      }

      final localCandidates = await _buildCandidates(
        savedUrl: savedUrl,
        customUrl: customUrl,
        includeProduction: false,
      );
      final localWorking = await _probeFirstMatch(localCandidates);
      if (localWorking != null) {
        return _saveResolved(
          localWorking,
          _environmentForUrl(localWorking),
          prefs,
        );
      }

      // Still pin the best local candidate so login can attempt the call.
      final localList = await _localDevCandidates();
      final fallbackLocal =
          localList.isNotEmpty ? localList.first : localDevBaseUrl;
      // ignore: avoid_print
      print('[ApiConfig] local fallback (unreachable yet) → $fallbackLocal');
      _lastProbeError = _buildLocalConnectionError(fallbackLocal);
      return _saveResolved(fallbackLocal, 'local', prefs);
    }

    // 4. Auto mode — production first, then local fallback.
    if (productionPreferred) {
      if (await _resolveProduction(prefs)) {
        return true;
      }
      // Pin production anyway so the APK can still attempt live calls.
      return _saveResolved(productionBaseUrl, 'production', prefs);
    }

    if (customUrl != null && await _probeFast(customUrl)) {
      return _saveResolved(customUrl, 'custom', prefs);
    }

    if (savedUrl != null && await _probeFast(savedUrl)) {
      return _saveResolved(savedUrl, 'custom', prefs, persist: false);
    }

    final candidates = await _buildCandidates(
      savedUrl: savedUrl,
      customUrl: customUrl,
      includeProduction: true,
    );

    final working = await _probeFirstMatch(candidates);
    if (working != null) {
      return _saveResolved(working, _environmentForUrl(working), prefs);
    }

    // Last resort for APK + live URL: still pin production.
    return _saveResolved(productionBaseUrl, 'production', prefs);
  }

  static Future<bool> _resolveProduction(SharedPreferences prefs) async {
    final target = await _pickProductionBaseUrl();
    return _saveResolved(target, 'production', prefs);
  }

  /// Physical Android: use USB tunnel only when it responds; otherwise .93.
  /// Emulator / desktop: prefer direct hospital LAN URL.
  static Future<String> _pickProductionBaseUrl() async {
    final physicalAndroid = await _isPhysicalAndroidDevice();

    if (physicalAndroid) {
      if (await _probeFast(productionUsbTunnelBaseUrl)) {
        return productionUsbTunnelBaseUrl;
      }
      if (await _probeFast(productionBaseUrl)) {
        return productionBaseUrl;
      }
      // Never default to a dead tunnel — .93 is the real production host.
      return productionBaseUrl;
    }

    if (await _probeFast(productionBaseUrl)) {
      return productionBaseUrl;
    }
    if (await _probeFast(productionUsbTunnelBaseUrl)) {
      return productionUsbTunnelBaseUrl;
    }
    return productionBaseUrl;
  }

  static bool _isProductionUsbTunnelUrl(String url) {
    final normalized = _normalize(url);
    return normalized == productionUsbTunnelBaseUrl ||
        (normalized.contains('127.0.0.1') &&
            normalized.endsWith(':$productionPort'));
  }

  /// Force the next requests through the USB tunnel (after a .93 failure).
  static Future<bool> preferProductionUsbTunnel() async {
    if (!await _probeFast(productionUsbTunnelBaseUrl)) {
      // ignore: avoid_print
      print('[ApiConfig] USB tunnel not available — keeping current host');
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await _saveResolved(productionUsbTunnelBaseUrl, 'production', prefs);
    // ignore: avoid_print
    print('[ApiConfig] switched to USB tunnel → $productionUsbTunnelBaseUrl');
    return true;
  }

  /// Force direct hospital API (after USB tunnel connection refused).
  static Future<void> preferDirectProduction() async {
    final prefs = await SharedPreferences.getInstance();
    await _saveResolved(productionBaseUrl, 'production', prefs);
    // ignore: avoid_print
    print('[ApiConfig] switched to direct production → $productionBaseUrl');
  }

  static bool get isUsingProductionUsbTunnel =>
      _isProductionUsbTunnelUrl(_resolvedBaseUrl ?? defaultBaseUrl);

  static bool? _physicalAndroidCache;

  static Future<bool> _isPhysicalAndroidDevice() async {
    if (!kIsWeb && Platform.isAndroid) {
      if (_physicalAndroidCache != null) {
        return _physicalAndroidCache!;
      }
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        _physicalAndroidCache = info.isPhysicalDevice;
        return info.isPhysicalDevice;
      } catch (_) {
        return true;
      }
    }
    return false;
  }

  /// True for local-dev targets (port 8080 / emulator), not hospital USB tunnel.
  static bool _isLocalDevUrl(String url) {
    final normalized = _normalize(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return false;

    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    if (port == productionPort) {
      // 127.0.0.1:7078 is the hospital API USB tunnel (run-dev option 3).
      return false;
    }

    if (port == localDevPort) {
      return true;
    }

    final host = uri.host.toLowerCase();
    return host == '10.0.2.2' ||
        host == 'localhost' ||
        host == '127.0.0.1';
  }

  static String _buildConnectionError(int triedCount) {
    return 'Cannot reach the HMIS API.\n\n'
        'Tried: $productionBaseUrl\n'
        'USB tunnel: $productionUsbTunnelBaseUrl\n\n'
        'For phone over USB (run-dev.bat option 3):\n'
        '1. Keep USB connected with debugging on\n'
        '2. Confirm: adb reverse --list shows tcp:7078\n'
        '3. Fully restart Flutter (not hot reload)\n\n'
        'Or join hospital Wi‑Fi and open:\n'
        '$productionSwaggerUrl';
  }

  static String _buildLocalConnectionError(String attemptedUrl) {
    return 'Cannot reach the local HMIS API at:\n'
        '$attemptedUrl\n\n'
        '1. Run option 1 or 2 from run-dev.bat so the local API starts\n'
        '2. Open $attemptedUrl/swagger/index.html\n'
        '3. For Android USB: keep the phone connected (adb reverse)\n'
        '4. Hot-restart the Flutter app after the API is up';
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
        normalized == productionUsbTunnelBaseUrl ||
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

  static Future<List<String>> _localDevCandidates() async {
    final candidates = <String>[];
    const lanHost = String.fromEnvironment('API_LAN_HOST');

    if (!kIsWeb && Platform.isAndroid) {
      final isPhysical = await _isPhysicalAndroidDevice();
      if (isPhysical) {
        candidates.add(usbTunnelBaseUrl);
        if (lanHost.isNotEmpty) {
          candidates.add('http://$lanHost:$localDevPort');
        }
      } else {
        candidates.add('http://10.0.2.2:$localDevPort');
      }
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

    final seen = <String>{};
    return candidates.where((url) => seen.add(_normalize(url))).toList();
  }

  static Future<List<String>> _buildCandidates({
    String? savedUrl,
    String? customUrl,
    bool includeProduction = true,
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

    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) {
      add(envHost);
    }

    add(customUrl);
    add(savedUrl);
    for (final localUrl in await _localDevCandidates()) {
      add(localUrl);
    }

    if (includeProduction) {
      add(productionBaseUrl);
      add(productionBaseUrl.replaceFirst('http://', 'https://'));

      if (!kIsWeb) {
        add(usbTunnelBaseUrl);
        add(productionUsbTunnelBaseUrl);
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
    const lanHost = String.fromEnvironment('API_LAN_HOST');
    if (lanHost.isNotEmpty && url.contains(lanHost)) {
      return false;
    }
    return url.contains('172.16.50.68') || url.contains('172.20.10.');
  }

  static Future<bool> _probeFast(String base) async {
    final normalized = _normalize(base);
    // Prefer real health endpoint; fall back to Swagger for older deploys.
    const probePaths = [
      '/api/Health',
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
        // Health may return 503 when degraded but API host is reachable.
        if (path == '/api/Health' &&
            (response.statusCode == 503 || response.statusCode == 200)) {
          return response.statusCode == 200;
        }
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
