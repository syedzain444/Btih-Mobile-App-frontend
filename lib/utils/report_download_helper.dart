import 'dart:io';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

class SavedReportFile {
  final String fileName;
  final String locationLabel;
  final String? filePath;
  final Uri? contentUri;

  const SavedReportFile({
    required this.fileName,
    required this.locationLabel,
    this.filePath,
    this.contentUri,
  });
}

class ReportDownloadHelper {
  ReportDownloadHelper._();

  static Future<SavedReportFile> savePdfBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    final cleanFileName = _sanitizeFileName(fileName);

    if (Platform.isAndroid) {
      return _saveToPublicDownloads(bytes, cleanFileName);
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final filePath = await _writeUniqueFile(
      directory: documentsDir,
      fileName: cleanFileName,
      bytes: bytes,
    );

    return SavedReportFile(
      fileName: filePath.split(Platform.pathSeparator).last,
      locationLabel: 'Documents',
      filePath: filePath,
    );
  }

  static Future<SavedReportFile> _saveToPublicDownloads(
    List<int> bytes,
    String fileName,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    SavedReportFile? savedFile;
    try {
      final mediaStore = MediaStore();
      final saveInfo = await mediaStore.saveFile(
        tempFilePath: tempPath,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: FilePath.root,
      );

      if (saveInfo != null && saveInfo.name.isNotEmpty) {
        savedFile = SavedReportFile(
          fileName: saveInfo.name,
          locationLabel: 'Downloads',
          contentUri: saveInfo.uri,
        );
      }
    } catch (_) {
      // Fall back to a direct write below.
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }

    return savedFile ?? _saveViaLegacyDownloadsFolder(bytes, fileName);
  }

  static Future<SavedReportFile> _saveViaLegacyDownloadsFolder(
    List<int> bytes,
    String fileName,
  ) async {
    const downloadsPath = '/storage/emulated/0/Download';
    final dir = Directory(downloadsPath);
    if (!await dir.exists()) {
      throw Exception('Could not save the report to Downloads');
    }

    final filePath = await _writeUniqueFile(
      directory: dir,
      fileName: fileName,
      bytes: bytes,
    );

    return SavedReportFile(
      fileName: filePath.split(Platform.pathSeparator).last,
      locationLabel: 'Downloads',
      filePath: filePath,
    );
  }

  static Future<String> _writeUniqueFile({
    required Directory directory,
    required String fileName,
    required List<int> bytes,
  }) async {
    var targetPath = '${directory.path}${Platform.pathSeparator}$fileName';
    var file = File(targetPath);

    if (await file.exists()) {
      final dotIndex = fileName.lastIndexOf('.');
      final baseName =
          dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
      final extension = dotIndex == -1 ? '' : fileName.substring(dotIndex);
      var counter = 1;

      do {
        final nextName = '${baseName}_$counter$extension';
        targetPath = '${directory.path}${Platform.pathSeparator}$nextName';
        file = File(targetPath);
        counter++;
      } while (await file.exists());
    }

    await file.writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  static String _ensurePdfExtension(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
  }

  static String _sanitizeFileName(String fileName) {
    var clean = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (clean.length > 120) {
      const ext = '.pdf';
      clean = '${clean.substring(0, 120 - ext.length)}$ext';
    }
    return _ensurePdfExtension(clean);
  }
}
