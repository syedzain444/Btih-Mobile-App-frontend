import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
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
  final _authService = AuthService();

  DateTime? _dateOfBirth;
  String? _gender;
  bool _isSubmitting = false;

  static const _genders = ['Male', 'Female'];

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
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
      return (mrData['mrNo'] ?? mrData['MR_NO'])?.toString();
    }
    final value = mrData.toString().trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _showRegisteredAccountDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Account Already Registered',
          style: AppTypography.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryRed,
          ),
        ),
        content: Text(
          'This mobile number is already linked to a patient account. '
          'Please log in with your phone number and password to book appointments.',
          style: AppTypography.roboto(fontSize: 14, color: AppColors.greyText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      CustomMessageDialog.showError(context, 'Please select date of birth');
      return;
    }
    if (_gender == null || _gender!.isEmpty) {
      CustomMessageDialog.showError(context, 'Please select gender');
      return;
    }

    final mobile = GuestSession.normalizePhone(_mobileController.text);
    setState(() => _isSubmitting = true);

    try {
      final response = await _authService.verifyPhoneNumber(mobile);
      if (_registeredMrNo(response) != null) {
        if (!mounted) return;
        await _showRegisteredAccountDialog();
        return;
      }
    } on AuthApiException catch (e) {
      if (e.type != AuthErrorType.unauthorized) {
        if (!mounted) return;
        CustomMessageDialog.showError(context, e.message);
        return;
      }
    } catch (_) {
      if (!mounted) return;
      CustomMessageDialog.showError(
        context,
        'Could not verify mobile number. Please try again.',
      );
      return;
    }

    final dob = DateTime(
      _dateOfBirth!.year,
      _dateOfBirth!.month,
      _dateOfBirth!.day,
    );

    await GuestSession.save(
      fullName: _nameController.text.trim(),
      mobileNumber: mobile,
      dateOfBirth: dob.toIso8601String(),
      gender: _gender!,
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
      filled: true,
      fillColor: AppColors.fieldFill,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobLabel = _dateOfBirth == null
        ? 'Select date of birth'
        : '${_dateOfBirth!.day.toString().padLeft(2, '0')}/'
            '${_dateOfBirth!.month.toString().padLeft(2, '0')}/'
            '${_dateOfBirth!.year}';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.deepRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Patient Information',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tell us about yourself',
                  style: AppTypography.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We use this information for appointment booking. '
                  'If your mobile number is already registered, you will be asked to log in.',
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
                  decoration: _fieldDecoration(
                    hint: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration(
                    hint: 'Mobile Number',
                    icon: Icons.phone_outlined,
                  ),
                  validator: (value) {
                    final digits = GuestSession.normalizePhone(value ?? '');
                    if (digits.length < 10 || digits.length > 15) {
                      return 'Enter a valid mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDateOfBirth,
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
                  onChanged: (value) => setState(() => _gender = value),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Select gender' : null,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
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
                          'Continue',
                          style: AppTypography.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
