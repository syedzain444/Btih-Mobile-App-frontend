import 'dart:convert';

import 'package:btih_andriod_app/screens/AppointmentsInfoScreen.dart';
import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/screens/patient_profile_screen.dart';
import 'package:btih_andriod_app/screens/patient_records_screen.dart';
import 'package:btih_andriod_app/screens/patient_report_history_screen.dart';
import 'package:btih_andriod_app/screens/reports_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/dashboard_helpers.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'doctors_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final bool isLoggedIn;

  const DashboardScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.isLoggedIn = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _UpcomingAppointment {
  final String doctorName;
  final String dateLabel;
  final String timeLabel;
  final String? department;

  const _UpcomingAppointment({
    required this.doctorName,
    required this.dateLabel,
    required this.timeLabel,
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

  const _RecentActivityItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.sortDate,
  });
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const _summaryNavIndex = 0;
  static const _emergencyNumber = 'tel:115';

  bool _isLoggedIn = false;
  _UpcomingAppointment? _upcomingAppointment;
  bool _loadingAppointment = false;

  int _reportsCount = 0;
  int _prescriptionsCount = 0;
  String _reportsLatestLabel = 'No recent reports';
  String _prescriptionsLatestLabel = 'No active prescriptions';
  List<_RecentActivityItem> _recentActivity = [];
  bool _loadingOverview = false;

  late AnimationController _entranceController;
  late Animation<double> _greetingAnim;
  late Animation<double> _appointmentAnim;
  late Animation<double> _overviewAnim;
  late Animation<double> _activityAnim;
  late Animation<double> _emergencyAnim;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
    _loadUpcomingAppointment();
    _loadHealthOverview();

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
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadUpcomingAppointment() async {
    if (!_isLoggedIn || widget.patientMrNo.isEmpty) return;

    setState(() => _loadingAppointment = true);
    try {
      final response = await http.get(
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
          upcoming = _UpcomingAppointment(
            doctorName: DashboardHelpers.normalizeDoctorName(
              raw['doctorName']?.toString() ?? '',
            ),
            dateLabel: DashboardHelpers.formatAppointmentDate(time),
            timeLabel: DashboardHelpers.formatAppointmentTime(time),
            department: DashboardHelpers.sanitizeLabel(raw['purpose']?.toString()),
          );
          break;
        }
        setState(() => _upcomingAppointment = upcoming);
      }
    } catch (_) {
      // Keep dashboard usable if appointment fetch fails.
    } finally {
      if (mounted) setState(() => _loadingAppointment = false);
    }
  }

  Future<void> _loadHealthOverview() async {
    if (!_isLoggedIn || widget.patientMrNo.isEmpty) return;

    setState(() => _loadingOverview = true);
    try {
      final mrNo = widget.patientMrNo;
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/labReports')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/gastroReports')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/radiologyReports')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient/$mrNo/prescriptionReports')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/Patient?MR_NO=$mrNo')),
      ]);

      if (!mounted) return;

      int reportsCount = 0;
      int prescriptionsCount = 0;
      DateTime? latestReportDate;
      DateTime? latestPrescriptionDate;
      final activities = <_RecentActivityItem>[];

      void addReportActivities(List<dynamic> data, String typeLabel) {
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          reportsCount++;
          final name = item['diagnostiC_NAME']?.toString() ?? 'Report';
          final dateRaw = item['dT_SAMPLECOLLECTION']?.toString() ?? '';
          DateTime? dt;
          try {
            if (dateRaw.isNotEmpty) dt = DateTime.parse(dateRaw);
          } catch (_) {}

          if (dt != null) {
            final latest = latestReportDate;
            if (latest == null || dt.isAfter(latest)) {
              latestReportDate = dt;
            }
          }

          if (dt != null) {
            activities.add(
              _RecentActivityItem(
                title: '$typeLabel Report Available',
                subtitle: '$name is ready',
                timestamp: DashboardHelpers.formatActivityTimestamp(dt),
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF7E57C2),
                iconBackground: const Color(0xFFEDE7F6),
                sortDate: dt,
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
            final latest = latestPrescriptionDate;
            if (latest == null || dt.isAfter(latest)) {
              latestPrescriptionDate = dt;
            }
          }

          if (dt != null) {
            activities.add(
              _RecentActivityItem(
                title: 'Prescription Updated',
                subtitle: 'New prescription added — $name',
                timestamp: DashboardHelpers.formatActivityTimestamp(dt),
                icon: Icons.medication_outlined,
                iconColor: const Color(0xFF26A69A),
                iconBackground: const Color(0xFFE0F2F1),
                sortDate: dt,
              ),
            );
          }
        }
      }

      if (responses[4].statusCode == 200) {
        final data = jsonDecode(responses[4].body) as List<dynamic>;
        for (final item in data.take(5)) {
          if (item is! Map<String, dynamic>) continue;
          final doctor = DashboardHelpers.normalizeDoctorName(
            item['doctorName']?.toString() ?? '',
          );
          final dateRaw = item['visitDate']?.toString() ?? '';
          DateTime? dt;
          try {
            if (dateRaw.isNotEmpty) dt = DateTime.parse(dateRaw);
          } catch (_) {}

          if (dt != null) {
            activities.add(
              _RecentActivityItem(
                title: 'Visit Completed',
                subtitle: doctor,
                timestamp: DashboardHelpers.formatActivityTimestamp(dt),
                icon: Icons.medical_services_outlined,
                iconColor: const Color(0xFFFF7043),
                iconBackground: const Color(0xFFFBE9E7),
                sortDate: dt,
              ),
            );
          }
        }
      }

      activities.sort((a, b) => b.sortDate.compareTo(a.sortDate));

      setState(() {
        _reportsCount = reportsCount;
        _prescriptionsCount = prescriptionsCount;
        _reportsLatestLabel = DashboardHelpers.formatLatestLabel(latestReportDate);
        _prescriptionsLatestLabel = prescriptionsCount > 0
            ? 'Active'
            : 'No active prescriptions';
        _recentActivity = activities.take(3).toList();
      });
    } catch (_) {
      // Keep dashboard usable if overview fetch fails.
    } finally {
      if (mounted) setState(() => _loadingOverview = false);
    }
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

  void _goToDoctorsList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorsListScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          isLoggedIn: _isLoggedIn,
        ),
      ),
    );
  }

  Future<void> _openAppointments() async {
    if (!await _checkLoginAndNavigate('appointments') || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentsInfoScreen(
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
        ),
      ),
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

  Future<void> _openProfile() async {
    if (!await _checkLoginAndNavigate('profile') || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProfilePage(
          mrNo: widget.patientMrNo,
          isLoggedIn: _isLoggedIn,
        ),
      ),
    );
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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          redirectAfterLogin: true,
          patientName: 'Patient',
        ),
      ),
      (route) => false,
    );
  }

  void _onBottomNavSelected(int index) {
    if (index == _summaryNavIndex) return;
    switch (index) {
      case 1:
        _goToDoctorsList();
      case 2:
        _openAppointments();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fadeSlideIn(
                      animation: _greetingAnim,
                      child: _buildGreetingCard(),
                    ),
                    const SizedBox(height: 12),
                    _fadeSlideIn(
                      animation: _appointmentAnim,
                      child: _buildUpcomingAppointmentCard(),
                    ),
                    const SizedBox(height: 16),
                    _fadeSlideIn(
                      animation: _overviewAnim,
                      child: _buildHealthOverview(),
                    ),
                    const SizedBox(height: 20),
                    _fadeSlideIn(
                      animation: _activityAnim,
                      child: _buildRecentActivity(),
                    ),
                    const SizedBox(height: 20),
                    _fadeSlideIn(
                      animation: _emergencyAnim,
                      child: _buildEmergencySection(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            'Summary',
            style: AppTypography.roboto(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const Spacer(),
          _headerIcon(
            Icons.notifications_none_rounded,
            badgeCount: 3,
            onTap: () {},
          ),
          const SizedBox(width: 10),
          _headerIcon(Icons.person_outline_rounded, onTap: _openProfile),
          if (_isLoggedIn) ...[
            const SizedBox(width: 10),
            _headerIcon(Icons.logout_rounded, onTap: _logout),
          ] else ...[
            const SizedBox(width: 10),
            _headerIcon(Icons.login_rounded, onTap: () => _showLoginRequiredDialog('dashboard')),
          ],
        ],
      ),
    );
  }

  Widget _headerIcon(
    IconData icon, {
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      materialColor: AppColors.white,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.darkText),
            if (badgeCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryRed,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$badgeCount',
                    textAlign: TextAlign.center,
                    style: AppTypography.roboto(
                      fontSize: 9,
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

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.deepRed, AppColors.primaryRed],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DashboardHelpers.timeBasedGreeting(),
                  style: AppTypography.roboto(
                    fontSize: 13,
                    color: AppColors.softRed.withValues(alpha: 0.92),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  DashboardHelpers.formatDisplayName(widget.patientName),
                  style: AppTypography.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 13,
                        color: AppColors.white.withValues(alpha: 0.88),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'MR Number: ${widget.patientMrNo}',
                          style: AppTypography.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white.withValues(alpha: 0.95),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.health_and_safety_outlined,
            size: 36,
            color: AppColors.white.withValues(alpha: 0.14),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentCard() {
    if (!_isLoggedIn) return const SizedBox.shrink();

    if (_loadingAppointment) {
      return _whiteCard(
        compact: true,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryRed,
            ),
          ),
        ),
      );
    }

    final appointment = _upcomingAppointment;
    if (appointment == null) {
      return _whiteCard(
        compact: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Upcoming Appointment',
                    style: AppTypography.roboto(
                      fontSize: 11,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No upcoming appointments',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _goToDoctorsList,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Book >'),
            ),
          ],
        ),
      );
    }

    return _whiteCard(
      compact: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.softRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upcoming Appointment',
                  style: AppTypography.roboto(
                    fontSize: 11,
                    color: AppColors.greyText,
                    height: 1.2,
                  ),
                ),
                Text(
                  appointment.doctorName,
                  style: AppTypography.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryRed,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${appointment.dateLabel} • ${appointment.timeLabel}'
                  '${appointment.department != null ? ' • ${appointment.department}' : ''}',
                  style: AppTypography.roboto(
                    fontSize: 11,
                    color: AppColors.greyText,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _openAppointments,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Details >'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Overview',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _overviewStatCard(
                title: 'Reports',
                count: _isLoggedIn ? '$_reportsCount' : '—',
                subtitle: _isLoggedIn ? _reportsLatestLabel : 'Login to view',
                icon: Icons.description_outlined,
                iconColor: AppColors.primaryRed,
                background: AppColors.softRed,
                onTap: () => _openReports(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _overviewStatCard(
                title: 'Prescriptions',
                count: _isLoggedIn ? '$_prescriptionsCount' : '—',
                subtitle: _isLoggedIn
                    ? _prescriptionsLatestLabel
                    : 'Login to view',
                icon: Icons.medication_outlined,
                iconColor: const Color(0xFF26A69A),
                background: const Color(0xFFE0F2F1),
                onTap: () => _openReports(initialTabIndex: 3),
              ),
            ),
          ],
        ),
        if (_loadingOverview && _isLoggedIn)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primaryRed,
              backgroundColor: AppColors.softRed,
            ),
          ),
      ],
    );
  }

  Widget _overviewStatCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 130,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const Spacer(),
              Text(
                title,
                style: AppTypography.raleway(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count,
                style: AppTypography.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                  height: 1.1,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.roboto(
                  fontSize: 12,
                  color: AppColors.greyText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
            Expanded(
              child: Text(
                'Recent Activity',
                style: AppTypography.raleway(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
            ),
            TextButton(
              onPressed: _openRecords,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: const Text('View All >'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_isLoggedIn)
          _whiteCard(
            child: Text(
              'Login to see your recent activity.',
              style: AppTypography.roboto(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
          )
        else if (_recentActivity.isEmpty)
          _whiteCard(
            child: Text(
              'No recent activity yet.',
              style: AppTypography.roboto(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
          )
        else
          ..._recentActivity.map(_buildActivityTile),
      ],
    );
  }

  Widget _buildActivityTile(_RecentActivityItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _openRecords,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.raleway(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.timestamp,
                      style: AppTypography.roboto(
                        fontSize: 11,
                        color: AppColors.greyText,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.greyText, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softRed.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: AppColors.primaryRed,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Assistance',
                  style: AppTypography.raleway(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Need urgent medical help? We're here for you 24/7",
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.greyText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _callEmergency,
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('Call Emergency'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: AppTypography.raleway(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child, bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: AppColors.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: compact ? 8 : 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _navItem(Icons.home_rounded, 'Summary', 0),
              _navItem(Icons.medical_services_outlined, 'Doctors', 1),
              _navItem(Icons.calendar_today_outlined, 'Appointments', 2),
              _navItem(Icons.folder_copy_outlined, 'Records', 3),
              _navItem(Icons.receipt_long_outlined, 'Billing', 4),
            ],
          ),
        ),
      ),
    );
  }

  Expanded _navItem(IconData icon, String label, int index) {
    final isSelected = index == _summaryNavIndex;
    return Expanded(
      child: TapFeedback(
        onTap: () => _onBottomNavSelected(index),
        borderRadius: BorderRadius.circular(12),
        highlightColor: AppColors.lightMaroon.withValues(alpha: 0.6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.softRed.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primaryRed : AppColors.greyText,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.roboto(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryRed : AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}