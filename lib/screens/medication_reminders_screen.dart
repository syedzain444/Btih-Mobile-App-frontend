import 'package:btih_andriod_app/models/current_medication_model.dart';
import 'package:btih_andriod_app/models/medication_reminder_model.dart';
import 'package:btih_andriod_app/models/refill_request_model.dart';
import 'package:btih_andriod_app/screens/medication_detail_screen.dart';
import 'package:btih_andriod_app/screens/medication_refill_detail_screen.dart';
import 'package:btih_andriod_app/screens/medication_reminder_form_screen.dart';
import 'package:btih_andriod_app/services/medication_reminder_service.dart';
import 'package:btih_andriod_app/services/medication_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class MedicationRemindersScreen extends StatefulWidget {
  final String patientMrNo;

  const MedicationRemindersScreen({
    super.key,
    required this.patientMrNo,
  });

  @override
  State<MedicationRemindersScreen> createState() =>
      _MedicationRemindersScreenState();
}

class _MedicationRemindersScreenState extends State<MedicationRemindersScreen> {
  final _medicationService = MedicationService();
  final _reminderService = MedicationReminderService();

  int _selectedTab = 0;
  bool _isLoading = true;
  String? _error;

  List<CurrentMedication> _medications = [];
  List<MedicationReminder> _reminders = [];
  List<RefillRequest> _refills = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _medicationService.getCurrentMedications(widget.patientMrNo),
        _reminderService.getReminders(widget.patientMrNo),
        _medicationService.getRefillHistory(widget.patientMrNo),
      ]);

      if (!mounted) return;
      setState(() {
        _medications = results[0] as List<CurrentMedication>;
        _reminders = results[1] as List<MedicationReminder>;
        _refills = results[2] as List<RefillRequest>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({
    MedicationReminder? existing,
    CurrentMedication? medication,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationReminderFormScreen(
          mrNo: widget.patientMrNo,
          existing: existing,
          initialMedicationName: medication?.medicineName,
          initialMedicationId:
              medication != null && medication.medicationId > 0
                  ? medication.medicationId
                  : null,
        ),
      ),
    );

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _toggleReminder(MedicationReminder reminder, bool enabled) async {
    try {
      await _reminderService.updateReminder(
        reminderId: reminder.reminderId,
        mrNo: widget.patientMrNo,
        isEnabled: enabled,
      );
      if (!mounted) return;
      setState(() {
        _reminders = _reminders
            .map(
              (item) => item.reminderId == reminder.reminderId
                  ? MedicationReminder(
                      reminderId: item.reminderId,
                      mrNo: item.mrNo,
                      medicationId: item.medicationId,
                      medicationName: item.medicationName,
                      reminderTime: item.reminderTime,
                      daysOfWeek: item.daysOfWeek,
                      isEnabled: enabled,
                      createdAt: item.createdAt,
                      updatedAt: item.updatedAt,
                    )
                  : item,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _openMedicationDetail(CurrentMedication medication) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationDetailScreen(
          mrNo: widget.patientMrNo,
          medicationId: medication.medicationId,
          fallbackName: medication.medicineName,
        ),
      ),
    );

    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _openRefillDetail(RefillRequest refill) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationRefillDetailScreen(
          mrNo: widget.patientMrNo,
          refillId: refill.refillId,
          initialRefill: refill,
        ),
      ),
    );
    await _loadData();
  }

  bool _hasReminderForMedication(CurrentMedication medication) {
    return _reminders.any(
      (reminder) =>
          reminder.medicationId == medication.medicationId ||
          reminder.medicationName.toLowerCase() ==
              medication.medicineName.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppAppBar(
        title: Text(
          'My Medications',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selectedTab == 1)
            TapFeedback(
              onTap: () => _openForm(),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: AppBarIconBadge(icon: Icons.add_rounded),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.medsTeal,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add_alarm_rounded),
              label: Text(
                'Add reminder',
                style: AppTypography.raleway(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : _error != null
              ? _buildErrorState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildIntroBanner(),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTabSwitcher(),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildTabContent()),
                  ],
                ),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.medsTeal.withValues(alpha: 0.08),
            AppColors.medsTealBg.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.medsTeal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage your medications',
                  style: AppTypography.raleway(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.medsTeal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View prescriptions, set reminders, and request refills.',
                  style: AppTypography.roboto(
                    fontSize: 13,
                    color: AppColors.greyText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          _buildTabButton(
            label: 'Meds (${_medications.length})',
            selected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          _buildTabButton(
            label: 'Reminders (${_reminders.length})',
            selected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          _buildTabButton(
            label: 'Refills (${_refills.length})',
            selected: _selectedTab == 2,
            onTap: () => setState(() => _selectedTab = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? AppColors.medsTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.raleway(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.white : AppColors.greyText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildMedicationsList();
      case 1:
        return _buildRemindersList();
      case 2:
        return _buildRefillsList();
      default:
        return _buildMedicationsList();
    }
  }

  Widget _buildMedicationsList() {
    if (_medications.isEmpty) {
      return _emptyState(
        icon: Icons.medication_liquid_outlined,
        title: 'No current medications',
        subtitle: 'Your active prescriptions will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: _medications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final medication = _medications[index];
          final hasReminder = _hasReminderForMedication(medication);
          return _medicationCard(medication, hasReminder);
        },
      ),
    );
  }

  Widget _medicationCard(CurrentMedication medication, bool hasReminder) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TapFeedback(
            onTap: () => _openMedicationDetail(medication),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.medsTealBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: AppColors.medsTeal,
                    size: 22,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medication.subtitle,
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: AppColors.greyText,
                          height: 1.35,
                        ),
                      ),
                      if (medication.doctor != null &&
                          medication.doctor!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Dr. ${medication.doctor}',
                          style: AppTypography.roboto(
                            fontSize: 12,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.greyText,
                  size: 22,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (hasReminder)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.medsTealBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        size: 14,
                        color: AppColors.medsTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reminder set',
                        style: AppTypography.raleway(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.medsTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              TapFeedback(
                onTap: () => _openForm(medication: medication),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: hasReminder
                        ? AppColors.fieldFill
                        : AppColors.medsTeal,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasReminder
                          ? AppColors.fieldBorder
                          : AppColors.medsTeal,
                    ),
                  ),
                  child: Text(
                    hasReminder ? 'Add another' : 'Set reminder',
                    style: AppTypography.raleway(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasReminder
                          ? AppColors.deepRed
                          : AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefillsList() {
    if (_refills.isEmpty) {
      return _emptyState(
        icon: Icons.replay_outlined,
        title: 'No refill requests',
        subtitle:
            'Open a medication and tap “Request refill” to submit a request.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: _refills.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _refillCard(_refills[index]),
      ),
    );
  }

  Widget _refillCard(RefillRequest refill) {
    Color statusColor;
    Color statusBg;
    switch (refill.status.toUpperCase()) {
      case 'APPROVED':
      case 'COMPLETED':
        statusColor = AppColors.medsTeal;
        statusBg = AppColors.medsTealBg;
      case 'REJECTED':
      case 'DECLINED':
        statusColor = AppColors.primaryRed;
        statusBg = AppColors.softRed;
      default:
        statusColor = AppColors.rustRed;
        statusBg = AppColors.lightMaroon;
    }

    return TapFeedback(
      onTap: () => _openRefillDetail(refill),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.replay_rounded, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    refill.medicationName ?? 'Medication refill',
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${refill.displayStatus} · ${refill.formattedDate}',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                  if (refill.quantity != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Qty: ${refill.quantity}',
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersList() {
    if (_reminders.isEmpty) {
      return _emptyState(
        icon: Icons.alarm_add_outlined,
        title: 'No reminders yet',
        subtitle: 'Tap “Add reminder” to schedule your medication times.',
        actionLabel: 'Add reminder',
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: _reminders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return _reminderCard(reminder);
        },
      ),
    );
  }

  Widget _reminderCard(MedicationReminder reminder) {
    return TapFeedback(
      onTap: () => _openForm(existing: reminder),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: reminder.isEnabled
                    ? AppColors.medsTealBg
                    : AppColors.fieldFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.alarm_rounded,
                color: reminder.isEnabled
                    ? AppColors.medsTeal
                    : AppColors.greyText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.medicationName,
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reminder.formattedTime} · ${MedicationReminder.formatDaysLabel(reminder.daysOfWeek)}',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: reminder.isEnabled,
              activeTrackColor: AppColors.medsTeal.withValues(alpha: 0.45),
              activeThumbColor: AppColors.medsTeal,
              onChanged: (value) => _toggleReminder(reminder, value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.medsTealBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.medsTeal),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.raleway(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.roboto(
                fontSize: 14,
                color: AppColors.greyText,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              TapFeedback(
                onTap: onAction,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.medsTeal,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    actionLabel,
                    style: AppTypography.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.primaryRed,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: AppTypography.roboto(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 16),
            TapFeedback(
              onTap: _loadData,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Retry',
                  style: AppTypography.raleway(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
