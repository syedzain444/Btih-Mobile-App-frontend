import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/screens/billing/invoice_detail_screen.dart';
import 'package:btih_andriod_app/services/billing_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

enum _PaymentTab { pending, recent }

class PaymentScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;

  const PaymentScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final BillingService _billingService = BillingService();
  BillingPaymentSummary? _summary;
  _PaymentTab _selectedTab = _PaymentTab.pending;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showAmounts = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary =
          await _billingService.getPaymentSummary(widget.patientMrNo);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
        if (summary.pendingBillCount == 0 && summary.recentPayments.isNotEmpty) {
          _selectedTab = _PaymentTab.recent;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load payment information. Pull to retry.';
      });
    }
  }

  void _openInvoice(PatientReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(
          patientMrNo: widget.patientMrNo,
          initialReport: report,
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
            'Payments',
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
        AppBarIconBadge(icon: Icons.payments_outlined),
      ],
    );
  }

  Widget _buildSummaryCard(BillingPaymentSummary summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.deepRed, AppColors.primaryRed],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryRed.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pending Balance',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      color: AppColors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                TapFeedback(
                  onTap: () => setState(() => _showAmounts = !_showAmounts),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _showAmounts
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _showAmounts
                  ? formatBillingCurrency(summary.totalPendingAmount)
                  : 'Rs. ******',
              style: AppTypography.montserrat(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Pending bills',
                    value: '${summary.pendingBillCount}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: AppColors.white.withValues(alpha: 0.25),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Paid Total',
                    value: _showAmounts
                        ? formatBillingCurrency(summary.totalPaidAmount)
                        : 'Rs. *****',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.softRed,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppColors.primaryRed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Online payment is not available yet. Please visit the hospital billing counter to settle pending bills.',
                style: AppTypography.roboto(
                  fontSize: 13,
                  color: AppColors.darkText,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(BillingPaymentSummary summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabChip(
                label: 'Pending (${summary.pendingBillCount})',
                selected: _selectedTab == _PaymentTab.pending,
                onTap: () => setState(() => _selectedTab = _PaymentTab.pending),
              ),
            ),
            Expanded(
              child: _TabChip(
                label: 'Recent (${summary.recentPayments.length})',
                selected: _selectedTab == _PaymentTab.recent,
                onTap: () => setState(() => _selectedTab = _PaymentTab.recent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillList() {
    final summary = _summary!;
    final isPending = _selectedTab == _PaymentTab.pending;
    final bills =
        isPending ? summary.pendingBills : summary.recentPayments;

    if (bills.isEmpty) {
      return _EmptyState(
        icon: isPending
            ? Icons.check_circle_outline_rounded
            : Icons.receipt_long_outlined,
        title: isPending ? 'No pending payments' : 'No recent payments',
        subtitle: isPending
            ? 'All your bills are settled.'
            : 'Your paid bills will appear here.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: bills.length,
      separatorBuilder: (_, _2) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _PaymentBillTile(
          report: bills[index],
          isPending: isPending,
          showAmount: _showAmounts,
          onTap: () => _openInvoice(bills[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppColors.greyText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTypography.roboto(
                            fontSize: 14,
                            color: AppColors.greyText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSummary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepRed,
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primaryRed,
                  onRefresh: _loadSummary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      _buildSummaryCard(_summary!),
                      _buildInfoBanner(),
                      _buildTabSelector(_summary!),
                      _buildBillList(),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.roboto(
              fontSize: 12,
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryRed : AppColors.greyText,
          ),
        ),
      ),
    );
  }
}

class _PaymentBillTile extends StatelessWidget {
  final PatientReport report;
  final bool isPending;
  final bool showAmount;
  final VoidCallback onTap;

  const _PaymentBillTile({
    required this.report,
    required this.isPending,
    required this.showAmount,
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
    if (isPending) {
      return report.balanceAmount ?? report.amount;
    }
    return report.amount;
  }

  @override
  Widget build(BuildContext context) {
    final dept = BillingDepartments.byCode(report.filterDepartmentCode);
    final accent = dept?.gradient.first ?? AppColors.primaryRed;
    final dateLabel = isPending
        ? (report.visitDate?.isNotEmpty == true
            ? 'Visit ${_formatDate(report.visitDate!)}'
            : 'Bill #${report.billId}')
        : 'Paid ${_formatDate(report.paymentDate)}';

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
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
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                dept?.icon ?? Icons.receipt_outlined,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
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
                  showAmount
                      ? formatBillingCurrency(_displayAmount)
                      : 'Rs. ****',
                  style: AppTypography.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isPending
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppColors.softRed
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? 'Pending' : 'Paid',
                    style: AppTypography.roboto(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPending
                          ? AppColors.primaryRed
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.greyText,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        children: [
          Icon(
            icon,
            size: 56,
            color: AppColors.greyText.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTypography.raleway(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}
