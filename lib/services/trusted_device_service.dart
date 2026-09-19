import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrustedLoginDevice {
  final int trustedDeviceId;
  final String deviceInstallId;
  final String? deviceLabel;
  final String? platform;
  final DateTime? trustedAt;
  final DateTime? lastLoginAt;
  final DateTime? expiresAt;

  const TrustedLoginDevice({
    required this.trustedDeviceId,
    required this.deviceInstallId,
    this.deviceLabel,
    this.platform,
    this.trustedAt,
    this.lastLoginAt,
    this.expiresAt,
  });

  factory TrustedLoginDevice.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) =>
        raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);

    return TrustedLoginDevice(
      trustedDeviceId: (json['trustedDeviceId'] as num?)?.toInt() ?? 0,
      deviceInstallId: json['deviceInstallId']?.toString() ?? '',
      deviceLabel: json['deviceLabel']?.toString(),
      platform: json['platform']?.toString(),
      trustedAt: parseDate(json['trustedAt']?.toString()),
      lastLoginAt: parseDate(json['lastLoginAt']?.toString()),
      expiresAt: parseDate(json['expiresAt']?.toString()),
    );
  }

  String get displayName {
    if (deviceLabel != null && deviceLabel!.trim().isNotEmpty) {
      return deviceLabel!.trim();
    }
    if (platform != null && platform!.isNotEmpty) {
      return platform!.toUpperCase();
    }
    return 'Trusted device';
  }
}

/// Device identity for trusted login.
///
/// Uses [SharedPreferences] (not flutter_secure_storage) so Android Keystore /
/// Cipher.doFinal failures cannot block Sign In.
class TrustedDeviceService {
  TrustedDeviceService._();

  static const _installIdKey = 'device_install_id_v2';
  static const _tokenPrefixMr = 'device_trust_token_mr_v2_';
  static const _tokenPrefixContact = 'device_trust_token_contact_v2_';

  /// Temporary SMS-outage bypass — login without OTP for this number only.
  static const temporarySmsBypassContacts = <String>{
    '03339993577',
    '3339993577',
    '923339993577',
  };

  static bool isTemporarySmsBypassContact(String contactNo) {
    final normalized = _normalizeContact(contactNo);
    return temporarySmsBypassContacts.any(
      (entry) => _normalizeContact(entry) == normalized,
    );
  }

  static String _normalizeContact(String contactNo) {
    var digits = contactNo.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92') && digits.length >= 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String _trustTokenKeyForMrNo(String mrNo) =>
      '$_tokenPrefixMr${mrNo.trim()}';

  static String _trustTokenKeyForContact(String contactNo) =>
      '$_tokenPrefixContact${contactNo.trim()}';

  static Future<String> getDeviceInstallId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_installIdKey);
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }

      final generated = _generateInstallId();
      await prefs.setString(_installIdKey, generated);
      return generated;
    } catch (e, st) {
      debugPrint('TrustedDeviceService.getDeviceInstallId failed: $e\n$st');
      return _generateInstallId();
    }
  }

  static Future<String?> getTrustTokenForContact(String contactNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_trustTokenKeyForContact(contactNo));
      if (token == null || token.trim().isEmpty) return null;
      return token.trim();
    } catch (e, st) {
      debugPrint('TrustedDeviceService.getTrustTokenForContact failed: $e\n$st');
      return null;
    }
  }

  static Future<void> saveTrustToken({
    required String contactNo,
    required String mrNo,
    required String token,
  }) async {
    final value = token.trim();
    if (value.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_trustTokenKeyForContact(contactNo), value);
      await prefs.setString(_trustTokenKeyForMrNo(mrNo), value);
    } catch (e, st) {
      debugPrint('TrustedDeviceService.saveTrustToken failed: $e\n$st');
    }
  }

  static Future<void> clearTrustTokenForMrNo(String mrNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trustTokenKeyForMrNo(mrNo));
    } catch (_) {}
  }

  static Future<void> clearTrustTokenForContact(String contactNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trustTokenKeyForContact(contactNo));
    } catch (_) {}
  }

  static Future<void> clearAllTrustTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where(
            (key) =>
                key.startsWith(_tokenPrefixMr) ||
                key.startsWith(_tokenPrefixContact),
          )
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e, st) {
      debugPrint('TrustedDeviceService.clearAllTrustTokens failed: $e\n$st');
    }
  }

  static Future<String> currentPlatform() async {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  static Future<String> currentDeviceLabel() async {
    if (kIsWeb) return 'This browser';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return '${android.manufacturer} ${android.model}';
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.name;
      }
    } catch (_) {}
    return 'This device';
  }

  /// Never throws — login must proceed even if storage fails.
  static Future<Map<String, String>> buildLoginDevicePayload({
    required String contactNo,
  }) async {
    try {
      final installId = await getDeviceInstallId();
      final payload = <String, String>{
        'deviceInstallId': installId,
        'deviceLabel': await currentDeviceLabel(),
        'platform': await currentPlatform(),
      };

      final trustToken = await getTrustTokenForContact(contactNo);
      if (trustToken != null) {
        payload['deviceTrustToken'] = trustToken;
      }

      return payload;
    } catch (e, st) {
      debugPrint('TrustedDeviceService.buildLoginDevicePayload failed: $e\n$st');
      return {
        'deviceInstallId': _generateInstallId(),
        'deviceLabel': 'This device',
        'platform': kIsWeb
            ? 'web'
            : (Platform.isAndroid
                ? 'android'
                : (Platform.isIOS ? 'ios' : 'unknown')),
      };
    }
  }

  static Future<List<TrustedLoginDevice>> fetchTrustedDevices(String mrNo) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/TrustedDevice?mrNo=${Uri.encodeComponent(mrNo)}',
    );
    final response = await ApiConfig.client.get(
      uri,
      headers: {'accept': '*/*'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load trusted devices (HTTP ${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is Map ? decoded['data'] : decoded;
    if (rawList is! List) return [];

    return rawList
        .whereType<Map>()
        .map((item) => TrustedLoginDevice.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
  }

  static Future<bool> revokeTrustedDevice({
    required String mrNo,
    required int trustedDeviceId,
    String? deviceInstallId,
  }) async {
    final currentInstallId = await getDeviceInstallId();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/TrustedDevice/revoke');
    final response = await ApiConfig.client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode({
        'mrNo': mrNo,
        'trustedDeviceId': trustedDeviceId,
      }),
    );

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok &&
        deviceInstallId != null &&
        deviceInstallId == currentInstallId) {
      await clearTrustTokenForMrNo(mrNo);
    }
    return ok;
  }

  static Future<bool> revokeAllTrustedDevices(String mrNo) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/TrustedDevice/revoke-all');
    final response = await ApiConfig.client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode({'mrNo': mrNo}),
    );

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok) {
      await clearTrustTokenForMrNo(mrNo);
    }
    return ok;
  }

  static String _generateInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final parts = [
      bytes.sublist(0, 4).map(hex).join(),
      bytes.sublist(4, 6).map(hex).join(),
      bytes.sublist(6, 8).map(hex).join(),
      bytes.sublist(8, 10).map(hex).join(),
      bytes.sublist(10, 16).map(hex).join(),
    ];
    return parts.join('-');
  }
}
