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
              ?.map((e) => DischargeRecord.fromJson(e))
              .toList() ??
          [],
    );
  }
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

  factory DischargeRecord.fromJson(Map<String, dynamic> json) {
    return DischargeRecord(
      mR_NO: json['mR_NO'] ?? '',
      patienT_VISIT_ID: json['patienT_VISIT_ID'] ?? 0,
      checK_IN: DateTime.tryParse(json['checK_IN'] ?? '') ?? DateTime.now(),
      dR_OUT: DateTime.tryParse(json['dR_OUT'] ?? '') ?? DateTime.now(),
      doctoR_NAME: json['doctoR_NAME'] ?? '',
      admissioN_OFFICER: json['admissioN_OFFICER'] ?? '',
    );
  }

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