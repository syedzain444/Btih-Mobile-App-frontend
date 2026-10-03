import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';

class PaymentAppointmentDetails {
  final String? appointmentId;
  final String? patientName;
  final String? mrNo;
  final String? doctorName;
  final int? departmentId;
  final String? departmentHint;
  final String? appointmentTime;
  final String? purpose;
  final String? status;

  const PaymentAppointmentDetails({
    this.appointmentId,
    this.patientName,
    this.mrNo,
    this.doctorName,
    this.departmentId,
    this.departmentHint,
    this.appointmentTime,
    this.purpose,
    this.status,
  });

  factory PaymentAppointmentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentAppointmentDetails(
      appointmentId: json['appointmentId']?.toString(),
      patientName: json['patientName']?.toString(),
      mrNo: json['mrNo']?.toString(),
      doctorName: json['doctorName']?.toString(),
      departmentId: (json['departmentId'] as num?)?.toInt(),
      departmentHint: json['departmentHint']?.toString(),
      appointmentTime: json['appointmentTime']?.toString(),
      purpose: json['purpose']?.toString(),
      status: json['status']?.toString(),
    );
  }

  bool get hasDetails =>
      (appointmentId?.isNotEmpty ?? false) ||
      (doctorName?.isNotEmpty ?? false) ||
      (appointmentTime?.isNotEmpty ?? false);
}

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
  final String? qrToken;
  final String? qrPayload;
  final String? qrImageBase64;
  final PaymentAppointmentDetails? appointment;

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
    this.qrToken,
    this.qrPayload,
    this.qrImageBase64,
    this.appointment,
  });

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get hasQr =>
      (qrPayload?.isNotEmpty ?? false) || (qrToken?.isNotEmpty ?? false);

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    PaymentAppointmentDetails? appointment;
    final rawAppt = json['appointment'];
    if (rawAppt is Map) {
      appointment = PaymentAppointmentDetails.fromJson(
        Map<String, dynamic>.from(rawAppt),
      );
    }

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
      qrToken: json['qrToken']?.toString(),
      qrPayload: json['qrPayload']?.toString(),
      qrImageBase64: json['qrImageBase64']?.toString(),
      appointment: appointment,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class PaymentQrResolve {
  final int paymentId;
  final String qrToken;
  final String? qrPayload;
  final double amount;
  final String currency;
  final String status;
  final String? billId;
  final String? invoiceNo;
  final String? checkoutUrl;
  final String? gatewayRef;
  final DateTime? createdAt;
  final PaymentAppointmentDetails? appointment;

  const PaymentQrResolve({
    required this.paymentId,
    required this.qrToken,
    this.qrPayload,
    required this.amount,
    this.currency = 'PKR',
    required this.status,
    this.billId,
    this.invoiceNo,
    this.checkoutUrl,
    this.gatewayRef,
    this.createdAt,
    this.appointment,
  });

  factory PaymentQrResolve.fromJson(Map<String, dynamic> json) {
    PaymentAppointmentDetails? appointment;
    final rawAppt = json['appointment'];
    if (rawAppt is Map) {
      appointment = PaymentAppointmentDetails.fromJson(
        Map<String, dynamic>.from(rawAppt),
      );
    }

    return PaymentQrResolve(
      paymentId: (json['paymentId'] as num?)?.toInt() ?? 0,
      qrToken: json['qrToken']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'PKR',
      status: json['status']?.toString() ?? '',
      billId: json['billId']?.toString(),
      invoiceNo: json['invoiceNo']?.toString(),
      checkoutUrl: json['checkoutUrl']?.toString(),
      gatewayRef: json['gatewayRef']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      appointment: appointment,
    );
  }
}

class PaymentService {
  static const returnDeepLink = 'btihapp://payment/return';

  Future<PaymentIntent> initiate({
    required String mrNo,
    required double amount,
    String? billId,
    String? invoiceNo,
    String? appointmentId,
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
        if (appointmentId != null && appointmentId.isNotEmpty)
          'appointmentId': appointmentId,
        'returnUrl': returnUrl,
      }),
    );

    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Unable to start payment');
    }

    final data = body['data'];
    if (data is! Map) {
      throw Exception('Invalid payment response');
    }
    return PaymentIntent.fromJson(Map<String, dynamic>.from(data));
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
    if (data is! Map) {
      throw Exception('Invalid confirm response');
    }
    return PaymentIntent.fromJson(Map<String, dynamic>.from(data));
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

  /// Resolves a scanned QR payload or bare token to payment + appointment details.
  Future<PaymentQrResolve> resolveQr(String qrTokenOrPayload) async {
    final token = extractQrToken(qrTokenOrPayload);
    if (token == null || token.isEmpty) {
      throw Exception('Invalid payment QR code');
    }

    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Payment/qr/$token'),
      headers: {'Content-Type': 'application/json'},
    );

    final body = _decodeMap(response.body);
    if (response.statusCode == 404) {
      throw Exception(body['message']?.toString() ?? 'Payment QR not found');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message']?.toString() ?? 'Unable to resolve payment QR',
      );
    }

    final data = body['data'];
    if (data is! Map) {
      throw Exception('Invalid QR resolve response');
    }
    return PaymentQrResolve.fromJson(Map<String, dynamic>.from(data));
  }

  static String? extractQrToken(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    const apiMarker = '/api/Payment/qr/';
    final apiIdx = value.toLowerCase().indexOf(apiMarker.toLowerCase());
    if (apiIdx >= 0) {
      var token = value.substring(apiIdx + apiMarker.length);
      final cut = token.indexOf(RegExp(r'[?#/&]'));
      if (cut >= 0) token = token.substring(0, cut);
      return token;
    }

    const deep = 'btihapp://payment/qr/';
    if (value.toLowerCase().startsWith(deep)) {
      var token = value.substring(deep.length);
      final cut = token.indexOf(RegExp(r'[?#/&]'));
      if (cut >= 0) token = token.substring(0, cut);
      return token;
    }

    if (RegExp(r'^[0-9a-fA-F]{16,64}$').hasMatch(value)) {
      return value;
    }

    return value;
  }

  Map<String, dynamic> _decodeMap(String raw) {
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }
}
