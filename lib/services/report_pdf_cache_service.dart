import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Local PDF cache for clinical reports (REQ-2026-020 / TC-020).
///
/// Stores generated Lab / Prescription / Gastro / Radiology PDFs under
/// `{ApplicationDocuments}/BTIHReports/cache` so re-open and re-download
/// avoid regenerating on the hospital network.
class ReportPdfCacheService {
  ReportPdfCacheService._();

  static const relativeCacheDir = 'BTIHReports/cache';
  static const maxAge = Duration(days: 7);
  static const maxEntries = 48;

  /// Stable key from GenerateReport query identity.
  static String buildKey({
    required String rptId,
    required String reportName,
    required String parameters,
  }) {
    final raw =
        '${rptId.trim()}|${reportName.trim().toUpperCase()}|${parameters.trim()}';
    return sha1.convert(utf8.encode(raw)).toString();
  }

  static Future<Directory?> _cacheDirectory() async {
    if (kIsWeb) return null;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$relativeCacheDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File?> getCachedFile(String cacheKey) async {
    if (kIsWeb || cacheKey.isEmpty) return null;
    try {
      final dir = await _cacheDirectory();
      if (dir == null) return null;
      final file = File('${dir.path}/$cacheKey.pdf');
      if (!await file.exists()) return null;

      final age = DateTime.now().difference(await file.lastModified());
      if (age > maxAge) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }

      final length = await file.length();
      if (length < 5) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }

      // Touch for LRU-ish eviction ordering.
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}

      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> getCachedBytes(String cacheKey) async {
    final file = await getCachedFile(cacheKey);
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<File> putBytes({
    required String cacheKey,
    required List<int> bytes,
  }) async {
    final dir = await _cacheDirectory();
    if (dir == null) {
      throw StateError('Report PDF cache is not available on this platform');
    }
    if (!looksLikePdf(bytes)) {
      throw ArgumentError('Refusing to cache non-PDF bytes');
    }

    final file = File('${dir.path}/$cacheKey.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await _evictIfNeeded(dir);
    return file;
  }

  /// Copies an already-cached PDF into [targetFileName] under the same cache
  /// folder when callers need a human-readable path for sharing. Returns the
  /// original cache file if rename is unnecessary.
  static Future<File> ensureShareableCopy({
    required File cachedFile,
    required String displayFileName,
  }) async {
    final safe = _sanitizeFileName(displayFileName);
    final parent = cachedFile.parent;
    final target = File('${parent.path}/$safe');
    if (target.path == cachedFile.path) return cachedFile;
    try {
      if (await target.exists()) {
        await target.delete();
      }
      await cachedFile.copy(target.path);
      return target;
    } catch (_) {
      return cachedFile;
    }
  }

  static Future<int> clearAll() async {
    if (kIsWeb) return 0;
    var deleted = 0;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory('${docs.path}/BTIHReports');
      if (!await root.exists()) return 0;
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            await entity.delete();
            deleted++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return deleted;
  }

  static bool looksLikePdf(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  static Future<void> _evictIfNeeded(Directory dir) async {
    try {
      final files = <File>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          files.add(entity);
        }
      }
      if (files.length <= maxEntries) return;

      files.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );
      final overflow = files.length - maxEntries;
      for (var i = 0; i < overflow; i++) {
        try {
          await files[i].delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static String _sanitizeFileName(String fileName) {
    var clean = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (!clean.toLowerCase().endsWith('.pdf')) {
      clean = '$clean.pdf';
    }
    if (clean.length > 120) {
      clean = '${clean.substring(0, 116)}.pdf';
    }
    return clean;
  }
}
