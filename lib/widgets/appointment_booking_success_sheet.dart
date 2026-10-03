import 'package:btih_andriod_app/services/appointment_confirmation_pdf_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Modern post-booking confirmation card: details + check-in QR + PDF actions.
class AppointmentBookingSuccessSheet extends StatelessWidget {
  final String patientName;
  final String doctorName;
  final String appointmentTime;
  final String status;
  final String? appointmentId;
  final String? mrNo;
  final String? phone;
  final String? departmentHint;
  final String? purpose;
  final String? qrPayload;
  final String? qrToken;
  final bool popTwiceOnDone;

  const AppointmentBookingSuccessSheet({
    super.key,
    required this.patientName,
    required this.doctorName,
    required this.appointmentTime,
    this.status = 'Pending',
    this.appointmentId,
    this.mrNo,
    this.phone,
    this.departmentHint,
    this.purpose,
    this.qrPayload,
    this.qrToken,
    this.popTwiceOnDone = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String patientName,
    required String doctorName,
    required String appointmentTime,
    String status = 'Pending',
    String? appointmentId,
    String? mrNo,
    String? phone,
    String? departmentHint,
    String? purpose,
    String? qrPayload,
    String? qrToken,
    Map<String, dynamic>? confirmationQr,
    bool popTwiceOnDone = false,
  }) {
    final qr = confirmationQr ?? const <String, dynamic>{};
    String pick(String key, String? fallback) {
      final fromQr = qr[key]?.toString().trim();
      if (fromQr != null && fromQr.isNotEmpty) return fromQr;
      return fallback?.trim() ?? '';
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => AppointmentBookingSuccessSheet(
        patientName: pick('patientName', patientName),
        doctorName: pick('doctorName', doctorName),
        appointmentTime: pick('appointmentTime', appointmentTime),
        status: pick('status', status).isEmpty ? 'Pending' : pick('status', status),
        appointmentId: pick('appointmentId', appointmentId).isEmpty
            ? null
            : pick('appointmentId', appointmentId),
        mrNo: pick('mrNo', mrNo).isEmpty ? null : pick('mrNo', mrNo),
        phone: pick('phone', phone).isEmpty ? null : pick('phone', phone),
        departmentHint: pick('departmentHint', departmentHint).isEmpty
            ? null
            : pick('departmentHint', departmentHint),
        purpose: pick('purpose', purpose).isEmpty ? null : pick('purpose', purpose),
        qrPayload: qrPayload ?? qr['qrPayload']?.toString(),
        qrToken: qrToken ?? qr['qrToken']?.toString(),
        popTwiceOnDone: popTwiceOnDone,
      ),
    );
  }

  String? get _resolvedQrPayload {
    final payload = qrPayload?.trim();
    if (payload != null && payload.isNotEmpty) return payload;

    final token = qrToken?.trim();
    if (token != null && token.isNotEmpty) {
      return '${ApiConfig.baseUrl}/api/AppointmentConfirmation/qr/$token';
    }

    final id = appointmentId?.trim();
    if (id != null && id.isNotEmpty) {
      // Fallback deep link — hospital scanners prefer the token URL above.
      return 'btihapp://appointment/$id';
    }
    return null;
  }

  String get _displayPurpose {
    final value = purpose?.trim() ?? '';
    if (value.isEmpty || value.toUpperCase() == 'NILL') {
      return 'General consultation';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final qrData = _resolvedQrPayload;
    final hasPdf = appointmentId != null && appointmentId!.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
          child: Material(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(),
                        const SizedBox(height: 18),
                        if (qrData != null) ...[
                          _QrCard(payload: qrData),
                          const SizedBox(height: 8),
                          Text(
                            'Show this QR at reception for quick check-in',
                            textAlign: TextAlign.center,
                            style: AppTypography.roboto(
                              fontSize: 12.5,
                              color: AppColors.greyText,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        _DetailsCard(
                          rows: [
                            ('Patient', patientName),
                            if (mrNo != null && mrNo!.trim().isNotEmpty)
                              ('MR No.', mrNo!.trim()),
                            ('Doctor', doctorName),
                            if (departmentHint != null &&
                                departmentHint!.trim().isNotEmpty)
                              ('Specialty', departmentHint!.trim()),
                            ('When', appointmentTime),
                            ('Status', status),
                            if (appointmentId != null &&
                                appointmentId!.trim().isNotEmpty)
                              ('Appt ID', appointmentId!.trim()),
                            if (phone != null && phone!.trim().isNotEmpty)
                              ('Phone', phone!.trim()),
                            ('Purpose', _displayPurpose),
                          ],
                        ),
                        if (hasPdf) ...[
                          const SizedBox(height: 16),
                          _PdfActions(appointmentId: appointmentId!.trim()),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        if (popTwiceOnDone) {
                          navigator.pop();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepRed,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Done',
                        style: AppTypography.raleway(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepRed, AppColors.primaryRed, Color(0xFFC24957)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRed.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appointment confirmed',
                  style: AppTypography.raleway(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your request was received. Keep this QR handy for check-in.',
                  style: AppTypography.roboto(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String payload;

  const _QrCard({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.softRed),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRed.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 196,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.deepRed,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.darkText,
              ),
              errorStateBuilder: (_, __) => SizedBox(
                width: 196,
                height: 196,
                child: Center(
                  child: Text(
                    'QR unavailable',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TapFeedback(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Check-in link copied'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: AppColors.primaryRed.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Copy check-in link',
                    style: AppTypography.roboto(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<(String, String)> rows;

  const _DetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointment details',
            style: AppTypography.raleway(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _DetailRow(label: rows[i].$1, value: rows[i].$2),
            if (i != rows.length - 1)
              Divider(
                height: 16,
                color: AppColors.fieldBorder.withValues(alpha: 0.85),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: AppTypography.roboto(
              fontSize: 12.5,
              color: AppColors.greyText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.roboto(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PdfActions extends StatelessWidget {
  final String appointmentId;

  const _PdfActions({required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirmation PDF',
          style: AppTypography.raleway(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => AppointmentConfirmationPdfService.viewPdf(
                  context,
                  appointmentId: appointmentId,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('View PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepRed,
                  side: const BorderSide(color: AppColors.softRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    AppointmentConfirmationPdfService.downloadToDevice(
                  context,
                  appointmentId: appointmentId,
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Save'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepRed,
                  side: const BorderSide(color: AppColors.softRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => AppointmentConfirmationPdfService.sharePdf(
            context,
            appointmentId: appointmentId,
          ),
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Share confirmation'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.deepRed,
            side: const BorderSide(color: AppColors.softRed),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}
