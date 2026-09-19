class DoctorSchedule {
  final int serialNumber;
  final int doctorId;
  final String doctorName;
  final String dayName;
  final DateTime timeFrom;
  final DateTime timeTo;
  final int weekId;
  final int opD_Charges;

  DoctorSchedule({
    required this.serialNumber,
    required this.doctorId,
    required this.doctorName,
    required this.dayName,
    required this.timeFrom,
    required this.timeTo,
    required this.weekId,
    required this.opD_Charges,
  });

  factory DoctorSchedule.fromJson(Map<String, dynamic> json) {
    final timeFrom = _readDateTime(json, ['timeFrom', 'TimeFrom']);
    final timeTo = _readDateTime(json, ['timeTo', 'TimeTo']);

    return DoctorSchedule(
      serialNumber: _readInt(json, ['serialNumber', 'SerialNumber']) ?? 0,
      doctorId:
          _readInt(json, ['doctor_ID', 'doctorId', 'Doctor_ID', 'DoctorId']) ??
              0,
      doctorName: _readString(json, ['doctorName', 'DoctorName']) ?? '',
      dayName: _readString(json, ['dayName', 'DayName']) ?? '',
      timeFrom: timeFrom ?? DateTime.fromMillisecondsSinceEpoch(0),
      timeTo: timeTo ?? DateTime.fromMillisecondsSinceEpoch(0),
      weekId: _readInt(json, ['week_ID', 'weekId', 'Week_ID', 'WeekId']) ?? 0,
      opD_Charges: _readInt(json, [
            'opD_Charges',
            'opd_Charges',
            'OPD_Charges',
            'opdCharges',
          ]) ??
          0,
    );
  }

  bool get hasValidTimes =>
      timeFrom.millisecondsSinceEpoch > 0 && timeTo.millisecondsSinceEpoch > 0;

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

  static DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    final value = _readDynamic(json, keys);
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
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

