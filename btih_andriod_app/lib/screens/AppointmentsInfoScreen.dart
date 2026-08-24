import 'dart:convert';

import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/dashboard_helpers.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AppointmentsInfoScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;

  const AppointmentsInfoScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
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

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/Patient/appointments/${widget.patientMrNo}',
      );

      final response = await http.get(
        url,
        headers: {'accept': '*/*'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allAppointments =
              data.map((json) => Appointment.fromJson(json)).toList();
          _splitAppointments();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load appointments');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
      default:
        return AppColors.fieldFill;
    }
  }

  List<Appointment> get _visibleAppointments =>
      _selectedTabIndex == 0 ? _upcomingAppointments : _pastAppointments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.deepRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appointments',
          style: AppTypography.raleway(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,

          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
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
          onTap: () {},
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
      purpose: json['purpose'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
