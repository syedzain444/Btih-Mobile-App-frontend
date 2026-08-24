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
      serialNumber: json['serialNumber'],
      specializationId: json['specializationId'],
      specializationName: json['specializationName'],
    );
  }
}