import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Decorative app-bar icon — matches Appointments screen (extreme right).
class AppBarIconBadge extends StatelessWidget {
  const AppBarIconBadge({
    super.key,
    required this.icon,
    this.count,
  });

  final IconData icon;

  /// Optional count bubble (e.g. active medications on the meds screen).
  final int? count;

  @override
  Widget build(BuildContext context) {
    final badgeCount = count ?? 0;
    final label = badgeCount > 99 ? '99+' : '$badgeCount';
    final isWide = label.length >= 2;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
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
            if (badgeCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  height: 14,
                  constraints: BoxConstraints(minWidth: isWide ? 18 : 14),
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 3 : 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.deepRed, width: 1.2),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.deepRed,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
