import 'dart:typed_data';
import 'dart:io';

import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/download_location_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/utils/report_download_helper.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Appointment confirmation PDF (details + check-in QR) — REQ-2026-014 / TC-014.
class AppointmentConfirmationPdfService {
  AppointmentConfirmationPdfService._();

  static String pdfUrl(String appointmentId) {
    final encoded = Uri.encodeComponent(appointmentId.trim());
    return '${ApiConfig.baseUrl}/api/AppointmentConfirmation/$encoded/pdf';
  }

  static String _formatFetchError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final body = error.response?.data;
      if (body is List<int> && body.isNotEmpty) {
        try {
          final text = String.fromCharCodes(body).trim();
          if (text.isNotEmpty) return text;
        } catch (_) {}
      } else if (body is String && body.trim().isNotEmpty) {
        return body.trim();
      }
      if (status == 404) {
        return 'Confirmation PDF is not available for this appointment.';
      }
      if (status != null) {
        return 'Could not load confirmation PDF (HTTP $status).';
      }
    }
    return error.toString();
  }

  static Future<List<int>> fetchPdfBytes(String appointmentId) async {
    final id = appointmentId.trim();
    if (id.isEmpty) {
      throw Exception('Appointment ID is missing for confirmation PDF.');
    }

    final dio = ApiConfig.createDio();
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 20);

    final response = await dio.get<List<int>>(
      pdfUrl(id),
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 200 &&
        response.data != null &&
        response.data!.isNotEmpty) {
      final contentType = response.headers.value('content-type');
      if (contentType != null && !contentType.contains('application/pdf')) {
        throw Exception('Server did not return a PDF.');
      }
      return response.data!;
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: 'Failed to download confirmation PDF',
    );
  }

  static Widget _loadingDialog({required String title}) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title)),
        ],
      ),
    );
  }

  static Future<void> viewPdf(
    BuildContext context, {
    required String appointmentId,
    String title = 'Appointment Confirmation',
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _loadingDialog(title: 'Opening confirmation'),
    );

    try {
      final bytes = await fetchPdfBytes(appointmentId);
      if (!context.mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.white,
            appBar: AppBar(
              title: Text(
                title,
                style: AppTypography.raleway(
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.deepRed,
              foregroundColor: AppColors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: ColoredBox(
              color: AppColors.white,
              child: SfPdfViewerTheme(
                data: const SfPdfViewerThemeData(
                  backgroundColor: AppColors.white,
                ),
                child: SfPdfViewer.memory(Uint8List.fromList(bytes)),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        CustomMessageDialog.showError(
          context,
          'Could not open confirmation PDF.\n\n${_formatFetchError(e)}',
        );
      }
    }
  }

  static Future<SavedReportFile?> downloadToDevice(
    BuildContext context, {
    required String appointmentId,
    String? fileName,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _loadingDialog(title: 'Downloading confirmation'),
    );

    try {
      final bytes = await fetchPdfBytes(appointmentId);
      if (!context.mounted) return null;
      if (Navigator.canPop(context)) Navigator.pop(context);

      if (kIsWeb) {
        if (context.mounted) {
          CustomMessageDialog.showError(
            context,
            'Download is available on the mobile app. Use View to open the PDF.',
          );
        }
        return null;
      }

      final savedFile = await ReportDownloadHelper.savePdfBytes(
        bytes: bytes,
        fileName: fileName ?? 'Appointment_$appointmentId.pdf',
      );

      if (context.mounted) {
        await CustomMessageDialog.showDownloadComplete(
          context,
          fileName: savedFile.fileName,
          locationLabel: savedFile.locationLabel,
          onOpenLocation: () =>
              DownloadLocationHelper.openSavedLocation(savedFile),
        );
      }
      return savedFile;
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        CustomMessageDialog.showError(
          context,
          'Download failed. Please try again.\n\n${_formatFetchError(e)}',
        );
      }
      return null;
    }
  }

  static Future<void> sharePdf(
    BuildContext context, {
    required String appointmentId,
    String? fileName,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _loadingDialog(title: 'Preparing to share'),
    );

    try {
      final bytes = await fetchPdfBytes(appointmentId);
      if (!context.mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      if (kIsWeb) {
        if (context.mounted) {
          CustomMessageDialog.showError(
            context,
            'Share is available on the mobile app.',
          );
        }
        return;
      }

      final cleanName = (fileName ?? 'Appointment_$appointmentId.pdf')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf', name: cleanName)],
        subject: 'Appointment Confirmation',
        text:
            'Bahria Town International Hospital — appointment confirmation PDF.',
      );
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        CustomMessageDialog.showError(
          context,
          'Share failed. Please try again.\n\n${_formatFetchError(e)}',
        );
      }
    }
  }
}
