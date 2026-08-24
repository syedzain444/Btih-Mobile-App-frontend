import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password != confirm) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await _authService.signup(
        fullName: name,
        contactNo: phone,
        password: password,
      );

      if (!mounted) return;

      final canLogin = response['canLogin'] == true;
      final message = response['message']?.toString() ??
          (canLogin
              ? 'Registration complete. You can sign in now.'
              : 'Registration request submitted. Please visit reception.');

      if (canLogin) {
        CustomMessageDialog.showSuccess(
          context,
          message,
          onSuccess: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        );
      } else {
        CustomMessageDialog.showSuccess(context, message);
      }
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
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : AppColors.primaryRed,
      ),
    );
  }

  InputDecoration _fieldDecoration({
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppColors.darkText,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
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
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/images/hospital_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Sign Up',
                  style: AppTypography.montserrat(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Create your account to manage appointments and access your health records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.greyText),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                enabled: !_loading,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Full name is required' : null,
                decoration: _fieldDecoration(
                  hint: 'Full Name',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_loading,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Contact number is required';
                  if (value.length < 10) return 'Enter at least 10 digits';
                  return null;
                },
                decoration: _fieldDecoration(
                  hint: 'Contact Number',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_loading,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 4) return 'At least 4 characters';
                  return null;
                },
                decoration: _fieldDecoration(
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                enabled: !_loading,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your password';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
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
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSignup,
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
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14, color: AppColors.greyText),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
