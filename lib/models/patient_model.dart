// lib/models/patient_model.dart

class PatientProfileData {
  final String mrNo;
  final String firstName;
  final String lastName;
  final String gender;
  final String dateOfBirth;
  final String cnic;
  final String contactNo;
  final String bloodGroup;
  final String emailAddress;

  PatientProfileData({
    required this.mrNo,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.cnic,
    required this.contactNo,
    required this.bloodGroup,
    required this.emailAddress,
  });

  factory PatientProfileData.fromJson(Map<String, dynamic> json) {
    return PatientProfileData(
      mrNo: json['mrNo']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      dateOfBirth: json['dateOfBirth']?.toString() ?? '',
      cnic: json['cnic']?.toString() ??
          json['CNIC']?.toString() ??
          json['cNIC']?.toString() ??
          '',
      contactNo: json['contactNo']?.toString() ?? '',
      bloodGroup: json['bloodGroup']?.toString() ?? '',
      emailAddress: json['emailAddress']?.toString() ?? '',
    );
  }
}

class PatientVisit {
  final int serialNumber;
  final int patientVisitId;
  final String visitDate;
  final String checkIn;
  final String? dischargeDate;
  final int doctorId;
  final String doctorName;
  final String department;
  final String admissionOfficer;
  final String? admissionNo;
  final String? disease;
  final String? presentingComplaints;
  final bool isDischarged;
  final int? dischargeId;

  // Legacy profile fields (old flat-list API)
  final String firstName;
  final String lastName;
  final String gender;
  final String dateOfBirth;
  final String cnic;
  final String contactNo;
  final String bloodGroup;
  final String email;

  PatientVisit({
    required this.serialNumber,
    this.patientVisitId = 0,
    required this.visitDate,
    this.checkIn = '',
    this.dischargeDate,
    this.doctorId = 0,
    required this.doctorName,
    this.department = '',
    this.admissionOfficer = '',
    this.admissionNo,
    this.disease,
    this.presentingComplaints,
    this.isDischarged = false,
    this.dischargeId,
    this.firstName = '',
    this.lastName = '',
    this.gender = '',
    this.dateOfBirth = '',
    this.cnic = '',
    this.contactNo = '',
    this.bloodGroup = '',
    this.email = '',
  });

  factory PatientVisit.fromJson(Map<String, dynamic> json) {
    return PatientVisit(
      serialNumber: json['serialNumber'] is int
          ? json['serialNumber'] as int
          : int.tryParse(json['serialNumber']?.toString() ?? '') ?? 0,
      patientVisitId: json['patientVisitId'] is int
          ? json['patientVisitId'] as int
          : int.tryParse(json['patientVisitId']?.toString() ?? '') ?? 0,
      visitDate: json['visitDate']?.toString() ?? '',
      checkIn: json['checkIn']?.toString() ?? '',
      dischargeDate: json['dischargeDate']?.toString(),
      doctorId: json['doctorId'] is int
          ? json['doctorId'] as int
          : int.tryParse(json['doctorId']?.toString() ?? '') ?? 0,
      doctorName: (json['doctorName']?.toString() ?? '').trim(),
      department: (json['department']?.toString() ?? '').trim(),
      admissionOfficer: (json['admissionOfficer']?.toString() ?? '').trim(),
      admissionNo: json['admissionNo']?.toString(),
      disease: json['disease']?.toString(),
      presentingComplaints: json['presentingComplaints']?.toString(),
      isDischarged: json['isDischarged'] == true,
      dischargeId: json['dischargeId'] is int
          ? json['dischargeId'] as int
          : int.tryParse(json['dischargeId']?.toString() ?? ''),
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      dateOfBirth: json['dateOfBirth']?.toString() ?? '',
      cnic: json['cnic']?.toString() ??
          json['CNIC']?.toString() ??
          json['cNIC']?.toString() ??
          '',
      contactNo: json['contactNo']?.toString() ?? '',
      bloodGroup: json['bloodGroup']?.toString() ?? '',
      email: json['emailAddress']?.toString() ?? '',
    );
  }

  String get displayDoctor {
    if (doctorName.isNotEmpty) return doctorName;
    if (admissionOfficer.isNotEmpty) return admissionOfficer;
    return 'Doctor not assigned';
  }

  String get displayDepartment {
    if (department.isNotEmpty) return department;
    return 'General';
  }
}

class PatientApiResponse {
  final PatientProfileData? profile;
  final List<PatientVisit> visitHistory;

  PatientApiResponse({
    required this.profile,
    required this.visitHistory,
  });

  static PatientApiResponse fromDynamic(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('visitHistory') || body.containsKey('profile')) {
        final profileJson = body['profile'];
        final visitsJson = body['visitHistory'];

        return PatientApiResponse(
          profile: profileJson is Map<String, dynamic>
              ? PatientProfileData.fromJson(profileJson)
              : null,
          visitHistory: visitsJson is List
              ? visitsJson
                  .map((e) => PatientVisit.fromJson(e as Map<String, dynamic>))
                  .toList()
              : [],
        );
      }
    }

    if (body is List && body.isNotEmpty) {
      final visits = body
          .map((e) => PatientVisit.fromJson(e as Map<String, dynamic>))
          .toList();
      final first = visits.first;
      return PatientApiResponse(
        profile: PatientProfileData(
          mrNo: '',
          firstName: first.firstName,
          lastName: first.lastName,
          gender: first.gender,
          dateOfBirth: first.dateOfBirth,
          cnic: first.cnic,
          contactNo: first.contactNo,
          bloodGroup: first.bloodGroup,
          emailAddress: first.email,
        ),
        visitHistory: visits,
      );
    }

    return PatientApiResponse(profile: null, visitHistory: []);
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

  factory PatientInfo.fromProfile(PatientProfileData profile) {
    return PatientInfo(
      firstName: profile.firstName,
      lastName: profile.lastName,
      gender: profile.gender,
      dateOfBirth: profile.dateOfBirth,
      cnic: profile.cnic,
      contactNo: profile.contactNo,
      bloodGroup: profile.bloodGroup,
      email: profile.emailAddress,
    );
  }

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
