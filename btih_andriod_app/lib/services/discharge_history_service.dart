import 'package:dio/dio.dart';
import '../models/discharge_history_model.dart';
import '../utils/ip_file.dart';

class DischargeHistoryService {
  final Dio _dio = Dio();
  
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
      } else {
        throw Exception("Failed to load discharge history: ${response.statusCode}");
      }
    } on DioException catch (e) {
      throw Exception("Network error: ${e.message}");
    } catch (e) {
      throw Exception("Unexpected error: $e");
    }
  }
}