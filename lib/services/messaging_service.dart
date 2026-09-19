import 'dart:convert';
import 'dart:io';

import 'package:btih_andriod_app/models/messaging_models.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/utils/doctor_image_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  static const maxAttachmentBytes = 10485760;
  static const allowedExtensions = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
  };

  Future<List<MessageThreadSummary>> getInbox({required String mrNo}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Messaging/inbox').replace(
      queryParameters: {'mrNo': mrNo},
    );
    final response =
        await ApiConfig.client.get(uri).timeout(ApiConfig.requestTimeout);
    final decoded = _decodeMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (e) => MessageThreadSummary.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }

    throw Exception(_errorMessage(decoded, response.statusCode, 'inbox'));
  }

  Future<int> createThread({
    required String mrNo,
    required String subject,
    String? category,
    String? initialMessage,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Messaging/threads');
    final response = await ApiConfig.client
        .post(
          uri,
          headers: const {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'mrNo': mrNo,
            'subject': subject.trim(),
            if (category != null && category.trim().isNotEmpty)
              'category': category.trim(),
            if (initialMessage != null && initialMessage.trim().isNotEmpty)
              'initialMessage': initialMessage.trim(),
          }),
        )
        .timeout(ApiConfig.requestTimeout);

    final decoded = _decodeMap(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final id = decoded?['threadId'];
      final threadId = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (threadId == null || threadId <= 0) {
        throw Exception('Thread created but no threadId returned');
      }
      return threadId;
    }

    throw Exception(_errorMessage(decoded, response.statusCode, 'create thread'));
  }

  Future<MessagePageResult> getMessages({
    required String mrNo,
    required int threadId,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Messaging/threads/$threadId/messages',
    ).replace(
      queryParameters: {
        'mrNo': mrNo,
        'pageNumber': '$pageNumber',
        'pageSize': '$pageSize',
      },
    );

    final response =
        await ApiConfig.client.get(uri).timeout(ApiConfig.requestTimeout);
    final decoded = _decodeMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded?['data'];
      final messages = data is List
          ? data
              .whereType<Map>()
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <ChatMessage>[];

      return MessagePageResult(
        messages: messages,
        pageNumber: _asInt(decoded?['pageNumber'], pageNumber),
        pageSize: _asInt(decoded?['pageSize'], pageSize),
        totalRecords: _asInt(decoded?['totalRecords'], messages.length),
        totalPages: _asInt(decoded?['totalPages'], 1),
      );
    }

    throw Exception(_errorMessage(decoded, response.statusCode, 'messages'));
  }

  Future<ChatMessage> sendMessage({
    required String mrNo,
    required int threadId,
    required String body,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Messaging/threads/$threadId/messages',
    );
    final response = await ApiConfig.client
        .post(
          uri,
          headers: const {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'mrNo': mrNo,
            'body': body.trim(),
          }),
        )
        .timeout(ApiConfig.requestTimeout);

    final decoded = _decodeMap(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded?['data'];
      if (data is Map) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Message sent but response was empty');
    }

    throw Exception(_errorMessage(decoded, response.statusCode, 'send message'));
  }

  Future<ChatMessage> uploadAttachment({
    required String mrNo,
    required int threadId,
    required File file,
    String? body,
  }) async {
    final extension = p.extension(file.path).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw Exception(
        'Unsupported file type. Allowed: PDF, JPG, PNG, GIF, WEBP.',
      );
    }

    final length = await file.length();
    if (length <= 0) {
      throw Exception('Selected file is empty.');
    }
    if (length > maxAttachmentBytes) {
      throw Exception('File is too large. Maximum size is 10 MB.');
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Messaging/threads/$threadId/attachments',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(AuthSession.authHeaders);
    request.fields['mrNo'] = mrNo;
    if (body != null && body.trim().isNotEmpty) {
      request.fields['body'] = body.trim();
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: p.basename(file.path),
        contentType: _mediaTypeForExtension(extension),
      ),
    );

    final streamed = await request.send().timeout(ApiConfig.requestTimeout);
    final response = await http.Response.fromStream(streamed);
    final decoded = _decodeMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded?['data'];
      if (data is Map) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Attachment uploaded but response was empty');
    }

    throw Exception(
      _errorMessage(decoded, response.statusCode, 'upload attachment'),
    );
  }

  static String resolveFileUrl(String? fileUrl) {
    return DoctorImageHelper.resolve(fileUrl) ?? '';
  }

  MediaType _mediaTypeForExtension(String extension) {
    return switch (extension) {
      '.pdf' => MediaType('application', 'pdf'),
      '.png' => MediaType('image', 'png'),
      '.gif' => MediaType('image', 'gif'),
      '.webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  Map<String, dynamic>? _decodeMap(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(
    Map<String, dynamic>? decoded,
    int statusCode,
    String action,
  ) {
    return decoded?['message']?.toString() ??
        'Failed to $action (HTTP $statusCode)';
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
