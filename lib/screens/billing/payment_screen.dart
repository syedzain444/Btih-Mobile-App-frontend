import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/services/billing_service.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/services/payment_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pay Now screen — pending bills, checkout initiate/confirm, online history.
class PaymentScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;

  const PaymentScreen({
    super.key,
    required this.patientMrNo,
    this.patientName = '',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _paidGreen = Color(0xFF2E7D32);

  final BillingService _billingService = BillingService();
  final PaymentService _paymentService = PaymentService();

  BillingPaymentSummary? _summary;
  List<PaymentIntent> _onlineHistory = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _payingBillKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary =
          await _billingService.getPaymentSummary(widget.patientMrNo);
      List<PaymentIntent> history = const [];
      try {
        history = await _paymentService.getHistory(widget.patientMrNo);
      } catch (_) {
        // Online history is optional if the table is not seeded yet.
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _onlineHistory = history;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load payment information. Pull to retry.';
      });
    }
  }

  Future<void> _payBill(PatientReport bill) async {
    final amount = (bill.balanceAmount != null && bill.balanceAmount! > 0)
        ? bill.balanceAmount!
        : bill.amount;
    if (amount <= 0) {
      _toast('Nothing due on this bill.');
      return;
    }

    setState(() => _payingBillKey = bill.billId.hashCode);

    try {
      final intent = await _paymentService.initiate(
        mrNo: widget.patientMrNo,
        amount: amount,
        billId: bill.billId,
        invoiceNo: bill.invoiceNo,
      );

      if (!mounted) return;

      final checkout = intent.checkoutUrl;
      if (checkout != null && checkout.isNotEmpty) {
        final uri = Uri.tryParse(checkout);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (!mounted) return;
      final shouldConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Confirm payment',
            style: AppTypography.raleway(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          content: Text(
            'Complete payment in the browser, then tap Confirm.\n\n'
            'Amount: ${formatBillingCurrency(amount)}\n'
            'Ref: ${intent.gatewayRef ?? intent.paymentId}',
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: AppTypography.raleway(
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyText,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Confirm',
                style: AppTypography.raleway(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldConfirm != true) {
        if (mounted) setState(() => _payingBillKey = null);
        return;
      }

      final confirmed = await _paymentService.confirm(
        paymentId: intent.paymentId,
        gatewayRef: intent.gatewayRef,
      );

      if (!mounted) return;

      await NotificationService.instance.notifyPaymentConfirmed(
        mrNo: widget.patientMrNo,
        amount: formatBillingCurrency(confirmed.amount),
        reference: confirmed.invoiceNo ?? bill.invoiceNo,
      );

      _toast('Payment confirmed successfully.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _payingBillKey = null);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Pay Now',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.payments_outlined),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: _load,
              child: _errorMessage != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: AppTypography.roboto(
                                fontSize: 14,
                                color: AppColors.greyText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    final summary = _summary!;
    final pending = summary.pendingBills;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _PendingSummaryCard(summary: summary),
        const SizedBox(height: 20),
        Text(
          'Pending bills',
          style: AppTypography.raleway(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          pending.isEmpty
              ? 'No outstanding balance right now.'
              : 'Select a bill to open checkout and confirm payment.',
          style: AppTypography.roboto(
            fontSize: 12,
            color: AppColors.greyText,
          ),
        ),
        const SizedBox(height: 12),
        if (pending.isEmpty)
          _EmptyHint(
            icon: Icons.check_circle_outline,
            message: 'You are all settled up.',
          )
        else
          ...pending.map(
            (bill) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PendingBillTile(
                bill: bill,
                isPaying: _payingBillKey == bill.billId.hashCode,
                onPay: () => _payBill(bill),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'Online payments',
          style: AppTypography.raleway(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Checkout payments started from this app',
          style: AppTypography.roboto(
            fontSize: 12,
            color: AppColors.greyText,
          ),
        ),
        const SizedBox(height: 12),
        if (_onlineHistory.isEmpty)
          const _EmptyHint(
            icon: Icons.receipt_long_outlined,
            message: 'No online payment intents yet.',
          )
        else
          ..._onlineHistory.map(
            (intent) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OnlinePaymentTile(intent: intent, paidGreen: _paidGreen),
            ),
          ),
      ],
    );
  }
}

class _PendingSummaryCard extends StatelessWidget {
  final BillingPaymentSummary summary;

  const _PendingSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryRed, AppColors.deepRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRed.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount due',
            style: AppTypography.roboto(
              fontSize: 12,
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatBillingCurrency(summary.totalPendingAmount),
            style: AppTypography.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.pendingBillCount} pending · '
            '${summary.paidBillCount} paid',
            style: AppTypography.roboto(
              fontSize: 12,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBillTile extends StatelessWidget {
  final PatientReport bill;
  final bool isPaying;
  final VoidCallback onPay;

  const _PendingBillTile({
    required this.bill,
    required this.isPaying,
    required this.onPay,
  });

  double get _amount {
    if (bill.balanceAmount != null && bill.balanceAmount! > 0) {
      return bill.balanceAmount!;
    }
    return bill.amount;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.softRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
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
                  bill.formattedDepartment,
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bill.invoiceNo.isNotEmpty
                      ? 'Invoice ${bill.invoiceNo}'
                      : 'Bill ${bill.billId}',
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatBillingCurrency(_amount),
                  style: AppTypography.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
              ],
            ),
          ),
          TapFeedback(
            onTap: isPaying ? null : onPay,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: isPaying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      'Pay',
                      style: AppTypography.raleway(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlinePaymentTile extends StatelessWidget {
  final PaymentIntent intent;
  final Color paidGreen;

  const _OnlinePaymentTile({
    required this.intent,
    required this.paidGreen,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = intent.isPaid;
    final statusColor = isPaid ? paidGreen : AppColors.primaryRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intent.invoiceNo?.isNotEmpty == true
                      ? 'Invoice ${intent.invoiceNo}'
                      : 'Payment #${intent.paymentId}',
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  intent.gatewayRef ?? intent.status,
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
                formatBillingCurrency(intent.amount),
                style: AppTypography.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                intent.status,
                style: AppTypography.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}
