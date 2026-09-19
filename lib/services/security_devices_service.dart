import 'dart:convert';
import 'dart:io';

import 'package:btih_andriod_app/services/push_notification_service.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class RegisteredDevice {
  final String deviceToken;
  final String platform;
  final DateTime? updatedAt;
  final bool isCurrentDevice;

  const RegisteredDevice({
    required this.deviceToken,
    required this.platform,
    this.updatedAt,
    this.isCurrentDevice = false,
  });

  String get displayName {
    final platformLabel = platform.isEmpty ? 'Device' : platform.toUpperCase();
    final suffix = deviceToken.length > 8
        ? deviceToken.substring(deviceToken.length - 8)
        : deviceToken;
    return '$platformLabel · ••••$suffix';
  }

  factory RegisteredDevice.fromJson(
    Map<String, dynamic> json, {
    required String? currentToken,
  }) {
    final token = json['deviceToken']?.toString() ?? '';
    final updatedRaw = json['updatedAt']?.toString();
    return RegisteredDevice(
      deviceToken: token,
      platform: json['platform']?.toString() ?? '',
      updatedAt: updatedRaw == null ? null : DateTime.tryParse(updatedRaw),
      isCurrentDevice:
          currentToken != null && currentToken.isNotEmpty && token == currentToken,
    );
  }
}

class SecurityDevicesService {
  SecurityDevicesService._();

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

  static Future<List<RegisteredDevice>> fetchDevices(String mrNo) async {
    final currentToken = await PushNotificationService.instance.getDeviceToken();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/PushNotification/devices?mrNo=${Uri.encodeComponent(mrNo)}',
    );

    final response = await ApiConfig.client.get(
      uri,
      headers: {'accept': '*/*'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load devices (HTTP ${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is Map ? decoded['data'] : decoded;
    if (rawList is! List) return [];

    return rawList
        .whereType<Map>()
        .map(
          (item) => RegisteredDevice.fromJson(
            Map<String, dynamic>.from(item),
            currentToken: currentToken,
          ),
        )
        .toList();
  }

  static Future<bool> unregisterDevice({
    required String mrNo,
    required String deviceToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/PushNotification/unregister');
    final response = await ApiConfig.client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode({
        'mrNo': mrNo,
        'deviceToken': deviceToken,
      }),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<bool> unregisterAllDevices(String mrNo) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/PushNotification/unregister-all');
    final response = await ApiConfig.client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode({'mrNo': mrNo}),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
