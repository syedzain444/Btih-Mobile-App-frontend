import 'package:btih_andriod_app/models/app_notification.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Categorized notification inbox — vertical sections (no horizontal tabs).
class NotificationsScreen extends StatefulWidget {
  final String patientMrNo;

  const NotificationsScreen({
    super.key,
    required this.patientMrNo,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final mr = widget.patientMrNo.trim().isNotEmpty
        ? widget.patientMrNo.trim()
        : _notificationService.lastKnownMrNo;
    await _notificationService.reloadForMrNo(mr);
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  IconData _iconFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.appointments:
        return Icons.event_available_rounded;
      case NotificationCategory.medications:
        return Icons.medication_rounded;
      case NotificationCategory.lab:
        return Icons.science_outlined;
      case NotificationCategory.records:
        return Icons.folder_shared_outlined;
      case NotificationCategory.billing:
        return Icons.payments_outlined;
      case NotificationCategory.messaging:
        return Icons.chat_bubble_outline_rounded;
      case NotificationCategory.security:
        return Icons.shield_outlined;
      case NotificationCategory.general:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _notificationService.groupedByCategory();
    final hasAny = _notificationService.notifications.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F4),
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Notifications',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: [
          if (_notificationService.unreadCount > 0)
            TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
              },
              child: Text(
                'Mark all read',
                style: AppTypography.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          const AppBarIconBadge(icon: Icons.notifications_outlined),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _loadNotifications,
        child: !hasAny
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: const [
                  SizedBox(height: 120),
                  _NotificationsEmptyState(),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  for (final entry in grouped.entries) ...[
                    _CategorySection(
                      category: entry.key,
                      icon: _iconFor(entry.key),
                      notifications: entry.value,
                      onTapItem: (id) => _notificationService.markAsRead(id),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.icon,
    required this.notifications,
    required this.onTapItem,
  });

  final NotificationCategory category;
  final IconData icon;
  final List<AppNotification> notifications;
  final ValueChanged<String> onTapItem;

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.isRead).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.softRed,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: AppColors.deepRed),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.sectionTitle,
                        style: AppTypography.raleway(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepRed,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.sectionSubtitle,
                        style: AppTypography.roboto(
                          fontSize: 11.5,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softRed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unread new',
                      style: AppTypography.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepRed,
                      ),
                    ),
                  )
                else
                  Text(
                    '${notifications.length}',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.greyText,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          for (var i = 0; i < notifications.length; i++) ...[
            _NotificationRow(
              notification: notifications[i],
              onTap: () => onTapItem(notifications[i].id),
            ),
            if (i < notifications.length - 1)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.hairline,
              ),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? AppColors.fieldBorder
                      : AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTypography.raleway(
                      fontSize: 14.5,
                      fontWeight: notification.isRead
                          ? FontWeight.w600
                          : FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: AppTypography.roboto(
                      fontSize: 13,
                      color: AppColors.greyText,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NotificationService.formatAbsoluteDateTime(
                      notification.createdAt,
                    ),
                    style: AppTypography.roboto(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.greyText.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: AppColors.greyText.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: AppTypography.raleway(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appointments, medications, lab reports, billing, messages, '
            'and security alerts will appear here by category.',
            textAlign: TextAlign.center,
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
