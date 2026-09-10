import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Total vertical space reserved for the bottom navigation bar.
const double kPatientBottomNavHeight = 74;

/// Blush bottom navigation — matches dashboard mockup (not floating / not white).
class PatientBottomNavBar extends StatelessWidget {
  const PatientBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const dashboardIndex = 2;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _inactiveColor = Color(0xFF6B6B6B);
  static const _activeColor = AppColors.deepRed;

  static const _items = [
    (icon: Icons.medical_services_outlined, label: 'Doctors'),
    (icon: Icons.calendar_today_outlined, label: 'Appointments'),
    (icon: Icons.home_outlined, label: 'Dashboard'),
    (icon: Icons.folder_outlined, label: 'Records'),
    (icon: Icons.receipt_long_outlined, label: 'Billing'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.blush,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.blush,
          border: Border(
            top: BorderSide(
              color: AppColors.hairline.withValues(alpha: 0.85),
            ),
          ),
        ),
        child: SizedBox(
          height: kPatientBottomNavHeight + bottomInset,
          child: Padding(
            padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottomInset),
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                return Expanded(
                  child: _NavItem(
                    icon: item.icon,
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
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
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
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.softRed : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.raleway(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: PatientBottomNavBar._activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
