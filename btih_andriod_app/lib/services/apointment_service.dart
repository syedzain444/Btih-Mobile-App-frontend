// import 'package:flutter/material.dart';

// class Appointment {
//   final String? id; // from backend
//   final String doctorId;
//   final DateTime date;
//   final String time;
//   final String userId;
// final String status;
//   Appointment({
//     this.id,
//     required this.doctorId,
//     required this.date,
//     required this.time,
//     required this.userId,
//         required this.status,

//   });

//   Map<String, dynamic> toJson() => {
//         'doctorId': doctorId,
//         'date': date.toIso8601String(),
//         'time': time,
//         'userId': userId,
//       };

//   factory Appointment.fromJson(Map<String, dynamic> json) {
//     return Appointment(
//       id: json['id'],
//       doctorId: json['doctorId'],
//       date: DateTime.parse(json['date']),
//       time: json['time'],
//       userId: json['userId'],
//       status: json['status'],
//     );
//   }
// }


class Appointment {
  final String? appointmentId; // Changed from id to appointmentId
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

  Appointment({
    this.appointmentId,
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
  });

  Map<String, dynamic> toJson() => {
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
  };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      appointmentId: json['appointmentId']?.toString(),
      name: json['name'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      mrNo: json['mrNo'] ?? '',
      email: json['email'] ?? '',
      weekId: json['weekId'] ?? 0,
      appointmentTime: json['appointmentTime'] ?? '',
      status: json['status'] ?? '',
      doctorName: json['doctorName'] ?? '',
      purpose: json['purpose'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}