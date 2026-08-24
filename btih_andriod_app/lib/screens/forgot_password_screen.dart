import 'dart:async';

import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
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

  int _start = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void dispose() {
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
      final debugOtp = response['debugOtp']?.toString();
      CustomMessageDialog.showSuccess(
        context,
        debugOtp != null
            ? '${response['message'] ?? 'OTP generated'}\nDev OTP: $debugOtp'
            : response['message']?.toString() ?? 'OTP sent successfully',
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
    if (phoneNo.isEmpty || phoneNo.length < 10) {
      CustomMessageDialog.showError(context, 'Please enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.verifyPhoneNumber(phoneNo);
      if (!mounted) return;
      setState(() => _verifiedMrNo = response['mr_no']?.toString());
      await _sendOtp();
      if (!mounted) return;
      setState(() => _step = 2);
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
    if (otp.isEmpty || otp.length != 6) {
      CustomMessageDialog.showError(context, 'Please enter a valid 6-digit OTP');
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
      setState(() => _step = 3);
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

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      CustomMessageDialog.showError(context, 'Please enter new password');
      return;
    }
    if (newPassword.length < 6) {
      CustomMessageDialog.showError(context, 'Password must be at least 6 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      CustomMessageDialog.showError(context, 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.updatePassword(
        mrno: _verifiedMrNo!,
        patientPassword: newPassword,
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

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.softRed.withValues(alpha: 0.35),
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  colors: [AppColors.rustRed, AppColors.primaryRed],
                ),
          color: onPressed == null ? AppColors.fieldBorder : null,
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 1:
        return 'Verify Phone';
      case 2:
        return 'Enter OTP';
      default:
        return 'New Password';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 1:
        return 'Enter your registered contact number.';
      case 2:
        return 'We sent a 6-digit code to your phone.';
      default:
        return 'Create a strong new password.';
    }
  }

  IconData get _stepIcon {
    switch (_step) {
      case 1:
        return Icons.phone_outlined;
      case 2:
        return Icons.sms_outlined;
      default:
        return Icons.lock_reset_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.blush, AppColors.scaffoldBg],
                  stops: [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -60,
            child: _decorativeBlob(220, AppColors.softRed.withValues(alpha: 0.55)),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _decorativeBlob(180, AppColors.rustRed.withValues(alpha: 0.10)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        color: AppColors.darkText,
                      ),
                      const Spacer(),
                      Text(
                        'Step $_step of 3',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.softRed.withValues(alpha: 0.9),
                                AppColors.softRed.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadow.withValues(alpha: 0.14),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _stepIcon,
                                color: AppColors.primaryRed,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Forgot Password',
                          textAlign: TextAlign.center,
                          style: AppTypography.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softRed.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _stepTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _StepIndicator(currentStep: _step),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.10),
                        blurRadius: 28,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.rustRed, AppColors.primaryRed],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        _stepSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.greyText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_step == 1) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_isLoading && !_isSendingOtp,
                          decoration: _fieldDecoration(
                            hint: 'Contact Number',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _gradientButton(
                          label: 'Verify & Send OTP',
                          loading: _isLoading || _isSendingOtp,
                          onPressed: (_isLoading || _isSendingOtp)
                              ? null
                              : _verifyPhoneNumber,
                        ),
                      ],
                      if (_step == 2) ...[
                        Text(
                          _phoneController.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          enabled: !_isVerifyingOtp,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _fieldDecoration(
                            hint: '000000',
                            icon: Icons.sms_outlined,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Resend in $_start s',
                              style: TextStyle(
                                fontSize: 12,
                                color: _start < 10
                                    ? AppColors.primaryRed
                                    : AppColors.greyText,
                              ),
                            ),
                            if (_canResend)
                              TextButton(
                                onPressed: _isSendingOtp ? null : _resendOtp,
                                child: const Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _step = 1;
                                    _timer?.cancel();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.greyText,
                                  side: const BorderSide(
                                    color: AppColors.fieldBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  minimumSize: const Size(0, 50),
                                ),
                                child: const Text('Back'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _gradientButton(
                                label: 'Verify OTP',
                                loading: _isVerifyingOtp,
                                onPressed:
                                    _isVerifyingOtp ? null : _verifyOtp,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_step == 3) ...[
                        TextField(
                          controller: _newPasswordController,
                          obscureText: _obscureNew,
                          enabled: !_isLoading,
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _step = 2),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.greyText,
                                  side: const BorderSide(
                                    color: AppColors.fieldBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  minimumSize: const Size(0, 50),
                                ),
                                child: const Text('Back'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _gradientButton(
                                label: 'Update Password',
                                loading: _isLoading,
                                onPressed: _isLoading ? null : _updatePassword,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _decorativeBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final step = index + 1;
        final active = step == currentStep;
        final done = step < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: active || done
                ? const LinearGradient(
                    colors: [AppColors.rustRed, AppColors.primaryRed],
                  )
                : null,
            color: active || done ? null : AppColors.fieldBorder,
          ),
        );
      }),
    );
  }
}
