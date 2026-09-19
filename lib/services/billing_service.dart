import 'dart:convert';

import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';

class BillingOverview {
  final String mrNo;
  final int totalBillCount;
  final double totalAmount;
  final int paidBillCount;
  final double paidAmount;
  final int pendingBillCount;
  final double pendingAmount;
  final List<BillingDepartmentOverview> departments;

  BillingOverview({
    required this.mrNo,
    required this.totalBillCount,
    required this.totalAmount,
    required this.paidBillCount,
    required this.paidAmount,
    required this.pendingBillCount,
    required this.pendingAmount,
    required this.departments,
  });

  factory BillingOverview.fromJson(Map<String, dynamic> json) {
    final rawDepartments = json['departments'] as List<dynamic>? ?? const [];
    return BillingOverview(
      mrNo: json['mrNo']?.toString() ?? '',
      totalBillCount: (json['totalBillCount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paidBillCount: (json['paidBillCount'] as num?)?.toInt() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      pendingBillCount: (json['pendingBillCount'] as num?)?.toInt() ?? 0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0,
      departments: rawDepartments
          .map((item) =>
              BillingDepartmentOverview.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BillingDepartmentOverview {
  final String departmentCode;
  final String departmentName;
  final int billCount;
  final double totalAmount;
  final int reportId;

  BillingDepartmentOverview({
    required this.departmentCode,
    required this.departmentName,
    required this.billCount,
    required this.totalAmount,
    required this.reportId,
  });

  factory BillingDepartmentOverview.fromJson(Map<String, dynamic> json) {
    return BillingDepartmentOverview(
      departmentCode: json['departmentCode']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? '',
      billCount: (json['billCount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      reportId: (json['reportId'] as num?)?.toInt() ?? 26,
    );
  }
}

class BillingHistoryResult {
  final String mrNo;
  final int totalCount;
  final double totalAmount;
  final List<PatientReport> items;

  BillingHistoryResult({
    required this.mrNo,
    required this.totalCount,
    required this.totalAmount,
    required this.items,
  });
}

class BillingPaymentSummary {
  final String mrNo;
  final double totalPaidAmount;
  final double totalPendingAmount;
  final int paidBillCount;
  final int pendingBillCount;
  final List<PatientReport> pendingBills;
  final List<PatientReport> recentPayments;

  BillingPaymentSummary({
    required this.mrNo,
    required this.totalPaidAmount,
    required this.totalPendingAmount,
    required this.paidBillCount,
    required this.pendingBillCount,
    required this.pendingBills,
    required this.recentPayments,
  });

  factory BillingPaymentSummary.fromJson(Map<String, dynamic> json) {
    List<PatientReport> parseItems(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .map((item) => PatientReport.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return BillingPaymentSummary(
      mrNo: json['mrNo']?.toString() ?? '',
      totalPaidAmount: (json['totalPaidAmount'] as num?)?.toDouble() ?? 0,
      totalPendingAmount: (json['totalPendingAmount'] as num?)?.toDouble() ?? 0,
      paidBillCount: (json['paidBillCount'] as num?)?.toInt() ?? 0,
      pendingBillCount: (json['pendingBillCount'] as num?)?.toInt() ?? 0,
      pendingBills: parseItems('pendingBills'),
      recentPayments: parseItems('recentPayments'),
    );
  }

  /// Build summary locally from history so the billing screen only needs
  /// one network round-trip.
  factory BillingPaymentSummary.fromReports({
    required String mrNo,
    required List<PatientReport> reports,
  }) {
    bool isCancelled(PatientReport r) {
      if (r.isCancel == true) return true;
      return (r.paymentStatus ?? '').toLowerCase() == 'cancelled';
    }

    bool isPending(PatientReport r) {
      if (isCancelled(r)) return false;
      final status = (r.paymentStatus ?? '').toLowerCase();
      if (status == 'pending') return true;
      if ((r.balanceAmount ?? 0) > 0) return true;
      return status.isEmpty && r.paymentDate.trim().isEmpty;
    }

    bool isPaid(PatientReport r) {
      if (isCancelled(r) || isPending(r)) return false;
      final status = (r.paymentStatus ?? '').toLowerCase();
      return status == 'paid' || r.paymentDate.trim().isNotEmpty;
    }

    DateTime? parseDate(PatientReport r) {
      for (final raw in [r.paymentDate, r.visitDate ?? '']) {
        if (raw.trim().isEmpty) continue;
        final dt = DateTime.tryParse(raw);
        if (dt != null) return dt;
      }
      return null;
    }

    double pendingAmount(PatientReport r) {
      final balance = r.balanceAmount;
      if (balance != null && balance > 0) return balance;
      return r.amount;
    }

    final active = reports.where((r) => !isCancelled(r)).toList();
    final pending = active.where(isPending).toList()
      ..sort((a, b) {
        final da = parseDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = parseDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    final paid = active.where(isPaid).toList()
      ..sort((a, b) {
        final da = parseDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = parseDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

    return BillingPaymentSummary(
      mrNo: mrNo,
      totalPaidAmount: paid.fold(0, (sum, r) => sum + r.amount),
      totalPendingAmount: pending.fold(0, (sum, r) => sum + pendingAmount(r)),
      paidBillCount: paid.length,
      pendingBillCount: pending.length,
      pendingBills: pending.take(10).toList(),
      recentPayments: paid.take(10).toList(),
    );
  }
}

class BillingService {
  static final Map<String, _CachedBillingHistory> _historyCache = {};
  static const _cacheTtl = Duration(minutes: 2);

  Future<BillingOverview> getOverview(String mrNo) async {
    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Billing/overview/$mrNo'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load billing overview');
    }

    return BillingOverview.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }

  Future<BillingHistoryResult> getHistory(
    String mrNo, {
    String? department,
    int? year,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    String? paymentStatus,
    bool bypassCache = false,
  }) async {
    final cacheKey = [
      mrNo.trim(),
      department ?? '',
      year?.toString() ?? '',
      dateFrom?.toIso8601String() ?? '',
      dateTo?.toIso8601String() ?? '',
      search ?? '',
      paymentStatus ?? '',
    ].join('|');

    if (!bypassCache) {
      final cached = _historyCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
        return cached.result;
      }
    }

    final query = <String, String>{};
    if (department != null && department.isNotEmpty) {
      query['department'] = department;
    }
    if (year != null) query['year'] = '$year';
    if (dateFrom != null) {
      query['dateFrom'] = dateFrom.toIso8601String();
    }
    if (dateTo != null) {
      query['dateTo'] = dateTo.toIso8601String();
    }
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (paymentStatus != null && paymentStatus.isNotEmpty) {
      query['paymentStatus'] = paymentStatus;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Billing/history/$mrNo')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await ApiConfig.client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load billing history');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? const [];

    final result = BillingHistoryResult(
      mrNo: data['mrNo']?.toString() ?? mrNo,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? rawItems.length,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      items: rawItems
          .map((item) => PatientReport.fromJson(item as Map<String, dynamic>))
          .toList(),
    );

    _historyCache[cacheKey] = _CachedBillingHistory(
      result: result,
      fetchedAt: DateTime.now(),
    );
    return result;
  }

  void invalidateHistoryCache([String? mrNo]) {
    if (mrNo == null || mrNo.trim().isEmpty) {
      _historyCache.clear();
      return;
    }
    final prefix = '${mrNo.trim()}|';
    _historyCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  Future<PatientReport> getInvoice({
    required String mrNo,
    required String billId,
  }) async {
    final encodedMrNo = Uri.encodeQueryComponent(mrNo);
    final response = await ApiConfig.client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/Billing/invoices/$billId?mrNo=$encodedMrNo',
      ),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 404) {
      throw Exception('Invoice not found');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load invoice details');
    }

    return PatientReport.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }

  Future<BillingPaymentSummary> getPaymentSummary(String mrNo) async {
    // Prefer history (often already cached) instead of a second Oracle call.
    final history = await getHistory(mrNo);
    return BillingPaymentSummary.fromReports(
      mrNo: mrNo,
      reports: history.items,
    );
  }
}

class _CachedBillingHistory {
  final BillingHistoryResult result;
  final DateTime fetchedAt;

  const _CachedBillingHistory({
    required this.result,
    required this.fetchedAt,
  });
}
