import 'dart:io';

import 'package:btih_andriod_app/models/messaging_models.dart';
import 'package:btih_andriod_app/services/messaging_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageThreadScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final MessageThreadSummary thread;

  const MessageThreadScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    required this.thread,
  });

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _service = MessagingService.instance;
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Reserved for future older-page fetch when threads grow beyond the load cap.
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // API returns ASC pages (oldest first). Load consecutive pages so the
      // chat list ends with the newest messages.
      final first = await _service.getMessages(
        mrNo: widget.patientMrNo,
        threadId: widget.thread.threadId,
        pageNumber: 1,
        pageSize: 50,
      );

      var messages = [...first.messages];
      final totalPages = first.totalPages.clamp(1, 6);

      for (var page = 2; page <= totalPages; page++) {
        final next = await _service.getMessages(
          mrNo: widget.patientMrNo,
          threadId: widget.thread.threadId,
          pageNumber: page,
          pageSize: 50,
        );
        final existing = messages.map((m) => m.messageId).toSet();
        messages = [
          ...messages,
          ...next.messages.where((m) => !existing.contains(m.messageId)),
        ];
      }

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
        _loadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(max);
    }
  }

  Future<void> _sendText() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final sent = await _service.sendMessage(
        mrNo: widget.patientMrNo,
        threadId: widget.thread.threadId,
        body: text,
      );
      if (!mounted) return;
      _composerController.clear();
      setState(() {
        _messages = [..._messages, sent];
        _sending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _showAttachOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Attach file',
                  style: AppTypography.raleway(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 12),
                _attachOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Photo from gallery',
                  value: 'gallery',
                ),
                _attachOption(
                  icon: Icons.photo_camera_outlined,
                  label: 'Take a photo',
                  value: 'camera',
                ),
                _attachOption(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF or document',
                  value: 'file',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) return;
    if (choice == 'gallery') {
      await _pickImage(ImageSource.gallery);
    } else if (choice == 'camera') {
      await _pickImage(ImageSource.camera);
    } else if (choice == 'file') {
      await _pickDocument();
    }
  }

  Widget _attachOption({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.softRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primaryRed),
      ),
      title: Text(
        label,
        style: AppTypography.raleway(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      ),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _uploadFile(File(picked.path));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _uploadFile(File(path));
  }

  Future<void> _uploadFile(File file) async {
    setState(() => _sending = true);
    try {
      final caption = _composerController.text.trim();
      final sent = await _service.uploadAttachment(
        mrNo: widget.patientMrNo,
        threadId: widget.thread.threadId,
        file: file,
        body: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      _composerController.clear();
      setState(() {
        _messages = [..._messages, sent];
        _sending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _openAttachment(MessageAttachment attachment) async {
    final url = MessagingService.resolveFileUrl(attachment.fileUrl);
    if (url.isEmpty) {
      CustomMessageDialog.showError(context, 'Attachment URL is unavailable.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      CustomMessageDialog.showError(context, 'Invalid attachment URL.');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      CustomMessageDialog.showError(context, 'Could not open attachment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.raleway(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            Text(
              [
                if ((widget.thread.category ?? '').trim().isNotEmpty)
                  widget.thread.category!.trim(),
                widget.thread.isOpen ? 'Open' : widget.thread.status,
              ].join(' · '),
              style: AppTypography.roboto(
                fontSize: 12,
                color: AppColors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageArea()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageArea() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.roboto(
                  fontSize: 14,
                  color: AppColors.greyText,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadMessages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.softRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primaryRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Start the conversation',
                style: AppTypography.raleway(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRed,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send a message or attach a report for the hospital team.',
                textAlign: TextAlign.center,
                style: AppTypography.roboto(
                  fontSize: 13,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _buildTimelineItems(_messages);

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: () => _loadMessages(silent: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (_loadingMore && index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
            );
          }

          final itemIndex = _loadingMore ? index - 1 : index;
          final item = items[itemIndex];
          if (item is _DateSeparator) {
            return _DateChip(label: item.label);
          }
          final message = item as ChatMessage;
          return _MessageBubble(
            message: message,
            onOpenAttachment: _openAttachment,
          );
        },
      ),
    );
  }

  List<Object> _buildTimelineItems(List<ChatMessage> messages) {
    final items = <Object>[];
    DateTime? lastDay;
    for (final message in messages) {
      final day = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (lastDay == null || day != lastDay) {
        items.add(_DateSeparator(label: _dayLabel(day)));
        lastDay = day;
      }
      items.add(message);
    }
    return items;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
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
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  Widget _buildComposer() {
    final canSend = _composerController.text.trim().isNotEmpty && !_sending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRed.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        10,
        10,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TapFeedback(
            onTap: _sending ? null : _showAttachOptions,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softRed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.attach_file_rounded,
                color: AppColors.primaryRed,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _composerController,
                enabled: !_sending,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: AppTypography.roboto(
                    color: AppColors.greyText,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TapFeedback(
            onTap: canSend ? _sendText : null,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: canSend ? AppColors.primaryGradient : null,
                color: canSend ? null : AppColors.lightMaroon,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.white,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: canSend ? AppColors.white : AppColors.greyText,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator {
  final String label;
  const _DateSeparator({required this.label});
}

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Text(
            label,
            style: AppTypography.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.greyText,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(MessageAttachment attachment) onOpenAttachment;

  const _MessageBubble({
    required this.message,
    required this.onOpenAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final mine = message.isFromPatient;
    final time = _formatTime(message.createdAt);
    final body = (message.body ?? '').trim();

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            gradient: mine ? AppColors.primaryGradient : null,
            color: mine ? null : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 5),
              bottomRight: Radius.circular(mine ? 5 : 18),
            ),
            border: mine
                ? null
                : Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRed.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    (message.senderName ?? 'Hospital').trim().isEmpty
                        ? 'Hospital'
                        : message.senderName!.trim(),
                    style: AppTypography.raleway(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              if (body.isNotEmpty)
                Text(
                  body,
                  style: AppTypography.roboto(
                    fontSize: 14.5,
                    height: 1.35,
                    color: mine ? AppColors.white : AppColors.darkText,
                  ),
                ),
              if (message.attachments.isNotEmpty) ...[
                if (body.isNotEmpty) const SizedBox(height: 8),
                ...message.attachments.map(
                  (attachment) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _AttachmentTile(
                      attachment: attachment,
                      onMine: mine,
                      onTap: () => onOpenAttachment(attachment),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                time,
                style: AppTypography.roboto(
                  fontSize: 10.5,
                  color: mine
                      ? AppColors.white.withValues(alpha: 0.8)
                      : AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }
}

class _AttachmentTile extends StatelessWidget {
  final MessageAttachment attachment;
  final bool onMine;
  final VoidCallback onTap;

  const _AttachmentTile({
    required this.attachment,
    required this.onMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = MessagingService.resolveFileUrl(attachment.fileUrl);

    if (attachment.isImage && url.isNotEmpty) {
      return TapFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: url,
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              height: 160,
              color: onMine
                  ? AppColors.white.withValues(alpha: 0.15)
                  : AppColors.softRed,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
            errorWidget: (_, _, _) => _fileChip(),
          ),
        ),
      );
    }

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: _fileChip(),
    );
  }

  Widget _fileChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: onMine
            ? AppColors.white.withValues(alpha: 0.14)
            : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            size: 20,
            color: onMine ? AppColors.white : AppColors.primaryRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onMine ? AppColors.white : AppColors.darkText,
              ),
            ),
          ),
          Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: onMine
                ? AppColors.white.withValues(alpha: 0.85)
                : AppColors.greyText,
          ),
        ],
      ),
    );
  }
}
