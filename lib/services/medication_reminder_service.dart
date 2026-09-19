import 'dart:convert';

import 'package:btih_andriod_app/models/medication_reminder_model.dart';
import 'package:btih_andriod_app/utils/api_response_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';

class MedicationReminderService {
  Future<List<MedicationReminder>> getReminders(String mrNo) async {
    final response = await ApiConfig.client.get(
      ApiResponseHelper.apiUri(
        '/api/MedicationReminders/${ApiResponseHelper.encodePathSegment(mrNo)}',
      ),
      headers: {'accept': 'application/json'},
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(MedicationReminder.fromJson)
            .toList();
      }
      return [];
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to load medication reminders',
    );
  }

  Future<MedicationReminder> createReminder({
    required String mrNo,
    required String medicationName,
    required String reminderTime,
    int? medicationId,
    String daysOfWeek = '1234567',
    bool isEnabled = true,
  }) async {
    final response = await ApiConfig.client.post(
      ApiResponseHelper.apiUri('/api/MedicationReminders'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mrNo': mrNo.trim(),
        'medicationName': medicationName.trim(),
        'reminderTime': reminderTime,
        if (medicationId != null) 'medicationId': medicationId,
        'daysOfWeek': daysOfWeek,
        'isEnabled': isEnabled,
      }),
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return MedicationReminder.fromJson(data);
      }
      throw Exception('Reminder created but response was invalid');
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to create reminder',
    );
  }

  Future<MedicationReminder> updateReminder({
    required int reminderId,
    required String mrNo,
    String? medicationName,
    String? reminderTime,
    String? daysOfWeek,
    bool? isEnabled,
  }) async {
    final response = await ApiConfig.client.put(
      ApiResponseHelper.apiUri('/api/MedicationReminders/$reminderId'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mrNo': mrNo.trim(),
        if (medicationName != null) 'medicationName': medicationName.trim(),
        if (reminderTime != null) 'reminderTime': reminderTime,
        if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
        if (isEnabled != null) 'isEnabled': isEnabled,
      }),
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return MedicationReminder.fromJson(data);
      }
      throw Exception('Reminder updated but response was invalid');
    }

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to update reminder',
    );
  }

  Future<void> deleteReminder({
    required int reminderId,
    required String mrNo,
  }) async {
    final response = await ApiConfig.client.delete(
      ApiResponseHelper.apiUri(
        '/api/MedicationReminders/$reminderId',
        query: {'mrNo': mrNo},
      ),
      headers: {'accept': 'application/json'},
    );

    final decoded = ApiResponseHelper.decodeBody(response.body);
    if (response.statusCode == 200) return;

    ApiResponseHelper.throwFromResponse(
      response.statusCode,
      decoded,
      'Failed to delete reminder',
    );
  }
}
