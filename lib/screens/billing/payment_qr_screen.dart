import 'dart:convert';

import 'package:btih_andriod_app/services/payment_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the online-payment QR and linked appointment details after initiate.
class PaymentQrScreen extends StatelessWidget {
  final PaymentIntent intent;
  final Future<void> Function()? onConfirmPaid;

  const PaymentQrScreen({
    super.key,
    required this.intent,
    this.onConfirmPaid,
  });

  @override
  Widget build(BuildContext context) {
    final payload = intent.qrPayload ??
        (intent.qrToken != null
            ? 'btihapp://payment/qr/${intent.qrToken}'
            : intent.checkoutUrl ?? '');
    final appt = intent.appointment;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Payment QR',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.qr_code_2_rounded),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Scan to view appointment details',
            style: AppTypography.raleway(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This QR is linked to your online payment. Scanning it returns the appointment details for this visit.',
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.greyText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.fieldBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRed.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: payload.isEmpty
                  ? const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(child: Text('QR unavailable')),
                    )
                  : _QrVisual(
                      payload: payload,
                      base64Png: intent.qrImageBase64,
                    ),
            ),
          ),
          const SizedBox(height: 18),
          _InfoCard(
            title: 'Payment',
            rows: [
              ('Amount', formatBillingCurrency(intent.amount)),
              ('Status', intent.status),
              if (intent.invoiceNo?.isNotEmpty == true)
                ('Invoice', intent.invoiceNo!),
              if (intent.gatewayRef?.isNotEmpty == true)
                ('Ref', intent.gatewayRef!),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Appointment details',
            rows: appt == null || !appt.hasDetails
                ? const [
                    (
                      'Note',
                      'No active appointment was linked. Book or confirm an appointment to attach details to this QR.'
                    ),
                  ]
                : [
                    if (appt.appointmentId?.isNotEmpty == true)
                      ('ID', appt.appointmentId!),
                    if (appt.patientName?.isNotEmpty == true)
                      ('Patient', appt.patientName!),
                    if (appt.doctorName?.isNotEmpty == true)
                      ('Doctor', appt.doctorName!),
                    if (appt.appointmentTime?.isNotEmpty == true)
                      ('Slot', appt.appointmentTime!),
                    if (appt.departmentHint?.isNotEmpty == true)
                      ('Specialty', appt.departmentHint!),
                    if (appt.purpose?.isNotEmpty == true)
                      ('Purpose', appt.purpose!),
                    if (appt.status?.isNotEmpty == true)
                      ('Status', appt.status!),
                  ],
          ),
          const SizedBox(height: 20),
          if (intent.checkoutUrl?.isNotEmpty == true)
            TapFeedback(
              onTap: () async {
                final uri = Uri.tryParse(intent.checkoutUrl!);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primaryRed),
                ),
                child: Text(
                  'Open checkout',
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
            ),
          if (onConfirmPaid != null) ...[
            const SizedBox(height: 12),
            TapFeedback(
              onTap: () async {
                try {
                  await onConfirmPaid!();
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'I have paid — Confirm',
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrVisual extends StatelessWidget {
  final String payload;
  final String? base64Png;

  const _QrVisual({required this.payload, this.base64Png});

  @override
  Widget build(BuildContext context) {
    if (base64Png != null && base64Png!.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Png!);
        return Image.memory(bytes, width: 220, height: 220, fit: BoxFit.contain);
      } catch (_) {
        // Fall through to QrImageView.
      }
    }

    return QrImageView(
      data: payload,
      version: QrVersions.auto,
      size: 220,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.deepRed,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.darkText,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.raleway(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      row.$1,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
