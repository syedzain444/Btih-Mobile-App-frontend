import 'package:btih_andriod_app/models/messaging_models.dart';
import 'package:btih_andriod_app/screens/messaging/message_thread_screen.dart';
import 'package:btih_andriod_app/screens/messaging/new_message_sheet.dart';
import 'package:btih_andriod_app/services/messaging_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class MessageInboxScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;

  const MessageInboxScreen({
    super.key,
    required this.patientMrNo,
    this.patientName = 'Patient',
  });

  @override
  State<MessageInboxScreen> createState() => _MessageInboxScreenState();
}

class _MessageInboxScreenState extends State<MessageInboxScreen> {
  final _service = MessagingService.instance;
  final _searchController = TextEditingController();

  List<MessageThreadSummary> _threads = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInbox({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final threads = await _service.getInbox(mrNo: widget.patientMrNo);
      threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<MessageThreadSummary> get _filteredThreads {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _threads;
    return _threads.where((t) {
      return t.subject.toLowerCase().contains(q) ||
          (t.category ?? '').toLowerCase().contains(q) ||
          (t.lastMessagePreview ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openThread(MessageThreadSummary thread) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          thread: thread,
        ),
      ),
    );
    if (mounted) await _loadInbox(showSpinner: false);
  }

  Future<void> _startNewMessage() async {
    final created = await showNewMessageSheet(
      context,
      patientMrNo: widget.patientMrNo,
    );
    if (created == null || !mounted) return;

    await _loadInbox(showSpinner: false);
    final match = _threads.where((t) => t.threadId == created).toList();
    final thread = match.isNotEmpty
        ? match.first
        : MessageThreadSummary(
            threadId: created,
            mrNo: widget.patientMrNo,
            subject: 'New conversation',
            category: null,
            status: 'OPEN',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            lastMessagePreview: null,
            unreadCount: 0,
          );

    if (!mounted) return;
    await _openThread(thread);
  }

  @override
  Widget build(BuildContext context) {
    final threads = _filteredThreads;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Messages',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: const [
          AppBarIconBadge(icon: Icons.chat_bubble_outline_rounded),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewMessage,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.edit_rounded),
        label: Text(
          'New message',
          style: AppTypography.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: () => _loadInbox(showSpinner: false),
              child: _buildBody(threads),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: 'Search conversations',
          hintStyle: AppTypography.roboto(
            color: AppColors.greyText,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.greyText.withValues(alpha: 0.9),
          ),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryRed),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<MessageThreadSummary> threads) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppColors.primaryRed.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load messages',
            textAlign: TextAlign.center,
            style: AppTypography.raleway(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: _loadInbox,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (threads.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 72),
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: AppColors.greyText.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 20),
          Text(
            _query.trim().isEmpty
                ? 'No conversations yet'
                : 'No matching conversations',
            textAlign: TextAlign.center,
            style: AppTypography.raleway(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _query.trim().isEmpty
                ? 'Message the hospital securely about appointments, reports, or billing.'
                : 'Try a different search term.',
            textAlign: TextAlign.center,
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      itemCount: threads.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        indent: 72,
        endIndent: 16,
        color: AppColors.hairline,
      ),
      itemBuilder: (context, index) {
        final thread = threads[index];
        return _ThreadRow(
          thread: thread,
          onTap: () => _openThread(thread),
        );
      },
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final MessageThreadSummary thread;
  final VoidCallback onTap;

  const _ThreadRow({
    required this.thread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = thread.unreadCount > 0;
    final preview = (thread.lastMessagePreview ?? '').trim().isEmpty
        ? 'No messages yet'
        : thread.lastMessagePreview!.trim();
    final meta = [
      if ((thread.category ?? '').trim().isNotEmpty) thread.category!.trim(),
      thread.isOpen ? 'Open' : thread.status,
    ].join(' · ');

    return TapFeedback(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softRed,
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(thread.subject),
                style: AppTypography.raleway(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.raleway(
                            fontSize: 15,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(thread.updatedAt),
                        style: AppTypography.roboto(
                          fontSize: 11,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryRed.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.roboto(
                      fontSize: 13,
                      height: 1.35,
                      color: unread ? AppColors.darkText : AppColors.greyText,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                  style: AppTypography.roboto(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String subject) {
    final parts = subject
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    if (day == today) return '$hh:$mm $ampm';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (now.difference(local).inDays < 7) {
      return weekdays[local.weekday - 1];
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]}';
  }
}
