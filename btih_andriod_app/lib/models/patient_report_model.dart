// lib/models/patient_report_model.dart

import 'package:flutter/material.dart';

class PatientReport {
  final String billId;
  final String? mrNo;
  final String invoiceNo;
  final String department;
  final String? visitDate;
  final String paymentDate;
  final String? paymentMethod;
  final double amount;
  final bool? isCancel;
  final String? cancelReason;

  PatientReport({
    required this.billId,
    this.mrNo,
    required this.invoiceNo,
    required this.department,
    this.visitDate,
    required this.paymentDate,
    this.paymentMethod,
    required this.amount,
    this.isCancel,
    this.cancelReason,
  });

  factory PatientReport.fromJson(Map<String, dynamic> json) {
    return PatientReport(
      billId: json['billId']?.toString() ?? '',
      mrNo: json['mrNo']?.toString(),
      invoiceNo: json['invoiceNo']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      visitDate: json['visitDate']?.toString(),
      paymentDate: json['paymentDate']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      isCancel: json['isCancel'],
      cancelReason: json['cancelReason']?.toString(),
    );
  }

  // Helper method to get formatted department name
  String get formattedDepartment {
    switch (department.toUpperCase()) {
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