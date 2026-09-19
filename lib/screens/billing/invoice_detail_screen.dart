import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/services/billing_pdf_service.dart';
import 'package:btih_andriod_app/services/billing_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:flutter/material.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String patientMrNo;
  final PatientReport initialReport;

  const InvoiceDetailScreen({
    super.key,
    required this.patientMrNo,
    required this.initialReport,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final BillingService _billingService = BillingService();
  late PatientReport _report;
  bool _isLoading = true;
  bool _isPdfBusy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    if (widget.initialReport.billId.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final invoice = await _billingService.getInvoice(
        mrNo: widget.patientMrNo,
        billId: widget.initialReport.billId,
      );
      if (!mounted) return;
      setState(() {
        _report = invoice;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not refresh invoice details.';
      });
    }
  }

  int get _reportId {
    if (_report.reportId != null) return _report.reportId!;
    return BillingDepartments.byCode(_report.filterDepartmentCode)?.rptId ??
        26;
  }

  bool get _isPending =>
      _report.paymentStatus?.toLowerCase() == 'pending' ||
      (_report.paymentDate.isEmpty && _report.isCancel != true);

  bool get _isCancelled => _report.isCancel == true;

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    try {
      final date = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $period';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _viewPdf() async {
    if (_isPdfBusy || _report.billId.isEmpty) return;
    setState(() => _isPdfBusy = true);
    await BillingPdfService.viewInApp(
      context,
      rptId: _reportId,
      billId: _report.billId,
      title: 'Invoice ${_report.invoiceNo.isNotEmpty ? _report.invoiceNo : _report.billId}',
    );
    if (mounted) setState(() => _isPdfBusy = false);
  }

  Future<void> _downloadPdf() async {
    if (_isPdfBusy || _report.billId.isEmpty) return;
    setState(() => _isPdfBusy = true);
    await BillingPdfService.downloadToDevice(
      context,
      rptId: _reportId,
      billId: _report.billId,
      fileName: 'Invoice_${_report.billId}.pdf',
    );
    if (mounted) setState(() => _isPdfBusy = false);
  }

  Widget _buildStatusBadge() {
    final String label;
    final Color bg;
    final Color fg;

    if (_isCancelled) {
      label = 'Cancelled';
      bg = AppColors.fieldFill;
      fg = AppColors.greyText;
    } else if (_isPending) {
      label = 'Pending';
      bg = AppColors.softRed;
      fg = AppColors.primaryRed;
    } else {
      label = 'Paid';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dept = BillingDepartments.byCode(_report.filterDepartmentCode);
    final accent = dept?.gradient.first ?? AppColors.primaryRed;
    final pendingAmount = _report.balanceAmount ?? _report.amount;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Invoice Details',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryRed),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.fieldBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  dept?.icon ?? Icons.receipt_long_outlined,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _report.formattedDepartment,
                                      style: AppTypography.raleway(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                    Text(
                                      'Bill #${_report.billId}',
                                      style: AppTypography.roboto(
                                        fontSize: 13,
                                        color: AppColors.greyText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            formatBillingCurrency(
                              _isPending ? pendingAmount : _report.amount,
                            ),
                            style: AppTypography.montserrat(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: _isPending
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: AppTypography.roboto(
                                fontSize: 12,
                                color: AppColors.greyText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.fieldBorder),
                      ),
                      child: Column(
                        children: [
                          _detailRow(
                            'Invoice No',
                            _report.invoiceNo.isNotEmpty
                                ? _report.invoiceNo
                                : '--',
                          ),
                          const Divider(height: 1, color: AppColors.fieldBorder),
                          _detailRow(
                            'Visit Date',
                            _formatDate(_report.visitDate),
                          ),
                          const Divider(height: 1, color: AppColors.fieldBorder),
                          _detailRow(
                            'Payment Date',
                            _formatDate(
                              _report.paymentDate.isEmpty
                                  ? null
                                  : _report.paymentDate,
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.fieldBorder),
                          _detailRow(
                            'Payment Method',
                            _report.paymentMethod?.isNotEmpty == true
                                ? _report.paymentMethod!
                                : '--',
                          ),
                          if (_report.paidAmount != null) ...[
                            const Divider(height: 1, color: AppColors.fieldBorder),
                            _detailRow(
                              'Paid Amount',
                              formatBillingCurrency(_report.paidAmount!),
                            ),
                          ],
                          if (_report.balanceAmount != null &&
                              _report.balanceAmount! > 0) ...[
                            const Divider(height: 1, color: AppColors.fieldBorder),
                            _detailRow(
                              'Balance Due',
                              formatBillingCurrency(_report.balanceAmount!),
                            ),
                          ],
                          if (_isCancelled &&
                              _report.cancelReason?.isNotEmpty == true) ...[
                            const Divider(height: 1, color: AppColors.fieldBorder),
                            _detailRow('Cancel Reason', _report.cancelReason!),
                          ],
                        ],
                      ),
                    ),
                    if (_isPending) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.softRed,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryRed.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_balance_outlined,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Visit the hospital billing counter with this invoice to complete payment.',
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
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isPdfBusy ? null : _downloadPdf,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: const BorderSide(color: AppColors.primaryRed),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isPdfBusy ? null : _viewPdf,
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('View PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          if (_isPdfBusy)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              ),
            ),
        ],
      ),
    );
  }
}
