// lib/models/specialization_model.dart
class Specialization {
  final int serialNumber;
  final int specializationId;
  final String specializationName;

  Specialization({
    required this.serialNumber,
    required this.specializationId,
    required this.specializationName,
  });

  factory Specialization.fromJson(Map<String, dynamic> json) {
    return Specialization(
      serialNumber:
          json['serialNumber'] ?? json['SerialNumber'] ?? 0,
      specializationId: json['specializationId'] ??
          json['SpecializationId'] ??
          json['specialization_ID'] ??
          0,
      specializationName: json['specializationName'] ??
          json['SpecializationName'] ??
          '',
    );
  }
}