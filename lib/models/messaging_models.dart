class MessageThreadSummary {
  final int threadId;
  final String mrNo;
  final String subject;
  final String? category;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessagePreview;
  final int unreadCount;

  const MessageThreadSummary({
    required this.threadId,
    required this.mrNo,
    required this.subject,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessagePreview,
    required this.unreadCount,
  });

  bool get isOpen => status.toUpperCase() == 'OPEN';

  factory MessageThreadSummary.fromJson(Map<String, dynamic> json) {
    return MessageThreadSummary(
      threadId: _asInt(json['threadId']),
      mrNo: json['mrNo']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'Conversation',
      category: json['category']?.toString(),
      status: json['status']?.toString() ?? 'OPEN',
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      unreadCount: _asInt(json['unreadCount']),
    );
  }
}

class MessageAttachment {
  final int attachmentId;
  final int messageId;
  final String fileName;
  final String fileUrl;
  final String? contentType;
  final int? fileSize;

  const MessageAttachment({
    required this.attachmentId,
    required this.messageId,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    required this.fileSize,
  });

  bool get isImage {
    final type = (contentType ?? '').toLowerCase();
    final name = fileName.toLowerCase();
    return type.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp');
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      attachmentId: _asInt(json['attachmentId']),
      messageId: _asInt(json['messageId']),
      fileName: json['fileName']?.toString() ?? 'file',
      fileUrl: json['fileUrl']?.toString() ?? '',
      contentType: json['contentType']?.toString(),
      fileSize: json['fileSize'] == null ? null : _asInt(json['fileSize']),
    );
  }
}

class ChatMessage {
  final int messageId;
  final int threadId;
  final String senderType;
  final String? senderName;
  final String? body;
  final DateTime createdAt;
  final List<MessageAttachment> attachments;

  const ChatMessage({
    required this.messageId,
    required this.threadId,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.createdAt,
    required this.attachments,
  });

  bool get isFromPatient => senderType.toUpperCase() == 'PATIENT';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
            .whereType<Map>()
            .map((e) => MessageAttachment.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MessageAttachment>[];

    return ChatMessage(
      messageId: _asInt(json['messageId']),
      threadId: _asInt(json['threadId']),
      senderType: json['senderType']?.toString() ?? '',
      senderName: json['senderName']?.toString(),
      body: json['body']?.toString(),
      createdAt: _asDate(json['createdAt']),
      attachments: attachments,
    );
  }
}

class MessagePageResult {
  final List<ChatMessage> messages;
  final int pageNumber;
  final int pageSize;
  final int totalRecords;
  final int totalPages;

  const MessagePageResult({
    required this.messages,
    required this.pageNumber,
    required this.pageSize,
    required this.totalRecords,
    required this.totalPages,
  });

  bool get hasMore => pageNumber < totalPages;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
