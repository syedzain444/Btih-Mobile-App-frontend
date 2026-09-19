import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Height of the bottom nav content row (excluding safe area).
const double kPatientBottomNavHeight = 60;

class PatientBottomNavBar extends StatelessWidget {
  const PatientBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const dashboardIndex = 2;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _inactiveColor = Color(0xFF9A8A8C);
  static const _activeColor = AppColors.primaryRed;

  static const _items = [
    (
      icon: Icons.medical_services_outlined,
      activeIcon: Icons.medical_services_rounded,
      label: 'Doctors',
    ),
    (
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Appointments',
    ),
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
      label: 'Records',
    ),
    (
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Billing',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(
              color: AppColors.primaryRed.withValues(alpha: 0.10),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRed.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: kPatientBottomNavHeight,
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                return Expanded(
                  child: _NavItem(
                    icon: item.icon,
                    activeIcon: item.activeIcon,
                    label: item.label,
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? PatientBottomNavBar._activeColor
        : PatientBottomNavBar._inactiveColor;

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 32,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.softRed.withValues(alpha: 0.95)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.raleway(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
