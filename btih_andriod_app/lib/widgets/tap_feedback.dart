import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Wraps tappable UI with visible splash + highlight feedback on press.
class TapFeedback extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? materialColor;

  const TapFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    this.materialColor,
  });

  static Color get defaultSplash =>
      AppColors.primaryRed.withValues(alpha: 0.14);

  static Color get defaultHighlight => AppColors.softRed.withValues(alpha: 0.85);

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;

    return Material(
      color: materialColor ?? Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: splashColor ?? defaultSplash,
        highlightColor: highlightColor ?? defaultHighlight,
        hoverColor: highlightColor ?? defaultHighlight,
        child: child,
      ),
    );
  }
}
