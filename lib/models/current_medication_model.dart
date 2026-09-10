class CurrentMedication {
  final int medicationId;
  final String medicineName;
  final String? dosage;
  final String? doseWhen;
  final String? frequency;
  final String? route;
  final String? remarks;
  final String? doctor;
  final String? department;
  final DateTime? visitDate;

  const CurrentMedication({
    required this.medicationId,
    required this.medicineName,
    this.dosage,
    this.doseWhen,
    this.frequency,
    this.route,
    this.remarks,
    this.doctor,
    this.department,
    this.visitDate,
  });

  factory CurrentMedication.fromJson(Map<String, dynamic> json) {
    return CurrentMedication(
      medicationId: _asInt(json['medicationId'] ?? json['MEDICATION_ID']),
      medicineName:
          json['medicineName']?.toString() ?? json['MEDICINE_NAME']?.toString() ?? 'Medication',
      dosage: json['dosage']?.toString() ?? json['DOSAGE']?.toString(),
      doseWhen: json['doseWhen']?.toString() ?? json['DOSE_WHEN']?.toString(),
      frequency: json['frequency']?.toString() ?? json['FREQUENCY']?.toString(),
      route: json['route']?.toString() ?? json['ROUTE']?.toString(),
      remarks: json['remarks']?.toString() ?? json['REMARKS']?.toString(),
      doctor: json['doctor']?.toString() ?? json['DOCTOR']?.toString(),
      department: json['department']?.toString() ?? json['DEPARTMENT']?.toString(),
      visitDate: _parseDate(json['visitDate'] ?? json['VISIT_DATE']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String get subtitle {
    final parts = <String>[
      if (dosage != null && dosage!.trim().isNotEmpty) dosage!.trim(),
      if (frequency != null && frequency!.trim().isNotEmpty) frequency!.trim(),
      if (doseWhen != null && doseWhen!.trim().isNotEmpty) doseWhen!.trim(),
    ];
    return parts.isEmpty ? 'Active prescription' : parts.join(' · ');
  }
}
