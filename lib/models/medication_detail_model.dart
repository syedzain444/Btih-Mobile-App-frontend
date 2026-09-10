import 'package:btih_andriod_app/models/current_medication_model.dart';

class MedicationDetail extends CurrentMedication {
  final int? ppId;
  final int? medicineId;
  final double? days;
  final double? perDay;
  final double? quantity;
  final String? pharmacyName;
  final int? patientVisitId;

  const MedicationDetail({
    required super.medicationId,
    required super.medicineName,
    super.dosage,
    super.doseWhen,
    super.frequency,
    super.route,
    super.remarks,
    super.doctor,
    super.department,
    super.visitDate,
    this.ppId,
    this.medicineId,
    this.days,
    this.perDay,
    this.quantity,
    this.pharmacyName,
    this.patientVisitId,
  });

  factory MedicationDetail.fromJson(Map<String, dynamic> json) {
    return MedicationDetail(
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
      ppId: _nullableInt(json['ppId'] ?? json['PP_ID']),
      medicineId: _nullableInt(json['medicineId'] ?? json['MEDICINE_ID']),
      days: _nullableDouble(json['days'] ?? json['DAYS']),
      perDay: _nullableDouble(json['perDay'] ?? json['PER_DAY']),
      quantity: _nullableDouble(json['quantity'] ?? json['QUANTITY']),
      pharmacyName: json['pharmacyName']?.toString() ?? json['PHARMACY_NAME']?.toString(),
      patientVisitId: _nullableInt(json['patientVisitId'] ?? json['PATIENT_VISIT_ID']),
    );
  }

  factory MedicationDetail.fromCurrent(CurrentMedication medication) {
    return MedicationDetail(
      medicationId: medication.medicationId,
      medicineName: medication.medicineName,
      dosage: medication.dosage,
      doseWhen: medication.doseWhen,
      frequency: medication.frequency,
      route: medication.route,
      remarks: medication.remarks,
      doctor: medication.doctor,
      department: medication.department,
      visitDate: medication.visitDate,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String get formattedVisitDate {
    if (visitDate == null) return '—';
    final d = visitDate!.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  List<({String label, String value})> get detailRows {
    final rows = <({String label, String value})>[];
    void add(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        rows.add((label: label, value: value.trim()));
      }
    }

    add('Dosage', dosage);
    add('Frequency', frequency);
    add('When to take', doseWhen);
    add('Route', route);
    if (days != null) add('Duration', '${days!.toStringAsFixed(0)} days');
    if (perDay != null) add('Per day', '${perDay!.toStringAsFixed(0)} dose(s)');
    if (quantity != null) add('Quantity', quantity!.toStringAsFixed(0));
    add('Pharmacy', pharmacyName);
    add('Prescribed by', doctor != null ? 'Dr. $doctor' : null);
    add('Department', department);
    add('Visit date', visitDate != null ? formattedVisitDate : null);
    add('Remarks', remarks);
    return rows;
  }
}
