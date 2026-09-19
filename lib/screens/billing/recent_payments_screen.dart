import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/services/billing_service.dart';
import 'package:btih_andriod_app/services/recent_activity_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/billing/invoice_details_modal.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Pending / Recent payments with swipeable tabs (max 10 each).
class RecentPaymentsScreen extends StatefulWidget {
  final String patientMrNo;
  final BillingPaymentSummary summary;

  const RecentPaymentsScreen({
    super.key,
    required this.patientMrNo,
    required this.summary,
  });

  @override
  State<RecentPaymentsScreen> createState() => _RecentPaymentsScreenState();
}

class _RecentPaymentsScreenState extends State<RecentPaymentsScreen> {
  late final PageController _pageController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final summary = widget.summary;
    if (summary.pendingBillCount == 0 && summary.recentPayments.isNotEmpty) {
      _selectedTabIndex = 1;
    }
    _pageController = PageController(initialPage: _selectedTabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openPaymentModal(PatientReport report, {required bool isPending}) async {
    final dept = BillingDepartments.byCode(report.filterDepartmentCode);
    RecentActivityService.instance.trackBill(
      scopeId: RecentActivityService.instance.resolveScope(
        patientMrNo: widget.patientMrNo,
      ),
      report: report.toJson(),
      departmentCode: report.filterDepartmentCode,
      departmentName: dept?.name ?? report.formattedDepartment,
      rptId: report.reportId ?? dept?.rptId ?? 0,
    );

    await showInvoiceDetailsModal(
      context: context,
      patientMrNo: widget.patientMrNo,
      report: report,
      rptId: report.reportId ?? dept?.rptId ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final pending = summary.pendingBills.take(10).toList();
    final recent = summary.recentPayments.take(10).toList();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Pending (${pending.length})',
                    selected: _selectedTabIndex == 0,
                    onTap: () => _selectTab(0),
                  ),
                  _TabButton(
                    label: 'Recent (${recent.length})',
                    selected: _selectedTabIndex == 1,
                    onTap: () => _selectTab(1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (_selectedTabIndex == index) return;
                setState(() => _selectedTabIndex = index);
              },
              children: [
                _PaymentsList(
                  bills: pending,
                  isPending: true,
                  emptyTitle: 'No pending payments',
                  emptySubtitle: 'All your bills are settled.',
                  onTap: (report) =>
                      _openPaymentModal(report, isPending: true),
                ),
                _PaymentsList(
                  bills: recent,
                  isPending: false,
                  emptyTitle: 'No recent payments',
                  emptySubtitle: 'Your paid bills will appear here.',
                  onTap: (report) =>
                      _openPaymentModal(report, isPending: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _PaymentsList extends StatelessWidget {
  final List<PatientReport> bills;
  final bool isPending;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<PatientReport> onTap;

  const _PaymentsList({
    required this.bills,
    required this.isPending,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPending
                    ? Icons.check_circle_outline_rounded
                    : Icons.receipt_long_outlined,
                size: 56,
                color: AppColors.greyText.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 14),
              Text(
                emptyTitle,
                style: AppTypography.raleway(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.roboto(
                  fontSize: 13,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: bills.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        color: AppColors.hairline,
      ),
      itemBuilder: (context, index) {
        final report = bills[index];
        return _PaymentRow(
          report: report,
          isPending: isPending,
          onTap: () => onTap(report),
        );
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PatientReport report;
  final bool isPending;
  final VoidCallback onTap;

  const _PaymentRow({
    required this.report,
    required this.isPending,
    required this.onTap,
  });

  String _formatDate(String raw) {
    if (raw.isEmpty) return '--';
    try {
      final date = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return raw;
    }
  }

  double get _displayAmount {
    if (isPending) return report.balanceAmount ?? report.amount;
    return report.amount;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = isPending
        ? (report.visitDate?.isNotEmpty == true
            ? 'Visit ${_formatDate(report.visitDate!)}'
            : 'Bill #${report.billId}')
        : 'Paid ${_formatDate(report.paymentDate)}';

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.formattedDepartment,
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Invoice ${report.invoiceNo.isNotEmpty ? report.invoiceNo : report.billId}',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatBillingCurrency(_displayAmount),
                  style: AppTypography.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPending ? 'Pending' : 'Paid',
                  style: AppTypography.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPending
                        ? AppColors.primaryRed
                        : AppColors.medsTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.greyText.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
