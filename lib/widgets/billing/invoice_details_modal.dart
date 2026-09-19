import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/services/billing_pdf_service.dart';
import 'package:btih_andriod_app/services/billing_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:flutter/material.dart';

/// Centered invoice details dialog with Download / View PDF actions.
Future<void> showInvoiceDetailsModal({
  required BuildContext context,
  required String patientMrNo,
  required PatientReport report,
  required int rptId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _InvoiceDetailsDialog(
      patientMrNo: patientMrNo,
      initialReport: report,
      rptId: rptId,
    ),
  );
}

class _InvoiceDetailsDialog extends StatefulWidget {
  final String patientMrNo;
  final PatientReport initialReport;
  final int rptId;

  const _InvoiceDetailsDialog({
    required this.patientMrNo,
    required this.initialReport,
    required this.rptId,
  });

  @override
  State<_InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends State<_InvoiceDetailsDialog> {
  final BillingService _billingService = BillingService();
  late PatientReport _report;
  bool _refreshing = false;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    _refreshInvoice();
  }

  Future<void> _refreshInvoice() async {
    if (_report.billId.isEmpty) return;
    setState(() => _refreshing = true);
    try {
      final invoice = await _billingService.getInvoice(
        mrNo: widget.patientMrNo,
        billId: _report.billId,
      );
      if (!mounted) return;
      setState(() {
        _report = invoice;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _refreshing = false);
    }
  }

  int get _effectiveRptId =>
      _report.reportId ?? widget.rptId;

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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _viewPdf() async {
    if (_pdfBusy || _report.billId.isEmpty) return;
    setState(() => _pdfBusy = true);
    await BillingPdfService.viewInApp(
      context,
      rptId: _effectiveRptId,
      billId: _report.billId,
      title:
          'Invoice ${_report.invoiceNo.isNotEmpty ? _report.invoiceNo : _report.billId}',
    );
    if (mounted) setState(() => _pdfBusy = false);
  }

  Future<void> _downloadPdf() async {
    if (_pdfBusy || _report.billId.isEmpty) return;
    setState(() => _pdfBusy = true);
    await BillingPdfService.downloadToDevice(
      context,
      rptId: _effectiveRptId,
      billId: _report.billId,
      fileName: 'Invoice_${_report.billId}.pdf',
    );
    if (mounted) setState(() => _pdfBusy = false);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.roboto(
                fontSize: 12,
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
                fontSize: 13,
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
    final accent = dept?.gradient.first ?? AppColors.deepRed;
    final amount = _isPending
        ? (_report.balanceAmount ?? _report.amount)
        : _report.amount;

    final statusLabel = _isCancelled
        ? 'Cancelled'
        : (_isPending ? 'Pending' : 'Paid');
    final statusColor = _isCancelled
        ? AppColors.greyText
        : (_isPending ? AppColors.primaryRed : AppColors.deepRed);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Invoice Details',
                          style: AppTypography.raleway(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.duskMaroon,
                          ),
                        ),
                      ),
                      if (_refreshing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.deepRed,
                          ),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  dept?.icon ?? Icons.receipt_long_outlined,
                                  color: accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _report.formattedDepartment,
                                      style: AppTypography.raleway(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                    Text(
                                      'Bill #${_report.billId}',
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
                                  color: AppColors.fieldFill,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: AppTypography.roboto(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            formatBillingCurrency(amount),
                            style: AppTypography.montserrat(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.duskMaroon,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.fieldBorder),
                          _row(
                            'Invoice No',
                            _report.invoiceNo.isNotEmpty
                                ? _report.invoiceNo
                                : '--',
                          ),
                          const Divider(height: 1, color: AppColors.fieldBorder),
                          _row('Visit Date', _formatDate(_report.visitDate)),
                          const Divider(height: 1, color: AppColors.fieldBorder),
                          _row(
                            'Payment Date',
                            _formatDate(
                              _report.paymentDate.isEmpty
                                  ? null
                                  : _report.paymentDate,
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.fieldBorder),
                          _row(
                            'Payment Method',
                            _report.paymentMethod?.isNotEmpty == true
                                ? _report.paymentMethod!
                                : '--',
                          ),
                          if (_report.paidAmount != null) ...[
                            const Divider(
                                height: 1, color: AppColors.fieldBorder),
                            _row(
                              'Paid Amount',
                              formatBillingCurrency(_report.paidAmount!),
                            ),
                          ],
                          if (_report.balanceAmount != null &&
                              _report.balanceAmount! > 0) ...[
                            const Divider(
                                height: 1, color: AppColors.fieldBorder),
                            _row(
                              'Balance Due',
                              formatBillingCurrency(_report.balanceAmount!),
                            ),
                          ],
                          if (_isCancelled &&
                              _report.cancelReason?.isNotEmpty == true) ...[
                            const Divider(
                                height: 1, color: AppColors.fieldBorder),
                            _row('Cancel Reason', _report.cancelReason!),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pdfBusy ? null : _downloadPdf,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.deepRed,
                            side: const BorderSide(color: AppColors.deepRed),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pdfBusy ? null : _viewPdf,
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text('View PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_pdfBusy)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.deepRed),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
