import 'package:btih_andriod_app/models/app_notification.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Notification inbox with horizontal category tabs.
class NotificationsScreen extends StatefulWidget {
  final String patientMrNo;

  const NotificationsScreen({
    super.key,
    required this.patientMrNo,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService.instance;
  late final TabController _tabController;

  static const _tabs = NotificationCategoryX.sectionOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _notificationService.addListener(_onNotificationsChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _notificationService.removeListener(_onNotificationsChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {});
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
      case NotificationCategory.support:
        return Icons.feedback_outlined;
      case NotificationCategory.security:
        return Icons.shield_outlined;
      case NotificationCategory.general:
        return Icons.campaign_outlined;
    }
  }

  int _unreadFor(NotificationCategory category) {
    return _notificationService
        .filteredByCategory(category)
        .where((n) => !n.isRead)
        .length;
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategoryPills(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final category in _tabs)
                  RefreshIndicator(
                    color: AppColors.primaryRed,
                    onRefresh: _loadNotifications,
                    child: _CategoryTabBody(
                      category: category,
                      icon: _iconFor(category),
                      notifications:
                          _notificationService.filteredByCategory(category),
                      onTapItem: (id) => _notificationService.markAsRead(id),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    return Material(
      color: AppColors.white,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.hairline),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _CategoryPill(
                  label: _tabs[i].sectionTitle,
                  selected: _tabController.index == i,
                  unread: _unreadFor(_tabs[i]),
                  onTap: () {
                    _tabController.animateTo(i);
                    setState(() {});
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.deepRed : AppColors.blush,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.deepRed : AppColors.softRed,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.raleway(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.white : AppColors.deepRed,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.white.withValues(alpha: 0.22)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unread',
                  style: AppTypography.roboto(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.white : AppColors.deepRed,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTabBody extends StatelessWidget {
  const _CategoryTabBody({
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
    if (notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          _CategoryEmptyState(category: category, icon: icon),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: notifications.length + 1,
      separatorBuilder: (_, index) {
        if (index == 0) return const SizedBox(height: 10);
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CategoryHeader(
            category: category,
            icon: icon,
            count: notifications.length,
            unread: notifications.where((n) => !n.isRead).length,
          );
        }
        final notification = notifications[index - 1];
        return _NotificationCard(
          notification: notification,
          onTap: () => onTapItem(notification.id),
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    required this.icon,
    required this.count,
    required this.unread,
  });

  final NotificationCategory category;
  final IconData icon;
  final int count;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            '$count',
            style: AppTypography.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.greyText,
            ),
          ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: TapFeedback(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
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
          ),
        ),
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({
    required this.category,
    required this.icon,
  });

  final NotificationCategory category;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(
            icon,
            size: 56,
            color: AppColors.greyText.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${category.sectionTitle.toLowerCase()} yet',
            style: AppTypography.raleway(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            category.sectionSubtitle,
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
