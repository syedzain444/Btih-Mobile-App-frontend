import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/support_service.dart';
import 'package:btih_andriod_app/screens/support/support_tickets_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Patient Complaints & Suggestions submission (REQ-2026-008).
/// Creates a [MOBILE_SUPPORT_TICKET] via the Support API.
class ComplaintsSuggestionsScreen extends StatefulWidget {
  const ComplaintsSuggestionsScreen({super.key});

  @override
  State<ComplaintsSuggestionsScreen> createState() =>
      _ComplaintsSuggestionsScreenState();
}

class _ComplaintsSuggestionsScreenState
    extends State<ComplaintsSuggestionsScreen> {
  final _service = SupportService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(
    text: AuthSession.displayName == 'Patient' ? '' : AuthSession.displayName,
  );
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _category = 'Complaint';
  bool _submitting = false;

  static const _categories = [
    'Complaint',
    'Suggestion',
    'Service Quality',
    'Staff Behavior',
    'Facilities',
    'Billing',
    'Appointments',
    'Medical Care',
    'App / Technical',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _buildSubject(String category, String message) {
    final preview = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (preview.isEmpty) return category;
    final clipped =
        preview.length > 72 ? '${preview.substring(0, 72)}…' : preview;
    return '$category — $clipped';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final category = _category;
    final message = _messageCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    try {
      final id = await _service.createTicket(
        mrNo: AuthSession.mrNo,
        contactName: name,
        contactPhone: phone.isEmpty ? null : phone,
        category: category,
        subject: _buildSubject(category, message),
        description: message,
      );
      if (!mounted) return;

      HapticFeedback.lightImpact();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Submitted',
            style: AppTypography.raleway(fontWeight: FontWeight.w700),
          ),
          content: Text(
            id > 0
                ? 'Your $category was received as ticket #$id. Hospital staff have been notified and will respond soon.'
                : 'Your $category was received. Hospital staff have been notified and will respond soon.',
            style: AppTypography.roboto(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            if (AuthSession.isLoggedIn)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportTicketsScreen(),
                    ),
                  );
                },
                child: const Text('View my tickets'),
              ),
          ],
        ),
      );
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Complaints & Suggestions',
          style: AppTypography.raleway(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.feedback_outlined),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Share feedback with the hospital',
              style: AppTypography.raleway(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select a category and describe your complaint or suggestion. Staff will be notified as soon as you submit.',
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: 'So we can follow up if needed',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                hintText: 'Describe your complaint or suggestion…',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Please enter your message';
                if (text.length < 10) {
                  return 'Please provide a bit more detail (at least 10 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TapFeedback(
              onTap: _submitting ? null : _submit,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        'Submit',
                        style: AppTypography.raleway(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),
            if (AuthSession.isLoggedIn) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportTicketsScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View My Previous Complaints',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepRed,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
