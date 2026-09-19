import 'dart:typed_data';

import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/download_location_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/utils/report_download_helper.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class BillingPdfService {
  BillingPdfService._();

  /// HMIS invoice/receipt template used for department bills.
  static const _billReportName = 'Advance_Reciept';

  static String pdfUrl({required int rptId, required String billId}) {
    return _generateReportsUrl(rptId: rptId, billId: billId);
  }

  static String _generateReportsUrl({
    required int rptId,
    required String billId,
  }) {
    final encodedBillId = Uri.encodeQueryComponent(billId);
    return '${ApiConfig.baseUrl}/api/PatientReport/GenerateReports?rptId=$rptId&param=$encodedBillId';
  }

  static String _generateReportUrl({
    required int rptId,
    required String billId,
  }) {
    final encodedBillId = Uri.encodeQueryComponent(billId);
    return '${ApiConfig.baseUrl}/api/PatientReport/GenerateReport'
        '?rptId=$rptId'
        '&reportName=$_billReportName'
        '&parameters=$encodedBillId'
        '&user=MobileApp';
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
        return 'Bill PDF is not available on the hospital server (HTTP 404). '
            'The report template or bill configuration may be missing on the server.';
      }
      if (status != null) {
        return 'Could not load bill PDF (HTTP $status).';
      }
    }
    return error.toString();
  }

  static Future<List<int>> fetchPdfBytes({
    required int rptId,
    required String billId,
  }) async {
    if (billId.trim().isEmpty) {
      throw Exception('Bill ID is missing for this record.');
    }

    final dio = ApiConfig.createDio();
    dio.options.connectTimeout = const Duration(seconds: 8);
    dio.options.receiveTimeout = const Duration(seconds: 12);

    final urls = <String>[
      _generateReportsUrl(rptId: rptId, billId: billId),
      _generateReportUrl(rptId: rptId, billId: billId),
    ];

    Object? lastError;

    for (final url in urls) {
      try {
        final response = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode == 404) {
          lastError = DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            message: 'HTTP 404',
          );
          continue;
        }

        if (response.statusCode != 200) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            message: 'HTTP ${response.statusCode}',
          );
        }

        final contentType = response.headers.value('content-type');
        if (contentType == null || !contentType.contains('application/pdf')) {
          throw Exception('Server did not return a valid PDF');
        }

        return response.data ?? const <int>[];
      } catch (e) {
        lastError = e;
        if (e is DioException && e.response?.statusCode == 404) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(_formatFetchError(lastError ?? 'Bill PDF not found'));
  }

  static Widget _loadingDialog({required String title}) {
    return Dialog(
      elevation: 0,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.softRed,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: AppColors.primaryRed,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait…',
              style: AppTypography.roboto(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> viewInApp(
    BuildContext context, {
    required int rptId,
    required String billId,
    required String title,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _loadingDialog(title: title),
    );

    try {
      final bytes = await fetchPdfBytes(rptId: rptId, billId: billId);
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!context.mounted) return;

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
              child: SfPdfViewer.memory(Uint8List.fromList(bytes)),
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
          'Could not open report.\n\n${_formatFetchError(e)}',
        );
      }
    }
  }

  static Future<void> downloadToDevice(
    BuildContext context, {
    required int rptId,
    required String billId,
    required String fileName,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _loadingDialog(title: 'Downloading bill'),
    );

    try {
      final bytes = await fetchPdfBytes(rptId: rptId, billId: billId);

      if (!context.mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (kIsWeb) {
        if (context.mounted) {
          CustomMessageDialog.showError(
            context,
            'Download to device is available on the mobile app. Use View to open the PDF in the browser.',
          );
        }
        return;
      }

      final savedFile = await ReportDownloadHelper.savePdfBytes(
        bytes: bytes,
        fileName: fileName,
      );

      if (!context.mounted) return;
      await CustomMessageDialog.showDownloadComplete(
        context,
        fileName: savedFile.fileName,
        locationLabel: savedFile.locationLabel,
        onOpenLocation: () => DownloadLocationHelper.openSavedLocation(savedFile),
      );
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
    }
  }
}
