import 'package:dio/dio.dart';
import '../utils/ip_file.dart';

class DischargeReportService {
  final Dio _dio = ApiConfig.createDio();

  Future<Response> generateDischargeReport({
    required int patientVisitId,
    int empId = 0,
    int rptId = 35,
  }) async {
    final String url =
        "${ApiConfig.baseUrl}/api/PatientReport/DischargeReport?rptId=$rptId&param=$patientVisitId&empId=$empId";

    // Keep aligned with clinical report SLA (REQ-2026-020).
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 12);
    _dio.options.sendTimeout = const Duration(seconds: 5);

    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final contentType = response.headers.value("content-type");
      final data = response.data;
      final looksLikePdf = data is List<int> &&
          data.length >= 4 &&
          data[0] == 0x25 &&
          data[1] == 0x50 &&
          data[2] == 0x44 &&
          data[3] == 0x46;

      if (!looksLikePdf &&
          (contentType == null || !contentType.contains("application/pdf"))) {
        throw Exception("Server did not return a valid PDF");
      }

      return response;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception(
          'Report is taking too long on the hospital network. '
          'Please try again in a moment.',
        );
      }
      rethrow;
    }
  }
}
