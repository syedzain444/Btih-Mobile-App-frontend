import 'package:btih_andriod_app/models/medication_detail_model.dart';
import 'package:btih_andriod_app/screens/medication_refill_detail_screen.dart';
import 'package:btih_andriod_app/services/medication_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MedicationRefillRequestScreen extends StatefulWidget {
  final String mrNo;
  final MedicationDetail medication;

  const MedicationRefillRequestScreen({
    super.key,
    required this.mrNo,
    required this.medication,
  });

  @override
  State<MedicationRefillRequestScreen> createState() =>
      _MedicationRefillRequestScreenState();
}

class _MedicationRefillRequestScreenState
    extends State<MedicationRefillRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _service = MedicationService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final quantityText = _quantityController.text.trim();
      final refill = await _service.requestRefill(
        mrNo: widget.mrNo,
        medicationId: widget.medication.medicationId,
        quantity: quantityText.isEmpty ? null : int.tryParse(quantityText),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicationRefillDetailScreen(
            mrNo: widget.mrNo,
            refillId: refill.refillId,
            initialRefill: refill,
          ),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppAppBar(
        title: Text(
          'Request Refill',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.medsTealBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined, color: AppColors.medsTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.medication.medicineName,
                          style: AppTypography.raleway(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepRed,
                          ),
                        ),
                        if (widget.medication.dosage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.medication.dosage!,
                            style: AppTypography.roboto(
                              fontSize: 13,
                              color: AppColors.greyText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quantity (optional)',
              style: AppTypography.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('e.g. 30'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Notes (optional)',
              style: AppTypography.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: _inputDecoration(
                'Any instructions for the pharmacy team...',
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Submit refill request',
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.roboto(color: AppColors.greyText, fontSize: 14),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4),
      ),
    );
  }
}
