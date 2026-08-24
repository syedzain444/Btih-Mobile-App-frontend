import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import '../theme/app_typography.dart';
import '../utils/ip_file.dart';
import '../theme/app_colors.dart';
import 'package:btih_andriod_app/screens/dashboard_screen.dart';
import 'package:btih_andriod_app/screens/signup_screen.dart';
import 'package:btih_andriod_app/screens/forgot_password_screen.dart';

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

      final mrData = response['MR_NO'] ??
          response['mrNo'] ??
          response['mR_NO'] ??
          response['mr_NO'];

      String mrNo = '';
      String patientName = widget.patientName ?? 'Patient';

      if (mrData is Map) {
        final nestedMr = mrData['mrNo'] ?? mrData['MrNo'] ?? mrData['MR_NO'];
        mrNo = nestedMr?.toString() ?? '';
        patientName =
            (mrData['firstName'] ?? mrData['FirstName'])?.toString() ??
                patientName;
      } else if (mrData != null) {
        mrNo = mrData.toString();
      }

      patientName =
          response['firstName']?.toString() ?? patientName;

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
    final contact = value?.trim() ?? '';
    if (contact.isEmpty) {
      return 'Contact number is required';
    }
    if (contact.length < 10) {
      return 'Enter a valid contact number (at least 10 digits)';
    }
    if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(contact)) {
      return 'Contact number can only contain digits';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  void _loginAsGuest() {
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
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.fieldFill,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.greyText, size: 20),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.7)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.primaryRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = widget.isStaffLogin;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              if (!widget.redirectAfterLogin)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: AppColors.darkText,
                    padding: EdgeInsets.zero,
                  ),
                )
              else
                const SizedBox(height: 8),

              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.fieldBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isStaff
                        ? Icons.medical_services_outlined
                        : Icons.local_hospital_rounded,
                    color: AppColors.primaryRed,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isStaff ? 'Hospital Staff Login' : 'Sign In',
                textAlign: TextAlign.center,
                style: AppTypography.montserrat(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isStaff ? 'For Doctors & Admins' : 'Welcome back. Sign in to continue managing your healthcare.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.greyText),
              ),
              if (isStaff) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.softRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: AppColors.primaryRed, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Secure access for authorized hospital staff only.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.darkText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                enabled: !_loading,
                validator: _validateContact,
                decoration: _authFieldDecoration(
                  hint: isStaff ? 'Staff ID / Email' : 'Contact Number',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_loading,
                validator: _validatePassword,
                decoration: _authFieldDecoration(
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.greyText,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (!isStaff) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.fieldBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(fontSize: 13, color: AppColors.greyText),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.fieldBorder)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _loginAsGuest,
                    icon: const Icon(
                      Icons.person_outline,
                      size: 20,
                      color: AppColors.greyText,
                    ),
                    label: const Text(
                      'Login as a Guest',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkText,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.fieldBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                              builder: (_) => DashboardScreen(
                                patientMrNo: '',
                                patientName: widget.patientName ?? 'Patient',
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    : isStaff
                        ? RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                              ),
                              children: [
                                const TextSpan(
                                  text: "Don't have an account? ",
                                ),
                                TextSpan(
                                  text: 'Contact Administrator',
                                  style: const TextStyle(
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
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                              ),
                              children: [
                                const TextSpan(
                                  text: "Don't have an account? ",
                                ),
                                TextSpan(
                                  text: 'Sign Up',
                                  style: const TextStyle(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SignupScreen(),
                                        ),
                                      );
                                    },
                                ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(height: 16),
            ],
            ),
          ),
        ),
      ),
    );
  }
}