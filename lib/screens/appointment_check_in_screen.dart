import 'package:btih_andriod_app/services/appointment_confirmation_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:flutter/material.dart';

/// Hospital check-in view after scanning an appointment confirmation QR.
class AppointmentCheckInScreen extends StatefulWidget {
  final String qrTokenOrPayload;

  const AppointmentCheckInScreen({
    super.key,
    required this.qrTokenOrPayload,
  });

  @override
  State<AppointmentCheckInScreen> createState() =>
      _AppointmentCheckInScreenState();
}

class _AppointmentCheckInScreenState extends State<AppointmentCheckInScreen> {
  final _service = AppointmentConfirmationService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.resolveQr(widget.qrTokenOrPayload);
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        setState(() {
          _data = data;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Unexpected response from server.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Appointment Check-in',
          style: AppTypography.raleway(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : _DetailsBody(data: _data!),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.roboto(fontSize: 14, color: AppColors.greyText),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DetailsBody({required this.data});

  String _v(String key) {
    final value = data[key]?.toString();
    if (value == null || value.isEmpty || value == 'null') return '—';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final verified = data['verified'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: verified
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: verified ? Colors.green : Colors.orange,
            ),
          ),
          child: Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: verified ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verified
                      ? 'Appointment verified from confirmation QR'
                      : 'Could not fully verify appointment',
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _row('Appointment ID', _v('appointmentId')),
        _row('Patient', _v('patientName')),
        _row('MR No', _v('mrNo')),
        _row('Phone', _v('phone')),
        _row('Doctor', _v('doctorName')),
        _row('Specialty', _v('departmentHint')),
        _row('Date / Time', _v('appointmentTime')),
        _row('Purpose', _v('purpose')),
        _row('Status', _v('status')),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.roboto(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
