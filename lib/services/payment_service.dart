import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';

class PaymentIntent {
  final int paymentId;
  final String mrNo;
  final String? billId;
  final String? invoiceNo;
  final double amount;
  final String currency;
  final String status;
  final String gateway;
  final String? checkoutUrl;
  final String? returnUrl;
  final String? gatewayRef;
  final DateTime? createdAt;
  final DateTime? paidAt;

  const PaymentIntent({
    required this.paymentId,
    required this.mrNo,
    this.billId,
    this.invoiceNo,
    required this.amount,
    this.currency = 'PKR',
    required this.status,
    this.gateway = '',
    this.checkoutUrl,
    this.returnUrl,
    this.gatewayRef,
    this.createdAt,
    this.paidAt,
  });

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isPending => status.toUpperCase() == 'PENDING';

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    return PaymentIntent(
      paymentId: (json['paymentId'] as num?)?.toInt() ?? 0,
      mrNo: json['mrNo']?.toString() ?? '',
      billId: json['billId']?.toString(),
      invoiceNo: json['invoiceNo']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'PKR',
      status: json['status']?.toString() ?? 'PENDING',
      gateway: json['gateway']?.toString() ?? '',
      checkoutUrl: json['checkoutUrl']?.toString(),
      returnUrl: json['returnUrl']?.toString(),
      gatewayRef: json['gatewayRef']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      paidAt: _parseDate(json['paidAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class PaymentService {
  static const returnDeepLink = 'btihapp://payment/return';

  Future<PaymentIntent> initiate({
    required String mrNo,
    required double amount,
    String? billId,
    String? invoiceNo,
    String returnUrl = returnDeepLink,
  }) async {
    final response = await ApiConfig.client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/Payment/initiate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mrNo': mrNo,
        'amount': amount,
        if (billId != null && billId.isNotEmpty) 'billId': billId,
        if (invoiceNo != null && invoiceNo.isNotEmpty) 'invoiceNo': invoiceNo,
        'returnUrl': returnUrl,
      }),
    );

    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Unable to start payment');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid payment response');
    }
    return PaymentIntent.fromJson(data);
  }

  Future<PaymentIntent> confirm({
    required int paymentId,
    String? gatewayRef,
  }) async {
    final response = await ApiConfig.client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/Payment/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paymentId': paymentId,
        if (gatewayRef != null && gatewayRef.isNotEmpty) 'gatewayRef': gatewayRef,
      }),
    );

    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message']?.toString() ?? 'Unable to confirm payment',
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid confirm response');
    }
    return PaymentIntent.fromJson(data);
  }

  Future<List<PaymentIntent>> getHistory(String mrNo) async {
    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Payment/history/$mrNo'),
      headers: {'Content-Type': 'application/json'},
    );

    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message']?.toString() ?? 'Unable to load payment history',
      );
    }

    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => PaymentIntent.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _decodeMap(String raw) {
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }
}
