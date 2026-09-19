import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Resolves doctor photo URLs from API — handles relative paths and rewrites
/// hardcoded backend hosts to the active [ApiConfig.baseUrl] host.
class DoctorImageHelper {
  DoctorImageHelper._();

  static const int avatarCachePx = 72;

  static String? resolve(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final trimmed = raw.trim();
    final apiBase = Uri.tryParse(ApiConfig.baseUrl);
    if (apiBase == null || !apiBase.hasAuthority) {
      return trimmed.startsWith('http') ? trimmed : null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final imageUri = Uri.tryParse(trimmed);
      if (imageUri == null || imageUri.path.isEmpty) return trimmed;

      return Uri(
        scheme: apiBase.scheme,
        host: apiBase.host,
        port: apiBase.hasPort ? apiBase.port : null,
        path: imageUri.path,
        query: imageUri.query.isEmpty ? null : imageUri.query,
      ).toString();
    }

    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return Uri(
      scheme: apiBase.scheme,
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
      path: path,
    ).toString();
  }

  static Future<void> precacheAvatars(
    BuildContext context,
    Iterable<String?> rawUrls, {
    int maxUrls = 20,
  }) async {
    if (!context.mounted) return;

    final urls = rawUrls
        .map(resolve)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet()
        .take(maxUrls);

    await Future.wait(
      urls.map(
        (url) => precacheImage(
          CachedNetworkImageProvider(
            url,
            maxWidth: avatarCachePx,
            maxHeight: avatarCachePx,
          ),
          context,
        ).catchError((_) {}),
      ),
      eagerError: false,
    );
  }
}
