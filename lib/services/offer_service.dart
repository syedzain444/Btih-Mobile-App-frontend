import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/foundation.dart';

class OfferItem {
  final int offerId;
  final String title;
  final String? subtitle;
  final String? description;
  final String category;
  final String? imageUrl;
  final double? originalPrice;
  final double? offerPrice;
  final String currency;
  final List<String> highlights;
  final String ctaLabel;
  final String? ctaPhone;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;

  const OfferItem({
    required this.offerId,
    required this.title,
    this.subtitle,
    this.description,
    this.category = 'Package',
    this.imageUrl,
    this.originalPrice,
    this.offerPrice,
    this.currency = 'PKR',
    this.highlights = const [],
    this.ctaLabel = 'Enquire',
    this.ctaPhone,
    this.sortOrder = 0,
    this.startAt,
    this.endAt,
  });

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    final highlightsRaw = json['highlights'];
    final highlights = <String>[];
    if (highlightsRaw is List) {
      for (final item in highlightsRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) highlights.add(text);
      }
    } else if (highlightsRaw is String && highlightsRaw.trim().isNotEmpty) {
      highlights.addAll(
        highlightsRaw
            .split(RegExp(r'[|\n\r]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    return OfferItem(
      offerId: int.tryParse(json['offerId']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? 'Package',
      imageUrl: json['imageUrl']?.toString(),
      originalPrice: double.tryParse(json['originalPrice']?.toString() ?? ''),
      offerPrice: double.tryParse(json['offerPrice']?.toString() ?? ''),
      currency: json['currency']?.toString() ?? 'PKR',
      highlights: highlights,
      ctaLabel: (json['ctaLabel']?.toString().trim().isNotEmpty ?? false)
          ? json['ctaLabel'].toString()
          : 'Enquire',
      ctaPhone: json['ctaPhone']?.toString(),
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      startAt: DateTime.tryParse(json['startAt']?.toString() ?? ''),
      endAt: DateTime.tryParse(json['endAt']?.toString() ?? ''),
    );
  }

  String get absoluteImageUrl {
    final raw = imageUrl?.trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (raw.startsWith('/')) return '$base$raw';
    return '$base/$raw';
  }

  String get displayPrice {
    final price = offerPrice ?? originalPrice;
    if (price == null) return '';
    final whole = price == price.roundToDouble();
    final formatted = whole ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return '$currency $formatted';
  }

  String? get strikethroughPrice {
    if (offerPrice == null || originalPrice == null) return null;
    if (originalPrice! <= offerPrice!) return null;
    final whole = originalPrice == originalPrice!.roundToDouble();
    final formatted = whole
        ? originalPrice!.toStringAsFixed(0)
        : originalPrice!.toStringAsFixed(2);
    return '$currency $formatted';
  }
}

/// Loads active offers/packages from `GET /api/Offer/active`.
class OfferService {
  OfferService._();

  static final OfferService instance = OfferService._();

  Future<List<OfferItem>> fetchActive({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      await ApiConfig.ensureResolved();
    } catch (e) {
      debugPrint('[OfferService] ensureResolved failed: $e');
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

    debugPrint('[OfferService] all hosts failed — no offers');
    return const [];
  }

  Future<OfferItem?> fetchById(
    int offerId, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      await ApiConfig.ensureResolved();
    } catch (_) {}

    final bases = <String>{
      ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''),
      ApiConfig.defaultBaseUrl.replaceAll(RegExp(r'/+$'), ''),
      ApiConfig.productionBaseUrl.replaceAll(RegExp(r'/+$'), ''),
    };

    for (final base in bases) {
      final item = await _tryFetchById(base, offerId, timeout);
      if (item != null) return item;
    }
    return null;
  }

  Future<List<OfferItem>?> _tryFetch(String base, Duration timeout) async {
    final bust = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('$base/api/Offer/active?_=$bust');
    try {
      final response = await ApiConfig.client.get(uri).timeout(timeout);
      debugPrint('[OfferService] GET $uri → ${response.statusCode}');
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) return null;

      final items = (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => OfferItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.title.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      debugPrint('[OfferService] loaded ${items.length} offer(s) from $base');
      return items;
    } catch (e) {
      debugPrint('[OfferService] $uri failed: $e');
      return null;
    }
  }

  Future<OfferItem?> _tryFetchById(
    String base,
    int offerId,
    Duration timeout,
  ) async {
    final uri = Uri.parse('$base/api/Offer/$offerId');
    try {
      final response = await ApiConfig.client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! Map) return null;
      return OfferItem.fromJson(
        Map<String, dynamic>.from(decoded['data'] as Map),
      );
    } catch (e) {
      debugPrint('[OfferService] $uri failed: $e');
      return null;
    }
  }
}
