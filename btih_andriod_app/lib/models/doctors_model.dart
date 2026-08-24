class Doctor {
  final int serialNumber;
  final int id;
  final String doctorName;
  final int departmentId;
  final String doctorDescription;
  final String specializationName;
  final String? doctorImagePath;   // 👈 Add this

  Doctor({
    required this.serialNumber,
    required this.id,
    required this.doctorName,
    required this.departmentId,
    required this.doctorDescription,
    required this.specializationName,
    this.doctorImagePath,

  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      serialNumber: json['serialNumber'],
      id: json['doctor_ID'],
      doctorName: json['doctorName'],
      departmentId: json['department_ID'],
      doctorDescription: json['doctorDescription'],
      specializationName: json['specializationName'],
      doctorImagePath: json['doctorImagePath'],  // 👈 Add this

    );
  }
}


// doctors_model.dart - Add this new class for paginated response

class DoctorResponse {
  final List<Doctor> data;
  final Pagination pagination;

  DoctorResponse({
    required this.data,
    required this.pagination,
  });

  factory DoctorResponse.fromJson(Map<String, dynamic> json) {
    return DoctorResponse(
      data: (json['data'] as List)
          .map((e) => Doctor.fromJson(e))
          .toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}

class Pagination {
  final int pageNumber;
  final int pageSize;
  final int totalRecords;
  final int totalPages;

  Pagination({
    required this.pageNumber,
    required this.pageSize,
    required this.totalRecords,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      pageNumber: json['pageNumber'],
      pageSize: json['pageSize'],
      totalRecords: json['totalRecords'],
      totalPages: json['totalPages'],
    );
  }
}