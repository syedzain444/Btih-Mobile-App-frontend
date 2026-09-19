import 'package:btih_andriod_app/services/messaging_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:flutter/material.dart';

const kMessageCategories = [
  'General',
  'Appointments',
  'Reports',
  'Billing',
  'Medications',
  'Other',
];

Future<int?> showNewMessageSheet(
  BuildContext context, {
  required String patientMrNo,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _NewMessageSheet(patientMrNo: patientMrNo),
  );
}

class _NewMessageSheet extends StatefulWidget {
  final String patientMrNo;

  const _NewMessageSheet({required this.patientMrNo});

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _category = kMessageCategories.first;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty) {
      CustomMessageDialog.showError(context, 'Please enter a subject.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final threadId = await MessagingService.instance.createThread(
        mrNo: widget.patientMrNo,
        subject: subject,
        category: _category,
        initialMessage: message.isEmpty ? null : message,
      );
      if (!mounted) return;
      Navigator.pop(context, threadId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
                'New message',
                style: AppTypography.raleway(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRed,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send a secure message to the hospital care team.',
                style: AppTypography.roboto(
                  fontSize: 13,
                  color: AppColors.greyText,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Category',
                style: AppTypography.raleway(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kMessageCategories.map((category) {
                  final selected = category == _category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = category),
                    selectedColor: AppColors.softRed,
                    labelStyle: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primaryRed
                          : AppColors.greyText,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryRed.withValues(alpha: 0.35)
                          : AppColors.hairline,
                    ),
                    backgroundColor: AppColors.fieldFill,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration('Subject'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                minLines: 4,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration('Write your message (optional)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor:
                        AppColors.primaryRed.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          'Start conversation',
                          style: AppTypography.raleway(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.roboto(
        color: AppColors.greyText,
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
