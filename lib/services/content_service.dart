import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizedContentItem {
  final String contentKey;
  final String langCode;
  final String? title;
  final String? body;

  const LocalizedContentItem({
    required this.contentKey,
    required this.langCode,
    this.title,
    this.body,
  });

  factory LocalizedContentItem.fromJson(Map<String, dynamic> json) {
    return LocalizedContentItem(
      contentKey: json['contentKey']?.toString() ?? '',
      langCode: json['langCode']?.toString() ?? 'en',
      title: json['title']?.toString(),
      body: json['body']?.toString(),
    );
  }
}

/// Loads and caches `GET /api/Content/{lang}`.
class ContentService {
  ContentService._();

  static final ContentService instance = ContentService._();

  static const _cachePrefix = 'content_cache_v1_';

  final Map<String, List<LocalizedContentItem>> _memory = {};

  Future<List<LocalizedContentItem>> load(String langCode) async {
    final lang = langCode.trim().isEmpty ? 'en' : langCode.trim().toLowerCase();
    if (_memory.containsKey(lang) && _memory[lang]!.isNotEmpty) {
      return _memory[lang]!;
    }

    try {
      final response = await ApiConfig.client.get(
        Uri.parse('${ApiConfig.baseUrl}/api/Content/$lang'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is List) {
          final items = (decoded['data'] as List)
              .whereType<Map>()
              .map(
                (e) => LocalizedContentItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
          _memory[lang] = items;
          await _persist(lang, items);
          return items;
        }
      }
    } catch (_) {}

    final cached = await _readCache(lang);
    if (cached.isNotEmpty) {
      _memory[lang] = cached;
      return cached;
    }
    return const [];
  }

  Future<LocalizedContentItem?> getItem(String langCode, String key) async {
    final items = await load(langCode);
    final needle = key.trim().toLowerCase();
    for (final item in items) {
      if (item.contentKey.toLowerCase() == needle) return item;
    }
    return null;
  }

  Future<String?> bodyFor(String langCode, String key) async {
    final item = await getItem(langCode, key);
    final body = item?.body?.trim();
    if (body != null && body.isNotEmpty) return body;
    return item?.title;
  }

  Future<void> _persist(String lang, List<LocalizedContentItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode([
        for (final i in items)
          {
            'contentKey': i.contentKey,
            'langCode': i.langCode,
            'title': i.title,
            'body': i.body,
          },
      ]);
      await prefs.setString('$_cachePrefix$lang', encoded);
    } catch (_) {}
  }

  Future<List<LocalizedContentItem>> _readCache(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$lang');
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (e) => LocalizedContentItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
