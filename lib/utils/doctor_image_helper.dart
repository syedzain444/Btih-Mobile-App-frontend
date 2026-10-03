import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Resolves doctor photo URLs from API — handles relative paths and rewrites
/// unreachable legacy image hosts onto the active [ApiConfig.baseUrl].
class DoctorImageHelper {
  DoctorImageHelper._();

  static const int avatarCachePx = 160;

  /// Legacy image IIS hosts. Photos are mirrored under the mobile API host
  /// (e.g. http://172.20.8.36/Images/...), so rewrite these to [ApiConfig.baseUrl].
  static const Set<String> _legacyImageHosts = {
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
    '172.16.40.10',
  };

  static String? resolve(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final trimmed = raw.trim();
    final apiBase = Uri.tryParse(ApiConfig.baseUrl);

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final imageUri = Uri.tryParse(trimmed);
      if (imageUri == null || imageUri.host.isEmpty) return trimmed;

      final host = imageUri.host.toLowerCase();
      final rewriteToApi = apiBase != null &&
          apiBase.hasAuthority &&
          (_legacyImageHosts.contains(host) ||
              (imageUri.hasPort &&
                  imageUri.port == 8080 &&
                  imageUri.path.toLowerCase().contains('/images')));

      if (rewriteToApi) {
        return _onApiBase(apiBase, imageUri.path, imageUri.query);
      }

      return _encodeUrl(imageUri);
    }

    if (apiBase == null || !apiBase.hasAuthority) return null;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return _onApiBase(apiBase, path, null);
  }

  static String _onApiBase(Uri apiBase, String path, String? query) {
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map((segment) {
          try {
            return Uri.decodeComponent(segment);
          } catch (_) {
            return segment;
          }
        })
        .toList(growable: false);

    return Uri(
      scheme: apiBase.scheme,
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
      pathSegments: segments,
      query: (query == null || query.isEmpty) ? null : query,
    ).toString();
  }

  static String _encodeUrl(Uri uri) {
    if (uri.pathSegments.isEmpty) return uri.toString();
    final segments = uri.pathSegments.map((segment) {
      try {
        return Uri.decodeComponent(segment);
      } catch (_) {
        return segment;
      }
    }).toList(growable: false);
    return uri.replace(pathSegments: segments).toString();
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
