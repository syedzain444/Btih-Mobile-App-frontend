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
      serialNumber: _readInt(json, ['serialNumber', 'SerialNumber']) ?? 0,
      id: _readInt(json, ['doctor_ID', 'doctorId', 'Doctor_ID', 'DoctorId']) ?? 0,
      doctorName: _readString(json, ['doctorName', 'DoctorName']) ?? '',
      departmentId:
          _readInt(json, ['department_ID', 'departmentId', 'Department_ID']) ??
              0,
      doctorDescription:
          _readString(json, ['doctorDescription', 'DoctorDescription']) ?? '',
      specializationName:
          _readString(json, ['specializationName', 'SpecializationName']) ?? '',
      doctorImagePath:
          _readString(json, ['doctorImagePath', 'DoctorImagePath']),
    );
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    final value = _readDynamic(json, keys);
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    final value = _readDynamic(json, keys);
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static dynamic _readDynamic(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key];
      }
    }
    return null;
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
    final rawData = json['data'] ?? json['Data'];
    final rawPagination = json['pagination'] ?? json['Pagination'];

    final data = rawData is List
        ? rawData.map((e) => Doctor.fromJson(e as Map<String, dynamic>)).toList()
        : <Doctor>[];

    final pagination = rawPagination is Map<String, dynamic>
        ? Pagination.fromJson(rawPagination)
        : Pagination.empty();

    return DoctorResponse(data: data, pagination: pagination);
  }

  factory DoctorResponse.empty({int pageNumber = 1, int pageSize = 10}) {
    return DoctorResponse(
      data: const <Doctor>[],
      pagination: Pagination(
        pageNumber: pageNumber,
        pageSize: pageSize,
        totalRecords: 0,
        totalPages: 0,
      ),
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
      pageNumber:
          json['pageNumber'] ?? json['PageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? json['PageSize'] ?? 10,
      totalRecords:
          json['totalRecords'] ?? json['TotalRecords'] ?? 0,
      totalPages: json['totalPages'] ?? json['TotalPages'] ?? 0,
    );
  }

  factory Pagination.empty() {
    return Pagination(
      pageNumber: 1,
      pageSize: 10,
      totalRecords: 0,
      totalPages: 0,
    );
  }
}