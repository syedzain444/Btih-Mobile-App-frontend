import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/screens/department_bills_screen.dart';
import 'package:btih_andriod_app/services/patient_report_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/billing/billing_amount_card.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class PatientReportHistoryScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final bool isLoggedIn;

  const PatientReportHistoryScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.isLoggedIn = false,
  });

  @override
  State<PatientReportHistoryScreen> createState() =>
      _PatientReportHistoryScreenState();
}

class _PatientReportHistoryScreenState extends State<PatientReportHistoryScreen> {
  final PatientReportService _reportService = PatientReportService();
  List<PatientReport> allReports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadReportHistory();
  }

  Future<void> loadReportHistory() async {
    try {
      final reports =
          await _reportService.getPatientReportHistory(widget.patientMrNo);
      if (!mounted) return;
      setState(() {
        allReports = reports;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  List<PatientReport> _reportsForDepartment(String code) {
    return allReports
        .where((report) => report.department.toUpperCase() == code)
        .toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
  }

  double get _grandTotal =>
      allReports.fold(0, (sum, item) => sum + item.amount);

  int get _departmentCount => BillingDepartments.departments.length;

  void _openDepartment(BillingDepartment department) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepartmentBillsScreen(
          department: department,
          reports: _reportsForDepartment(department.code),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppAppBar(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Patient Reports',
            style: AppTypography.raleway(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'MR No: ${widget.patientMrNo}',
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
      actions: const [
        AppBarIconBadge(icon: Icons.receipt_long_outlined),
      ],
    );
  }

  Widget _buildDepartmentsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            'Departments',
            style: AppTypography.raleway(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const Spacer(),
          Text(
            '$_departmentCount',
            style: AppTypography.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentRow({
    required BillingDepartment department,
    required int count,
    required bool showDivider,
  }) {
    final accent = department.gradient.first;

    return Column(
      children: [
        TapFeedback(
          onTap: () => _openDepartment(department),
          borderRadius: BorderRadius.zero,
          materialColor: AppColors.softRed.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    department.icon,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              department.name,
                              style: AppTypography.raleway(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          Text(
                            '$count',
                            style: AppTypography.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.greyText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        department.subtitle,
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: AppColors.greyText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.fieldBorder.withValues(alpha: 0.9),
            indent: 74,
          ),
      ],
    );
  }

  Widget _buildDepartmentList() {
    final departments = BillingDepartments.departments;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < departments.length; i++)
              _buildDepartmentRow(
                department: departments[i],
                count: _reportsForDepartment(departments[i].code).length,
                showDivider: i < departments.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: loadReportHistory,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  BillingAmountCard(
                    billCount: allReports.length,
                    totalAmount: _grandTotal,
                  ),
                  _buildDepartmentsHeader(),
                  _buildDepartmentList(),
                ],
              ),
            ),
    );
  }
}
