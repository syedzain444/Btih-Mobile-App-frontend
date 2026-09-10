import 'dart:convert';

import 'package:btih_andriod_app/models/local_appointment.dart';
import 'package:btih_andriod_app/screens/doctor_schedule_screen.dart';
import 'package:btih_andriod_app/services/appointment_service.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:btih_andriod_app/utils/dashboard_helpers.dart';
import 'package:btih_andriod_app/utils/database_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';

class AppointmentsInfoScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final bool isGuestMode;
  final String? focusAppointmentId;
  final int? focusWeekId;
  final String? focusAppointmentTime;

  const AppointmentsInfoScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.isGuestMode = false,
    this.focusAppointmentId,
    this.focusWeekId,
    this.focusAppointmentTime,
  });

  @override
  State<AppointmentsInfoScreen> createState() => _AppointmentsInfoScreenState();
}

class _AppointmentsInfoScreenState extends State<AppointmentsInfoScreen> {
  List<Appointment> _allAppointments = [];
  List<Appointment> _upcomingAppointments = [];
  List<Appointment> _pastAppointments = [];
  bool _isLoading = true;
  String? _error;
  int _selectedTabIndex = 0;
  bool _didOpenFocusedAppointment = false;
  final AppointmentService _appointmentService = AppointmentService();
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    if (widget.isGuestMode) {
      await _fetchGuestAppointments();
      return;
    }

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/Patient/appointments/${widget.patientMrNo}',
      );

      final response = await ApiConfig.client.get(
        url,
        headers: {'accept': '*/*'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body is List ? body : [];
        setState(() {
          _allAppointments =
              data.map((json) => Appointment.fromJson(json)).toList();
          _splitAppointments();
          _isLoading = false;
          _error = null;
        });
        _maybeOpenFocusedAppointment();
      } else if (response.statusCode == 404) {
        setState(() {
          _allAppointments = [];
          _splitAppointments();
          _isLoading = false;
          _error = null;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Session expired. Please log in again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              'Failed to load appointments (HTTP ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGuestAppointments() async {
    try {
      final guestPhone = GuestSession.normalizePhone(
        GuestSession.mobileNumber ?? '',
      );
      final localAppointments = await DatabaseHelper().getGuestAppointments();
      final filtered = localAppointments.where((item) {
        if (guestPhone.isEmpty) return true;
        return GuestSession.normalizePhone(item.phoneNo) == guestPhone;
      }).toList();

      if (!mounted) return;
      setState(() {
        _allAppointments = filtered.map(_appointmentFromLocal).toList();
        _splitAppointments();
        _isLoading = false;
      });
      _maybeOpenFocusedAppointment();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Appointment _appointmentFromLocal(LocalAppointment local) {
    return Appointment(
      appointmentId: local.appointmentId,
      name: local.name,
      phoneNo: local.phoneNo,
      mrNo: local.mrNo,
      email: local.email,
      weekId: local.weekId,
      appointmentTime: local.appointmentTime,
      status: local.status,
      doctorName: local.doctorName,
      doctorId: local.doctorId,
      departmentId: local.departmentId,
      purpose: local.purpose,
      createdAt: local.createdAt,
    );
  }

  void _splitAppointments() {
    _upcomingAppointments = [];
    _pastAppointments = [];

    for (final appointment in _allAppointments) {
      if (_isPastAppointment(appointment)) {
        _pastAppointments.add(appointment);
      } else {
        _upcomingAppointments.add(appointment);
      }
    }

    _upcomingAppointments.sort(_compareByAppointmentDate);
    _pastAppointments.sort(_compareByAppointmentDate);
  }

  bool _isPastAppointment(Appointment appointment) {
    final status = appointment.status.toLowerCase();
    if (status == 'completed' || status == 'cancelled') {
      return true;
    }

    final date = _parseDate(appointment.appointmentTime);
    if (date == null) {
      return status != 'pending' && status != 'confirmed';
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final appointmentDate = DateTime(date.year, date.month, date.day);
    return appointmentDate.isBefore(todayDate);
  }

  int _compareByAppointmentDate(Appointment a, Appointment b) {
    final dateA = _parseDate(a.appointmentTime);
    final dateB = _parseDate(b.appointmentTime);
    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    return dateB.compareTo(dateA);
  }

  DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _formatCardDate(Appointment appointment) {
    final date = _parseDate(appointment.appointmentTime);
    if (date != null) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    if (appointment.createdAt.isNotEmpty) {
      return _formatCardDateFromString(appointment.createdAt);
    }
    return 'Date pending';
  }

  String _formatCardDateFromString(String raw) {
    try {
      final date = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }

  String _formatTimeLine(Appointment appointment) {
    final raw = appointment.appointmentTime.trim();
    if (raw.isEmpty) return 'Time pending';

    if (raw.contains(':') && !raw.contains('T')) {
      return raw;
    }

    final date = _parseDate(raw);
    if (date == null) return raw;

    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final weekday = weekdays[date.weekday - 1];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$weekday: $hour:$minute $period';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFE65100);
      case 'confirmed':
        return const Color(0xFF26A69A);
      case 'cancelled':
        return AppColors.primaryRed;
      case 'reschedule pending':
        return const Color(0xFF6A1B9A);
      default:
        return AppColors.greyText;
    }
  }

  Color _statusBackground(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFE8F5E9);
      case 'pending':
        return const Color(0xFFFFF3E0);
      case 'confirmed':
        return const Color(0xFFE0F2F1);
      case 'cancelled':
        return AppColors.softRed;
      case 'reschedule pending':
        return const Color(0xFFF3E5F5);
      default:
        return AppColors.fieldFill;
    }
  }

  bool _canManageAppointment(Appointment appointment) {
    final status = appointment.status.toLowerCase();
    return status == 'pending' || status == 'confirmed';
  }

  Future<String?> _promptReasonDialog({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: AppTypography.raleway(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.roboto(
                  fontSize: 14,
                  color: AppColors.greyText,
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
                ),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Reason is required';
                if (trimmed.length < 5) {
                  return 'Please enter at least 5 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Back',
                style: AppTypography.roboto(color: AppColors.greyText),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, controller.text.trim());
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return reason;
  }

  Future<bool> _confirmCancelDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cancel appointment?',
            style: AppTypography.raleway(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          content: Text(
            'This will cancel your appointment immediately. This action cannot be undone.',
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Keep appointment',
                style: AppTypography.roboto(color: AppColors.greyText),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
              ),
              child: const Text('Yes, cancel'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _handleCancelAppointment(
    Appointment appointment,
    BuildContext sheetContext,
  ) async {
    if (_actionInProgress) return;

    final reason = await _promptReasonDialog(
      title: 'Cancellation reason',
      hint: 'Tell us why you need to cancel',
    );
    if (reason == null || !mounted) return;

    final confirmed = await _confirmCancelDialog();
    if (!confirmed || !mounted) return;

    setState(() => _actionInProgress = true);

    try {
      if (widget.isGuestMode) {
        await DatabaseHelper().updateAppointmentStatus(
          appointmentId: appointment.appointmentId,
          status: 'Cancelled',
          purposeAppend: '[CANCELLED BY PATIENT: $reason]',
        );
      } else {
        if (appointment.appointmentId.isEmpty) {
          throw Exception('Appointment ID is missing');
        }
        await _appointmentService.cancelAppointment(
          appointmentId: appointment.appointmentId,
          mrNo: widget.patientMrNo,
          reason: reason,
        );
      }

      if (!mounted) return;
      Navigator.pop(sheetContext);

      if (widget.patientMrNo.isNotEmpty) {
        await NotificationService.instance.notifyAppointmentCancelled(
          mrNo: widget.patientMrNo,
          doctorName: appointment.doctorName,
          appointmentTime: appointment.appointmentTime,
        );
      }

      CustomMessageDialog.showSuccess(
        context,
        'Your appointment has been cancelled.',
      );
      await _fetchAppointments();
    } catch (e) {
      if (mounted) {
        CustomMessageDialog.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleRescheduleAppointment(
    Appointment appointment,
    BuildContext sheetContext,
  ) async {
    if (_actionInProgress) return;

    if (appointment.doctorId <= 0) {
      CustomMessageDialog.showError(
        context,
        'Doctor information is missing for this appointment. Please contact the hospital.',
      );
      return;
    }

    final reason = await _promptReasonDialog(
      title: 'Reschedule reason',
      hint: 'Tell us why you need to reschedule',
    );
    if (reason == null || !mounted) return;

    Navigator.pop(sheetContext);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorScheduleScreen(
          doctorId: appointment.doctorId,
          doctorName: appointment.doctorName,
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          departmentId: appointment.departmentId,
          isLoggedIn: !widget.isGuestMode,
          isForSelf: true,
          isRescheduleMode: true,
          rescheduleAppointmentId: appointment.appointmentId,
          rescheduleReason: reason,
        ),
      ),
    );

    if (result == true && mounted) {
      CustomMessageDialog.showSuccess(
        context,
        'Reschedule request submitted. You will be notified once admin approves it.',
      );
      await _fetchAppointments();
    }
  }

  List<Appointment> get _visibleAppointments =>
      _selectedTabIndex == 0 ? _upcomingAppointments : _pastAppointments;

  bool get _hasFocusTarget =>
      (widget.focusAppointmentId != null &&
          widget.focusAppointmentId!.isNotEmpty) ||
      (widget.focusWeekId != null &&
          widget.focusAppointmentTime != null &&
          widget.focusAppointmentTime!.isNotEmpty);

  Appointment? _findFocusedAppointment() {
    if (!_hasFocusTarget || _allAppointments.isEmpty) return null;

    if (widget.focusAppointmentId != null &&
        widget.focusAppointmentId!.isNotEmpty) {
      for (final appt in _allAppointments) {
        if (appt.appointmentId == widget.focusAppointmentId) return appt;
      }
    }

    if (widget.focusWeekId != null &&
        widget.focusAppointmentTime != null &&
        widget.focusAppointmentTime!.isNotEmpty) {
      for (final appt in _allAppointments) {
        if (appt.weekId == widget.focusWeekId &&
            appt.appointmentTime == widget.focusAppointmentTime) {
          return appt;
        }
      }
    }

    return null;
  }

  void _maybeOpenFocusedAppointment() {
    if (_didOpenFocusedAppointment || !_hasFocusTarget || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didOpenFocusedAppointment) return;
      final focused = _findFocusedAppointment();
      if (focused == null) return;

      _didOpenFocusedAppointment = true;
      setState(() => _selectedTabIndex = 0);
      _showAppointmentDetails(focused);
    });
  }

  void _showAppointmentDetails(Appointment appointment) {
    final statusColor = _statusColor(appointment.status);
    final statusBg = _statusBackground(appointment.status);
    final department = DashboardHelpers.sanitizeLabel(appointment.purpose);
    final doctor = DashboardHelpers.normalizeDoctorName(appointment.doctorName);
    final displayId = appointment.appointmentId.isNotEmpty
        ? appointment.appointmentId
        : appointment.weekId.toString();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                        Icons.calendar_month_outlined,
                        color: AppColors.primaryRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appointment #$displayId',
                            style: AppTypography.raleway(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepRed,
                            ),
                          ),
                          Text(
                            _formatCardDate(appointment),
                            style: AppTypography.roboto(
                              fontSize: 12,
                              color: AppColors.greyText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        appointment.status.isEmpty
                            ? 'Unknown'
                            : appointment.status,
                        style: AppTypography.raleway(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.access_time_rounded,
                  _formatTimeLine(appointment),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.person_outline_rounded, doctor),
                if (department != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.place_outlined, department),
                ],
                if (_canManageAppointment(appointment)) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TapFeedback(
                          onTap: _actionInProgress
                              ? null
                              : () => _handleRescheduleAppointment(
                                    appointment,
                                    sheetContext,
                                  ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryRed),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Reschedule',
                              style: AppTypography.raleway(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TapFeedback(
                          onTap: _actionInProgress
                              ? null
                              : () => _handleCancelAppointment(
                                    appointment,
                                    sheetContext,
                                  ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Cancel',
                              style: AppTypography.raleway(
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (appointment.status.toLowerCase() ==
                    'reschedule pending') ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'Your reschedule request is awaiting admin approval.',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: const Color(0xFF6A1B9A),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.greyText,
                      side: const BorderSide(color: AppColors.hairline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppTypography.raleway(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppAppBar(
        title: Text(
          'Appointments',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.calendar_month_outlined),
        ],
      ),
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
                    Expanded(child: _buildTabContent()),
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
            label: 'Current (${_upcomingAppointments.length})',
            selected: _selectedTabIndex == 0,
            onTap: () => setState(() => _selectedTabIndex = 0),
          ),
          _buildTabButton(
            label: 'Past (${_pastAppointments.length})',
            selected: _selectedTabIndex == 1,
            onTap: () => setState(() => _selectedTabIndex = 1),
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
            color: selected ? AppColors.deepRed : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.raleway(
                fontSize: 13,
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
    if (_visibleAppointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedTabIndex == 0
                    ? Icons.event_available_outlined
                    : Icons.history_rounded,
                size: 64,
                color: AppColors.greyText.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedTabIndex == 0
                    ? 'No upcoming appointments'
                    : 'No past appointments',
                style: AppTypography.raleway(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedTabIndex == 0
                    ? 'Your active appointments will appear here.'
                    : 'Your completed appointments will appear here.',
                textAlign: TextAlign.center,
                style: AppTypography.roboto(
                  fontSize: 14,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sectionTitle = _selectedTabIndex == 0
        ? 'Upcoming Appointments (${_upcomingAppointments.length})'
        : 'Past Appointments (${_pastAppointments.length})';
    final sectionIcon = _selectedTabIndex == 0
        ? Icons.calendar_month_outlined
        : Icons.history_rounded;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Icon(sectionIcon, size: 18, color: AppColors.deepRed),
            const SizedBox(width: 8),
            Text(
              sectionTitle,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._visibleAppointments.map(_buildAppointmentCard),
      ],
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final statusColor = _statusColor(appointment.status);
    final statusBg = _statusBackground(appointment.status);
    final department = DashboardHelpers.sanitizeLabel(appointment.purpose);
    final doctor = DashboardHelpers.normalizeDoctorName(appointment.doctorName);
    final displayId = appointment.appointmentId.isNotEmpty
        ? appointment.appointmentId
        : appointment.weekId.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showAppointmentDetails(appointment),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.fieldBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.softRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.primaryRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Appointment #$displayId',
                                  style: AppTypography.raleway(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatCardDate(appointment),
                                  style: AppTypography.roboto(
                                    fontSize: 12,
                                    color: AppColors.greyText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              appointment.status.isEmpty
                                  ? 'Unknown'
                                  : appointment.status,
                              style: AppTypography.raleway(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        Icons.access_time_rounded,
                        _formatTimeLine(appointment),
                      ),
                      if (department != null) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow(Icons.place_outlined, department),
                      ],
                      const SizedBox(height: 6),
                      _buildDetailRow(Icons.person_outline_rounded, doctor),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primaryRed,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.greyText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.darkText,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.primaryRed),
            const SizedBox(height: 16),
            Text(
              'Error loading appointments',
              style: AppTypography.raleway(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchAppointments();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class Appointment {
  final String appointmentId;
  final String name;
  final String phoneNo;
  final String mrNo;
  final String email;
  final int weekId;
  final String appointmentTime;
  final String status;
  final String doctorName;
  final int doctorId;
  final int departmentId;
  final String purpose;
  final String createdAt;

  Appointment({
    required this.appointmentId,
    required this.name,
    required this.phoneNo,
    required this.mrNo,
    required this.email,
    required this.weekId,
    required this.appointmentTime,
    required this.status,
    required this.doctorName,
    this.doctorId = 0,
    this.departmentId = 0,
    required this.purpose,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      appointmentId: json['appointmentId']?.toString() ?? '',
      name: json['name'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      mrNo: json['mrNo'] ?? '',
      email: json['email'] ?? '',
      weekId: json['weekId'] ?? 0,
      appointmentTime: json['appointmentTime'] ?? '',
      status: json['status'] ?? '',
      doctorName: json['doctorName'] ?? '',
      doctorId: json['doctorId'] is int
          ? json['doctorId'] as int
          : int.tryParse(json['doctorId']?.toString() ?? '') ?? 0,
      departmentId: json['departmentId'] is int
          ? json['departmentId'] as int
          : int.tryParse(json['departmentId']?.toString() ?? '') ?? 0,
      purpose: json['purpose'] ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}
