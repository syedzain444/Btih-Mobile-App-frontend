import 'package:btih_andriod_app/screens/billing/payment_qr_screen.dart';
import 'package:btih_andriod_app/services/payment_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a payment QR and shows the linked appointment details.
class PaymentQrScanScreen extends StatefulWidget {
  const PaymentQrScanScreen({super.key});

  @override
  State<PaymentQrScanScreen> createState() => _PaymentQrScanScreenState();
}

class _PaymentQrScanScreenState extends State<PaymentQrScanScreen> {
  final _paymentService = PaymentService();
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _handling = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    setState(() {
      _handling = true;
      _error = null;
    });

    try {
      await _controller.stop();
      final resolved = await _paymentService.resolveQr(raw);
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _ResolvedSheet(
          resolved: resolved,
          onViewQr: () {
            Navigator.pop(ctx);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentQrScreen(
                  intent: PaymentIntent(
                    paymentId: resolved.paymentId,
                    mrNo: resolved.appointment?.mrNo ?? '',
                    billId: resolved.billId,
                    invoiceNo: resolved.invoiceNo,
                    amount: resolved.amount,
                    currency: resolved.currency,
                    status: resolved.status,
                    checkoutUrl: resolved.checkoutUrl,
                    gatewayRef: resolved.gatewayRef,
                    qrToken: resolved.qrToken,
                    qrPayload: resolved.qrPayload,
                    appointment: resolved.appointment,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _handling = false);
        try {
          await _controller.start();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppAppBar(
        title: Text(
          'Scan payment QR',
          style: AppTypography.raleway(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.qr_code_scanner_rounded),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              color: Colors.black.withValues(alpha: 0.55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _handling
                        ? 'Resolving appointment details…'
                        : 'Point the camera at a BTIH payment QR',
                    textAlign: TextAlign.center,
                    style: AppTypography.roboto(
                      fontSize: 13,
                      color: AppColors.white,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: const Color(0xFFFFCDD2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedSheet extends StatelessWidget {
  final PaymentQrResolve resolved;
  final VoidCallback onViewQr;

  const _ResolvedSheet({
    required this.resolved,
    required this.onViewQr,
  });

  @override
  Widget build(BuildContext context) {
    final appt = resolved.appointment;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Appointment from payment QR',
            style: AppTypography.raleway(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 12),
          if (appt == null || !appt.hasDetails)
            Text(
              'Payment #${resolved.paymentId} resolved, but no appointment is linked.',
              style: AppTypography.roboto(fontSize: 13, color: AppColors.greyText),
            )
          else ...[
            _row('Doctor', appt.doctorName ?? '—'),
            _row('Slot', appt.appointmentTime ?? '—'),
            _row('Specialty', appt.departmentHint ?? '—'),
            _row('Status', appt.status ?? '—'),
            if (appt.purpose?.isNotEmpty == true) _row('Purpose', appt.purpose!),
            if (appt.appointmentId?.isNotEmpty == true)
              _row('Appointment ID', appt.appointmentId!),
          ],
          const SizedBox(height: 10),
          _row('Amount due', formatBillingCurrency(resolved.amount)),
          _row('Payment status', resolved.status),
          const SizedBox(height: 16),
          TapFeedback(
            onTap: onViewQr,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'View payment QR',
                style: AppTypography.raleway(
                  fontSize: 14,
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.roboto(fontSize: 12, color: AppColors.greyText),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
}
