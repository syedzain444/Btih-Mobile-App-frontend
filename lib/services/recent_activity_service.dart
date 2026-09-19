import 'dart:convert';

import 'package:btih_andriod_app/models/recent_activity_item.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists up to [maxItems] recently opened screens.
///
/// Logged-in patients: store/fetch via `/api/RecentActivity` (DB).
/// Guests / offline: local SharedPreferences cache fallback.
class RecentActivityService {
  RecentActivityService._();

  static final RecentActivityService instance = RecentActivityService._();

  static const maxItems = 3;

  /// Device-wide cache — used for guests and offline fallback.
  static const _deviceKey = 'recent_activity_device_v2';
  static const _legacyPrefix = 'recent_activity_v1_';
  static const _lastScopeKey = 'recent_activity_last_scope';

  String resolveScope({
    required String patientMrNo,
    String? guestPhone,
  }) {
    final mr = patientMrNo.trim();
    if (mr.isNotEmpty) return mr;
    final phone = guestPhone?.trim() ?? '';
    if (phone.isNotEmpty) return 'guest_$phone';
    return 'guest';
  }

  String? _resolvedMrNo(String? scopeId) {
    final sessionMr = AuthSession.mrNo?.trim() ?? '';
    if (!AuthSession.isLoggedIn || sessionMr.isEmpty) return null;

    final scope = scopeId?.trim() ?? '';
    if (scope.startsWith('guest')) return null;
    if (scope.isNotEmpty && scope != sessionMr) return null;
    return sessionMr;
  }

  Future<List<RecentActivityItem>> getActivities([String? scopeId]) async {
    final mrNo = _resolvedMrNo(scopeId);
    if (mrNo != null) {
      try {
        final remote = await _fetchFromApi(mrNo);
        await _saveLocalCache(remote, scopeId: mrNo);
        return remote;
      } catch (_) {
        // Fall through to local cache if API/table unavailable.
      }
    }

    return _getLocalActivities(scopeId);
  }

  Future<void> track({
    required String scopeId,
    required RecentActivityItem item,
  }) async {
    if (item.id.isEmpty) return;

    // Always update local cache first for snappy UI / offline.
    final existing = await _getLocalActivities(scopeId);
    final next = <RecentActivityItem>[
      item,
      ...existing.where((e) => e.id != item.id),
    ].take(maxItems).toList();
    await _saveLocalCache(next, scopeId: scopeId);

    final mrNo = _resolvedMrNo(scopeId);
    if (mrNo == null) return;

    try {
      await _postToApi(mrNo, item);
    } catch (_) {
      // Keep local cache; sync will happen on next successful fetch/track.
    }
  }

  Future<List<RecentActivityItem>> _fetchFromApi(String mrNo) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/RecentActivity').replace(
      queryParameters: {
        'mrNo': mrNo,
        'limit': '$maxItems',
      },
    );

    final response = await ApiConfig.client.get(uri).timeout(
          ApiConfig.requestTimeout,
        );

    if (response.statusCode == 404 || response.statusCode == 403) {
      return const [];
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load recent activity (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];
    final data = decoded['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((e) => RecentActivityItem.fromJson(Map<String, dynamic>.from(e)))
        .take(maxItems)
        .toList();
  }

  Future<void> _postToApi(String mrNo, RecentActivityItem item) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/RecentActivity');
    final body = jsonEncode({
      'mrNo': mrNo,
      'activityKey': item.id,
      'kind': item.kind.name,
      'title': item.title,
      'subtitle': item.subtitle,
      'payload': item.payload,
      'viewedAt': item.viewedAt.toIso8601String(),
    });

    final response = await ApiConfig.client
        .post(
          uri,
          headers: const {
            'accept': '*/*',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to store recent activity (${response.statusCode})');
    }
  }

  Future<List<RecentActivityItem>> _getLocalActivities([String? scopeId]) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_deviceKey);

    if (raw == null || raw.isEmpty) {
      final legacyScope = (scopeId?.trim().isNotEmpty == true)
          ? scopeId!.trim()
          : prefs.getString(_lastScopeKey);
      if (legacyScope != null && legacyScope.isNotEmpty) {
        raw = prefs.getString('$_legacyPrefix$legacyScope');
        if (raw != null && raw.isNotEmpty) {
          await prefs.setString(_deviceKey, raw);
        }
      }
    }

    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => RecentActivityItem.fromJson(Map<String, dynamic>.from(e)))
          .take(maxItems)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocalCache(
    List<RecentActivityItem> items, {
    String? scopeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _deviceKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    if (scopeId != null && scopeId.trim().isNotEmpty) {
      await prefs.setString(_lastScopeKey, scopeId.trim());
    }
  }

  Future<void> trackDoctor({
    required String scopeId,
    required int doctorId,
    required String doctorName,
    required int departmentId,
    String specializationName = '',
  }) {
    final name = doctorName.trim().isEmpty ? 'Doctor' : doctorName.trim();
    return track(
      scopeId: scopeId,
      item: RecentActivityItem(
        id: 'doctor_$doctorId',
        kind: RecentActivityKind.doctor,
        title: 'Viewed doctor',
        subtitle: name,
        viewedAt: DateTime.now(),
        payload: {
          'doctorId': doctorId,
          'doctorName': name,
          'departmentId': departmentId,
          'specializationName': specializationName,
        },
      ),
    );
  }

  Future<void> trackAppointment({
    required String scopeId,
    required String appointmentId,
    required int weekId,
    required String appointmentTime,
    required String doctorName,
    required String status,
  }) {
    final id = appointmentId.trim().isNotEmpty
        ? appointmentId.trim()
        : 'week_${weekId}_$appointmentTime';
    final doctor =
        doctorName.trim().isEmpty ? 'Appointment' : doctorName.trim();
    return track(
      scopeId: scopeId,
      item: RecentActivityItem(
        id: 'appointment_$id',
        kind: RecentActivityKind.appointment,
        title: 'Viewed appointment',
        subtitle: doctor,
        viewedAt: DateTime.now(),
        payload: {
          'appointmentId': appointmentId,
          'weekId': weekId,
          'appointmentTime': appointmentTime,
          'doctorName': doctor,
          'status': status,
        },
      ),
    );
  }

  Future<void> trackMedicalReport({
    required String scopeId,
    required int categoryIndex,
    required String categoryLabel,
    required Map<String, dynamic> report,
  }) {
    final safeReport = _jsonSafeMap(report);
    final reportId = (safeReport['patDiagId'] ??
            safeReport['paT_DIAG_ID'] ??
            safeReport['pat_diag_id'] ??
            safeReport['patVisitId'] ??
            safeReport['paT_VISIT_ID'] ??
            safeReport['pat_visit_id'] ??
            safeReport['name'] ??
            DateTime.now().millisecondsSinceEpoch)
        .toString();
    final name = (safeReport['diagnosticName'] ??
            safeReport['diagnostiC_NAME'] ??
            safeReport['name'] ??
            categoryLabel)
        .toString();

    return track(
      scopeId: scopeId,
      item: RecentActivityItem(
        id: 'report_${categoryIndex}_$reportId',
        kind: RecentActivityKind.medicalReport,
        title: '$categoryLabel report',
        subtitle: name,
        viewedAt: DateTime.now(),
        payload: {
          'categoryIndex': categoryIndex,
          'categoryLabel': categoryLabel,
          'report': safeReport,
        },
      ),
    );
  }

  Future<void> trackDischarge({
    required String scopeId,
    required Map<String, dynamic> record,
  }) {
    final visitId = record['patienT_VISIT_ID'] ?? record['patientVisitId'] ?? 0;
    final doctor = (record['doctoR_NAME'] ?? record['doctorName'] ?? 'Discharge')
        .toString();
    return track(
      scopeId: scopeId,
      item: RecentActivityItem(
        id: 'discharge_$visitId',
        kind: RecentActivityKind.discharge,
        title: 'Discharge report',
        subtitle: doctor,
        viewedAt: DateTime.now(),
        payload: {'record': record},
      ),
    );
  }

  Future<void> trackVisit({
    required String scopeId,
    required int patientVisitId,
    required String doctorName,
    required String department,
  }) {
    final doctor = doctorName.trim().isEmpty ? 'Visit' : doctorName.trim();
    final dept = department.trim().isEmpty ? 'Hospital' : department.trim();
    return track(
      scopeId: scopeId,
      item: RecentActivityItem(
        id: 'visit_$patientVisitId',
        kind: RecentActivityKind.visit,
        title: 'Visit details',
        subtitle: '$doctor · $dept',
        viewedAt: DateTime.now(),
        payload: {
          'patientVisitId': patientVisitId,
          'doctorName': doctor,
          'department': dept,
        },
      ),
    );
  }

  Future<void> trackBill({
    required String scopeId,
    required Map<String, dynamic> report,
    required String departmentCode,
    required String departmentName,
    required int rptId,
  }) {
    final billId = (report['billId'] ?? report['invoiceNo'] ?? '').toString();
    final invoice = (report['invoiceNo'] ?? billId).toString();
    return track(
      scopeId: scopeId,
      item: RecentActivityItem(
        id: 'bill_${departmentCode}_$billId',
        kind: RecentActivityKind.bill,
        title: '$departmentName bill',
        subtitle: invoice.isEmpty ? 'Invoice' : 'Invoice #$invoice',
        viewedAt: DateTime.now(),
        payload: {
          'report': report,
          'departmentCode': departmentCode,
          'departmentName': departmentName,
          'rptId': rptId,
        },
      ),
    );
  }

  Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      final safe = _jsonSafeValue(value);
      if (safe != null || value == null) {
        out[key] = safe;
      }
    });
    return out;
  }

  dynamic _jsonSafeValue(dynamic value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }
    if (value is Map) {
      return _jsonSafeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_jsonSafeValue).toList();
    }
    return null;
  }
}
