import 'package:btih_andriod_app/models/current_medication_model.dart';
import 'package:btih_andriod_app/models/medication_reminder_model.dart';
import 'package:btih_andriod_app/models/refill_request_model.dart';
import 'package:btih_andriod_app/services/medication_reminder_service.dart';
import 'package:btih_andriod_app/services/medication_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/medication/medication_sheets.dart';
import 'package:btih_andriod_app/utils/medication_duplicate_guard.dart';
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
  late final PageController _pageController;

  int _selectedTab = 0;
  bool _isLoading = true;
  String? _error;

  List<CurrentMedication> _medications = [];
  List<MedicationReminder> _reminders = [];
  List<RefillRequest> _refills = [];

  static const _tabTitles = ['Medications', 'Reminders', 'Refills'];
  static const _tabIcons = [
    Icons.medication_outlined,
    Icons.notifications_active_outlined,
    Icons.replay_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        _medications = MedicationDuplicateGuard.dedupeMedications(
          results[0] as List<CurrentMedication>,
        );
        _reminders = MedicationDuplicateGuard.dedupeReminders(
          results[1] as List<MedicationReminder>,
        );
        _refills = MedicationDuplicateGuard.dedupeRefills(
          results[2] as List<RefillRequest>,
        );
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

  void _goToTab(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openReminderSheet({
    MedicationReminder? existing,
    CurrentMedication? medication,
  }) async {
    if (existing == null && medication == null) return;

    if (medication != null &&
        MedicationDuplicateGuard.hasReminderForMedication(
          existing: _reminders,
          medication: medication,
        )) {
      final linked = MedicationDuplicateGuard.findReminderForMedication(
        existing: _reminders,
        medication: medication,
      );
      if (linked != null) {
        await _openReminderSheet(existing: linked);
      }
      return;
    }

    final saved = await MedicationSheets.showReminderForm(
      context: context,
      mrNo: widget.patientMrNo,
      existingReminders: _reminders,
      existing: existing,
      medication: medication,
    );
    if (saved == true) await _loadData();
  }

  Future<void> _openAddReminderPicker() async {
    if (_medications.isEmpty) {
      CustomMessageDialog.showError(
        context,
        'No prescribed medications yet. Your doctor\'s active prescriptions will appear under the Meds tab.',
      );
      return;
    }

    final available = MedicationDuplicateGuard.medicationsWithoutReminders(
      medications: _medications,
      reminders: _reminders,
    );

    if (available.isEmpty) {
      CustomMessageDialog.showError(
        context,
        'Reminders are already set for all your current medications. Edit or delete an existing reminder if needed.',
      );
      return;
    }

    final selected = await MedicationSheets.showMedicationPicker(
      context: context,
      medications: available,
    );

    if (selected != null && mounted) {
      await _openReminderSheet(medication: selected);
    }
  }

  Future<void> _confirmDeleteReminder(MedicationReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text(
          'Remove the reminder for ${reminder.medicationName}?',
        ),
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
    await _deleteReminder(reminder);
  }

  Future<void> _deleteReminder(MedicationReminder reminder) async {
    try {
      await _reminderService.deleteReminder(
        reminderId: reminder.reminderId,
        mrNo: widget.patientMrNo,
      );
      if (!mounted) return;
      setState(() {
        _reminders = _reminders
            .where((item) => item.reminderId != reminder.reminderId)
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

  Future<void> _openPrescriptionSheet(CurrentMedication medication) async {
    await MedicationSheets.showPrescriptionDetail(
      context: context,
      mrNo: widget.patientMrNo,
      medication: medication,
    );
  }

  Future<void> _openRefillSheet(CurrentMedication medication) async {
    final activeRefill = MedicationDuplicateGuard.activeRefillForMedication(
      _refills,
      medication.medicationId,
    );
    if (activeRefill != null) {
      CustomMessageDialog.showError(
        context,
        'A refill request for ${medication.medicineName} is already '
        '${activeRefill.displayStatus.toLowerCase()}. You cannot submit it again '
        'until the current request is completed.',
      );
      return;
    }

    final saved = await MedicationSheets.showRefillRequest(
      context: context,
      mrNo: widget.patientMrNo,
      medication: medication,
      existingRefills: _refills,
    );
    if (saved == true) await _refreshRefillsSilently();
  }

  Future<void> _refreshRefillsSilently() async {
    try {
      final refills =
          await _medicationService.getRefillHistory(widget.patientMrNo);
      if (!mounted) return;
      setState(() {
        _refills = MedicationDuplicateGuard.dedupeRefills(refills);
      });
    } catch (_) {
      // Keep the current list visible if the refresh fails.
    }
  }

  Future<void> _openRefillStatus(RefillRequest refill) async {
    final updated = await MedicationSheets.showRefillStatus(
      context: context,
      mrNo: widget.patientMrNo,
      refill: refill,
    );

    if (!mounted) return;

    if (updated != null) {
      setState(() {
        _refills = _refills
            .map(
              (item) => item.refillId == updated.refillId ? updated : item,
            )
            .toList();
      });
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

  bool _hasReminderForMedication(CurrentMedication medication) {
    return MedicationDuplicateGuard.hasReminderForMedication(
      existing: _reminders,
      medication: medication,
    );
  }

  RefillRequest? _latestRefillForMedication(CurrentMedication medication) {
    RefillRequest? latest;
    for (final refill in _refills) {
      if (refill.medicationId == medication.medicationId) {
        latest = refill;
        break;
      }
    }
    return latest;
  }

  IconData _medicationIcon(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('INJ')) return Icons.vaccines_outlined;
    if (upper.contains('TAB') || upper.contains('CAP')) {
      return Icons.medication_outlined;
    }
    if (upper.contains('SYR') || upper.contains('SYP')) {
      return Icons.local_drink_outlined;
    }
    return Icons.medication_liquid_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _tabTitles[_selectedTab],
            key: ValueKey(_selectedTab),
            style: AppTypography.raleway(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: AppBarIconBadge(
              key: ValueKey('icon_$_selectedTab'),
              icon: _tabIcons[_selectedTab],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton(
              onPressed: _openAddReminderPicker,
              backgroundColor: AppColors.deepRed,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.add_rounded, size: 26),
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
                      child: _buildTabSwitcher(),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _selectedTab = index);
                        },
                        children: [
                          _buildMedicationsTab(),
                          _buildRemindersTab(),
                          _buildRefillsTab(),
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
            icon: Icons.medication_outlined,
            label: 'Meds',
            count: _medications.length,
            selected: _selectedTab == 0,
            onTap: () => _goToTab(0),
          ),
          _buildTabButton(
            icon: Icons.notifications_active_outlined,
            label: 'Reminders',
            count: _reminders.length,
            selected: _selectedTab == 1,
            onTap: () => _goToTab(1),
          ),
          _buildTabButton(
            icon: Icons.replay_rounded,
            label: 'Refills',
            count: _refills.length,
            selected: _selectedTab == 2,
            onTap: () => _goToTab(2),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? AppColors.deepRed : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.white : AppColors.greyText,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$label ($count)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.raleway(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.white : AppColors.greyText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Matches AppointmentsInfoScreen section header (icon + title row).
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: AppColors.deepRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
        ),
      ],
    );
  }

  /// Flat list with hairline dividers — matches dashboard Recent Activity.
  Widget _buildHairlineList(List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: List.generate(items.length, (index) {
        final isLast = index == items.length - 1;
        return Column(
          children: [
            items[index],
            if (!isLast)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.hairline,
              ),
          ],
        );
      }),
    );
  }

  Widget _activityIconCircle(
    IconData icon, {
    Color iconColor = AppColors.primaryRed,
    Color background = AppColors.softRed,
  }) {
    return SizedBox(
      width: 44,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }

  Widget _sleekAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.deepRed,
  }) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.raleway(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsTab() {
    if (_medications.isEmpty) {
      return _emptyScroll(
        icon: Icons.medication_liquid_outlined,
        title: 'No current medications',
        subtitle: 'Your active prescriptions will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _sectionHeader(
            'Your Medications (${_medications.length})',
            Icons.medication_outlined,
          ),
          const SizedBox(height: 12),
          _buildHairlineList(
            _medications.map(_medicationRow).toList(),
          ),
        ],
      ),
    );
  }

  Widget _medicationRow(CurrentMedication medication) {
    final hasReminder = _hasReminderForMedication(medication);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TapFeedback(
          onTap: () => _openPrescriptionSheet(medication),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _activityIconCircle(_medicationIcon(medication.medicineName)),
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
                      const SizedBox(height: 3),
                      Text(
                        medication.subtitle,
                        style: AppTypography.roboto(
                          fontSize: 12,
                          color: AppColors.greyText,
                          height: 1.35,
                        ),
                      ),
                      if (medication.doctor != null &&
                          medication.doctor!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Dr. ${medication.doctor}',
                          style: AppTypography.roboto(
                            fontSize: 11,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                      if (hasReminder) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reminder active',
                          style: AppTypography.raleway(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.medsTeal,
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
        ),
        Padding(
          padding: const EdgeInsets.only(left: 44, bottom: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: _sleekAction(
              icon: hasReminder
                  ? Icons.edit_outlined
                  : Icons.notifications_none_outlined,
              label: hasReminder ? 'Edit' : 'Remind',
              color: AppColors.medsTeal,
              onTap: () {
                if (hasReminder) {
                  final linked =
                      MedicationDuplicateGuard.findReminderForMedication(
                    existing: _reminders,
                    medication: medication,
                  );
                  if (linked != null) {
                    _openReminderSheet(existing: linked);
                  }
                } else {
                  _openReminderSheet(medication: medication);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefillsTab() {
    if (_medications.isEmpty) {
      return _emptyScroll(
        icon: Icons.replay_outlined,
        title: 'No medications to refill',
        subtitle: 'Active prescriptions will appear here for refill requests.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _sectionHeader(
            'Your Refills (${_medications.length})',
            Icons.replay_rounded,
          ),
          const SizedBox(height: 12),
          _buildHairlineList(
            _medications.map(_refillMedicationRow).toList(),
          ),
          if (_refills.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader(
              'Recent requests (${_refills.length})',
              Icons.history_rounded,
            ),
            const SizedBox(height: 12),
            _buildHairlineList(
              _refills.map(_refillHistoryRow).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _refillMedicationRow(CurrentMedication medication) {
    final latestRefill = _latestRefillForMedication(medication);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TapFeedback(
          onTap: () => _openPrescriptionSheet(medication),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _activityIconCircle(
                  _medicationIcon(medication.medicineName),
                  background: AppColors.medsTealBg,
                  iconColor: AppColors.medsTeal,
                ),
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
                      if (medication.doctor != null &&
                          medication.doctor!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Dr. ${medication.doctor}',
                          style: AppTypography.roboto(
                            fontSize: 12,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                      if (latestRefill != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last request: ${latestRefill.displayStatus} · ${latestRefill.formattedCreatedDate}',
                          style: AppTypography.roboto(
                            fontSize: 11,
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
        ),
        Padding(
          padding: const EdgeInsets.only(left: 44, bottom: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: _sleekAction(
              icon: Icons.replay_rounded,
              label: 'Refill',
              color: AppColors.medsTeal,
              onTap: () => _openRefillSheet(medication),
            ),
          ),
        ),
      ],
    );
  }

  Widget _refillHistoryRow(RefillRequest refill) {
    return TapFeedback(
      onTap: () => _openRefillStatus(refill),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _activityIconCircle(Icons.receipt_long_outlined),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    refill.medicationName ?? 'Refill request',
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepRed,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${refill.displayStatus} · ${refill.formattedCreatedDate}',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
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
  }

  Widget _buildRemindersTab() {
    if (_reminders.isEmpty) {
      return _emptyScroll(
        icon: Icons.alarm_add_outlined,
        title: 'No reminders yet',
        subtitle:
            'Tap + to choose a prescribed medication and set a reminder.',
        actionLabel: 'Add reminder',
        onAction: _openAddReminderPicker,
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
        children: [
          _sectionHeader(
            'Your Reminders (${_reminders.length})',
            Icons.notifications_active_outlined,
          ),
          const SizedBox(height: 12),
          _buildHairlineList(
            _reminders.map(_reminderRow).toList(),
          ),
        ],
      ),
    );
  }

  Widget _reminderRow(MedicationReminder reminder) {
    return Dismissible(
      key: ValueKey('reminder_${reminder.reminderId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDeleteReminder(reminder);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.primaryRed.withValues(alpha: 0.12),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.primaryRed,
        ),
      ),
      child: TapFeedback(
        onTap: () => _openReminderSheet(existing: reminder),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _activityIconCircle(
                Icons.notifications_active_outlined,
                iconColor: reminder.isEnabled
                    ? AppColors.primaryRed
                    : AppColors.greyText,
                background: reminder.isEnabled
                    ? AppColors.softRed
                    : AppColors.fieldFill,
              ),
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
                    const SizedBox(height: 3),
                    Text(
                      '${reminder.formattedTime} · ${MedicationReminder.formatDaysLabel(reminder.daysOfWeek)}',
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                    if (reminder.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Added ${reminder.formattedCreatedDate}',
                        style: AppTypography.roboto(
                          fontSize: 11,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete reminder',
                onPressed: () => _confirmDeleteReminder(reminder),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 22,
                  color: AppColors.primaryRed,
                ),
              ),
              Switch.adaptive(
                value: reminder.isEnabled,
                activeTrackColor: AppColors.deepRed.withValues(alpha: 0.4),
                activeThumbColor: AppColors.deepRed,
                onChanged: (value) => _toggleReminder(reminder, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyScroll({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _emptyState(
          icon: icon,
          title: title,
          subtitle: subtitle,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.greyText.withValues(alpha: 0.35)),
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
                  color: AppColors.deepRed,
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
