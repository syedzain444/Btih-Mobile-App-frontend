import 'dart:convert';

import 'package:btih_andriod_app/models/current_medication_model.dart';
import 'package:btih_andriod_app/models/medication_detail_model.dart';
import 'package:btih_andriod_app/models/refill_request_model.dart';
import 'package:btih_andriod_app/utils/api_response_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';

class MedicationService {
  Future<List<CurrentMedication>> getCurrentMedications(String mrNo) async {
    final response = await ApiConfig.client.get(
      ApiResponseHelper.apiUri(
        '/api/Medications/current/${ApiResponseHelper.encodePathSegment(mrNo)}',
      ),
      headers: {'accept': 'application/json'},
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(CurrentMedication.fromJson)
            .toList();
      }
      return [];
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to load current medications',
    );
  }

  Future<MedicationDetail> getMedicationDetail({
    required String mrNo,
    required int medicationId,
  }) async {
    final response = await ApiConfig.client.get(
      ApiResponseHelper.apiUri(
        '/api/Medications/$medicationId',
        query: {'mrNo': mrNo},
      ),
      headers: {'accept': 'application/json'},
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return MedicationDetail.fromJson(data);
      }
      throw Exception('Medication detail response was invalid');
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to load medication detail',
    );
  }

  Future<RefillRequest> requestRefill({
    required String mrNo,
    required int medicationId,
    int? quantity,
    String? notes,
  }) async {
    final response = await ApiConfig.client.post(
      ApiResponseHelper.apiUri('/api/Medications/refill'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mrNo': mrNo.trim(),
        'medicationId': medicationId,
        if (quantity != null) 'quantity': quantity,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      }),
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return RefillRequest.fromJson(data);
      }
      throw Exception('Refill request response was invalid');
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to submit refill request',
    );
  }

  Future<RefillRequest> getRefillStatus({
    required int refillId,
    required String mrNo,
  }) async {
    final response = await ApiConfig.client.get(
      ApiResponseHelper.apiUri(
        '/api/Medications/refill/$refillId',
        query: {'mrNo': mrNo},
      ),
      headers: {'accept': 'application/json'},
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return RefillRequest.fromJson(data);
      }
      throw Exception('Refill status response was invalid');
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to load refill status',
    );
  }

  Future<List<RefillRequest>> getRefillHistory(String mrNo) async {
    final response = await ApiConfig.client.get(
      ApiResponseHelper.apiUri(
        '/api/Medications/refills/${ApiResponseHelper.encodePathSegment(mrNo)}',
      ),
      headers: {'accept': 'application/json'},
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(RefillRequest.fromJson)
            .toList();
      }
      return [];
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to load refill requests',
    );
  }
}
