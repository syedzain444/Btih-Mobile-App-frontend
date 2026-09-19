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
  final String? profileImageUrl;

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
    this.profileImageUrl,
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
      profileImageUrl: json['profileImageUrl']?.toString() ??
          json['ProfileImageUrl']?.toString(),
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
      isDischarged: json['isDischarged'] == true ||
          json['isDischarged']?.toString() == '1' ||
          json['isDischarged']?.toString().toLowerCase() == 'true',
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

  /// OPD visits are excluded from patient visit history in the app.
  bool get isOpdVisit {
    final raw = department.trim().toUpperCase();
    if (raw.isEmpty) return false;
    return raw == 'OPD' ||
        raw.contains('OPD') ||
        raw.contains('OUT PATIENT') ||
        raw.contains('OUTPATIENT');
  }
}

class PatientApiResponse {
  final PatientProfileData? profile;
  final List<PatientVisit> visitHistory;

  PatientApiResponse({
    required this.profile,
    required this.visitHistory,
  });

  /// OPD visits are never surfaced in the app's patient history.
  static List<PatientVisit> _withoutOpd(List<PatientVisit> visits) =>
      visits.where((v) => !v.isOpdVisit).toList();

  static List<PatientVisit> _parseVisitList(dynamic visitsJson) {
    if (visitsJson is List) {
      return visitsJson
          .whereType<Map>()
          .map((e) => PatientVisit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    // Paged shape from API: { pageNumber, pageSize, totalRecords, data: [...] }
    if (visitsJson is Map) {
      final map = Map<String, dynamic>.from(visitsJson);
      final data = map['data'] ?? map['Data'] ?? map['items'] ?? map['Items'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => PatientVisit.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return const <PatientVisit>[];
  }

  static PatientApiResponse fromDynamic(dynamic body) {
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map.containsKey('visitHistory') || map.containsKey('profile')) {
        final profileJson = map['profile'];
        final visits = _parseVisitList(map['visitHistory']);

        return PatientApiResponse(
          profile: profileJson is Map
              ? PatientProfileData.fromJson(
                  Map<String, dynamic>.from(profileJson),
                )
              : null,
          visitHistory: _withoutOpd(visits),
        );
      }
    }

    if (body is List && body.isNotEmpty) {
      final visits = _withoutOpd(
        body
            .whereType<Map>()
            .map((e) => PatientVisit.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
      if (visits.isEmpty) {
        return PatientApiResponse(profile: null, visitHistory: []);
      }
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
  final String? profileImageUrl;

  PatientInfo({
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.cnic,
    required this.contactNo,
    required this.bloodGroup,
    required this.email,
    this.profileImageUrl,
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
      profileImageUrl: profile.profileImageUrl,
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
