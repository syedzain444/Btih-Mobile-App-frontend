import 'dart:async';

import 'package:btih_andriod_app/screens/patient_main_shell.dart';
import 'package:btih_andriod_app/screens/forgot_password_screen.dart';
import 'package:btih_andriod_app/screens/profile_setup_screen.dart';
import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/auth_field_decoration.dart';
import 'package:btih_andriod_app/utils/auth_validation.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/login_wave_header.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with CodeAutoFill {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  int _step = 1;
  bool _loading = false;
  bool _sendingOtp = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;

  String? _normalizedPhone;

  int _resendSeconds = 120;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
    _listenForSmsOtp();
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      cancel();
    }
    _phoneController.dispose();
    _otpController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _listenForSmsOtp() {
    if (kIsWeb) return;
    try {
      listenForCode();
    } catch (_) {}
  }

  @override
  void codeUpdated() {
    final received = code?.trim();
    if (received == null || received.length != 6) return;
    _otpController.text = received;
    if (mounted) setState(() {});
  }

  void _startTimer({int seconds = 120}) {
    setState(() {
      _resendSeconds = seconds;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String get _phoneForApi => _normalizedPhone ?? '';

  Future<bool> _sendRegistrationOtp({bool showDialog = true}) async {
    setState(() => _sendingOtp = true);
    try {
      final response =
          await _authService.sendRegistrationOtp(_phoneForApi);
      if (!mounted) return false;

      final expiresInMinutes = int.tryParse(
        response['expiresInMinutes']?.toString() ?? '',
      );
      _startTimer(
        seconds: expiresInMinutes != null && expiresInMinutes > 0
            ? expiresInMinutes * 60
            : 120,
      );
      _listenForSmsOtp();

      if (showDialog) {
        final debugOtp = AuthService.extractDebugOtp(response);
        final baseMessage =
            response['message']?.toString() ?? 'Registration OTP sent';
        final message = debugOtp != null
            ? '$baseMessage\n\nYour verification code: $debugOtp'
            : baseMessage;
        if (debugOtp != null) {
          _otpController.text = debugOtp;
        }
        CustomMessageDialog.showSuccess(context, message);
      }
      return true;
    } on AuthApiException catch (e) {
      if (!mounted) return false;
      CustomMessageDialog.showError(context, e.message);
      return false;
    } catch (e) {
      if (!mounted) return false;
      CustomMessageDialog.showError(context, 'Failed to send OTP: $e');
      return false;
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyPhoneAndContinue() async {
    final rawPhone = _phoneController.text.trim();
    final phoneError = AuthValidation.validatePatientContact(rawPhone);
    if (phoneError != null) {
      CustomMessageDialog.showError(context, phoneError);
      return;
    }

    final normalized = AuthValidation.normalizePakistanPhone(rawPhone);
    setState(() => _loading = true);

    try {
      final verifyResponse = await _authService.verifyPhoneNumber(normalized);
      if (!mounted) return;

      final hasPortal = verifyResponse['hasPortalAccount'] == true;
      if (hasPortal) {
        await CustomMessageDialog.showAlreadyRegisteredLogin(
          context,
          onLogin: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          onForgotPassword: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            );
          },
        );
        return;
      }

      _normalizedPhone = normalized;

      final otpSent = await _sendRegistrationOtp();
      if (!mounted || !otpSent) return;

      setState(() => _step = 2);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      if (e.type == AuthErrorType.unauthorized) {
        CustomMessageDialog.showNotRegisteredPatient(
          context,
          phoneDisplay: AuthValidation.formatPakistanPhoneDisplay(
            AuthValidation.normalizePakistanPhone(rawPhone),
          ),
        );
        return;
      }
      CustomMessageDialog.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      CustomMessageDialog.showNotRegisteredPatient(
        context,
        phoneDisplay: AuthValidation.formatPakistanPhoneDisplay(
          AuthValidation.normalizePakistanPhone(rawPhone),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continueFromOtp() {
    final otpError = AuthValidation.validateOtp(_otpController.text);
    if (otpError != null) {
      CustomMessageDialog.showError(context, otpError);
      return;
    }
    setState(() => _step = 3);
  }

  Future<void> _completeRegistration() async {
    final firstNameError =
        AuthValidation.validateFirstName(_firstNameController.text);
    if (firstNameError != null) {
      CustomMessageDialog.showError(context, firstNameError);
      return;
    }

    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final passwordError = AuthValidation.validatePassword(password);
    if (passwordError != null) {
      CustomMessageDialog.showError(context, passwordError);
      return;
    }
    if (password != confirm) {
      CustomMessageDialog.showError(context, 'Passwords do not match');
      return;
    }
    if (!_acceptTerms) {
      CustomMessageDialog.showError(
        context,
        'Please accept the terms and conditions',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _authService.register(
        phoneNumber: _phoneForApi,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        password: password,
        confirmPassword: confirm,
        otp: _otpController.text.trim(),
        acceptTerms: _acceptTerms,
      );

      if (!mounted) return;

      if (!AuthSession.hasValidToken) {
        CustomMessageDialog.showError(
          context,
          'Registration succeeded but no login token was returned.\n\n'
          'Please sign in with your new password.',
        );
        return;
      }

      final mrNo = AuthSession.mrNo ?? response['mrNo']?.toString() ?? '';
      if (mrNo.isEmpty) {
        CustomMessageDialog.showError(
          context,
          'Registration succeeded but MR number was missing. Please sign in.',
        );
        return;
      }

      final profileSetupRequired =
          response['profileSetupRequired'] == true;

      if (!profileSetupRequired) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PatientMainShell(
              patientMrNo: mrNo,
              patientName: AuthSession.displayName,
              isLoggedIn: true,
            ),
          ),
          (_) => false,
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            mrNo: mrNo,
            initialPhone: _phoneForApi,
          ),
        ),
        (_) => false,
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      final message = e.message.toLowerCase();
      if (message.contains('already registered') ||
          message.contains('please login')) {
        await CustomMessageDialog.showAlreadyRegisteredLogin(
          context,
          onLogin: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LoginScreen(
                  redirectAfterLogin: false,
                ),
              ),
            );
          },
          onForgotPassword: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            );
          },
        );
        return;
      }
      CustomMessageDialog.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _handleBack() {
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
        return 'Sign Up';
      case 2:
        return 'Verify Your Code';
      default:
        return 'Create Account';
    }
  }

  String get _headerSubtitle {
    switch (_step) {
      case 1:
        return 'Enter your registered mobile number to create your patient portal account.';
      case 2:
        final display = _normalizedPhone != null
            ? AuthValidation.formatPakistanPhoneDisplay(_normalizedPhone!)
            : '';
        return display.isEmpty
            ? 'Enter the 6-digit code we sent to your phone.'
            : 'Enter the 6-digit code sent to $display. It expires in 2 minutes.';
      default:
        return 'Set your name and password to finish registration.';
    }
  }

  Widget _buildPhoneField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            '+92',
            style: AppTypography.raleway(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            enabled: !_loading && !_sendingOtp,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTypography.roboto(
              fontSize: 15,
              color: AppColors.darkText,
            ),
            decoration: authUnderlineFieldDecoration(
              hint: '3XX XXXXXXX',
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: _openForgotPassword,
        child: Text(
          'Forgot Password?',
          style: AppTypography.raleway(
            fontSize: 13,
            color: AppColors.primaryRed,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: AppTypography.roboto(fontSize: 14, color: AppColors.greyText),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Sign In',
              style: AppTypography.raleway(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
            ),
          ],
        ),
      ),
    );
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
            onBack: _handleBack,
            stepIndicator: 'Step $_step of 3',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 25, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 1) ...[
                    const SizedBox(height: 8),
                    _buildPhoneField(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_phoneController.text.length}/10',
                        style: AppTypography.roboto(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppPrimaryButton(
                      label: 'Continue',
                      loading: _loading || _sendingOtp,
                      useBrandGradient: true,
                      onPressed: (_loading || _sendingOtp)
                          ? null
                          : _verifyPhoneAndContinue,
                    ),
                    const SizedBox(height: 16),
                    _buildForgotPasswordLink(),
                    const SizedBox(height: 8),
                    _buildLoginLink(),
                  ],
                  if (_step == 2) ...[
                    AutofillGroup(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: AppTypography.roboto(
                          fontSize: 22,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                        decoration: authUnderlineFieldDecoration(
                          hint: '000000',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Resend in $_resendSeconds s',
                          style: AppTypography.roboto(
                            fontSize: 12,
                            color: _resendSeconds < 10
                                ? AppColors.primaryRed
                                : AppColors.greyText,
                          ),
                        ),
                        if (_canResend)
                          TextButton(
                            onPressed:
                                _sendingOtp ? null : () => _sendRegistrationOtp(),
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
                      label: 'Continue',
                      useBrandGradient: true,
                      onPressed: _continueFromOtp,
                    ),
                    const SizedBox(height: 16),
                    _buildForgotPasswordLink(),
                  ],
                  if (_step == 3) ...[
                    TextField(
                      controller: _firstNameController,
                      enabled: !_loading,
                      style: AppTypography.roboto(
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                      decoration: authUnderlineFieldDecoration(
                        hint: 'First Name',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _lastNameController,
                      enabled: !_loading,
                      style: AppTypography.roboto(
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                      decoration: authUnderlineFieldDecoration(
                        hint: 'Last Name (optional)',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_loading,
                      style: AppTypography.roboto(
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                      decoration: authUnderlineFieldDecoration(
                        hint: 'Password',
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.greyText,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      enabled: !_loading,
                      style: AppTypography.roboto(
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                      decoration: authUnderlineFieldDecoration(
                        hint: 'Confirm Password',
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
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _acceptTerms,
                      onChanged: _loading
                          ? null
                          : (value) =>
                              setState(() => _acceptTerms = value ?? false),
                      activeColor: AppColors.primaryRed,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'I accept the terms and conditions',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: AppColors.greyText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      label: 'Create Account',
                      loading: _loading,
                      useBrandGradient: true,
                      onPressed: _loading ? null : _completeRegistration,
                    ),
                    const SizedBox(height: 16),
                    _buildForgotPasswordLink(),
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
