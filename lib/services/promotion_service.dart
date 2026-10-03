import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/foundation.dart';

class PromotionItem {
  final int promotionId;
  final String title;
  final String imageUrl;
  final int sortOrder;
  final int durationSeconds;
  final bool isAsset;

  const PromotionItem({
    required this.promotionId,
    required this.title,
    required this.imageUrl,
    this.sortOrder = 0,
    this.durationSeconds = 5,
    this.isAsset = false,
  });

  factory PromotionItem.fromJson(Map<String, dynamic> json) {
    final duration =
        int.tryParse(json['durationSeconds']?.toString() ?? '') ?? 5;
    return PromotionItem(
      promotionId: int.tryParse(json['promotionId']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      durationSeconds: duration.clamp(2, 60),
    );
  }

  /// Absolute image URL for network loads.
  String get absoluteImageUrl {
    final raw = imageUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (raw.startsWith('/')) return '$base$raw';
    return '$base/$raw';
  }
}

/// Loads active launch promotions from `GET /api/Promotion/active`.
class PromotionService {
  PromotionService._();

  static final PromotionService instance = PromotionService._();

  /// Returns active promotions from the API (already capped by admin display limit).
  /// Empty list if none / unreachable — caller should skip to welcome.
  Future<List<PromotionItem>> fetchActive({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      await ApiConfig.ensureResolved();
    } catch (e) {
      debugPrint('[PromotionService] ensureResolved failed: $e');
    }

    final bases = <String>{
      ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''),
      ApiConfig.defaultBaseUrl.replaceAll(RegExp(r'/+$'), ''),
      ApiConfig.productionBaseUrl.replaceAll(RegExp(r'/+$'), ''),
    };

    for (final base in bases) {
      final items = await _tryFetch(base, timeout);
      if (items != null) return items;
    }

    debugPrint('[PromotionService] all hosts failed — no promotions');
    return const [];
  }

  Future<List<PromotionItem>?> _tryFetch(String base, Duration timeout) async {
    final bust = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('$base/api/Promotion/active?_=$bust');
    try {
      final response = await ApiConfig.client.get(uri).timeout(timeout);
      debugPrint(
        '[PromotionService] GET $uri → ${response.statusCode}',
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) return null;

      final items = (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => PromotionItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.imageUrl.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      debugPrint(
        '[PromotionService] loaded ${items.length} promotion(s) from $base',
      );
      return items;
    } catch (e) {
      debugPrint('[PromotionService] $uri failed: $e');
      return null;
    }
  }
}
