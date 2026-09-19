import 'package:dio/dio.dart';
import '../models/discharge_history_model.dart';
import '../utils/ip_file.dart';

class DischargeHistoryService {
  final Dio _dio = ApiConfig.createDio();
  
  Future<DischargeHistoryResponse> getDischargeHistory({
    required String mrNo,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    try {
      final String url = "${ApiConfig.baseUrl}/api/Patient/dischargeHistory/$mrNo?pageNumber=$pageNumber&pageSize=$pageSize";
      
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        return DischargeHistoryResponse.fromJson(response.data);
      }
      if (response.statusCode == 404) {
        return DischargeHistoryResponse(
          pageNumber: pageNumber,
          pageSize: pageSize,
          totalRecords: 0,
          data: const [],
        );
      }
      throw Exception("Failed to load discharge history: ${response.statusCode}");
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return DischargeHistoryResponse(
          pageNumber: pageNumber,
          pageSize: pageSize,
          totalRecords: 0,
          data: const [],
        );
      }
      throw Exception("Network error: ${e.message}");
    } catch (e) {
      throw Exception("Unexpected error: $e");
    }
  }
}