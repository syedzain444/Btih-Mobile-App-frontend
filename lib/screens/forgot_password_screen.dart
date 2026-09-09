import 'dart:async';

import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/utils/auth_validation.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/login_wave_header.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with CodeAutoFill {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  int _step = 1;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _verifiedMrNo;
  String? _resetToken;

  int _start = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _listenForSmsOtp();
  }

  void _listenForSmsOtp() {
    try {
      listenForCode();
    } catch (_) {
      // SMS auto-read is best-effort; manual entry still works.
    }
  }

  @override
  void codeUpdated() {
    final received = code?.trim();
    if (received == null || received.length != 6) return;

    _otpController.text = received;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _start = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_start > 0) {
          _start--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _isSendingOtp = true);
    try {
      final response = await _authService.sendOtp(_phoneController.text.trim());
      if (!mounted) return;
      _startTimer();
      if (_step == 2) {
        _listenForSmsOtp();
      }
      CustomMessageDialog.showSuccess(
        context,
        response['message']?.toString() ?? 'OTP sent successfully',
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, 'Error sending OTP: $e');
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyPhoneNumber() async {
    final phoneNo = _phoneController.text.trim();
    final phoneError = AuthValidation.validatePatientContact(phoneNo);
    if (phoneError != null) {
      CustomMessageDialog.showError(context, phoneError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.verifyPhoneNumber(phoneNo);
      if (!mounted) return;
      setState(() {
        _verifiedMrNo = response['mrNo']?.toString() ??
            response['mr_no']?.toString();
      });
      await _sendOtp();
      if (!mounted) return;
      setState(() => _step = 2);
      _listenForSmsOtp();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, 'Phone number not found');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    final otpError = AuthValidation.validateOtp(otp);
    if (otpError != null) {
      CustomMessageDialog.showError(context, otpError);
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final response = await _authService.verifyOtp(
        phoneNumber: _phoneController.text.trim(),
        otp: otp,
      );
      if (!mounted) return;
      _timer?.cancel();

      final resetToken = AuthService.extractResetToken(response);
      if (resetToken == null || resetToken.isEmpty) {
        CustomMessageDialog.showError(
          context,
          'OTP verified but reset token was not returned.\n\n'
          'Do not verify OTP in Swagger while using the app — verify only here.\n'
          'If this keeps happening, redeploy the latest API.',
        );
        return;
      }

      setState(() {
        _step = 3;
        _resetToken = resetToken;
        _verifiedMrNo = response['mrNo']?.toString() ??
            response['mr_no']?.toString() ??
            _verifiedMrNo;
      });
      CustomMessageDialog.showSuccess(
        context,
        response['message']?.toString() ?? 'OTP verified successfully!',
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, 'OTP verification failed');
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    await _sendOtp();
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final passwordError = AuthValidation.validatePassword(newPassword);
    if (passwordError != null) {
      CustomMessageDialog.showError(context, passwordError);
      return;
    }
    if (newPassword != confirmPassword) {
      CustomMessageDialog.showError(context, 'Passwords do not match');
      return;
    }
    if (_verifiedMrNo == null || _verifiedMrNo!.isEmpty) {
      CustomMessageDialog.showError(context, 'Patient verification expired. Please start again.');
      return;
    }
    if (_resetToken == null || _resetToken!.isEmpty) {
      CustomMessageDialog.showError(context, 'Reset token missing. Please verify OTP again.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.updatePassword(
        mrno: _verifiedMrNo!,
        patientPassword: newPassword,
        resetToken: _resetToken!,
      );
      if (!mounted) return;
      CustomMessageDialog.showSuccess(
        context,
        response['message']?.toString() ?? 'Password updated successfully!',
        onSuccess: () => Navigator.pop(context),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, 'Failed to update password: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _fieldFillGrey = Color(0xFFF0F0F0);
  static const _fieldBorderGrey = Color(0xFFE0E0E0);

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: _fieldFillGrey,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.greyText, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
    );
  }

  void _handleHeaderBack() {
    if (_step == 3) {
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      setState(() {
        _step = 1;
        _timer?.cancel();
      });
      return;
    }
    Navigator.pop(context);
  }

  String get _headerTitle {
    switch (_step) {
      case 1:
        return 'Forgot Password';
      case 2:
        return 'Verify Your Code';
      default:
        return 'Create New Password';
    }
  }

  String get _headerSubtitle {
    switch (_step) {
      case 1:
        return 'Enter your registered mobile number and we\'ll send a verification code.';
      case 2:
        final phone = _phoneController.text.trim();
        if (phone.isEmpty) {
          return 'Enter the 6-digit code we sent to your phone.';
        }
        return 'Enter the 6-digit code sent to $phone. It expires in 2 minutes.';
      default:
        return 'Choose a strong password you\'ll use to sign in from now on.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoginWaveHeader(
            title: _headerTitle,
            subtitle: _headerSubtitle,
            onBack: _handleHeaderBack,
            stepIndicator: 'Step $_step of 3',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 38, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 1) ...[
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading && !_isSendingOtp,
                      style: AppTypography.roboto(
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                      decoration: _fieldDecoration(
                        hint: 'Contact Number',
                        icon: Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppPrimaryButton(
                      label: 'Verify & Send OTP',
                      loading: _isLoading || _isSendingOtp,
                      useBrandGradient: true,
                      onPressed: (_isLoading || _isSendingOtp)
                          ? null
                          : _verifyPhoneNumber,
                    ),
                  ],
                  if (_step == 2) ...[
                    AutofillGroup(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        enabled: !_isVerifyingOtp,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: AppTypography.roboto(
                          fontSize: 22,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                        decoration: _fieldDecoration(
                          hint: '000000',
                          icon: Icons.sms_outlined,
                        ).copyWith(
                          counterText: '',
                          helperText: '',
                          helperMaxLines: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Resend in $_start s',
                          style: AppTypography.roboto(
                            fontSize: 12,
                            color: _start < 10
                                ? AppColors.primaryRed
                                : AppColors.greyText,
                          ),
                        ),
                        if (_canResend)
                          TextButton(
                            onPressed: _isSendingOtp ? null : _resendOtp,
                            child: Text(
                              'Resend OTP',
                              style: AppTypography.roboto(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    AppPrimaryButton(
                      label: 'Verify OTP',
                      loading: _isVerifyingOtp,
                      useBrandGradient: true,
                      onPressed: _isVerifyingOtp ? null : _verifyOtp,
                    ),
                  ],
                  if (_step == 3) ...[
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      enabled: !_isLoading,
                      style: AppTypography.roboto(
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                      decoration: _fieldDecoration(
                        hint: 'New Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.greyText,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      enabled: !_isLoading,
                      style: AppTypography.roboto(
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                      decoration: _fieldDecoration(
                        hint: 'Confirm Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.greyText,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppPrimaryButton(
                      label: 'Update Password',
                      loading: _isLoading,
                      useBrandGradient: true,
                      onPressed: _isLoading ? null : _updatePassword,
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
