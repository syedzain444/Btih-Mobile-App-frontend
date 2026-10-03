import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/auth_field_decoration.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// 6-digit OTP field with banking-style keyboard SMS autofill (REQ-2026-019 / TC-019).
///
/// - Android / iOS: [AutofillHints.oneTimeCode] so the system can offer the code
///   above the keyboard when an OTP SMS arrives.
/// - Android (with app-hash SMS): [CodeAutoFill] / SMS Retriever also fills silently.
/// - Manual typing always works.
class OtpAutofillField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final String hint;

  const OtpAutofillField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.onCompleted,
    this.onChanged,
    this.hint = '000000',
  });

  @override
  State<OtpAutofillField> createState() => _OtpAutofillFieldState();
}

class _OtpAutofillFieldState extends State<OtpAutofillField> with CodeAutoFill {
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void didUpdateWidget(covariant OtpAutofillField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_listening) {
      _startListening();
    }
  }

  void _startListening() {
    if (kIsWeb || !widget.enabled) return;
    try {
      listenForCode();
      _listening = true;
    } catch (_) {
      // Manual entry and keyboard autofill still work.
    }
  }

  @override
  void codeUpdated() {
    final received = _extractSixDigitOtp(code);
    if (received == null) return;
    _applyOtp(received, fromSmsRetriever: true);
  }

  void _applyOtp(String otp, {required bool fromSmsRetriever}) {
    if (widget.controller.text == otp) {
      widget.onCompleted?.call(otp);
      return;
    }
    widget.controller.text = otp;
    widget.controller.selection = TextSelection.collapsed(offset: otp.length);
    widget.onChanged?.call(otp);
    if (otp.length == 6) {
      widget.onCompleted?.call(otp);
    }
    if (mounted) setState(() {});
  }

  static String? _extractSixDigitOtp(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'\b(\d{6})\b').firstMatch(raw);
    if (match != null) return match.group(1);
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) return digits.substring(0, 6);
    return null;
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      try {
        cancel();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        maxLength: 6,
        autofillHints: const [AutofillHints.oneTimeCode],
        enableSuggestions: false,
        autocorrect: false,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        textAlign: TextAlign.center,
        style: AppTypography.roboto(
          fontSize: 22,
          letterSpacing: 8,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        decoration: authUnderlineFieldDecoration(
          hint: widget.hint,
          counterText: '',
        ),
        onChanged: (value) {
          widget.onChanged?.call(value);
          if (value.trim().length == 6) {
            widget.onCompleted?.call(value.trim());
          }
        },
      ),
    );
  }
}

/// Starts SMS Retriever listening as soon as an OTP screen opens
/// (call before/while waiting for SMS). Safe no-op on web.
Future<void> ensureSmsOtpListening() async {
  if (kIsWeb) return;
  try {
    await SmsAutoFill().listenForCode();
  } catch (_) {}
}

/// Returns the 11-char Android SMS Retriever app hash (for server Sms:AndroidAppHash).
Future<String?> getAndroidSmsAppHash() async {
  if (kIsWeb) return null;
  try {
    final sig = await SmsAutoFill().getAppSignature;
    return sig.isEmpty ? null : sig;
  } catch (_) {
    return null;
  }
}
