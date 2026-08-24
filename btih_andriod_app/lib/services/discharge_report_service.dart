import 'package:dio/dio.dart';
import '../utils/ip_file.dart';

class DischargeReportService {
  final Dio _dio = Dio();
  
  // rptId = 35 for discharge report
  // param = patientVisitId
  // empId = employee id (you can pass from user session or config)
  
  Future<Response> generateDischargeReport({
    required int patientVisitId,
    required int empId,
    int rptId = 35,
  }) async {
    final String url = "${ApiConfig.baseUrl}/api/PatientReport/DischargeReport?rptId=$rptId&param=$patientVisitId&empId=$empId";
    
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    
    // Validate if response is PDF
    final contentType = response.headers.value("content-type");
    if (contentType == null || !contentType.contains("application/pdf")) {
      throw Exception("Server did not return a valid PDF");
    }
    
    return response;
  }
}