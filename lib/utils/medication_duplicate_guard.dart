import 'package:btih_andriod_app/models/current_medication_model.dart';
import 'package:btih_andriod_app/models/medication_reminder_model.dart';
import 'package:btih_andriod_app/models/refill_request_model.dart';

/// Client-side deduplication and duplicate-action guards for medications UI.
class MedicationDuplicateGuard {
  MedicationDuplicateGuard._();

  static const _activeRefillStatuses = {
    'PENDING',
    'IN_PROGRESS',
    'PROCESSING',
  };

  static List<CurrentMedication> dedupeMedications(List<CurrentMedication> items) {
    final seen = <int>{};
    final unique = <CurrentMedication>[];
    for (final item in items) {
      if (item.medicationId <= 0) continue;
      if (seen.add(item.medicationId)) unique.add(item);
    }
    return unique;
  }

  static List<MedicationReminder> dedupeReminders(
    List<MedicationReminder> items,
  ) {
    final seen = <int>{};
    final unique = <MedicationReminder>[];
    for (final item in items) {
      if (item.reminderId <= 0) continue;
      if (seen.add(item.reminderId)) unique.add(item);
    }
    return unique;
  }

  static List<RefillRequest> dedupeRefills(List<RefillRequest> items) {
    final seen = <int>{};
    final unique = <RefillRequest>[];
    for (final item in items) {
      if (item.refillId <= 0) continue;
      if (seen.add(item.refillId)) unique.add(item);
    }
    return unique;
  }

  /// One reminder per prescribed medication — different meds may share time/schedule.
  static bool hasReminderForMedication({
    required List<MedicationReminder> existing,
    required CurrentMedication medication,
    int? excludeReminderId,
  }) {
    for (final reminder in existing) {
      if (excludeReminderId != null &&
          reminder.reminderId == excludeReminderId) {
        continue;
      }

      if (reminder.medicationId != null &&
          reminder.medicationId == medication.medicationId) {
        return true;
      }

      if (reminder.medicationName.trim().toLowerCase() ==
          medication.medicineName.trim().toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  static MedicationReminder? findReminderForMedication({
    required List<MedicationReminder> existing,
    required CurrentMedication medication,
  }) {
    for (final reminder in existing) {
      if (reminder.medicationId != null &&
          reminder.medicationId == medication.medicationId) {
        return reminder;
      }
      if (reminder.medicationName.trim().toLowerCase() ==
          medication.medicineName.trim().toLowerCase()) {
        return reminder;
      }
    }
    return null;
  }

  static List<CurrentMedication> medicationsWithoutReminders({
    required List<CurrentMedication> medications,
    required List<MedicationReminder> reminders,
  }) {
    return medications
        .where(
          (medication) => !hasReminderForMedication(
            existing: reminders,
            medication: medication,
          ),
        )
        .toList();
  }

  static RefillRequest? activeRefillForMedication(
    List<RefillRequest> refills,
    int medicationId,
  ) {
    for (final refill in refills) {
      if (refill.medicationId != medicationId) continue;
      if (_activeRefillStatuses.contains(refill.status.toUpperCase())) {
        return refill;
      }
    }
    return null;
  }

}
