class MedicationReminder {
  final int reminderId;
  final String mrNo;
  final int? medicationId;
  final String medicationName;
  final String reminderTime;
  final String daysOfWeek;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MedicationReminder({
    required this.reminderId,
    required this.mrNo,
    this.medicationId,
    required this.medicationName,
    required this.reminderTime,
    required this.daysOfWeek,
    required this.isEnabled,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      reminderId: _asInt(json['reminderId'] ?? json['REMINDER_ID']),
      mrNo: json['mrNo']?.toString() ?? json['MR_NO']?.toString() ?? '',
      medicationId: _nullableInt(json['medicationId'] ?? json['MEDICATION_ID']),
      medicationName:
          json['medicationName']?.toString() ?? json['MEDICATION_NAME']?.toString() ?? '',
      reminderTime:
          json['reminderTime']?.toString() ?? json['REMINDER_TIME']?.toString() ?? '',
      daysOfWeek:
          json['daysOfWeek']?.toString() ?? json['DAYS_OF_WEEK']?.toString() ?? '1234567',
      isEnabled: _asBool(json['isEnabled'] ?? json['IS_ENABLED']),
      createdAt: _parseDate(json['createdAt'] ?? json['CREATED_AT']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['UPDATED_AT']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().toUpperCase() ?? '';
    return text == 'TRUE' || text == 'Y' || text == '1';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Backend uses 1=Mon … 7=Sun in [daysOfWeek] string.
  static String formatDaysLabel(String days) {
    if (days.isEmpty || days == '1234567') return 'Every day';
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selected = <String>[];
    for (var i = 1; i <= 7; i++) {
      if (days.contains('$i')) selected.add(labels[i - 1]);
    }
    return selected.isEmpty ? 'Every day' : selected.join(', ');
  }

  String get formattedTime {
    final parts = reminderTime.split(':');
    if (parts.length < 2) return reminderTime;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String get formattedCreatedDate => _formatDate(createdAt);

  String get formattedUpdatedDate => _formatDate(updatedAt);

  static String _formatDate(DateTime? value) {
    final d = value?.toLocal();
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
