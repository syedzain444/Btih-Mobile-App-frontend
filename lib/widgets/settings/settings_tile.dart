import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? AppColors.primaryRed : AppColors.deepRed;
    final tileBg = isDestructive
        ? AppColors.softRed.withValues(alpha: 0.75)
        : AppColors.white;

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? AppColors.primaryRed.withValues(alpha: 0.18)
                : AppColors.fieldBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.white
                    : AppColors.softRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isDestructive
                  ? Icons.logout_rounded
                  : Icons.chevron_right_rounded,
              size: 20,
              color: accent.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}
