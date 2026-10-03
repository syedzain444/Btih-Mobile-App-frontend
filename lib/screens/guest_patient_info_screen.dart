import 'dart:async';

import 'package:btih_andriod_app/screens/forgot_password_screen.dart';
import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/screens/sign_up_screen.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/services/guest_service.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/auth_validation.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/otp_autofill_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuestPatientInfoScreen extends StatefulWidget {
  const GuestPatientInfoScreen({super.key});

  @override
  State<GuestPatientInfoScreen> createState() => _GuestPatientInfoScreenState();
}

class _GuestPatientInfoScreenState extends State<GuestPatientInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final _authService = AuthService();
  final _guestService = GuestService();

  DateTime? _dateOfBirth;
  String? _gender;
  bool _isSubmitting = false;
  bool _sendingOtp = false;
  String? _phoneLookupHint;
  String? _debugOtp;
  String? _normalizedPhone;

  /// 1 = patient info form, 2 = OTP verification
  int _step = 1;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  static const _genders = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _prefillFromSession();
  }

  void _prefillFromSession() {
    if (GuestSession.fullName?.trim().isNotEmpty == true) {
      _nameController.text = GuestSession.fullName!.trim();
    }
    if (GuestSession.mobileNumber?.trim().isNotEmpty == true) {
      _mobileController.text = GuestSession.mobileNumber!.trim();
    }
    if (GuestSession.gender?.trim().isNotEmpty == true) {
      final g = GuestSession.gender!.trim();
      if (_genders.contains(g)) _gender = g;
    }
    final dobRaw = GuestSession.dateOfBirth?.trim();
    if (dobRaw != null && dobRaw.isNotEmpty) {
      _dateOfBirth = DateTime.tryParse(dobRaw);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryRed,
              onPrimary: AppColors.white,
              onSurface: AppColors.darkText,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  String? _registeredMrNo(Map<String, dynamic> response) {
    final mrData = response['mr_no'] ??
        response['MR_NO'] ??
        response['mrNo'] ??
        response['mR_NO'];
    if (mrData == null) return null;
    if (mrData is Map) {
      final nested = (mrData['mrNo'] ?? mrData['MR_NO'])?.toString().trim();
      return (nested == null || nested.isEmpty) ? null : nested;
    }
    final value = mrData.toString().trim();
    return value.isEmpty ? null : value;
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _goToSignUp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  Future<void> _promptAlreadyHasPortalAccount() {
    return CustomMessageDialog.showAlreadyRegisteredLogin(
      context,
      message:
          'This mobile number is already registered with a patient account. '
          'Please log in to book appointments, or reset your password if you forgot it.',
      onLogin: _goToLogin,
      onForgotPassword: _goToForgotPassword,
    );
  }

  Future<void> _promptHospitalRecordNeedsSignup(String? mrNo) {
    return CustomMessageDialog.showHospitalRecordNeedsSignup(
      context,
      mrNo: mrNo,
      onSignUp: _goToSignUp,
    );
  }

  Future<bool> _sendGuestOtp(String mobile) async {
    setState(() => _sendingOtp = true);
    try {
      final response = await _authService.sendRegistrationOtp(mobile);
      if (!mounted) return false;
      final debug = response['debugOtp']?.toString();
      setState(() {
        _debugOtp = (debug != null && debug.isNotEmpty) ? debug : null;
      });
      _startResendTimer();
      if (_step == 2) {
        unawaited(ensureSmsOtpListening());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
      return true;
    } on AuthApiException catch (e) {
      if (!mounted) return false;
      CustomMessageDialog.showError(context, e.message);
      return false;
    } catch (_) {
      if (!mounted) return false;
      CustomMessageDialog.showError(
        context,
        'Could not send OTP. Please try again.',
      );
      return false;
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  /// Step 1: validate form + phone, then send OTP and show OTP screen.
  Future<void> _continueToOtp() async {
    if (_isSubmitting || _sendingOtp) return;
    setState(() => _phoneLookupHint = null);

    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      CustomMessageDialog.showError(context, 'Please select date of birth');
      return;
    }
    if (_gender == null || _gender!.isEmpty) {
      CustomMessageDialog.showError(context, 'Please select gender');
      return;
    }

    final phoneError =
        AuthValidation.validatePakistanMobile(_mobileController.text);
    if (phoneError != null) {
      CustomMessageDialog.showError(context, phoneError);
      return;
    }

    final mobile =
        AuthValidation.normalizePakistanPhone(_mobileController.text);
    setState(() => _isSubmitting = true);

    try {
      try {
        final response = await _authService.verifyPhoneNumber(mobile);
        if (!mounted) return;

        final mrNo = _registeredMrNo(response);
        final hasPortal = response['hasPortalAccount'] == true;

        if (hasPortal) {
          await _promptAlreadyHasPortalAccount();
          return;
        }
        if (mrNo != null) {
          await _promptHospitalRecordNeedsSignup(mrNo);
          return;
        }
      } on AuthApiException catch (e) {
        if (!mounted) return;
        if (e.type != AuthErrorType.unauthorized) {
          CustomMessageDialog.showError(context, e.message);
          return;
        }
        setState(() {
          _phoneLookupHint =
              'Number not found in hospital records — continuing as guest.';
        });
      } catch (_) {
        if (!mounted) return;
        CustomMessageDialog.showError(
          context,
          'Could not verify mobile number. Check your connection and try again.',
        );
        return;
      }

      final sent = await _sendGuestOtp(mobile);
      if (!mounted || !sent) return;

      setState(() {
        _normalizedPhone = mobile;
        _step = 2;
        _otpController.clear();
      });
      unawaited(ensureSmsOtpListening());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNode.requestFocus();
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Step 2: verify OTP with profile save, then return to doctor flow.
  Future<void> _verifyOtpAndSave() async {
    if (_isSubmitting) return;
    final otpError = AuthValidation.validateOtp(_otpController.text);
    if (otpError != null) {
      CustomMessageDialog.showError(context, otpError);
      return;
    }

    final mobile = _normalizedPhone ??
        AuthValidation.normalizePakistanPhone(_mobileController.text);
    final dob = DateTime(
      _dateOfBirth!.year,
      _dateOfBirth!.month,
      _dateOfBirth!.day,
    );

    setState(() => _isSubmitting = true);
    try {
      final apiResponse = await _guestService.saveProfile(
        fullName: _nameController.text.trim(),
        mobileNumber: mobile,
        dateOfBirth: dob,
        gender: _gender!,
        otp: _otpController.text.trim(),
      );
      await GuestSession.saveFromApiResponse(apiResponse);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on GuestProfileConflictException catch (e) {
      if (!mounted) return;
      await CustomMessageDialog.showAlreadyRegisteredLogin(
        context,
        message: e.message.isNotEmpty
            ? e.message
            : 'This mobile number is already linked to a patient account. Please log in.',
        onLogin: _goToLogin,
        onForgotPassword: _goToForgotPassword,
      );
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hint,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
      filled: true,
      fillColor: AppColors.white,
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
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryRed),
      ),
    );
  }

  Widget _buildFormStep() {
    final dobLabel = _dateOfBirth == null
        ? 'Select date of birth'
        : '${_dateOfBirth!.day.toString().padLeft(2, '0')}/'
            '${_dateOfBirth!.month.toString().padLeft(2, '0')}/'
            '${_dateOfBirth!.year}';

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '         Tell Us About Yourself',
            style: AppTypography.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We use this for guest appointment booking. '
            'You will verify your mobile number with an OTP.',
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              hint: 'Full Name',
              icon: Icons.person_outline,
            ),
            validator: AuthValidation.validateFullName,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDecoration(
              hint: '03XXXXXXXXX',
              icon: Icons.phone_outlined,
              helperText: _phoneLookupHint ??
                  'Registered numbers cannot continue as guest.',
            ).copyWith(counterText: ''),
            validator: AuthValidation.validatePakistanMobile,
            onChanged: (_) {
              if (_phoneLookupHint != null) {
                setState(() => _phoneLookupHint = null);
              }
            },
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _isSubmitting ? null : _pickDateOfBirth,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _fieldDecoration(
                hint: 'Date of Birth',
                icon: Icons.calendar_today_outlined,
              ),
              child: Text(
                dobLabel,
                style: AppTypography.roboto(
                  fontSize: 15,
                  color: _dateOfBirth == null
                      ? AppColors.greyText
                      : AppColors.darkText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: _fieldDecoration(
              hint: 'Gender',
              icon: Icons.wc_outlined,
            ),
            items: _genders
                .map(
                  (g) => DropdownMenuItem<String>(
                    value: g,
                    child: Text(g),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _gender = value),
            validator: (value) =>
                value == null || value.isEmpty ? 'Select gender' : null,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: (_isSubmitting || _sendingOtp) ? null : _continueToOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: (_isSubmitting || _sendingOtp)
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'Continue',
                    style: AppTypography.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSubmitting ? null : _goToLogin,
            child: Text(
              'Already have an account? Log in',
              style: AppTypography.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final displayPhone = AuthValidation.formatPakistanPhoneDisplay(
      _normalizedPhone ?? _mobileController.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify Your Mobile',
          style: AppTypography.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit OTP sent to $displayPhone',
          style: AppTypography.roboto(
            fontSize: 14,
            color: AppColors.greyText,
            height: 1.45,
          ),
        ),
        if (_debugOtp != null) ...[
          const SizedBox(height: 10),
          Text(
            'Dev OTP: $_debugOtp',
            style: AppTypography.roboto(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryRed,
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'Tap the code above your keyboard when the SMS arrives, or type it manually.',
          textAlign: TextAlign.center,
          style: AppTypography.roboto(
            fontSize: 12,
            color: AppColors.greyText,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        OtpAutofillField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          enabled: !_isSubmitting && !_sendingOtp,
          onCompleted: (_) {
            if (!_isSubmitting && !_sendingOtp) unawaited(_verifyOtpAndSave());
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _resendSeconds > 0
                  ? 'Resend in $_resendSeconds s'
                  : 'Didn’t get the code?',
              style: AppTypography.roboto(
                fontSize: 12,
                color: _resendSeconds > 0 && _resendSeconds < 10
                    ? AppColors.primaryRed
                    : AppColors.greyText,
              ),
            ),
            if (_resendSeconds == 0)
              TextButton(
                onPressed: _sendingOtp
                    ? null
                    : () async {
                        final mobile = _normalizedPhone ??
                            AuthValidation.normalizePakistanPhone(
                              _mobileController.text,
                            );
                        await _sendGuestOtp(mobile);
                      },
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
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _verifyOtpAndSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: AppColors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Text(
                  'Verify & Continue',
                  style: AppTypography.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => setState(() {
                    _step = 1;
                    _otpController.clear();
                    _debugOtp = null;
                  }),
          child: Text(
            'Back to patient information',
            style: AppTypography.raleway(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryRed,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          _step == 1 ? 'Patient Information' : 'OTP Verification',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: const [
          AppBarIconBadge(icon: Icons.calendar_month_outlined),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: _step == 1 ? _buildFormStep() : _buildOtpStep(),
        ),
      ),
    );
  }
}
