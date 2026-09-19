import 'dart:async';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/utils/auth_field_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/screens/patient_main_shell.dart';
import '../theme/app_typography.dart';
import '../utils/auth_validation.dart';
import '../utils/ip_file.dart';
import 'package:btih_andriod_app/screens/forgot_password_screen.dart';
import 'package:btih_andriod_app/screens/sign_up_screen.dart';
import '../theme/app_colors.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/login_outlined_button.dart';
import 'package:btih_andriod_app/widgets/login_wave_header.dart';

/// =====================
/// LOGIN SCREEN  (redesigned to match mockup)
/// =====================
class LoginScreen extends StatefulWidget {
  final bool redirectAfterLogin;
  final String returnScreen;
  final String? patientMrNo;
  final String? patientName;
  final bool isStaffLogin;

  const LoginScreen({
    super.key,
    this.redirectAfterLogin = false,
    this.returnScreen = '',
    this.patientMrNo,
    this.patientName,
    this.isStaffLogin = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _otpController = TextEditingController();

  bool _loading = false;
  bool _loginSucceeded = false;
  bool _obscurePassword = true;
  bool _awaitingOtp = false;
  bool _trustThisDevice = true;
  String? _loginChallengeId;
  String? _maskedContactNo;
  String _pendingContactNo = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clearControllers();
    ApiConfig.ensureResolved();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearControllers();
      ApiConfig.ensureResolved(force: true);
      AuthSession.ensureValidSession();
    }
  }

  void _clearControllers() {
    _contactController.clear();
    _passwordController.clear();
    _otpController.clear();
    setState(() {
      _loading = false;
      _obscurePassword = true;
      _awaitingOtp = false;
      _loginChallengeId = null;
      _maskedContactNo = null;
      _pendingContactNo = '';
      _trustThisDevice = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contactController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _login() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final contactNo = _contactController.text.trim();
    final password = _passwordController.text;

    setState(() => _loading = true);

    try {
      final response = await _authService.login(
        contactNo: contactNo,
        password: password,
        useTrustedDevice: !widget.isStaffLogin,
      );

      if (response['requiresOtp'] == true) {
        final debugOtp = AuthService.extractDebugOtp(response);
        if (!mounted) return;
        setState(() {
          _awaitingOtp = true;
          _loginChallengeId = response['loginChallengeId']?.toString();
          _maskedContactNo = response['maskedContactNo']?.toString();
          _pendingContactNo = contactNo;
          if (debugOtp != null) {
            _otpController.text = debugOtp;
          }
        });
        return;
      }

      await _completeLogin(response['message']?.toString());
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e, st) {
      debugPrint('Login failed: $e\n$st');
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      final isCrypto = raw.contains('Cipher') ||
          raw.contains('javax.crypto') ||
          raw.contains('BadPadding') ||
          raw.contains('KeyStore');
      CustomMessageDialog.showError(
        context,
        isCrypto
            ? 'Device storage was reset. Please try signing in again.'
            : 'Unable to sign in right now. Please try again.\n\n$raw',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyLoginOtp() async {
    if (_loading) return;

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      CustomMessageDialog.showError(context, 'Enter the 6-digit verification code');
      return;
    }

    final challengeId = _loginChallengeId;
    if (challengeId == null || challengeId.isEmpty) {
      CustomMessageDialog.showError(
        context,
        'Login verification expired. Please sign in again.',
      );
      setState(() => _awaitingOtp = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _authService.verifyLoginOtp(
        loginChallengeId: challengeId,
        otp: otp,
        contactNo: _pendingContactNo,
        trustDevice: _trustThisDevice,
      );
      await _completeLogin(response['message']?.toString());
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e, st) {
      debugPrint('OTP verify failed: $e\n$st');
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        'Unable to verify the code right now. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeLogin([String? message]) async {
    final mrNo = AuthSession.mrNo ?? '';
    final patientName = AuthSession.displayName;

    if (mrNo.isEmpty) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        'MR Number not found in login response',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _loginSucceeded = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PatientMainShell(
          patientMrNo: mrNo,
          patientName: patientName,
          isLoggedIn: true,
        ),
      ),
      (route) => false,
    );
  }

  void _backToCredentials() {
    setState(() {
      _awaitingOtp = false;
      _loginChallengeId = null;
      _maskedContactNo = null;
      _otpController.clear();
    });
  }

  String? _validateContact(String? value) {
    return widget.isStaffLogin
        ? AuthValidation.validateStaffIdentifier(value)
        : AuthValidation.validatePatientContact(value);
  }

  String? _validatePassword(String? value) {
    return AuthValidation.validatePassword(value);
  }

  Future<void> _loginAsGuest() async {
    if (_loading) return;
    await GuestSession.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const PatientMainShell(
          patientMrNo: '',
          patientName: 'Guest',
          isLoggedIn: false,
        ),
      ),
      (route) => false,
    );
  }

  void _showContactAdministrator() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Contact Administrator'),
        content: const Text(
          'For doctor or admin account access, please contact the hospital IT department or administration office.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _authFieldDecoration({
    required String hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.roboto(
        fontSize: 14,
        color: AppColors.greyText,
      ),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.hairline, width: 1.2),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.primaryRed.withValues(alpha: 0.7),
        ),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
      ),
      errorStyle: AppTypography.roboto(
        fontSize: 12,
        color: AppColors.primaryRed,
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.fieldBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.greyText,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.fieldBorder)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = widget.isStaffLogin;

    return Scaffold(
      backgroundColor: AppColors.blush,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoginWaveHeader(
                title: isStaff
                    ? 'Hospital Staff Login'
                    : (_awaitingOtp ? 'Verify Device' : 'Sign In'),
                subtitle: isStaff
                    ? 'Secure access for authorized hospital staff.'
                    : _awaitingOtp
                        ? 'We sent a verification code to ${_maskedContactNo ?? 'your registered mobile number'}.'
                        : 'Welcome back — Sign in to manage your healthcare with ease.',
                showBackButton: !widget.redirectAfterLogin,
                onBack: _awaitingOtp ? _backToCredentials : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 25, 28, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        if (!_awaitingOtp) ...[
                          TextFormField(
                            controller: _contactController,
                            keyboardType:
                                isStaff ? TextInputType.text : TextInputType.phone,
                            enabled: !_loading && !_loginSucceeded,
                            validator: _validateContact,
                            style: AppTypography.roboto(
                              fontSize: 15,
                              color: AppColors.darkText,
                            ),
                            decoration: _authFieldDecoration(
                              hint: isStaff ? 'Staff ID / Email' : 'Contact Number',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !_loading && !_loginSucceeded,
                            validator: _validatePassword,
                        style: AppTypography.roboto(
                          fontSize: 15,
                          color: AppColors.darkText,
                        ),
                        decoration: _authFieldDecoration(
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
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _showForgotPasswordDialog,
                          child: Text(
                            'Forgot Password?',
                            style: AppTypography.raleway(
                              fontSize: 13,
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AppPrimaryButton(
                        label: 'Login',
                        loading: _loading,
                        useBrandGradient: true,
                        fullWidth: false,
                        height: 48,
                        onPressed: _login,
                      ),
                    ] else ...[
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        enabled: !_loading,
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
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _trustThisDevice,
                        onChanged: _loading
                            ? null
                            : (value) => setState(
                                  () => _trustThisDevice = value ?? true,
                                ),
                        activeColor: AppColors.primaryRed,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          'Trust this device — skip verification next time',
                          style: AppTypography.roboto(
                            fontSize: 13,
                            color: AppColors.greyText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppPrimaryButton(
                        label: 'Verify & Sign In',
                        loading: _loading,
                        useBrandGradient: true,
                        fullWidth: false,
                        height: 48,
                        onPressed: _verifyLoginOtp,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _backToCredentials,
                          child: Text(
                            'Back to sign in',
                            style: AppTypography.raleway(
                              fontSize: 13,
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (!isStaff && !_awaitingOtp) ...[
                      const SizedBox(height: 24),
                      _buildOrDivider(),
                      const SizedBox(height: 24),
                      LoginOutlinedButton(
                        label: 'Login as a Guest',
                        onPressed:
                            (_loading || _loginSucceeded) ? null : _loginAsGuest,
                      ),
                    ],
                    const SizedBox(height: 28),
                    Center(
                      child: widget.redirectAfterLogin
                          ? InkWell(
                              onTap: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => PatientMainShell(
                                      patientMrNo: '',
                                      patientName:
                                          widget.patientName ?? 'Patient',
                                      isLoggedIn: false,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Text(
                                  'Cancel',
                                  style: AppTypography.raleway(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.greyText,
                                  ),
                                ),
                              ),
                            )
                          : isStaff
                              ? RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: AppTypography.roboto(
                                      fontSize: 14,
                                      color: AppColors.greyText,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: "Don't have an account? ",
                                      ),
                                      TextSpan(
                                        text: 'Contact Administrator',
                                        style: AppTypography.raleway(
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = _showContactAdministrator,
                                      ),
                                    ],
                                  ),
                                )
                              : RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: AppTypography.roboto(
                                      fontSize: 14,
                                      color: AppColors.greyText,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Already registered at the hospital? '),
                                      TextSpan(
                                        text: 'Sign up with your registered mobile number.',
                                        style: AppTypography.raleway(
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SignUpScreen(),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
          if (_loginSucceeded)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.white.withValues(alpha: 0.94),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Login Successful',
                        style: AppTypography.raleway(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}