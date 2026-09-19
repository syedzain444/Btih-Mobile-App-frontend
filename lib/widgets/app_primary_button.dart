import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Gradient primary action button — matches login screen Login button.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.showArrow = false,
    this.height = 56,
    this.useBrandGradient = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final double height;
  final bool useBrandGradient;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final enabled = onPressed != null || loading;
    final gradient = enabled
        ? (useBrandGradient
            ? AppColors.brandGradient
            : AppColors.primaryGradient)
        : LinearGradient(
            colors: [
              AppColors.primaryRed.withValues(alpha: 0.45),
              AppColors.duskMaroon.withValues(alpha: 0.45),
            ],
          );

    final button = SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.deepRed.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: radius,
              ),
              child: InkWell(
                onTap: loading ? null : onPressed,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: fullWidth ? 0 : 28,
                  ),
                  child: Center(
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: AppTypography.raleway(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                            if (showArrow) ...[
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.arrow_forward,
                                color: AppColors.white,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (fullWidth) {
      return button;
    }

    return Align(
      alignment: Alignment.center,
      child: button,
    );
  }
}
