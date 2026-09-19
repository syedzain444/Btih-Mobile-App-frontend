import 'package:btih_andriod_app/models/current_medication_model.dart';
import 'package:btih_andriod_app/models/medication_detail_model.dart';
import 'package:btih_andriod_app/models/medication_reminder_model.dart';
import 'package:btih_andriod_app/models/refill_request_model.dart';
import 'package:btih_andriod_app/services/medication_reminder_service.dart';
import 'package:btih_andriod_app/services/medication_service.dart';
import 'package:btih_andriod_app/utils/medication_duplicate_guard.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom sheets for medications — matches appointments modal pattern.
class MedicationSheets {
  MedicationSheets._();

  /// Maroon-themed time picker — AM/PM selector uses primary red tones.
  static ThemeData timePickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryRed,
        onPrimary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.darkText,
        tertiary: AppColors.rustRed,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.white,
        hourMinuteTextColor: AppColors.deepRed,
        hourMinuteColor: AppColors.softRed,
        dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.white;
          }
          return AppColors.deepRed;
        }),
        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryRed;
          }
          return AppColors.softRed;
        }),
        dialHandColor: AppColors.primaryRed,
        dialBackgroundColor: AppColors.blush,
        entryModeIconColor: AppColors.primaryRed,
        helpTextStyle: AppTypography.raleway(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.deepRed,
        ),
      ),
    );
  }

  static Future<bool?> showPrescriptionDetail({
    required BuildContext context,
    required String mrNo,
    required CurrentMedication medication,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PrescriptionDetailSheet(
        mrNo: mrNo,
        medication: medication,
      ),
    );
  }

  static Future<CurrentMedication?> showMedicationPicker({
    required BuildContext context,
    required List<CurrentMedication> medications,
  }) {
    return showModalBottomSheet<CurrentMedication>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MedicationPickerSheet(medications: medications),
    );
  }

  static Future<bool?> showReminderForm({
    required BuildContext context,
    required String mrNo,
    required List<MedicationReminder> existingReminders,
    MedicationReminder? existing,
    CurrentMedication? medication,
  }) {
    if (existing == null && medication == null) {
      return Future.value(null);
    }

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReminderFormSheet(
        mrNo: mrNo,
        existingReminders: existingReminders,
        existing: existing,
        medication: medication,
      ),
    );
  }

  static Future<bool?> showRefillRequest({
    required BuildContext context,
    required String mrNo,
    required CurrentMedication medication,
    required List<RefillRequest> existingRefills,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RefillRequestSheet(
        mrNo: mrNo,
        medication: medication,
        existingRefills: existingRefills,
      ),
    );
  }

  static Future<RefillRequest?> showRefillStatus({
    required BuildContext context,
    required String mrNo,
    required RefillRequest refill,
  }) {
    return showModalBottomSheet<RefillRequest>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _RefillStatusSheet(
        mrNo: mrNo,
        refill: refill,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PrescriptionDetailSheet extends StatefulWidget {
  const _PrescriptionDetailSheet({
    required this.mrNo,
    required this.medication,
  });

  final String mrNo;
  final CurrentMedication medication;

  @override
  State<_PrescriptionDetailSheet> createState() =>
      _PrescriptionDetailSheetState();
}

class _PrescriptionDetailSheetState extends State<_PrescriptionDetailSheet> {
  final _service = MedicationService();
  MedicationDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _service.getMedicationDetail(
        mrNo: widget.mrNo,
        medicationId: widget.medication.medicationId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final rows = detail?.detailRows ??
        [
          if (widget.medication.dosage != null)
            (label: 'Dosage', value: widget.medication.dosage!),
          if (widget.medication.frequency != null)
            (label: 'Frequency', value: widget.medication.frequency!),
          if (widget.medication.doctor != null)
            (label: 'Prescribed by', value: 'Dr. ${widget.medication.doctor}'),
        ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.softRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medication_outlined,
                      color: AppColors.primaryRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.medication.medicineName,
                      style: AppTypography.raleway(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepRed,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: AppColors.greyText,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Prescription details',
                style: AppTypography.raleway(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRed,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryRed,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: AppTypography.roboto(
                                fontSize: 13,
                                color: AppColors.greyText,
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            children: rows
                                .map(
                                  (row) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 108,
                                          child: Text(
                                            row.label,
                                            style: AppTypography.roboto(
                                              fontSize: 13,
                                              color: AppColors.greyText,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            row.value,
                                            style: AppTypography.roboto(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.darkText,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MedicationPickerSheet extends StatelessWidget {
  const _MedicationPickerSheet({required this.medications});

  final List<CurrentMedication> medications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          Text(
            'Choose a medication',
            style: AppTypography.raleway(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select from your current prescriptions',
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.greyText,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: medications.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.hairline,
              ),
              itemBuilder: (context, index) {
                final medication = medications[index];
                return TapFeedback(
                  onTap: () => Navigator.pop(context, medication),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.softRed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.medication_outlined,
                            size: 18,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medication.medicineName,
                                style: AppTypography.raleway(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepRed,
                                ),
                              ),
                              if (medication.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  medication.subtitle,
                                  style: AppTypography.roboto(
                                    fontSize: 12,
                                    color: AppColors.greyText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.greyText.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _RepeatPreset { everyDay, weekdays, weekends, custom }

class _ReminderFormSheet extends StatefulWidget {
  const _ReminderFormSheet({
    required this.mrNo,
    required this.existingReminders,
    this.existing,
    this.medication,
  });

  final String mrNo;
  final List<MedicationReminder> existingReminders;
  final MedicationReminder? existing;
  final CurrentMedication? medication;

  bool get isEditing => existing != null;

  String get medicationName =>
      medication?.medicineName ?? existing?.medicationName ?? 'Medication';

  int? get medicationId => medication?.medicationId ?? existing?.medicationId;

  @override
  State<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends State<_ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _service = MedicationReminderService();

  late TimeOfDay _selectedTime;
  late Set<int> _selectedDays;
  _RepeatPreset _preset = _RepeatPreset.everyDay;
  bool _isEnabled = true;
  bool _isSaving = false;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _isEnabled = existing.isEnabled;
      _selectedDays = _parseDays(existing.daysOfWeek);
      _selectedTime = _parseTime(existing.reminderTime);
      _preset = _detectPreset(_selectedDays);
    } else {
      _selectedDays = {1, 2, 3, 4, 5, 6, 7};
      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
      _preset = _RepeatPreset.everyDay;
    }
  }

  Set<int> _parseDays(String days) {
    final selected = <int>{};
    for (var i = 1; i <= 7; i++) {
      if (days.contains('$i')) selected.add(i);
    }
    return selected.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : selected;
  }

  _RepeatPreset _detectPreset(Set<int> days) {
    if (days.length == 7) return _RepeatPreset.everyDay;
    if (days.containsAll({1, 2, 3, 4, 5}) && days.length == 5) {
      return _RepeatPreset.weekdays;
    }
    if (days.containsAll({6, 7}) && days.length == 2) {
      return _RepeatPreset.weekends;
    }
    return _RepeatPreset.custom;
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  String _formatTimeForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _encodeDays(Set<int> days) {
    final sorted = days.toList()..sort();
    return sorted.join();
  }

  void _applyPreset(_RepeatPreset preset) {
    setState(() {
      _preset = preset;
      switch (preset) {
        case _RepeatPreset.everyDay:
          _selectedDays = {1, 2, 3, 4, 5, 6, 7};
        case _RepeatPreset.weekdays:
          _selectedDays = {1, 2, 3, 4, 5};
        case _RepeatPreset.weekends:
          _selectedDays = {6, 7};
        case _RepeatPreset.custom:
          break;
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: MedicationSheets.timePickerTheme(context),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      CustomMessageDialog.showError(context, 'Select at least one day');
      return;
    }

    final time = _formatTimeForApi(_selectedTime);
    final days = _encodeDays(_selectedDays);
    final medicationName = widget.medicationName;

    if (!widget.isEditing && widget.medication != null) {
      if (MedicationDuplicateGuard.hasReminderForMedication(
        existing: widget.existingReminders,
        medication: widget.medication!,
      )) {
        CustomMessageDialog.showError(
          context,
          'A reminder is already set for $medicationName. Edit it from the Reminders tab.',
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      if (widget.isEditing) {
        await _service.updateReminder(
          reminderId: widget.existing!.reminderId,
          mrNo: widget.mrNo,
          medicationName: medicationName,
          reminderTime: time,
          daysOfWeek: days,
          isEnabled: _isEnabled,
        );
      } else {
        await _service.createReminder(
          mrNo: widget.mrNo,
          medicationName: medicationName,
          reminderTime: time,
          medicationId: widget.medicationId,
          daysOfWeek: days,
          isEnabled: _isEnabled,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: const Text('This reminder will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await _service.deleteReminder(
        reminderId: widget.existing!.reminderId,
        mrNo: widget.mrNo,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _selectedTime.hour >= 12 ? 'PM' : 'AM';
    final displayHour =
        _selectedTime.hour % 12 == 0 ? 12 : _selectedTime.hour % 12;
    final timeLabel =
        '${displayHour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} $period';

    final title = widget.isEditing ? 'Edit reminder' : 'Set reminder';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              Text(
                title,
                style: AppTypography.raleway(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRed,
                ),
              ),
              const SizedBox(height: 16),
              Text('Prescribed medication', style: _labelStyle()),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.medication_outlined,
                      size: 20,
                      color: AppColors.primaryRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.medicationName,
                        style: AppTypography.raleway(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Reminder time', style: _labelStyle()),
              const SizedBox(height: 8),
              TapFeedback(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: AppColors.primaryRed,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeLabel,
                        style: AppTypography.raleway(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepRed,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.greyText,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Repeat on', style: _labelStyle()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip('Every day', _RepeatPreset.everyDay),
                  _presetChip('Weekdays', _RepeatPreset.weekdays),
                  _presetChip('Weekends', _RepeatPreset.weekends),
                  _presetChip('Pick days', _RepeatPreset.custom),
                ],
              ),
              if (_preset == _RepeatPreset.custom) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    final selected = _selectedDays.contains(day);
                    return TapFeedback(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                          _preset = _RepeatPreset.custom;
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.deepRed
                              : AppColors.fieldFill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.deepRed
                                : AppColors.fieldBorder,
                          ),
                        ),
                        child: Text(
                          _dayLabels[index],
                          style: AppTypography.raleway(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.white
                                : AppColors.greyText,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable reminder', style: _labelStyle()),
                        Text(
                          'Push notification at scheduled time',
                          style: AppTypography.roboto(
                            fontSize: 12,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isEnabled,
                    activeTrackColor:
                        AppColors.primaryRed.withValues(alpha: 0.45),
                    activeThumbColor: AppColors.primaryRed,
                    onChanged: (value) => setState(() => _isEnabled = value),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: widget.isEditing ? 'Save changes' : 'Save reminder',
                loading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(
                    'Delete reminder',
                    style: AppTypography.raleway(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    side: const BorderSide(color: AppColors.primaryRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label, _RepeatPreset preset) {
    final selected = _preset == preset;
    return TapFeedback(
      onTap: () => _applyPreset(preset),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.deepRed : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.deepRed : AppColors.fieldBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.raleway(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.greyText,
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() {
    return AppTypography.raleway(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.deepRed,
    );
  }
}

class _RefillRequestSheet extends StatefulWidget {
  const _RefillRequestSheet({
    required this.mrNo,
    required this.medication,
    required this.existingRefills,
  });

  final String mrNo;
  final CurrentMedication medication;
  final List<RefillRequest> existingRefills;

  @override
  State<_RefillRequestSheet> createState() => _RefillRequestSheetState();
}

class _RefillRequestSheetState extends State<_RefillRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _service = MedicationService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final activeRefill = MedicationDuplicateGuard.activeRefillForMedication(
      widget.existingRefills,
      widget.medication.medicationId,
    );
    if (activeRefill != null) {
      CustomMessageDialog.showError(
        context,
        'A refill request for ${widget.medication.medicineName} is already '
        '${activeRefill.displayStatus.toLowerCase()}. Check Recent requests for updates.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final quantityText = _quantityController.text.trim();
      await _service.requestRefill(
        mrNo: widget.mrNo,
        medicationId: widget.medication.medicationId,
        quantity: quantityText.isEmpty ? null : int.tryParse(quantityText),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              'Request refill',
              style: AppTypography.raleway(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.medication_outlined,
                    size: 20,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.medication.medicineName,
                      style: AppTypography.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Quantity (optional)',
              style: AppTypography.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('e.g. 30'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Notes (optional)',
              style: AppTypography.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: _inputDecoration('Instructions for pharmacy...'),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Submit request',
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.roboto(color: AppColors.greyText, fontSize: 14),
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4),
      ),
    );
  }
}

class _RefillStatusSheet extends StatefulWidget {
  const _RefillStatusSheet({
    required this.mrNo,
    required this.refill,
  });

  final String mrNo;
  final RefillRequest refill;

  @override
  State<_RefillStatusSheet> createState() => _RefillStatusSheetState();
}

class _RefillStatusSheetState extends State<_RefillStatusSheet> {
  final _service = MedicationService();
  RefillRequest? _refill;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refill = widget.refill;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final refill = await _service.getRefillStatus(
        refillId: widget.refill.refillId,
        mrNo: widget.mrNo,
      );
      if (!mounted) return;
      setState(() {
        _refill = refill;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'COMPLETED':
        return AppColors.medsTeal;
      case 'REJECTED':
      case 'DECLINED':
        return AppColors.primaryRed;
      default:
        return AppColors.rustRed;
    }
  }

  void _closeSheet() {
    Navigator.pop(context, _refill ?? widget.refill);
  }

  @override
  Widget build(BuildContext context) {
    final refill = _refill ?? widget.refill;
    final statusColor = _statusColor(refill.status);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeSheet();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    refill.medicationName ?? 'Refill request',
                  style: AppTypography.raleway(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryRed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              refill.displayStatus,
              style: AppTypography.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _statusRow('Requested', refill.formattedCreatedDate),
          _statusRow('Last updated', refill.formattedUpdatedDate),
          if (refill.ppId != null) _statusRow('Prescription ID', '${refill.ppId}'),
          if (refill.patientVisitId != null)
            _statusRow('Visit ID', '${refill.patientVisitId}'),
          if (refill.quantity != null)
            _statusRow('Quantity', '${refill.quantity}'),
          if (refill.notes != null && refill.notes!.trim().isNotEmpty)
            _statusRow('Notes', refill.notes!.trim()),
          if (refill.statusMessage != null &&
              refill.statusMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              refill.statusMessage!.trim(),
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
                height: 1.4,
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
