import 'dart:convert';

import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/firebase_messaging_handlers.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers the device FCM token with the HMIS API and handles incoming push messages.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _cachedToken;
  bool _handlersConfigured = false;

  static String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return defaultTargetPlatform.name;
    }
  }

  Future<void> init() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'FCM permission: ${settings.authorizationStatus.name}',
    );

    if (!_handlersConfigured) {
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      _handlersConfigured = true;
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleIncomingMessage(initialMessage, openedFromTray: true);
    }

    _messaging.onTokenRefresh.listen((token) async {
      _cachedToken = token;
      debugPrint('FCM token refreshed');
      await registerForCurrentUser();
    });
  }

  /// Returns the Firebase Cloud Messaging device token for API registration.
  Future<String?> getDeviceToken() async {
    if (kIsWeb) return null;
    try {
      _cachedToken ??= await _messaging.getToken();
      return _cachedToken;
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  Future<bool> registerForCurrentUser() async {
    final mrNo = AuthSession.mrNo?.trim();
    if (mrNo == null || mrNo.isEmpty || !AuthSession.isLoggedIn) {
      return false;
    }

    final deviceToken = await getDeviceToken();
    if (deviceToken == null || deviceToken.isEmpty) {
      debugPrint('FCM token unavailable — cannot register push notifications.');
      return false;
    }

    return _postRegister(
      mrNo: mrNo,
      deviceToken: deviceToken,
      platform: platform,
    );
  }

  Future<bool> unregisterForCurrentUser() async {
    final mrNo = AuthSession.mrNo?.trim();
    if (mrNo == null || mrNo.isEmpty) return false;

    final deviceToken = _cachedToken ?? await getDeviceToken();
    if (deviceToken == null || deviceToken.isEmpty) return false;

    try {
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
      ).timeout(ApiConfig.requestTimeout);

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (ok) {
        debugPrint('Push token unregistered for $mrNo');
      } else {
        debugPrint(
          'Push unregister failed: HTTP ${response.statusCode} ${response.body}',
        );
      }
      return ok;
    } catch (e) {
      debugPrint('Push unregister failed: $e');
      return false;
    }
  }


  Future<void> clearOnLogout() async {
    await unregisterForCurrentUser();
    _cachedToken = null;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _handleIncomingMessage(message);
  }

  Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    await _handleIncomingMessage(message, openedFromTray: true);
  }

  Future<void> _handleIncomingMessage(
    RemoteMessage message, {
    bool openedFromTray = false,
  }) async {
    await NotificationService.instance.ingestRemoteMessage(
      message,
      openedFromTray: openedFromTray,
    );
  }

  Future<bool> _postRegister({
    required String mrNo,
    required String deviceToken,
    required String platform,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/PushNotification/register');
      final body = jsonEncode({
        'mrNo': mrNo,
        'deviceToken': deviceToken,
        'platform': platform,
      });

      final response = await ApiConfig.client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: body,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Push token registered for $mrNo ($platform)');
        return true;
      }

      debugPrint(
        'Push register failed: HTTP ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('Push register error: $e');
      return false;
    }
  }
}
