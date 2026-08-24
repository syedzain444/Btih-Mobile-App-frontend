// lib/utils/date_formatter.dart

class DateFormatter {
  static String formatDate(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Not available';
    try {
      DateTime date = DateTime.parse(dateTimeString);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (e) {
      return dateTimeString;
    }
  }

  static String formatDisplayDate(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Not available';
    try {
      DateTime date = DateTime.parse(dateTimeString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateTimeString;
    }
  }
}