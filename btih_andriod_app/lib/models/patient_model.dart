// lib/models/patient_model.dart

class PatientVisit {
  final int serialNumber;
  final String firstName;
  final String lastName;
  final String gender;
  final String visitDate;
  final String dateOfBirth;
  final String cnic;
  final String contactNo;
  final String bloodGroup;
  final String email;
  final String doctorName;

  PatientVisit({
    required this.serialNumber,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.visitDate,
    required this.dateOfBirth,
    required this.cnic,
    required this.contactNo,
    required this.bloodGroup,
    required this.email,
    required this.doctorName,

  });

  factory PatientVisit.fromJson(Map<String, dynamic> json) {
    return PatientVisit(
      serialNumber: json['serialNumber'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? '',
      visitDate: json['visitDate'] ?? '',
      dateOfBirth: json['dateOfBirth'] ?? '',
      cnic: json['cnic'] ?? '',
      contactNo: json['contactNo'] ?? '',
      bloodGroup: json['bloodGroup'] ?? '',
      email: json['emailAddress'] ?? '',
      doctorName: json['doctorName'] ?? '',

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serialNumber': serialNumber,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'visitDate': visitDate,
      'dateOfBirth': dateOfBirth,
      'cnic': cnic,
      'contactNo': contactNo,
      'bloodGroup': bloodGroup,
      'emailAddress': email,
      'doctorName': doctorName,

    };
  }
}

class PatientInfo {
  final String firstName;
  final String lastName;
  final String gender;
  final String dateOfBirth;
  final String cnic;
  final String contactNo;
  final String bloodGroup;
  final String email;

  PatientInfo({
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.cnic,
    required this.contactNo,
    required this.bloodGroup,
    required this.email,

  });

  factory PatientInfo.fromPatientVisit(PatientVisit visit) {
    return PatientInfo(
      firstName: visit.firstName,
      lastName: visit.lastName,
      gender: visit.gender,
      dateOfBirth: visit.dateOfBirth,
      cnic: visit.cnic,
      contactNo: visit.contactNo,
      bloodGroup: visit.bloodGroup,
      email: visit.email,
    );
  }
}