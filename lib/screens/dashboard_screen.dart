import 'dart:convert';

import 'package:btih_andriod_app/screens/AppointmentsInfoScreen.dart';
import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/screens/notifications_screen.dart';
import 'package:btih_andriod_app/screens/guest_patient_info_screen.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/screens/welcome_screen.dart';
import 'package:btih_andriod_app/screens/medication_reminders_screen.dart';
import 'package:btih_andriod_app/screens/patient_profile_screen.dart';
import 'package:btih_andriod_app/screens/patient_records_screen.dart';
import 'package:btih_andriod_app/screens/patient_report_history_screen.dart';
import 'package:btih_andriod_app/screens/reports_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/widgets/patient_bottom_nav_bar.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/dashboard_helpers.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/patient_model.dart';
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

class _RecentActivityItem {
  final String title;
  final String subtitle;
  final String timestamp;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final DateTime sortDate;
  final String statusLabel;
  final bool isNew;

  const _RecentActivityItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.sortDate,
    this.statusLabel = 'Done',
    this.isNew = false,
  });
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const _summaryNavIndex = 2;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const _emergencyNumber = 'tel:115';

  bool _isLoggedIn = false;
  late String _patientDisplayName;
  int _notificationBadgeCount = 0;
  _UpcomingAppointment? _upcomingAppointment;
  bool _loadingAppointment = false;

  int _prescriptionsCount = 0;
  int _medicationsCount = 0;
  List<_RecentActivityItem> _recentActivity = [];
  bool _loadingOverview = false;

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
    NotificationService.instance.addListener(_onNotificationsChanged);
    if (_isLoggedIn && widget.patientMrNo.isNotEmpty) {
      NotificationService.instance.reloadForMrNo(widget.patientMrNo);
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
      final responses = await Future.wait([
        ApiConfig.client.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/labReports')),
        ApiConfig.client.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/gastroReports')),
        ApiConfig.client.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/radiologyReports')),
        ApiConfig.client.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/prescriptionReports')),
        ApiConfig.client.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient?MR_NO=$mrNo')),
        ApiConfig.client.get(
          Uri.parse('${ApiConfig.baseUrl}/api/Medications/current/$mrNo'),
        ),
      ]);

      if (!mounted) return;

      int prescriptionsCount = 0;
      final activities = <_RecentActivityItem>[];

      void addReportActivities(List<dynamic> data, String typeLabel) {
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          final name = item['diagnostiC_NAME']?.toString() ?? 'Report';
          final dateRaw = item['dT_SAMPLECOLLECTION']?.toString() ?? '';
          DateTime? dt;
          try {
            if (dateRaw.isNotEmpty) dt = DateTime.parse(dateRaw);
          } catch (_) {}

          if (dt != null) {
            activities.add(
              _RecentActivityItem(
                title: '$typeLabel report available',
                subtitle: '$name is ready',
                timestamp: DashboardHelpers.formatActivityTimestamp(dt),
                icon: Icons.description_outlined,
                iconColor: AppColors.primaryRed,
                iconBackground: AppColors.softRed,
                sortDate: dt,
                statusLabel: 'New',
                isNew: true,
              ),
            );
          }
        }
      }

      if (responses[0].statusCode == 200) {
        addReportActivities(jsonDecode(responses[0].body) as List<dynamic>, 'Lab');
      }
      if (responses[1].statusCode == 200) {
        addReportActivities(jsonDecode(responses[1].body) as List<dynamic>, 'Gastro');
      }
      if (responses[2].statusCode == 200) {
        addReportActivities(
          jsonDecode(responses[2].body) as List<dynamic>,
          'Radiology',
        );
      }

      if (responses[3].statusCode == 200) {
        final data = jsonDecode(responses[3].body) as List<dynamic>;
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          prescriptionsCount++;
          final name = item['diagnostiC_NAME']?.toString() ?? 'Prescription';
          final dateRaw = item['dT_SAMPLECOLLECTION']?.toString() ?? '';
          DateTime? dt;
          try {
            if (dateRaw.isNotEmpty) dt = DateTime.parse(dateRaw);
          } catch (_) {}

          if (dt != null) {
            activities.add(
              _RecentActivityItem(
                title: 'Prescription updated',
                subtitle: 'New prescription added — $name',
                timestamp: DashboardHelpers.formatActivityTimestamp(dt),
                icon: Icons.medication_outlined,
                iconColor: AppColors.deepRed,
                iconBackground: AppColors.blush,
                sortDate: dt,
                statusLabel: 'New',
                isNew: true,
              ),
            );
          }
        }
      }

      if (responses[4].statusCode == 200) {
        final parsed =
            PatientApiResponse.fromDynamic(jsonDecode(responses[4].body));
        for (final visit in parsed.visitHistory.take(5)) {
          final doctor = DashboardHelpers.normalizeDoctorName(
            visit.displayDoctor,
          );
          final dateRaw = visit.visitDate;
          DateTime? dt;
          try {
            if (dateRaw.isNotEmpty) dt = DateTime.parse(dateRaw);
          } catch (_) {}

          if (dt != null) {
            activities.add(
              _RecentActivityItem(
                title: 'Visit completed',
                subtitle: doctor,
                timestamp: DashboardHelpers.formatActivityTimestamp(dt),
                icon: Icons.medical_services_outlined,
                iconColor: AppColors.primaryRed,
                iconBackground: AppColors.softRed,
                sortDate: dt,
              ),
            );
          }
        }
      }

      activities.sort((a, b) => b.sortDate.compareTo(a.sortDate));

      final recent = activities.take(3).toList();
      final coloredRecent = <_RecentActivityItem>[];
      for (var i = 0; i < recent.length; i++) {
        final item = recent[i];
        if (item.title == 'Visit completed') {
          final accent = AppColors.activityPalette[i % AppColors.activityPalette.length];
          coloredRecent.add(
            _RecentActivityItem(
              title: item.title,
              subtitle: item.subtitle,
              timestamp: item.timestamp,
              icon: Icons.medical_services_outlined,
              iconColor: accent.icon,
              iconBackground: accent.background,
              sortDate: item.sortDate,
              statusLabel: item.statusLabel,
              isNew: item.isNew,
            ),
          );
        } else {
          coloredRecent.add(item);
        }
      }

      var medicationsCount = 0;
      if (responses.length > 5 && responses[5].statusCode == 200) {
        try {
          final medsBody = jsonDecode(responses[5].body);
          if (medsBody is Map<String, dynamic>) {
            final data = medsBody['data'];
            if (data is List) medicationsCount = data.length;
          }
        } catch (_) {}
      }

      setState(() {
        _prescriptionsCount = prescriptionsCount;
        _medicationsCount = medicationsCount;
        _recentActivity = coloredRecent;
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

  Future<bool> _ensureGuestProfile() async {
    if (GuestSession.isComplete) return true;
    if (!mounted) return false;

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GuestPatientInfoScreen()),
    );
    return completed == true && GuestSession.isComplete;
  }

  Future<bool> _ensureGuestAccess() async {
    if (_isLoggedIn) return true;
    return _ensureGuestProfile();
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
    if (!await _checkLoginAndNavigate('notifications') || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          patientMrNo: widget.patientMrNo,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _notificationBadgeCount = NotificationService.instance.unreadCount;
    });
  }

  void _goToDoctorsList() async {
    if (!await _ensureGuestAccess() || !mounted) return;
    Navigator.push(
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
  }

  Future<void> _openAppointments({
    String? focusAppointmentId,
    int? focusWeekId,
    String? focusAppointmentTime,
  }) async {
    if (!await _ensureGuestAccess() || !mounted) return;
    Navigator.push(
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientRecordsScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
        ),
      ),
    );
  }

  Future<void> _openBilling() async {
    if (!await _checkLoginAndNavigate('billing') || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientReportHistoryScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          isLoggedIn: _isLoggedIn,
        ),
      ),
    );
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

  Future<void> _openProfile() async {
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

  Future<void> _openReports({int initialTabIndex = 0}) async {
    if (!await _checkLoginAndNavigate('reports') || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse(_emergencyNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
      backgroundColor: AppColors.blush,
      endDrawer: _buildProfileDrawer(),
      body: Column(
        children: [
          _fadeSlideIn(
            animation: _greetingAnim,
            offsetY: 0.04,
            child: _buildHeroHeader(),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.blush),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DashboardContentBackgroundPainter(),
                  ),
                ),
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

  String get _displayInitial {
    final trimmed = _displayName.trim();
    if (trimmed.isEmpty) return 'P';
    return trimmed[0].toUpperCase();
  }

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
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_hospital_rounded,
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bahria Town\nInternational Hospital',
                        style: AppTypography.raleway(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                          '·',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Text(
                        'Patient portal',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Guest mode · Login for full access',
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
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: forHero ? AppColors.duskMaroon : AppColors.blush,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _displayInitial,
                style: AppTypography.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: forHero ? AppColors.white : AppColors.primaryRed,
                ),
              ),
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
      backgroundColor: AppColors.blush,
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
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _displayInitial,
                            style: AppTypography.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
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
                                  'Guest · Patient Portal',
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
                if (_isLoggedIn) ...[
                  _profileDrawerTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    onTap: () {
                      _closeProfileDrawer();
                      _openProfile();
                    },
                  ),
                  const SizedBox(height: 10),
                  _profileDrawerTile(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    badge: _notificationBadgeCount,
                    onTap: () {
                      _closeProfileDrawer();
                      _openNotifications();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                _profileDrawerTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    _closeProfileDrawer();
                    if (_isLoggedIn) {
                      _openProfile();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Login to access settings'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
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
    final prescriptions = _isLoggedIn ? '$_prescriptionsCount' : '—';
    final medications = _isLoggedIn ? '$_medicationsCount' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Health snapshot',
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
              onTap: () => _openReports(initialTabIndex: 3),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View details',
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
                background: AppColors.softRed,
                iconBackground: AppColors.lightMaroon,
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
                'Recent activity',
                style: AppTypography.raleway(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRed,
                ),
              ),
            ),
            TapFeedback(
              onTap: () => _switchMainTab(3),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: AppTypography.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.primaryRed,
                  ),
                ],
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
    _RecentActivityItem item, {
    required int index,
    required bool showTimeline,
  }) {
    final ({Color icon, Color background}) accent;
    if (item.title == 'Visit completed') {
      accent = AppColors.activityPalette[index % AppColors.activityPalette.length];
    } else {
      accent = (icon: item.iconColor, background: item.iconBackground);
    }
    final isVisit = item.title == 'Visit completed';

    return TapFeedback(
      onTap: () => _switchMainTab(3),
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
                    child: isVisit
                        ? _StethoscopeIcon(color: accent.icon, size: 18)
                        : Icon(
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
                  item.timestamp,
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
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.duskMaroon,
            AppColors.deepRed,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.duskMaroon.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              top: -24,
              right: -16,
              child: _decorativeBlob(
                80,
                AppColors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\NEED URGENT MEDICAL HELP?',
                          style: AppTypography.raleway(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        Text(
                          'Emergency assistance 24/7',
                          style: AppTypography.roboto(
                            fontSize: 11,
                            color: AppColors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TapFeedback(
                    onTap: _callEmergency,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rustRed,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phone_in_talk_rounded,
                            size: 15,
                            color: AppColors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Call',
                            style: AppTypography.raleway(
                              fontSize: 11,
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
            ),
          ],
        ),
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
class _StethoscopeIcon extends StatelessWidget {
  const _StethoscopeIcon({required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StethoscopeIconPainter(color),
      ),
    );
  }
}

class _StethoscopeIconPainter extends CustomPainter {
  _StethoscopeIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    canvas.drawCircle(Offset(w * 0.5, h * 0.74), w * 0.15, paint);

    final tube = Path()
      ..moveTo(w * 0.5, h * 0.59)
      ..lineTo(w * 0.5, h * 0.36)
      ..cubicTo(w * 0.5, h * 0.16, w * 0.2, h * 0.1, w * 0.17, h * 0.28)
      ..moveTo(w * 0.5, h * 0.36)
      ..cubicTo(w * 0.5, h * 0.16, w * 0.8, h * 0.1, w * 0.83, h * 0.28);
    canvas.drawPath(tube, paint);

    canvas.drawCircle(Offset(w * 0.17, h * 0.33), w * 0.085, paint);
    canvas.drawCircle(Offset(w * 0.83, h * 0.33), w * 0.085, paint);
  }

  @override
  bool shouldRepaint(covariant _StethoscopeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Notched bottom edge on the burgundy hero — bubbles only, no cross pattern.
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

/// Soft blush background with subtle maroon bubble accents under the hero.
class _DashboardContentBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.blush,
            AppColors.white.withValues(alpha: 0.92),
            AppColors.fieldFill.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    void drawBubble(Offset center, double radius, Color color) {
      canvas.drawCircle(center, radius, Paint()..color = color);
    }

    drawBubble(
      Offset(size.width * 0.88, size.height * 0.08),
      72,
      AppColors.softRed.withValues(alpha: 0.35),
    );
    drawBubble(
      Offset(size.width * 0.12, size.height * 0.22),
      56,
      AppColors.lightMaroon.withValues(alpha: 0.28),
    );
    drawBubble(
      Offset(size.width * 0.92, size.height * 0.55),
      48,
      AppColors.softRed.withValues(alpha: 0.22),
    );
    drawBubble(
      Offset(size.width * 0.06, size.height * 0.72),
      64,
      AppColors.blush.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}