import 'package:btih_andriod_app/models/medication_reminder_model.dart';
import 'package:btih_andriod_app/services/medication_reminder_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class MedicationReminderFormScreen extends StatefulWidget {
  final String mrNo;
  final MedicationReminder? existing;
  final String? initialMedicationName;
  final int? initialMedicationId;

  const MedicationReminderFormScreen({
    super.key,
    required this.mrNo,
    this.existing,
    this.initialMedicationName,
    this.initialMedicationId,
  });

  bool get isEditing => existing != null;

  @override
  State<MedicationReminderFormScreen> createState() =>
      _MedicationReminderFormScreenState();
}

class _MedicationReminderFormScreenState
    extends State<MedicationReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _service = MedicationReminderService();

  late TimeOfDay _selectedTime;
  late Set<int> _selectedDays;
  bool _isEnabled = true;
  bool _isSaving = false;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.medicationName;
      _isEnabled = existing.isEnabled;
      _selectedDays = _parseDays(existing.daysOfWeek);
      _selectedTime = _parseTime(existing.reminderTime);
    } else {
      _nameController.text = widget.initialMedicationName ?? '';
      _selectedDays = {1, 2, 3, 4, 5, 6, 7};
      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Set<int> _parseDays(String days) {
    final selected = <int>{};
    for (var i = 1; i <= 7; i++) {
      if (days.contains('$i')) selected.add(i);
    }
    return selected.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : selected;
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryRed,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.darkText,
            ),
          ),
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

    setState(() => _isSaving = true);
    try {
      final time = _formatTimeForApi(_selectedTime);
      final days = _encodeDays(_selectedDays);

      if (widget.isEditing) {
        await _service.updateReminder(
          reminderId: widget.existing!.reminderId,
          mrNo: widget.mrNo,
          medicationName: _nameController.text.trim(),
          reminderTime: time,
          daysOfWeek: days,
          isEnabled: _isEnabled,
        );
      } else {
        await _service.createReminder(
          mrNo: widget.mrNo,
          medicationName: _nameController.text.trim(),
          reminderTime: time,
          medicationId: widget.initialMedicationId,
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
        content: const Text('This medication reminder will be removed permanently.'),
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

    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppAppBar(
        title: Text(
          widget.isEditing ? 'Edit Reminder' : 'Add Reminder',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Medication name',
                    style: _labelStyle(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    style: AppTypography.roboto(
                      fontSize: 15,
                      color: AppColors.darkText,
                    ),
                    decoration: _inputDecoration('e.g. Paracetamol 500mg'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Medication name is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Reminder time', style: _labelStyle()),
                  const SizedBox(height: 10),
                  TapFeedback(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.fieldBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.medsTealBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              color: AppColors.medsTeal,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            timeLabel,
                            style: AppTypography.raleway(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepRed,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.greyText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Repeat on', style: _labelStyle())),
                      TapFeedback(
                        onTap: () => setState(() {
                          _selectedDays = {1, 2, 3, 4, 5, 6, 7};
                        }),
                        child: Text(
                          'Every day',
                          style: AppTypography.raleway(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.medsTeal
                                : AppColors.fieldFill,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppColors.medsTeal
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
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable reminder', style: _labelStyle()),
                        const SizedBox(height: 4),
                        Text(
                          'Receive push notifications at the scheduled time',
                          style: AppTypography.roboto(
                            fontSize: 12,
                            color: AppColors.greyText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isEnabled,
                    activeTrackColor: AppColors.primaryRed.withValues(alpha: 0.45),
                    activeThumbColor: AppColors.primaryRed,
                    onChanged: (value) => setState(() => _isEnabled = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: widget.isEditing ? 'Save changes' : 'Create reminder',
              loading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving ? null : _delete,
                child: Text(
                  'Delete reminder',
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  TextStyle _labelStyle() {
    return AppTypography.raleway(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.deepRed,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.roboto(
        color: AppColors.greyText,
        fontSize: 14,
      ),
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
