import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists in-progress Sign In / Verify OTP state across app backgrounding
/// and process death (REQ-2026-018 / TC-018).
///
/// Cleared after successful login or when the draft expires.
class LoginFlowPersistence {
  LoginFlowPersistence._();

  static const _storageKey = 'login_flow_draft_v1';

  /// Align with typical login OTP challenge window on the API.
  static const Duration draftTtl = Duration(minutes: 10);

  static Future<LoginFlowDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        await clear();
        return null;
      }

      final draft = LoginFlowDraft.fromJson(map);
      if (draft.isExpired) {
        await clear();
        return null;
      }
      return draft;
    } catch (e, st) {
      debugPrint('LoginFlowPersistence.load failed: $e\n$st');
      return null;
    }
  }

  static Future<void> save(LoginFlowDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(draft.copyWith(savedAt: DateTime.now()).toJson()),
      );
    } catch (e, st) {
      debugPrint('LoginFlowPersistence.save failed: $e\n$st');
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e, st) {
      debugPrint('LoginFlowPersistence.clear failed: $e\n$st');
    }
  }
}

class LoginFlowDraft {
  final String identifier;
  final String password;
  final bool awaitingOtp;
  final String? loginChallengeId;
  final String? maskedContactNo;
  final String pendingContactNo;
  final bool trustThisDevice;
  final String otp;
  final DateTime savedAt;

  const LoginFlowDraft({
    required this.identifier,
    required this.password,
    required this.awaitingOtp,
    required this.loginChallengeId,
    required this.maskedContactNo,
    required this.pendingContactNo,
    required this.trustThisDevice,
    required this.otp,
    required this.savedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(savedAt) > LoginFlowPersistence.draftTtl;

  bool get hasMeaningfulData =>
      identifier.trim().isNotEmpty ||
      password.isNotEmpty ||
      awaitingOtp ||
      (loginChallengeId != null && loginChallengeId!.isNotEmpty);

  LoginFlowDraft copyWith({
    String? identifier,
    String? password,
    bool? awaitingOtp,
    String? loginChallengeId,
    String? maskedContactNo,
    String? pendingContactNo,
    bool? trustThisDevice,
    String? otp,
    DateTime? savedAt,
  }) {
    return LoginFlowDraft(
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      awaitingOtp: awaitingOtp ?? this.awaitingOtp,
      loginChallengeId: loginChallengeId ?? this.loginChallengeId,
      maskedContactNo: maskedContactNo ?? this.maskedContactNo,
      pendingContactNo: pendingContactNo ?? this.pendingContactNo,
      trustThisDevice: trustThisDevice ?? this.trustThisDevice,
      otp: otp ?? this.otp,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
        'awaitingOtp': awaitingOtp,
        'loginChallengeId': loginChallengeId,
        'maskedContactNo': maskedContactNo,
        'pendingContactNo': pendingContactNo,
        'trustThisDevice': trustThisDevice,
        'otp': otp,
        'savedAt': savedAt.toIso8601String(),
      };

  factory LoginFlowDraft.fromJson(Map<String, dynamic> json) {
    return LoginFlowDraft(
      identifier: json['identifier']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      awaitingOtp: json['awaitingOtp'] == true,
      loginChallengeId: json['loginChallengeId']?.toString(),
      maskedContactNo: json['maskedContactNo']?.toString(),
      pendingContactNo: json['pendingContactNo']?.toString() ?? '',
      trustThisDevice: json['trustThisDevice'] != false,
      otp: json['otp']?.toString() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
