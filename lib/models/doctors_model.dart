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

  factory Doctor.minimal({
    required int id,
    required String doctorName,
    required int departmentId,
    String specializationName = '',
    String doctorDescription = '',
    String? doctorImagePath,
  }) {
    return Doctor(
      serialNumber: 0,
      id: id,
      doctorName: doctorName,
      departmentId: departmentId,
      doctorDescription: doctorDescription,
      specializationName: specializationName,
      doctorImagePath: doctorImagePath,
    );
  }

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

    final data = <Doctor>[];
    if (rawData is List) {
      for (final entry in rawData) {
        if (entry is! Map) continue;
        try {
          data.add(Doctor.fromJson(Map<String, dynamic>.from(entry)));
        } catch (_) {
          // Skip malformed doctor rows instead of crashing the list.
        }
      }
    }

    final pagination = rawPagination is Map
        ? Pagination.fromJson(Map<String, dynamic>.from(rawPagination))
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
      pageNumber: _asInt(json['pageNumber'] ?? json['PageNumber']) ?? 1,
      pageSize: _asInt(json['pageSize'] ?? json['PageSize']) ?? 10,
      totalRecords: _asInt(json['totalRecords'] ?? json['TotalRecords']) ?? 0,
      totalPages: _asInt(json['totalPages'] ?? json['TotalPages']) ?? 0,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
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