import 'package:btih_andriod_app/screens/dashboard_screen.dart';
import 'package:btih_andriod_app/widgets/patient_bottom_nav_bar.dart';
import 'package:flutter/material.dart';

/// Entry shell — dashboard is the home screen with bottom navigation.
/// Other sections open as pushed routes with a header back button.
class PatientMainShell extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final bool isLoggedIn;
  final int initialTabIndex;

  const PatientMainShell({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.isLoggedIn = false,
    this.initialTabIndex = PatientBottomNavBar.dashboardIndex,
  });

  @override
  State<PatientMainShell> createState() => _PatientMainShellState();
}

class _PatientMainShellState extends State<PatientMainShell> {
  late bool _isLoggedIn;
  late String _patientName;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
    _patientName = widget.patientName;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(
      patientMrNo: widget.patientMrNo,
      patientName: _patientName,
      isLoggedIn: _isLoggedIn,
      initialTabIndex: widget.initialTabIndex,
      onLoginStateChanged: (loggedIn) {
        if (mounted) setState(() => _isLoggedIn = loggedIn);
      },
      onPatientNameChanged: (name) {
        if (mounted) setState(() => _patientName = name);
      },
    );
  }
}
