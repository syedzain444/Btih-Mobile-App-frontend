// lib/models/patient_report_model.dart

import 'package:flutter/material.dart';

class PatientReport {
  final String billId;
  final String? mrNo;
  final String invoiceNo;
  final String department;
  final String? departmentCode;
  final String? visitDate;
  final String paymentDate;
  final String? paymentMethod;
  final double amount;
  final double? paidAmount;
  final double? balanceAmount;
  final bool? isCancel;
  final String? cancelReason;
  final String? paymentStatus;
  final int? reportId;

  PatientReport({
    required this.billId,
    this.mrNo,
    required this.invoiceNo,
    required this.department,
    this.departmentCode,
    this.visitDate,
    required this.paymentDate,
    this.paymentMethod,
    required this.amount,
    this.paidAmount,
    this.balanceAmount,
    this.isCancel,
    this.cancelReason,
    this.paymentStatus,
    this.reportId,
  });

  factory PatientReport.fromJson(Map<String, dynamic> json) {
    final departmentCode = json['departmentCode']?.toString();
    final departmentName = json['department']?.toString() ?? '';

    return PatientReport(
      billId: json['billId']?.toString() ?? '',
      mrNo: json['mrNo']?.toString(),
      invoiceNo: json['invoiceNo']?.toString() ?? '',
      department: departmentCode ?? departmentName,
      departmentCode: departmentCode,
      visitDate: json['visitDate']?.toString(),
      paymentDate: json['paymentDate']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble(),
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble(),
      isCancel: _parseBool(json['isCancel']),
      cancelReason: json['cancelReason']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      reportId: (json['reportId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'billId': billId,
        'mrNo': mrNo,
        'invoiceNo': invoiceNo,
        'department': department,
        'departmentCode': departmentCode,
        'visitDate': visitDate,
        'paymentDate': paymentDate,
        'paymentMethod': paymentMethod,
        'amount': amount,
        'paidAmount': paidAmount,
        'balanceAmount': balanceAmount,
        'isCancel': isCancel,
        'cancelReason': cancelReason,
        'paymentStatus': paymentStatus,
        'reportId': reportId,
      };

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toUpperCase();
    if (normalized == 'Y' || normalized == 'YES' || normalized == '1') {
      return true;
    }
    if (normalized == 'N' || normalized == 'NO' || normalized == '0') {
      return false;
    }
    return null;
  }

  String get filterDepartmentCode =>
      (departmentCode ?? department).toUpperCase();

  // Helper method to get formatted department name
  String get formattedDepartment {
    switch (filterDepartmentCode) {
      case 'EMERGENCY':
        return 'Emergency';
      case 'OPD':
        return 'OPD';
      case 'SERVICES':
        return 'Services';
      case 'LABORATORY':
        return 'Laboratory';
      case 'RADIOLOGY':
        return 'Radiology';
      case 'IPD':
        return 'IPD';
      default:
        return department;
    }
  }

  // Get department icon
  IconData get departmentIcon {
    switch (department.toUpperCase()) {
      case 'EMERGENCY':
        return Icons.emergency;
      case 'OPD':
        return Icons.local_hospital;
      case 'SERVICES':
        return Icons.room_service;
      case 'LABORATORY':
        return Icons.science;
      case 'RADIOLOGY':
        return Icons.emergency;
      case 'IPD':
        return Icons.bed;
      default:
        return Icons.receipt;
    }
  }

  // Get color for department
  Color get departmentColor {
    switch (department.toUpperCase()) {
      case 'EMERGENCY':
        return Colors.red;
      case 'OPD':
        return Colors.blue;
      case 'SERVICES':
        return Colors.purple;
      case 'LABORATORY':
        return Colors.orange;
      case 'RADIOLOGY':
        return Colors.teal;
      case 'IPD':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}