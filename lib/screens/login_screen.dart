import 'dart:async';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/screens/dashboard_screen.dart';
import '../theme/app_typography.dart';
import '../utils/auth_validation.dart';
import '../utils/ip_file.dart';
import 'package:btih_andriod_app/screens/forgot_password_screen.dart';
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

  bool _loading = false;
  bool _obscurePassword = true;

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
    setState(() {
      _loading = false;
      _obscurePassword = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contactController.dispose();
    _passwordController.dispose();
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
      );

      final mrNo = AuthSession.mrNo ?? '';
      final patientName = AuthSession.displayName;

      if (mrNo.isEmpty) {
        if (!mounted) return;
        CustomMessageDialog.showError(context, 'MR Number not found in login response');
        return;
      }

      if (!mounted) return;

      CustomMessageDialog.showSuccess(
        context, 
        response['message']?.toString() ?? 'Login successful!',
        onSuccess: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  patientMrNo: mrNo,
                  patientName: patientName,
                  isLoggedIn: true,
                ),
              ),
              (route) => false,
            );
        },
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
        builder: (_) => const DashboardScreen(
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoginWaveHeader(
            title: isStaff ? 'Hospital Staff Login' : 'Sign In',
            subtitle: isStaff
                ? 'Secure access for authorized hospital staff.'
                : 'Welcome back — Sign in to manage your healthcare with ease.',
            showBackButton: !widget.redirectAfterLogin,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 38, 28, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contactController,
                      keyboardType:
                          isStaff ? TextInputType.text : TextInputType.phone,
                      enabled: !_loading,
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
                      enabled: !_loading,
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
                      onPressed: _login,
                    ),
                    if (!isStaff) ...[
                      const SizedBox(height: 24),
                      _buildOrDivider(),
                      const SizedBox(height: 24),
                      LoginOutlinedButton(
                        label: 'Login as a Guest',
                        onPressed: _loading ? null : _loginAsGuest,
                      ),
                    ],
                    const SizedBox(height: 28),
                    Center(
                      child: widget.redirectAfterLogin
                          ? InkWell(
                              onTap: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => DashboardScreen(
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
                                      const TextSpan(text: 'New patient? '),
                                      TextSpan(
                                        text: 'Register at hospital reception.',
                                        style: AppTypography.raleway(
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.w700,
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
    );
  }
}