class DashboardHelpers {
  DashboardHelpers._();

  static String timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  static String formatDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Patient';
    return trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String normalizeDoctorName(String raw) {
    var name = raw.trim();
    if (name.isEmpty) return 'Doctor';

    name = name.replaceAll(
      RegExp(r'^(?:(?:dr|prof)\.?\s*)+', caseSensitive: false),
      '',
    );
    name = name.trim();
    if (name.isEmpty) return 'Doctor';
    return 'Dr. $name';
  }

  static String formatAppointmentDate(String raw) {
    if (raw.isEmpty) return 'Date pending';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }

  static String formatAppointmentTime(String raw) {
    if (raw.isEmpty) return 'Time pending';
    try {
      final dt = DateTime.parse(raw);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    } catch (_) {
      return raw;
    }
  }

  /// Splits API schedule text into non-repeating day + time labels.
  static ({String dayLabel, String timeLabel}) parseAppointmentSchedule(
    String raw,
  ) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (dayLabel: 'Date pending', timeLabel: 'Time pending');
    }

    try {
      final dt = DateTime.parse(trimmed);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday',
      ];
      final dayLabel =
          '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return (dayLabel: dayLabel, timeLabel: '$hour:$minute $period');
    } catch (_) {}

    final weekdaySplit = RegExp(r'^([A-Za-z]+)\s*:\s*(.+)$').firstMatch(trimmed);
    if (weekdaySplit != null) {
      final day = weekdaySplit.group(1)!.trim();
      final time = weekdaySplit.group(2)!.trim().replaceAll('-', '–');
      return (dayLabel: day, timeLabel: time);
    }

    if (trimmed.contains('T')) {
      return (
        dayLabel: formatAppointmentDate(trimmed),
        timeLabel: formatAppointmentTime(trimmed),
      );
    }

    return (dayLabel: trimmed, timeLabel: '');
  }

  static String? sanitizeLabel(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final upper = trimmed.toUpperCase();
    if (upper == 'NILL' || upper == 'NIL' || upper == 'NULL') return null;
    return trimmed;
  }

  static String formatActivityTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute $period';

    if (date == today) return 'Today, $time';
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String formatLatestLabel(DateTime? dt) {
    if (dt == null) return 'No recent reports';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'Latest: Today';
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Latest: Yesterday';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Latest: ${dt.day} ${months[dt.month - 1]}';
  }
}
