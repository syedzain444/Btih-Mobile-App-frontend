import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BillingDepartment {
  final String name;
  final String code;
  final String subtitle;
  final int rptId;
  final IconData icon;
  final List<Color> gradient;

  const BillingDepartment({
    required this.name,
    required this.code,
    required this.subtitle,
    required this.rptId,
    required this.icon,
    required this.gradient,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'code': code,
        'subtitle': subtitle,
        'rptId': rptId,
        'icon': icon,
        'gradient': gradient,
      };
}

class BillingDepartments {
  BillingDepartments._();

  static const departments = <BillingDepartment>[
    BillingDepartment(
      name: 'Emergency',
      code: 'EMERGENCY',
      subtitle: 'Emergency department reports',
      rptId: 27,
      icon: Icons.medical_services_outlined,
      gradient: [AppColors.primaryRed, AppColors.deepRed],
    ),
    BillingDepartment(
      name: 'OPD',
      code: 'OPD',
      subtitle: 'Outpatient reports',
      rptId: 26,
      icon: Icons.grid_view_rounded,
      gradient: [AppColors.rustRed, AppColors.primaryRed],
    ),
    BillingDepartment(
      name: 'Laboratory',
      code: 'LABORATORY',
      subtitle: 'Laboratory reports',
      rptId: 26,
      icon: Icons.science_outlined,
      gradient: [AppColors.deepRed, AppColors.duskMaroon],
    ),
    BillingDepartment(
      name: 'Services',
      code: 'SERVICES',
      subtitle: 'Service reports',
      rptId: 26,
      icon: Icons.room_service_outlined,
      gradient: [AppColors.primaryRed, AppColors.rustRed],
    ),
    BillingDepartment(
      name: 'Radiology',
      code: 'RADIOLOGY',
      subtitle: 'Radiology reports',
      rptId: 26,
      icon: Icons.monitor_heart_outlined,
      gradient: [AppColors.duskMaroon, AppColors.deepRed],
    ),
    BillingDepartment(
      name: 'IPD',
      code: 'IPD',
      subtitle: 'Inpatient reports',
      rptId: 27,
      icon: Icons.bed_outlined,
      gradient: [AppColors.rustRed, AppColors.deepRed],
    ),
    BillingDepartment(
      name: 'Procedure',
      code: 'PROCEDURE',
      subtitle: 'Procedure reports',
      rptId: 26,
      icon: Icons.healing_outlined,
      gradient: [AppColors.deepRed, AppColors.primaryRed],
    ),
  ];

  static BillingDepartment? byCode(String code) {
    final upper = code.toUpperCase();
    for (final dept in departments) {
      if (dept.code == upper) return dept;
    }
    return null;
  }
}

String formatBillingCurrency(double amount) {
  final whole = amount.round().abs();
  final formatted = whole.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  final sign = amount < 0 ? '-' : '';
  return 'Rs. $sign$formatted';
}
