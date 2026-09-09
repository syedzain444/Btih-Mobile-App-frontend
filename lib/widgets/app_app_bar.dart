import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Flat maroon app bar — login [AppColors.brandGradient], no decorative blobs.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle = true,
    this.bottom,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  static IconButton backButton(BuildContext context, {VoidCallback? onPressed}) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      color: AppColors.white,
      onPressed: onPressed ?? () => Navigator.pop(context),
    );
  }

  Widget? _resolveLeading(BuildContext context) {
    if (leading != null) return leading;
    if (!automaticallyImplyLeading) return null;
    if (!Navigator.canPop(context)) return null;
    return backButton(context);
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: _resolveLeading(context),
      title: title,
      actions: actions,
      centerTitle: centerTitle,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      ),
    );
  }
}
