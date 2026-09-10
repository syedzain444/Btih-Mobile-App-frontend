import 'package:btih_andriod_app/models/medication_detail_model.dart';
import 'package:btih_andriod_app/screens/medication_refill_request_screen.dart';
import 'package:btih_andriod_app/screens/medication_reminder_form_screen.dart';
import 'package:btih_andriod_app/services/medication_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class MedicationDetailScreen extends StatefulWidget {
  final String mrNo;
  final int medicationId;
  final String? fallbackName;

  const MedicationDetailScreen({
    super.key,
    required this.mrNo,
    required this.medicationId,
    this.fallbackName,
  });

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  final _service = MedicationService();
  MedicationDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _service.getMedicationDetail(
        mrNo: widget.mrNo,
        medicationId: widget.medicationId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openReminderForm() async {
    final detail = _detail;
    if (detail == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationReminderFormScreen(
          mrNo: widget.mrNo,
          initialMedicationName: detail.medicineName,
          initialMedicationId: detail.medicationId,
        ),
      ),
    );
  }

  Future<void> _openRefillRequest() async {
    final detail = _detail;
    if (detail == null) return;

    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationRefillRequestScreen(
          mrNo: widget.mrNo,
          medication: detail,
        ),
      ),
    );

    if (submitted == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _detail?.medicineName ?? widget.fallbackName ?? 'Medication';

    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppAppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.raleway(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.primaryRed),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load medication',
              textAlign: TextAlign.center,
              style: AppTypography.roboto(fontSize: 14, color: AppColors.greyText),
            ),
            const SizedBox(height: 16),
            TapFeedback(
              onTap: _loadDetail,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Retry',
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
      ),
    );
  }

  Widget _buildContent() {
    final detail = _detail!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.medsTealBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.medsTeal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.medicineName,
                      style: AppTypography.raleway(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail.subtitle,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Prescription details',
                style: AppTypography.raleway(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRed,
                ),
              ),
              const SizedBox(height: 14),
              ...detail.detailRows.map(_detailRow),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppPrimaryButton(
          label: 'Request refill',
          showArrow: true,
          onPressed: _openRefillRequest,
        ),
        const SizedBox(height: 12),
        TapFeedback(
          onTap: _openReminderForm,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.medsTeal, width: 1.4),
            ),
            child: Text(
              'Set reminder',
              style: AppTypography.raleway(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.medsTeal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(({String label, String value}) row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              row.label,
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: AppTypography.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.darkText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
