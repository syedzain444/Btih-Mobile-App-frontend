import 'package:btih_andriod_app/services/notification_preferences_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:flutter/material.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({
    super.key,
    required this.patientMrNo,
  });

  final String patientMrNo;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _loading = true;
  bool _pushEnabled = true;
  bool _appointmentAlerts = true;
  bool _medicationAlerts = true;
  bool _billingAlerts = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mrNo = widget.patientMrNo;
    final results = await Future.wait([
      NotificationPreferencesService.getPushEnabled(mrNo),
      NotificationPreferencesService.getAppointmentAlerts(mrNo),
      NotificationPreferencesService.getMedicationAlerts(mrNo),
      NotificationPreferencesService.getBillingAlerts(mrNo),
    ]);

    if (!mounted) return;
    setState(() {
      _pushEnabled = results[0];
      _appointmentAlerts = results[1];
      _medicationAlerts = results[2];
      _billingAlerts = results[3];
      _loading = false;
    });
  }

  Future<void> _updatePush(bool value) async {
    setState(() => _pushEnabled = value);
    await NotificationPreferencesService.setPushEnabled(
      widget.patientMrNo,
      value,
    );
  }

  Future<void> _updateAppointments(bool value) async {
    setState(() => _appointmentAlerts = value);
    await NotificationPreferencesService.setAppointmentAlerts(
      widget.patientMrNo,
      value,
    );
  }

  Future<void> _updateMedications(bool value) async {
    setState(() => _medicationAlerts = value);
    await NotificationPreferencesService.setMedicationAlerts(
      widget.patientMrNo,
      value,
    );
  }

  Future<void> _updateBilling(bool value) async {
    setState(() => _billingAlerts = value);
    await NotificationPreferencesService.setBillingAlerts(
      widget.patientMrNo,
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Notification Preferences',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: const [
          AppBarIconBadge(icon: Icons.notifications_none_rounded),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                _prefTile(
                  title: 'Push notifications',
                  subtitle: 'Allow hospital alerts on this device',
                  value: _pushEnabled,
                  onChanged: _updatePush,
                ),
                _prefTile(
                  title: 'Appointment reminders',
                  subtitle: 'Upcoming visits and schedule changes',
                  value: _appointmentAlerts,
                  onChanged: _pushEnabled ? _updateAppointments : null,
                ),
                _prefTile(
                  title: 'Medication reminders',
                  subtitle: 'Prescription and refill updates',
                  value: _medicationAlerts,
                  onChanged: _pushEnabled ? _updateMedications : null,
                ),
                _prefTile(
                  title: 'Billing alerts',
                  subtitle: 'New bills and payment confirmations',
                  value: _billingAlerts,
                  onChanged: _pushEnabled ? _updateBilling : null,
                ),
              ],
            ),
    );
  }

  Widget _prefTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final disabled = onChanged == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.raleway(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: disabled ? AppColors.greyText : AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.deepRed.withValues(alpha: 0.4),
            activeThumbColor: AppColors.deepRed,
          ),
        ],
      ),
    );
  }
}
