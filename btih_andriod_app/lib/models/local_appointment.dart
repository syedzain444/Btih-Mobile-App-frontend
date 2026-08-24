// lib/models/local_appointment.dart
class LocalAppointment {
  final int? id;
  final String appointmentId;
  final String name;
  final String phoneNo;
  final String mrNo;
  final String email;
  final int weekId;
  final String appointmentTime;
  final String status;
  final String doctorName;
  final String purpose;
  final String createdAt;
  final int doctorId;
  final int departmentId;
  final bool isGuestAppointment;

  LocalAppointment({
    this.id,
    required this.appointmentId,
    required this.name,
    required this.phoneNo,
    required this.mrNo,
    required this.email,
    required this.weekId,
    required this.appointmentTime,
    required this.status,
    required this.doctorName,
    required this.purpose,
    required this.createdAt,
    required this.doctorId,
    required this.departmentId,
    required this.isGuestAppointment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'name': name,
      'phoneNo': phoneNo,
      'mrNo': mrNo,
      'email': email,
      'weekId': weekId,
      'appointmentTime': appointmentTime,
      'status': status,
      'doctorName': doctorName,
      'purpose': purpose,
      'createdAt': createdAt,
      'doctorId': doctorId,
      'departmentId': departmentId,
      'isGuestAppointment': isGuestAppointment ? 1 : 0,
    };
  }

  factory LocalAppointment.fromMap(Map<String, dynamic> map) {
    return LocalAppointment(
      id: map['id'],
      appointmentId: map['appointmentId'],
      name: map['name'],
      phoneNo: map['phoneNo'],
      mrNo: map['mrNo'],
      email: map['email'],
      weekId: map['weekId'],
      appointmentTime: map['appointmentTime'],
      status: map['status'],
      doctorName: map['doctorName'],
      purpose: map['purpose'],
      createdAt: map['createdAt'],
      doctorId: map['doctorId'],
      departmentId: map['departmentId'],
      isGuestAppointment: map['isGuestAppointment'] == 1,
    );
  }
}