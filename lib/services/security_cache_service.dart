import 'dart:io';

import 'package:btih_andriod_app/services/report_pdf_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SecurityCacheService {
  SecurityCacheService._();

  static Future<int> clearDownloadedReportsAndCache() async {
    var deleted = 0;

    if (!kIsWeb) {
      deleted += await _clearDirectory(await getTemporaryDirectory());
      deleted += await ReportPdfCacheService.clearAll();
    }

    return deleted;
  }

  static Future<int> _clearDirectory(
    Directory dir, {
    bool removeDir = false,
  }) async {
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          await entity.delete();
          count++;
        } catch (_) {}
      }
    }
    if (removeDir) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    return count;
  }
}
