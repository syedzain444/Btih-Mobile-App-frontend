import 'dart:io';

import 'package:btih_andriod_app/utils/report_download_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadLocationHelper {
  DownloadLocationHelper._();

  static Future<String> openSavedLocation(SavedReportFile savedFile) async {
    if (Platform.isAndroid) {
      final downloadsUri = Uri.parse(
        'content://com.android.externalstorage.documents/document/primary%3ADownload',
      );

      try {
        final launched = await launchUrl(
          downloadsUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return 'Downloads folder opened';
        }
      } catch (_) {}

      final contentUri = savedFile.contentUri;
      if (contentUri != null) {
        try {
          final launched = await launchUrl(
            contentUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            return 'Saved file opened';
          }
        } catch (_) {}
      }
    }

    final filePath = savedFile.filePath;
    if (filePath != null) {
      final folderUri = Uri.file(File(filePath).parent.path);
      try {
        final launched = await launchUrl(
          folderUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return 'Folder opened';
        }
      } catch (_) {}
    }

    return 'Open the ${savedFile.locationLabel} folder from your file manager';
  }
}
