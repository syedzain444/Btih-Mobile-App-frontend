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
  NotificationFilter _selectedFilter = NotificationFilter.all;

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
    await _notificationService.reloadForMrNo(widget.patientMrNo);
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  List<AppNotification> get _visibleNotifications {
    return _notificationService.filtered(_selectedFilter);
  }

  Map<String, List<AppNotification>> get _groupedNotifications {
    final grouped = <String, List<AppNotification>>{};
    for (final notification in _visibleNotifications) {
      final label = NotificationService.groupLabelFor(notification.createdAt);
      grouped.putIfAbsent(label, () => []).add(notification);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedNotifications;
    const groupOrder = ['Today', 'Yesterday', 'Earlier'];

    return Scaffold(
      backgroundColor: AppColors.blush,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: _loadNotifications,
              child: _visibleNotifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        _NotificationsEmptyState(),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _sectionCount(grouped, groupOrder),
                      itemBuilder: (context, index) {
                        return _buildSectionItem(grouped, groupOrder, index);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: NotificationFilter.values.map((filter) {
            final selected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TapFeedback(
                onTap: () => setState(() => _selectedFilter = filter),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryRed : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryRed
                          : AppColors.fieldBorder,
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.white : AppColors.darkText,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  int _sectionCount(
    Map<String, List<AppNotification>> grouped,
    List<String> groupOrder,
  ) {
    var count = 0;
    for (final label in groupOrder) {
      final items = grouped[label];
      if (items == null || items.isEmpty) continue;
      count += 1 + items.length;
    }
    return count;
  }

  Widget _buildSectionItem(
    Map<String, List<AppNotification>> grouped,
    List<String> groupOrder,
    int index,
  ) {
    var current = 0;
    for (final label in groupOrder) {
      final items = grouped[label];
      if (items == null || items.isEmpty) continue;

      if (current == index) {
        return _SectionHeader(label: label);
      }
      current++;

      for (final notification in items) {
        if (current == index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NotificationTile(
              notification: notification,
              onTap: () => _notificationService.markAsRead(notification.id),
            ),
          );
        }
        current++;
      }
    }
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.raleway(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: AppColors.fieldBorder.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
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
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? AppColors.fieldBorder
                : AppColors.lightMaroon,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 10,
                height: 10,
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
                            fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 6),
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
            'Updates about appointments, lab reports, billing, and hospital announcements will appear here.',
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
