import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/login_flow_persistence.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/otp_autofill_field.dart';
import 'package:btih_andriod_app/screens/patient_main_shell.dart';
import '../theme/app_typography.dart';
import '../utils/auth_validation.dart';
import '../utils/ip_file.dart';
import 'package:btih_andriod_app/screens/forgot_password_screen.dart';
import 'package:btih_andriod_app/screens/sign_up_screen.dart';
import '../theme/app_colors.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/login_wave_header.dart';

/// =====================
/// LOGIN SCREEN  (redesigned to match mockup)
/// =====================
class LoginScreen extends StatefulWidget {
  final bool redirectAfterLogin;
  final String returnScreen;
  final String? patientMrNo;
  final String? patientName;

  const LoginScreen({
    super.key,
    this.redirectAfterLogin = false,
    this.returnScreen = '',
    this.patientMrNo,
    this.patientName,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _loading = false;
  bool _loginSucceeded = false;
  bool _obscurePassword = true;
  bool _awaitingOtp = false;
  bool _trustThisDevice = true;
  bool _restoringDraft = true;
  String? _loginChallengeId;
  String? _maskedContactNo;
  String _pendingContactNo = '';
  String? _smsAppHash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contactController.addListener(_onDraftFieldChanged);
    _passwordController.addListener(_onDraftFieldChanged);
    _otpController.addListener(_onDraftFieldChanged);
    ApiConfig.ensureResolved();
    unawaited(_restoreLoginDraft());
  }

  Future<void> _restoreLoginDraft() async {
    final draft = await LoginFlowPersistence.load();
    if (!mounted) return;

    if (draft == null || !draft.hasMeaningfulData) {
      setState(() => _restoringDraft = false);
      return;
    }

    _contactController.text = draft.identifier;
    _passwordController.text = draft.password;
    _otpController.text = draft.otp;
    setState(() {
      _awaitingOtp = draft.awaitingOtp &&
          draft.loginChallengeId != null &&
          draft.loginChallengeId!.isNotEmpty;
      _loginChallengeId = draft.loginChallengeId;
      _maskedContactNo = draft.maskedContactNo;
      _pendingContactNo = draft.pendingContactNo;
      _trustThisDevice = draft.trustThisDevice;
      _restoringDraft = false;
    });

    if (_awaitingOtp) {
      await _prepareOtpAutofill();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNode.requestFocus();
      });
    }
  }

  void _onDraftFieldChanged() {
    if (_restoringDraft || _loginSucceeded) return;
    unawaited(_persistLoginDraft());
  }

  LoginFlowDraft _currentDraft() {
    return LoginFlowDraft(
      identifier: _contactController.text,
      password: _passwordController.text,
      awaitingOtp: _awaitingOtp,
      loginChallengeId: _loginChallengeId,
      maskedContactNo: _maskedContactNo,
      pendingContactNo: _pendingContactNo,
      trustThisDevice: _trustThisDevice,
      otp: _otpController.text,
      savedAt: DateTime.now(),
    );
  }

  Future<void> _persistLoginDraft() async {
    final draft = _currentDraft();
    if (!draft.hasMeaningfulData) {
      await LoginFlowPersistence.clear();
      return;
    }
    await LoginFlowPersistence.save(draft);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!_loginSucceeded && !_restoringDraft) {
        unawaited(_persistLoginDraft());
      }
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    if (_awaitingOtp) {
      unawaited(_persistLoginDraft());
      unawaited(_prepareOtpAutofill());
      if (_otpFocusNode.canRequestFocus) {
        _otpFocusNode.requestFocus();
      }
      return;
    }

    ApiConfig.ensureResolved(force: false);
    unawaited(_persistLoginDraft());
  }

  Future<void> _prepareOtpAutofill() async {
    await ensureSmsOtpListening();
    if (kDebugMode) {
      final hash = await getAndroidSmsAppHash();
      if (hash != null && mounted) {
        setState(() => _smsAppHash = hash);
        // ignore: avoid_print
        print('[SMS Autofill] Android app hash: $hash');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contactController.removeListener(_onDraftFieldChanged);
    _passwordController.removeListener(_onDraftFieldChanged);
    _otpController.removeListener(_onDraftFieldChanged);
    if (!_loginSucceeded) {
      unawaited(_persistLoginDraft());
    }
    _contactController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
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

    final contactNo = AuthValidation.normalizeLoginIdentifier(
      _contactController.text.trim(),
    );
    final password = _passwordController.text;

    setState(() => _loading = true);

    try {
      final response = await _authService.login(
        contactNo: contactNo,
        password: password,
        useTrustedDevice: true,
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
        await _persistLoginDraft();
        await _prepareOtpAutofill();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNode.requestFocus();
        });
        if (debugOtp != null && debugOtp.length == 6) {
          // Dev/SMS-fallback path: auto-verify when server returns the code.
          unawaited(_verifyLoginOtp());
        }
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
      setState(() {
        _awaitingOtp = false;
        _loginChallengeId = null;
        _maskedContactNo = null;
      });
      unawaited(_persistLoginDraft());
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
    await LoginFlowPersistence.clear();

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
    // Keep MR/phone + password; only leave the OTP step (TC-018).
    setState(() {
      _awaitingOtp = false;
      _loginChallengeId = null;
      _maskedContactNo = null;
      _otpController.clear();
    });
    unawaited(_persistLoginDraft());
  }

  String? _validateContact(String? value) {
    return AuthValidation.validateLoginIdentifier(value);
  }

  String? _validatePassword(String? value) {
    return AuthValidation.validateLoginPassword(value);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_awaitingOtp && !widget.redirectAfterLogin,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(_persistLoginDraft());
          return;
        }
        if (_awaitingOtp) {
          _backToCredentials();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.blush,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoginWaveHeader(
                title: _awaitingOtp ? 'Verify Device' : 'Sign In',
                subtitle: _awaitingOtp
                    ? 'We sent a verification code to ${_maskedContactNo ?? 'your registered mobile number'}.'
                    : 'Welcome back — Sign in to manage your healthcare with ease.',
                showBackButton: !widget.redirectAfterLogin || _awaitingOtp,
                onBack: _awaitingOtp
                    ? _backToCredentials
                    : (widget.redirectAfterLogin
                        ? null
                        : () {
                            unawaited(_persistLoginDraft());
                            Navigator.of(context).maybePop();
                          }),
              ),
              Expanded(
                child: _restoringDraft
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : SingleChildScrollView(
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
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enabled: !_loading && !_loginSucceeded,
                            validator: _validateContact,
                            style: AppTypography.roboto(
                              fontSize: 15,
                              color: AppColors.darkText,
                            ),
                            decoration: _authFieldDecoration(
                              hint: 'MR or Mobile Number',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '',
                            style: AppTypography.roboto(
                              fontSize: 11,
                              color: AppColors.greyText,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                      Text(
                        'When the SMS arrives, tap the code above your keyboard '
                        'to autofill — or type it manually.',
                        textAlign: TextAlign.center,
                        style: AppTypography.roboto(
                          fontSize: 12,
                          color: AppColors.greyText,
                          height: 1.35,
                        ),
                      ),
                      if (kDebugMode &&
                          _smsAppHash != null &&
                          _smsAppHash!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _smsAppHash!),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('App hash copied'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(
                            'SMS app hash: $_smsAppHash\n'
                            '(tap to copy → Sms:AndroidAppHash)',
                            textAlign: TextAlign.center,
                            style: AppTypography.roboto(
                              fontSize: 11,
                              color: AppColors.primaryRed,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      OtpAutofillField(
                        controller: _otpController,
                        focusNode: _otpFocusNode,
                        enabled: !_loading,
                        onCompleted: (_) {
                          if (!_loading) unawaited(_verifyLoginOtp());
                        },
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _trustThisDevice,
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(
                                  () => _trustThisDevice = value ?? true,
                                );
                                unawaited(_persistLoginDraft());
                              },
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
      ),
    );
  }
}