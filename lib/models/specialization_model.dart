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
      serialNumber: _readInt(json, ['serialNumber', 'SerialNumber']) ?? 0,
      specializationId: _readInt(json, [
            'specializationId',
            'SpecializationId',
            'specialization_ID',
            'Specialization_ID',
          ]) ??
          0,
      specializationName: _readString(json, [
            'specializationName',
            'SpecializationName',
            'specialization_NAME',
          ]) ??
          '',
    );
  }

  /// Case-insensitive match that never throws on odd Unicode / empty input.
  bool matchesQuery(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return true;
    return _normalize(specializationName).contains(needle);
  }

  static String _normalize(String value) {
    try {
      return value.trim().toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    final value = _readDynamic(json, keys);
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    final value = _readDynamic(json, keys);
    if (value == null) return null;
    final text = value.toString().trim();
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
