import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Decorative app-bar icon — matches Appointments screen (extreme right).
class AppBarIconBadge extends StatelessWidget {
  const AppBarIconBadge({
    super.key,
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: AppColors.white,
          size: 20,
        ),
      ),
    );
  }
}
