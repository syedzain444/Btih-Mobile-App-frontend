import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/screens/billing/recent_payments_screen.dart';
import 'package:btih_andriod_app/screens/department_bills_screen.dart';
import 'package:btih_andriod_app/services/billing_service.dart';
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
  BillingPaymentSummary? _paymentSummary;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    try {
      BillingService().invalidateHistoryCache(widget.patientMrNo);
      final history =
          await _reportService.getPatientReportHistory(widget.patientMrNo);
      if (!mounted) return;

      final summary = BillingPaymentSummary.fromReports(
        mrNo: widget.patientMrNo,
        reports: history,
      );

      setState(() {
        allReports = history;
        _paymentSummary = summary;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> loadReportHistory() async {
    try {
      final reports =
          await _reportService.getPatientReportHistory(widget.patientMrNo);
      if (!mounted) return;
      final summary = BillingPaymentSummary.fromReports(
        mrNo: widget.patientMrNo,
        reports: reports,
      );
      setState(() {
        allReports = reports;
        _paymentSummary = summary;
      });
    } catch (_) {}
  }

  List<PatientReport> _reportsForDepartment(String code) {
    return allReports
        .where((report) => report.filterDepartmentCode == code.toUpperCase())
        .toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
  }

  double get _grandTotal =>
      allReports.fold(0, (sum, item) => sum + item.amount);

  void _openDepartment(BillingDepartment department) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepartmentBillsScreen(
          patientMrNo: widget.patientMrNo,
          department: department,
          reports: _reportsForDepartment(department.code),
        ),
      ),
    );
  }

  void _openRecentPayments() {
    final summary = _paymentSummary;
    if (summary == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecentPaymentsScreen(
          patientMrNo: widget.patientMrNo,
          summary: summary,
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
            'Billing',
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

  Widget _buildSectionLabel(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing,
              style: AppTypography.roboto(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDepartmentGrid() {
    final departments = BillingDepartments.departments;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const crossAxisCount = 2;
          const spacing = 10.0;
          final tileWidth =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final department in departments)
                SizedBox(
                  width: tileWidth,
                  child: _DepartmentTile(
                    department: department,
                    billCount: _reportsForDepartment(department.code).length,
                    onTap: () => _openDepartment(department),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentPaymentsLink() {
    final summary = _paymentSummary;
    final pendingCount = summary?.pendingBillCount ?? 0;
    final recentCount = summary?.recentPayments.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: TapFeedback(
        onTap: summary == null ? null : _openRecentPayments,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Payments',
                      style: AppTypography.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pendingCount pending · $recentCount recent',
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'View',
                style: AppTypography.raleway(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryRed,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: _loadAll,
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
                  _buildRecentPaymentsLink(),
                  _buildSectionLabel(
                    'Departments',
                    trailing: '${BillingDepartments.departments.length} areas',
                  ),
                  _buildDepartmentGrid(),
                ],
              ),
            ),
    );
  }
}

class _DepartmentTile extends StatelessWidget {
  final BillingDepartment department;
  final int billCount;
  final VoidCallback onTap;

  const _DepartmentTile({
    required this.department,
    required this.billCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = department.gradient.first;

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(department.icon, color: accent, size: 18),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$billCount',
                    style: AppTypography.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              department.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              department.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.roboto(
                fontSize: 11,
                color: AppColors.greyText,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

