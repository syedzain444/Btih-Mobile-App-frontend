class DischargeHistoryResponse {
  final int pageNumber;
  final int pageSize;
  final int totalRecords;
  final List<DischargeRecord> data;

  DischargeHistoryResponse({
    required this.pageNumber,
    required this.pageSize,
    required this.totalRecords,
    required this.data,
  });

  factory DischargeHistoryResponse.fromJson(Map<String, dynamic> json) {
    return DischargeHistoryResponse(
      pageNumber: json['pageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      totalRecords: json['totalRecords'] ?? 0,
      data: (json['data'] as List?)
              ?.map((e) => DischargeRecord.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [],
    );
  }

  int get totalPages {
    if (pageSize <= 0 || totalRecords <= 0) return 0;
    return (totalRecords / pageSize).ceil();
  }

  bool get hasNextPage => pageNumber < totalPages;
  bool get hasPreviousPage => pageNumber > 1;
}

class DischargeRecord {
  final String mR_NO;
  final int patienT_VISIT_ID;
  final DateTime checK_IN;
  final DateTime dR_OUT;
  final String doctoR_NAME;
  final String admissioN_OFFICER;

  DischargeRecord({
    required this.mR_NO,
    required this.patienT_VISIT_ID,
    required this.checK_IN,
    required this.dR_OUT,
    required this.doctoR_NAME,
    required this.admissioN_OFFICER,
  });

  static dynamic _pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) return json[key];
    }
    // Case-insensitive fallback for quirky serializer names.
    final lower = {for (final e in json.entries) e.key.toLowerCase(): e.value};
    for (final key in keys) {
      final value = lower[key.toLowerCase()];
      if (value != null) return value;
    }
    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _asDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  factory DischargeRecord.fromJson(Map<String, dynamic> json) {
    return DischargeRecord(
      mR_NO: _pick(json, ['mR_NO', 'mrNo', 'MR_NO', 'mr_no'])?.toString() ?? '',
      patienT_VISIT_ID: _asInt(_pick(json, [
        'patienT_VISIT_ID',
        'patientVisitId',
        'PATIENT_VISIT_ID',
        'patient_visit_id',
      ])),
      checK_IN: _asDate(_pick(json, [
        'checK_IN',
        'checkIn',
        'CHECK_IN',
        'check_in',
      ])),
      dR_OUT: _asDate(_pick(json, [
        'dR_OUT',
        'drOut',
        'DR_OUT',
        'dischargeDate',
        'dr_out',
      ])),
      doctoR_NAME: _pick(json, [
            'doctoR_NAME',
            'doctorName',
            'DOCTOR_NAME',
            'doctor_name',
          ])
              ?.toString() ??
          '',
      admissioN_OFFICER: _pick(json, [
            'admissioN_OFFICER',
            'admissionOfficer',
            'ADMISSION_OFFICER',
            'admission_officer',
          ])
              ?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'mR_NO': mR_NO,
        'patienT_VISIT_ID': patienT_VISIT_ID,
        'checK_IN': checK_IN.toIso8601String(),
        'dR_OUT': dR_OUT.toIso8601String(),
        'doctoR_NAME': doctoR_NAME,
        'admissioN_OFFICER': admissioN_OFFICER,
        // Stable camelCase aliases for recent-activity / future clients.
        'mrNo': mR_NO,
        'patientVisitId': patienT_VISIT_ID,
        'checkIn': checK_IN.toIso8601String(),
        'dischargeDate': dR_OUT.toIso8601String(),
        'doctorName': doctoR_NAME,
        'admissionOfficer': admissioN_OFFICER,
      };

  // Helper properties for UI
  String get formattedCheckInDate {
    return '${checK_IN.day}/${checK_IN.month}/${checK_IN.year}';
  }

  String get formattedCheckInTime {
    final hour = checK_IN.hour > 12 ? checK_IN.hour - 12 : checK_IN.hour;
    final minute = checK_IN.minute.toString().padLeft(2, '0');
    final period = checK_IN.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  String get formattedDischargeDate {
    return '${dR_OUT.day}/${dR_OUT.month}/${dR_OUT.year}';
  }

  String get formattedDischargeTime {
    final hour = dR_OUT.hour > 12 ? dR_OUT.hour - 12 : dR_OUT.hour;
    final minute = dR_OUT.minute.toString().padLeft(2, '0');
    final period = dR_OUT.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  String get stayDuration {
    final difference = dR_OUT.difference(checK_IN);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return "$days day(s), $hours hour(s)";
    } else if (hours > 0) {
      return "$hours hour(s), $minutes min(s)";
    } else {
      return "$minutes minute(s)";
    }
  }
}
