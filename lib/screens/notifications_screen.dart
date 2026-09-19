import 'package:btih_andriod_app/models/app_notification.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

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
      case NotificationCategory.general:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _notificationService.groupedByCategory();
    final hasAny = _notificationService.notifications.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.white,
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
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  _NotificationsEmptyState(),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                itemCount: _flatItemCount(grouped),
                itemBuilder: (context, index) {
                  return _buildFlatItem(grouped, index);
                },
              ),
      ),
    );
  }

  int _flatItemCount(Map<NotificationCategory, List<AppNotification>> grouped) {
    var count = 0;
    for (final entry in grouped.entries) {
      count += 1 + entry.value.length;
    }
    return count;
  }

  Widget _buildFlatItem(
    Map<NotificationCategory, List<AppNotification>> grouped,
    int index,
  ) {
    var current = 0;
    for (final entry in grouped.entries) {
      if (current == index) {
        return _CategoryHeader(
          title: entry.key.sectionTitle,
          icon: _iconFor(entry.key),
          count: entry.value.length,
        );
      }
      current++;

      for (final notification in entry.value) {
        if (current == index) {
          return _NotificationRow(
            notification: notification,
            onTap: () => _notificationService.markAsRead(notification.id),
          );
        }
        current++;
      }
    }
    return const SizedBox.shrink();
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;

  const _CategoryHeader({
    required this.title,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.softRed,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: AppColors.primaryRed),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppTypography.raleway(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
          ),
          Text(
            '$count',
            style: AppTypography.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.greyText,
            ),
          ),
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

  Color _dotColor() {
    switch (notification.priority) {
      case NotificationPriority.high:
        return AppColors.primaryRed;
      case NotificationPriority.normal:
        return AppColors.success;
      case NotificationPriority.low:
        return AppColors.greyText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TapFeedback(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _dotColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTypography.raleway(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6, left: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
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
                      const SizedBox(height: 6),
                      Text(
                        NotificationService.formatRelativeTime(
                          notification.createdAt,
                        ),
                        style: AppTypography.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.greyText.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          indent: 41,
          endIndent: 20,
          color: AppColors.hairline,
        ),
      ],
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
            'Appointment reminders, medications, lab reports, payments, and hospital updates will appear here by category.',
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
