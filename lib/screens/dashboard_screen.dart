import 'dart:convert';

import 'package:btih_andriod_app/models/doctors_model.dart';
import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/models/recent_activity_item.dart';
import 'package:btih_andriod_app/screens/AppointmentsInfoScreen.dart';
import 'package:btih_andriod_app/screens/discharge_history_screen.dart';
import 'package:btih_andriod_app/screens/doctor_schedule_screen.dart';
import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/screens/notifications_screen.dart';
import 'package:btih_andriod_app/screens/guest_patient_info_screen.dart';
import 'package:btih_andriod_app/models/current_medication_model.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/services/medication_service.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/services/recent_activity_service.dart';
import 'package:btih_andriod_app/screens/telemedicine_screen.dart';
import 'package:btih_andriod_app/screens/welcome_screen.dart';
import 'package:btih_andriod_app/screens/medication_reminders_screen.dart';
import 'package:btih_andriod_app/screens/messaging/message_inbox_screen.dart';
import 'package:btih_andriod_app/screens/patient_profile_screen.dart';
import 'package:btih_andriod_app/screens/settings/help_support_screen.dart';
import 'package:btih_andriod_app/screens/settings/notification_preferences_screen.dart';
import 'package:btih_andriod_app/screens/settings/security_settings_screen.dart';
import 'package:btih_andriod_app/screens/settings/settings_static_screen.dart';
import 'package:btih_andriod_app/screens/patient_records_screen.dart';
import 'package:btih_andriod_app/screens/patient_report_history_screen.dart';
import 'package:btih_andriod_app/screens/reports_screen.dart';
import 'package:btih_andriod_app/screens/visit_history_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/widgets/billing/invoice_details_modal.dart';
import 'package:btih_andriod_app/widgets/guest_profile_required_dialog.dart';
import 'package:btih_andriod_app/widgets/offline_banner.dart';
import 'package:btih_andriod_app/widgets/patient_avatar.dart';
import 'package:btih_andriod_app/widgets/patient_bottom_nav_bar.dart';
import 'package:btih_andriod_app/services/profile_photo_service.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/utils/dashboard_helpers.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'doctors_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final bool isLoggedIn;
  final int initialTabIndex;
  final ValueChanged<bool>? onLoginStateChanged;
  final ValueChanged<String>? onPatientNameChanged;

  const DashboardScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.isLoggedIn = false,
    this.initialTabIndex = PatientBottomNavBar.dashboardIndex,
    this.onLoginStateChanged,
    this.onPatientNameChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _UpcomingAppointment {
  final String appointmentId;
  final int weekId;
  final String appointmentTimeRaw;
  final String doctorName;
  final String scheduleDay;
  final String scheduleTime;
  final String? department;

  const _UpcomingAppointment({
    required this.appointmentId,
    required this.weekId,
    required this.appointmentTimeRaw,
    required this.doctorName,
    required this.scheduleDay,
    required this.scheduleTime,
    this.department,
  });
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const _summaryNavIndex = 2;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const _emergencyPhoneDigits = '02137187111';

  bool _isLoggedIn = false;
  late String _patientDisplayName;
  int _notificationBadgeCount = 0;
  _UpcomingAppointment? _upcomingAppointment;
  bool _loadingAppointment = false;

  int _prescriptionsCount = 0;
  int _medicationsCount = 0;
  List<RecentActivityItem> _recentActivity = [];
  bool _loadingOverview = false;
  final _medicationService = MedicationService();

  late AnimationController _entranceController;
  late Animation<double> _greetingAnim;
  late Animation<double> _appointmentAnim;
  late Animation<double> _overviewAnim;
  late Animation<double> _activityAnim;
  late Animation<double> _emergencyAnim;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = false;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
    _patientDisplayName = _resolvePatientDisplayName();
    _scrollController.addListener(_onDashboardScroll);
    _loadUpcomingAppointment();
    _loadHealthOverview();
    _loadRecentActivity();
    NotificationService.instance.addListener(_onNotificationsChanged);
    if (_isLoggedIn && widget.patientMrNo.isNotEmpty) {
      NotificationService.instance.reloadForMrNo(widget.patientMrNo);
      _syncProfilePhoto();
    }

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _greetingAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
    );
    _appointmentAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.14, 0.54, curve: Curves.easeOutCubic),
    );
    _overviewAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.28, 0.68, curve: Curves.easeOutCubic),
    );
    _activityAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.40, 0.80, curve: Curves.easeOutCubic),
    );
    _emergencyAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.52, 0.92, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScrollHint();
      if (widget.initialTabIndex != PatientBottomNavBar.dashboardIndex) {
        _switchMainTab(widget.initialTabIndex);
      }
    });
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onNotificationsChanged);
    _scrollController.removeListener(_onDashboardScroll);
    _scrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onDashboardScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScroll = position.maxScrollExtent > 8;
    final nearTop = position.pixels < 28;
    final shouldShow = canScroll && nearTop;
    if (shouldShow != _showScrollHint && mounted) {
      setState(() => _showScrollHint = shouldShow);
    }
  }

  void _refreshScrollHint() {
    if (!_scrollController.hasClients || !mounted) return;
    final canScroll = _scrollController.position.maxScrollExtent > 8;
    setState(() => _showScrollHint = canScroll);
  }

  void _onNotificationsChanged() {
    if (!mounted) return;
    setState(() {
      _notificationBadgeCount = NotificationService.instance.unreadCount;
    });
  }

  Future<void> _loadUpcomingAppointment() async {
    if (!_isLoggedIn || widget.patientMrNo.isEmpty) return;

    setState(() => _loadingAppointment = true);
    try {
      final response = await ApiConfig.client.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/Patient/appointments/${widget.patientMrNo}',
        ),
        headers: {'accept': '*/*'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _UpcomingAppointment? upcoming;
        for (final raw in data) {
          if (raw is! Map<String, dynamic>) continue;
          final status = raw['status']?.toString().toLowerCase() ?? '';
          if (status != 'pending') continue;

          final time = raw['appointmentTime']?.toString() ?? '';
          final schedule = DashboardHelpers.parseAppointmentSchedule(time);
          upcoming = _UpcomingAppointment(
            appointmentId: raw['appointmentId']?.toString() ?? '',
            weekId: raw['weekId'] is int
                ? raw['weekId'] as int
                : int.tryParse(raw['weekId']?.toString() ?? '') ?? 0,
            appointmentTimeRaw: time,
            doctorName: DashboardHelpers.normalizeDoctorName(
              raw['doctorName']?.toString() ?? '',
            ),
            scheduleDay: schedule.dayLabel,
            scheduleTime: schedule.timeLabel,
            department: DashboardHelpers.sanitizeLabel(raw['purpose']?.toString()),
          );
          break;
        }
        setState(() => _upcomingAppointment = upcoming);
      }
    } catch (_) {
      // Keep dashboard usable if appointment fetch fails.
    } finally {
      if (mounted) {
        setState(() => _loadingAppointment = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshScrollHint());
      }
    }
  }

  Future<void> _loadHealthOverview() async {
    if (!_isLoggedIn || widget.patientMrNo.isEmpty) return;

    setState(() => _loadingOverview = true);
    try {
      final mrNo = widget.patientMrNo;
      final overviewResponses = Future.wait([
        ApiConfig.client.get(
          Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/prescriptionReports'),
        ),
      ]);
      final medicationsFuture = _medicationService
          .getCurrentMedications(mrNo)
          .catchError((_) => <CurrentMedication>[]);

      final parallelResults = await Future.wait([
        overviewResponses,
        medicationsFuture,
      ]);
      final responses = parallelResults[0] as List<http.Response>;
      final medications = parallelResults[1] as List<CurrentMedication>;

      if (!mounted) return;

      int prescriptionsCount = 0;
      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        if (data is List) prescriptionsCount = data.length;
      }

      setState(() {
        _prescriptionsCount = prescriptionsCount;
        _medicationsCount = medications.length;
      });
    } catch (_) {
      // Keep dashboard usable if overview fetch fails.
    } finally {
      if (mounted) {
        setState(() => _loadingOverview = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshScrollHint());
      }
    }
  }

  String get _activityScopeId => RecentActivityService.instance.resolveScope(
        patientMrNo: _isLoggedIn ? widget.patientMrNo : '',
        guestPhone: GuestSession.mobileNumber,
      );

  Future<void> _loadRecentActivity() async {
    final items = await RecentActivityService.instance.getActivities(
      _activityScopeId,
    );
    if (!mounted) return;
    setState(() => _recentActivity = items);
  }

  Future<void> _openRecentActivity(RecentActivityItem item) async {
    switch (item.kind) {
      case RecentActivityKind.doctor:
        final doctorId = item.payload['doctorId'] as int? ??
            int.tryParse(item.payload['doctorId']?.toString() ?? '') ??
            0;
        if (doctorId <= 0) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorScheduleScreen(
              doctor: Doctor.minimal(
                id: doctorId,
                doctorName: item.payload['doctorName']?.toString() ?? item.subtitle,
                departmentId: item.payload['departmentId'] as int? ??
                    int.tryParse(
                          item.payload['departmentId']?.toString() ?? '',
                        ) ??
                        0,
                specializationName:
                    item.payload['specializationName']?.toString() ?? '',
              ),
              patientMrNo: widget.patientMrNo,
              patientName: widget.patientName,
              isLoggedIn: _isLoggedIn,
            ),
          ),
        );
      case RecentActivityKind.appointment:
        await _openAppointments(
          focusAppointmentId: item.payload['appointmentId']?.toString(),
          focusWeekId: item.payload['weekId'] as int? ??
              int.tryParse(item.payload['weekId']?.toString() ?? ''),
          focusAppointmentTime: item.payload['appointmentTime']?.toString(),
        );
      case RecentActivityKind.medicalReport:
        if (!await _checkLoginAndNavigate('reports') || !mounted) return;
        final categoryIndex = item.payload['categoryIndex'] as int? ??
            int.tryParse(item.payload['categoryIndex']?.toString() ?? '') ??
            0;
        final reportRaw = item.payload['report'];
        final report = reportRaw is Map
            ? Map<String, dynamic>.from(reportRaw)
            : null;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportsScreen(
              patientMrNo: widget.patientMrNo,
              patientName: widget.patientName,
              initialTabIndex: categoryIndex.clamp(0, 3),
              autoOpenReport: report,
            ),
          ),
        );
      case RecentActivityKind.discharge:
        if (!await _checkLoginAndNavigate('discharge history') || !mounted) {
          return;
        }
        final recordRaw = item.payload['record'];
        final record = recordRaw is Map
            ? Map<String, dynamic>.from(recordRaw)
            : null;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DischargeHistoryScreen(
              patientMrNo: widget.patientMrNo,
              autoOpenRecord: record,
            ),
          ),
        );
      case RecentActivityKind.visit:
        if (!await _checkLoginAndNavigate('visit history') || !mounted) {
          return;
        }
        final visitId = item.payload['patientVisitId'] as int? ??
            int.tryParse(item.payload['patientVisitId']?.toString() ?? '');
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitHistoryScreen(
              patientMrNo: widget.patientMrNo,
              patientName: widget.patientName,
              focusVisitId: visitId,
            ),
          ),
        );
      case RecentActivityKind.bill:
        if (!await _checkLoginAndNavigate('billing') || !mounted) return;
        final reportRaw = item.payload['report'];
        if (reportRaw is! Map) return;
        final report =
            PatientReport.fromJson(Map<String, dynamic>.from(reportRaw));
        final rptId = item.payload['rptId'] as int? ??
            int.tryParse(item.payload['rptId']?.toString() ?? '') ??
            BillingDepartments.byCode(
                  item.payload['departmentCode']?.toString() ?? '',
                )?.rptId ??
            report.reportId ??
            0;
        await showInvoiceDetailsModal(
          context: context,
          patientMrNo: widget.patientMrNo,
          report: report,
          rptId: rptId,
        );
    }

    if (mounted) await _loadRecentActivity();
  }

  Future<bool> _ensureGuestProfileForDoctors() async {
    if (_isLoggedIn || GuestSession.isComplete) return true;
    if (!mounted) return false;

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GuestPatientInfoScreen()),
    );
    return completed == true && GuestSession.isComplete;
  }

  Future<bool> _checkLoginAndNavigate(String destination) async {
    if (_isLoggedIn) return true;
    if (!mounted) return false;
    _showLoginRequiredDialog(destination);
    return false;
  }

  void _showLoginRequiredDialog(String destination) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Login Required',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryRed,
            ),
          ),
          content: const Text(
            'You need to login first to access this feature.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      redirectAfterLogin: true,
                      returnScreen: destination,
                      patientMrNo: widget.patientMrNo,
                      patientName: widget.patientName,
                    ),
                  ),
                ).then((loggedIn) {
                  if (loggedIn == true && mounted) {
                    setState(() => _isLoggedIn = true);
                    widget.onLoginStateChanged?.call(true);
                    _loadUpcomingAppointment();
                    _loadHealthOverview();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Login Now'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openNotifications() async {
    final mrNo = widget.patientMrNo.trim().isNotEmpty
        ? widget.patientMrNo.trim()
        : NotificationService.instance.lastKnownMrNo;
    if (mrNo.isEmpty) {
      if (!await _checkLoginAndNavigate('notifications') || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          patientMrNo: mrNo.isNotEmpty ? mrNo : widget.patientMrNo,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _notificationBadgeCount = NotificationService.instance.unreadCount;
    });
  }

  void _goToDoctorsList() async {
    if (!_isLoggedIn && !await _ensureGuestProfileForDoctors()) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorsListScreen(
          patientMrNo: _isLoggedIn ? widget.patientMrNo : '',
          patientName: _isLoggedIn
              ? widget.patientName
              : GuestSession.displayName,
          isLoggedIn: _isLoggedIn,
        ),
      ),
    );
    if (mounted) await _loadRecentActivity();
  }

  Future<void> _openAppointments({
    String? focusAppointmentId,
    int? focusWeekId,
    String? focusAppointmentTime,
  }) async {
    if (!_isLoggedIn && !GuestSession.isComplete) {
      if (!mounted) return;
      final action = await showGuestProfileRequiredDialog(context);
      if (action == GuestProfileRequiredAction.goToDoctors) {
        _goToDoctorsList();
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentsInfoScreen(
          patientMrNo: _isLoggedIn ? widget.patientMrNo : '',
          patientName: _isLoggedIn
              ? widget.patientName
              : GuestSession.displayName,
          isGuestMode: !_isLoggedIn,
          focusAppointmentId: focusAppointmentId,
          focusWeekId: focusWeekId,
          focusAppointmentTime: focusAppointmentTime,
        ),
      ),
    );
    if (mounted) await _loadRecentActivity();
  }

  Future<void> _openUpcomingAppointmentDetails() async {
    final appt = _upcomingAppointment;
    if (appt == null) return;
    await _openAppointments(
      focusAppointmentId:
          appt.appointmentId.isNotEmpty ? appt.appointmentId : null,
      focusWeekId: appt.weekId > 0 ? appt.weekId : null,
      focusAppointmentTime:
          appt.appointmentTimeRaw.isNotEmpty ? appt.appointmentTimeRaw : null,
    );
  }

  Future<void> _openRecords() async {
    if (!await _checkLoginAndNavigate('records') || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientRecordsScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
        ),
      ),
    );
    if (mounted) await _loadRecentActivity();
  }

  Future<void> _openBilling() async {
    if (!await _checkLoginAndNavigate('billing') || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientReportHistoryScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          isLoggedIn: _isLoggedIn,
        ),
      ),
    );
    if (mounted) await _loadRecentActivity();
  }

  Future<void> _openMedicationReminders() async {
    if (!await _checkLoginAndNavigate('medications') || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicationRemindersScreen(
          patientMrNo: widget.patientMrNo,
        ),
      ),
    );
    if (!mounted) return;
    _loadHealthOverview();
  }

  String _resolvePatientDisplayName() {
    if (!_isLoggedIn) return widget.patientName;
    final sessionName = AuthSession.displayName.trim();
    if (sessionName.isNotEmpty && sessionName != 'Patient') {
      return sessionName;
    }
    return widget.patientName.trim().isNotEmpty
        ? widget.patientName.trim()
        : 'Patient';
  }

  Future<void> _syncProfilePhoto() async {
    try {
      await ProfilePhotoService().syncFromPatientApi(widget.patientMrNo);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _openProfile() async {
    _closeProfileDrawer();
    if (!await _checkLoginAndNavigate('profile') || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProfilePage(
          mrNo: widget.patientMrNo,
          isLoggedIn: _isLoggedIn,
        ),
      ),
    );
    if (!mounted) return;
    final updatedName = _resolvePatientDisplayName();
    setState(() => _patientDisplayName = updatedName);
    widget.onPatientNameChanged?.call(updatedName);
  }

  Future<void> _openNotificationPreferences() async {
    _closeProfileDrawer();
    if (!await _checkLoginAndNavigate('notification preferences') || !mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationPreferencesScreen(
          patientMrNo: widget.patientMrNo,
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    _closeProfileDrawer();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsStaticScreen(
          page: SettingsStaticPage.privacyPolicy,
        ),
      ),
    );
  }

  Future<void> _openHelpSupport() async {
    _closeProfileDrawer();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  }

  Future<void> _openMessages() async {
    _closeProfileDrawer();
    if (!await _checkLoginAndNavigate('messages') || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageInboxScreen(
          patientMrNo: widget.patientMrNo,
          patientName: _displayName,
        ),
      ),
    );
  }

  Future<void> _openSecuritySettings() async {
    _closeProfileDrawer();
    if (!await _checkLoginAndNavigate('security settings') || !mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecuritySettingsScreen(),
      ),
    );
  }

  Future<void> _openReports({int initialTabIndex = 0}) async {
    if (!await _checkLoginAndNavigate('reports') || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
    if (mounted) await _loadRecentActivity();
  }

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: _emergencyPhoneDigits);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Phone dialer unavailable on this platform (e.g. some web builds).
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_isLoggedIn ? 'Logout' : 'Exit Guest Mode'),
        content: Text(
          _isLoggedIn
              ? 'Are you sure you want to logout?'
              : 'Return to the welcome screen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            child: Text(_isLoggedIn ? 'Logout' : 'Exit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_isLoggedIn) {
      await AuthSession.clear();
    } else {
      await GuestSession.clear();
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _switchMainTab(
    int index, {
    String? focusAppointmentId,
    int? focusWeekId,
    String? focusAppointmentTime,
  }) {
    switch (index) {
      case PatientBottomNavBar.dashboardIndex:
        return;
      case 0:
        _goToDoctorsList();
      case 1:
        _openAppointments(
          focusAppointmentId: focusAppointmentId,
          focusWeekId: focusWeekId,
          focusAppointmentTime: focusAppointmentTime,
        );
      case 3:
        _openRecords();
      case 4:
        _openBilling();
    }
  }

  Widget _fadeSlideIn({
    required Animation<double> animation,
    required Widget child,
    double offsetY = 0.08,
  }) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, offsetY),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  static const _sectionGap = 24.0;
  static const _horizontalPadding = 20.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      endDrawer: _buildProfileDrawer(),
      body: Column(
        children: [
          const OfflineBanner(),
          _fadeSlideIn(
            animation: _greetingAnim,
            offsetY: 0.04,
            child: _buildHeroHeader(),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.white),
                Theme(
                  data: Theme.of(context).copyWith(
                    scrollbarTheme: ScrollbarThemeData(
                      thumbColor: WidgetStateProperty.all(
                        AppColors.primaryRed.withValues(alpha: 0.55),
                      ),
                      trackColor: WidgetStateProperty.all(
                        AppColors.lightMaroon.withValues(alpha: 0.65),
                      ),
                      trackBorderColor: WidgetStateProperty.all(
                        Colors.transparent,
                      ),
                      radius: const Radius.circular(4),
                      thickness: WidgetStateProperty.all(4),
                    ),
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 4,
                    radius: const Radius.circular(4),
                    interactive: true,
                    child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      _horizontalPadding,
                      16,
                      _horizontalPadding,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fadeSlideIn(
                          animation: _appointmentAnim,
                          child: _buildAppointmentSection(),
                        ),
                        const SizedBox(height: _sectionGap),
                        _fadeSlideIn(
                          animation: _overviewAnim,
                          child: _buildHealthSnapshot(),
                        ),
                        if (_isLoggedIn) ...[
                          const SizedBox(height: _sectionGap),
                          _fadeSlideIn(
                            animation: _activityAnim,
                            child: _buildRecentActivity(),
                          ),
                        ],
                        const SizedBox(height: _sectionGap),
                        _fadeSlideIn(
                          animation: _emergencyAnim,
                          child: _buildEmergencyBlock(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showScrollHint ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: _buildScrollHint(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  static Widget _decorativeBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  String get _displayName => DashboardHelpers.formatDisplayName(
        _isLoggedIn ? _patientDisplayName : GuestSession.displayName,
      );

  Widget _buildHeroHeader() {
    final topPadding = MediaQuery.paddingOf(context).top;

    return ClipPath(
      clipper: _DashboardHeroClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 42),
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -40,
              right: -50,
              child: _decorativeBlob(
                180,
                Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              top: 60,
              left: -70,
              child: _decorativeBlob(
                150,
                Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              top: 20,
              right: 90,
              child: _decorativeBlob(
                64,
                Colors.white.withValues(alpha: 0.11),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 40,
              child: _decorativeBlob(
                48,
                Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Brand mark only — sized to stay clear of header actions.
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 188,
                        maxHeight: 54,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 52,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    const Spacer(),
                    _buildNotificationHeaderButton(),
                    const SizedBox(width: 8),
                    _buildMessagesHeaderButton(),
                    const SizedBox(width: 8),
                    _buildProfileMenuButton(forHero: true),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  DashboardHelpers.timeBasedGreeting(),
                  style: AppTypography.raleway(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white.withValues(alpha: 0.95),
                    height: 1.2,
                  ),
                ),
                Text(
                  _displayName, 
                  style: AppTypography.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (_isLoggedIn && widget.patientMrNo.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.duskMaroon,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'MR ${widget.patientMrNo}',
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '\u00B7',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Text(
                        'Patient Portal',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Guest mode \u00B7 Login for full access',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationHeaderButton() {
    return TapFeedback(
      onTap: _openNotifications,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.22),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
            if (_notificationBadgeCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: _UnreadBadge(count: _notificationBadgeCount),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesHeaderButton() {
    return TapFeedback(
      onTap: _openMessages,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.22),
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: AppColors.white,
          size: 19,
        ),
      ),
    );
  }

  Widget _buildProfileMenuButton({bool forHero = false}) {
    return TapFeedback(
      onTap: _showProfileMenu,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        decoration: BoxDecoration(
          color: forHero
              ? AppColors.white.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: forHero
              ? Border.all(color: AppColors.white.withValues(alpha: 0.22))
              : Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PatientAvatar(
              displayName: _displayName,
              imageUrl: AuthSession.profileImageUrl,
              size: 30,
              backgroundColor:
                  forHero ? AppColors.duskMaroon : AppColors.blush,
              foregroundColor:
                  forHero ? AppColors.white : AppColors.primaryRed,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(
                _displayName.split(' ').first,
                style: AppTypography.raleway(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: forHero ? AppColors.white : AppColors.darkText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: forHero ? AppColors.white : AppColors.greyText,
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _closeProfileDrawer() {
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildProfileDrawer() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth * 0.82).clamp(280.0, 340.0);
    final topPadding = MediaQuery.paddingOf(context).top;

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 12, 24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -30,
                  right: -20,
                  child: _decorativeBlob(
                    100,
                    AppColors.white.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  bottom: -10,
                  left: -30,
                  child: _decorativeBlob(
                    80,
                    AppColors.white.withValues(alpha: 0.06),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Menu',
                          style: AppTypography.raleway(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _closeProfileDrawer,
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.white.withValues(alpha: 0.92),
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PatientAvatar(
                          displayName: _displayName,
                          imageUrl: AuthSession.profileImageUrl,
                          size: 52,
                          backgroundColor:
                              AppColors.white.withValues(alpha: 0.18),
                          foregroundColor: AppColors.white,
                          showBorder: true,
                          borderColor:
                              AppColors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: AppTypography.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (_isLoggedIn && widget.patientMrNo.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.duskMaroon,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'MR ${widget.patientMrNo}',
                                    style: AppTypography.mono(
                                      fontSize: 11,
                                      color: AppColors.white,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'Guest \u00B7 Patient Portal',
                                  style: AppTypography.roboto(
                                    fontSize: 12,
                                    color: AppColors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                _profileDrawerTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile Management',
                  onTap: _openProfile,
                ),
                const SizedBox(height: 8),
                _profileDrawerTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notification Preferences',
                  onTap: _openNotificationPreferences,
                ),
                const SizedBox(height: 8),
                _profileDrawerTile(
                  icon: Icons.shield_outlined,
                  label: 'Security Settings',
                  onTap: _openSecuritySettings,
                ),
                const SizedBox(height: 8),
                _profileDrawerTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: _openPrivacyPolicy,
                ),
                const SizedBox(height: 8),
                _profileDrawerTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: _openHelpSupport,
                ),
                if (_isLoggedIn) ...[
                  const SizedBox(height: 8),
                  _profileDrawerTile(
                    icon: Icons.videocam_outlined,
                    label: 'Telemedicine',
                    onTap: () {
                      _closeProfileDrawer();
                      openTelemedicineScreen(context);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                _profileDrawerTile(
                  icon: Icons.logout_rounded,
                  label: _isLoggedIn ? 'Logout' : 'Exit guest mode',
                  isDestructive: true,
                  onTap: () {
                    _closeProfileDrawer();
                    _logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileDrawerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
    bool isDestructive = false,
  }) {
    final accent =
        isDestructive ? AppColors.primaryRed : AppColors.deepRed;
    final tileBg = isDestructive
        ? AppColors.softRed.withValues(alpha: 0.75)
        : AppColors.lightMaroon.withValues(alpha: 0.45);

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? AppColors.primaryRed.withValues(alpha: 0.18)
                : AppColors.lightMaroon,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.raleway(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
            if (badge > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: AppTypography.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withValues(alpha: 0.55),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _appointmentCardDecoration({bool booked = false}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: booked
            ? [
                AppColors.softRed.withValues(alpha: 0.95),
                AppColors.lightMaroon.withValues(alpha: 0.72),
                AppColors.softRed.withValues(alpha: 0.82),
              ]
            : [
                AppColors.white,
                AppColors.blush,
                AppColors.softRed.withValues(alpha: 0.48),
              ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: AppColors.primaryRed.withValues(alpha: booked ? 0.22 : 0.16),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.deepRed.withValues(alpha: booked ? 0.11 : 0.08),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildBookedAppointmentContent(_UpcomingAppointment appt) {
    final hasSeparateTime =
        appt.scheduleTime.isNotEmpty && appt.scheduleTime != appt.scheduleDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING APPOINTMENT',
          style: AppTypography.raleway(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: 8),
        if (hasSeparateTime) ...[
          Text(
            appt.scheduleTime,
            style: AppTypography.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            appt.scheduleDay,
            style: AppTypography.raleway(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryRed,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          Text(
            appt.scheduleDay,
            style: AppTypography.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Text(
          appt.doctorName,
          style: AppTypography.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.deepRed,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (appt.department != null) ...[
          const SizedBox(height: 2),
          Text(
            appt.department!,
            style: AppTypography.roboto(
              fontSize: 12,
              color: AppColors.greyText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildScrollHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lightMaroon),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scroll for more',
              style: AppTypography.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.primaryRed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentIconBadge({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.88),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.18),
        ),
      ),
      child: Icon(
        Icons.event_available_outlined,
        color: AppColors.deepRed,
        size: size * 0.5,
      ),
    );
  }

  Widget _appointmentCompactAction({
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRed.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Tooltip(
          message: tooltip ?? 'Details',
          child: const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentSection() {
    if (_loadingAppointment && _isLoggedIn) {
      return Container(
        height: 92,
        decoration: _appointmentCardDecoration(),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryRed,
          ),
        ),
      );
    }

    final appointment = _upcomingAppointment;
    final hasAppointment = _isLoggedIn && appointment != null;

    if (hasAppointment) {
      final appt = appointment;
      return TapFeedback(
        onTap: _openUpcomingAppointmentDetails,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _appointmentCardDecoration(booked: true),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _appointmentIconBadge(),
              const SizedBox(width: 12),
              Expanded(child: _buildBookedAppointmentContent(appt)),
              const SizedBox(width: 8),
              _appointmentCompactAction(
                onTap: _openUpcomingAppointmentDetails,
                tooltip: 'View appointment details',
              ),
            ],
          ),
        ),
      );
    }

    return TapFeedback(
      onTap: () => _switchMainTab(0),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _appointmentCardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _appointmentIconBadge(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPCOMING APPOINTMENT',
                    style: AppTypography.raleway(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Book an appointment',
                    style: AppTypography.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepRed,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoggedIn
                        ? 'Schedule your visit with a specialist'
                        : 'Book as guest or login to sync',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _appointmentCompactAction(
              onTap: () => _switchMainTab(0),
              tooltip: 'Book appointment',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSnapshot() {
    final prescriptions = '$_prescriptionsCount';
    final medications = '$_medicationsCount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Health Snapshot',
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.hairline,
              ),
            ),
            const SizedBox(width: 12),
            TapFeedback(
              onTap: _openMedicationReminders,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Details',
                    style: AppTypography.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.primaryRed,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _healthSnapshotCard(
                count: prescriptions,
                label: 'Active prescriptions',
                icon: Icons.description_outlined,
                background: AppColors.rxCardBg,
                iconBackground: AppColors.rxIconBg,
                iconColor: AppColors.primaryRed,
                countColor: AppColors.deepRed,
                onTap: () => _openReports(initialTabIndex: 3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _healthSnapshotCard(
                count: medications,
                label: 'Current medications',
                icon: Icons.medication,
                background: AppColors.medsCardBg,
                iconBackground: AppColors.medsTealBg,
                iconColor: AppColors.medsTeal,
                countColor: AppColors.deepRed,
                onTap: _openMedicationReminders,
              ),
            ),
          ],
        ),
        if (_loadingOverview && _isLoggedIn)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primaryRed,
              backgroundColor: AppColors.softRed,
            ),
          ),
      ],
    );
  }

  Widget _healthSnapshotCard({
    required String count,
    required String label,
    required IconData icon,
    required Color background,
    required Color iconBackground,
    required Color iconColor,
    required Color countColor,
    required VoidCallback onTap,
  }) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const Spacer(),
            Text(
              count,
              style: AppTypography.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: countColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                      height: 1.25,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.greyText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 18,
              color: AppColors.deepRed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recent Activity',
                style: AppTypography.raleway(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRed,
                ),
              ),
            ),
            if (_recentActivity.isNotEmpty && _isLoggedIn)
              TapFeedback(
                onTap: () async {
                  final scope = RecentActivityService.instance.resolveScope(
                    patientMrNo: widget.patientMrNo,
                  );
                  await RecentActivityService.instance.clearAll(scope);
                  if (!mounted) return;
                  await _loadRecentActivity();
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Clear',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentActivity.isEmpty)
          Text(
            'No recent activity yet.',
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
            ),
          )
        else
          Column(
            children: List.generate(_recentActivity.length, (index) {
              final item = _recentActivity[index];
              final isLast = index == _recentActivity.length - 1;
              return Column(
                children: [
                  _buildActivityRow(
                    item,
                    index: index,
                    showTimeline: !isLast,
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.hairline,
                    ),
                ],
              );
            }),
          ),
      ],
    );
  }

  Widget _buildActivityRow(
    RecentActivityItem item, {
    required int index,
    required bool showTimeline,
  }) {
    final accent =
        AppColors.activityPalette[index % AppColors.activityPalette.length];
    final timestamp =
        DashboardHelpers.formatActivityTimestamp(item.viewedAt);

    return TapFeedback(
      onTap: () => _openRecentActivity(item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      size: 18,
                      color: accent.icon,
                    ),
                  ),
                  if (showTimeline)
                    Container(
                      width: 2,
                      height: 36,
                      margin: const EdgeInsets.only(top: 4),
                      color: accent.icon.withValues(alpha: 0.28),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.raleway(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timestamp,
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.greyText.withValues(alpha: 0.65),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyBlock() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B1524), AppColors.deepRed],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRed.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
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
                  'NEED URGENT MEDICAL HELP?',
                  style: AppTypography.raleway(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Emergency assistance 24/7',
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TapFeedback(
            onTap: _callEmergency,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 16,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Call',
                    style: AppTypography.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return PatientBottomNavBar(
      selectedIndex: _summaryNavIndex,
      onSelected: _switchMainTab,
    );
  }
}

/// Stethoscope glyph for recent-activity rows (matches dashboard mockup).
class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final isWide = label.length >= 2;

    return Container(
      height: 14,
      constraints: BoxConstraints(
        minWidth: isWide ? 18 : 14,
      ),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 3 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.deepRed, width: 1.2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.deepRed,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _DashboardHeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const curveDepth = 28.0;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - curveDepth)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + 14,
        0,
        size.height - curveDepth,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
