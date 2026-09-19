import 'package:btih_andriod_app/models/patient_model.dart';
import 'package:btih_andriod_app/screens/patient_main_shell.dart';
import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/patient_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/auth_field_decoration.dart';
import 'package:btih_andriod_app/utils/cnic_input_formatter.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/login_wave_header.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Post-registration profile review — pre-fills HMIS data, MR/DOB read-only.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.mrNo,
    this.initialPhone,
  });

  final String mrNo;
  final String? initialPhone;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientService = PatientService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _selectedGender;
  String? _selectedBloodGroup;
  String _dobLabel = 'Not available';
  DateTime? _dateOfBirth;

  static const _fieldHeight = 48.0;
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];
  static const _genderOptions = [
    MapEntry('M', 'Male'),
    MapEntry('F', 'Female'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cnicController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    if (!AuthSession.hasValidToken) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Your session is not active. Please sign in again to load your hospital record.';
      });
      return;
    }

    try {
      final profile = await _patientService.fetchProfile(widget.mrNo);
      if (!mounted) return;

      if (profile != null) {
        _applyProfile(profile);
      } else if (widget.initialPhone != null) {
        _contactController.text = widget.initialPhone!;
      }

      setState(() => _loading = false);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await AuthSession.handleUnauthorized();
      }
      setState(() {
        _loading = false;
        _errorMessage = e.statusCode == 401
            ? 'Session expired. Please sign in again, then complete your profile.'
            : e.message;
        if (widget.initialPhone != null) {
          _contactController.text = widget.initialPhone!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not load profile: $e';
      });
    }
  }

  void _applyProfile(PatientProfileData profile) {
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _contactController.text = profile.contactNo.isNotEmpty
        ? profile.contactNo
        : (widget.initialPhone ?? '');
    _emailController.text = profile.emailAddress;
    _cnicController.text = CnicInputFormatter.formatDigits(profile.cnic);
    _selectedBloodGroup = _normalizeBloodGroup(profile.bloodGroup);
    _selectedGender = _normalizeGender(profile.gender);

    if (profile.dateOfBirth.isNotEmpty) {
      try {
        _dateOfBirth = DateTime.parse(profile.dateOfBirth);
        _dobLabel = _formatDate(profile.dateOfBirth);
      } catch (_) {
        _dobLabel = profile.dateOfBirth;
      }
    }
  }

  String _formatDate(String raw) {
    try {
      final date = DateTime.parse(raw);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return raw;
    }
  }

  String? _normalizeBloodGroup(String value) {
    final trimmed = value.trim().toUpperCase();
    for (final group in _bloodGroups) {
      if (group.toUpperCase() == trimmed) return group;
    }
    return null;
  }

  String? _normalizeGender(String value) {
    final upper = value.trim().toUpperCase();
    if (upper == 'M' || upper == 'MALE') return 'M';
    if (upper == 'F' || upper == 'FEMALE') return 'F';
    return null;
  }

  String get _displayName {
    final name = '${_firstNameController.text} ${_lastNameController.text}'
        .trim();
    return name.isEmpty ? AuthSession.displayName : name;
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) {
      CustomMessageDialog.showError(context, 'Please select your date of birth.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _patientService.setupProfile(
        mrNo: widget.mrNo,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        cnic: _cnicController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        gender: _selectedGender!,
        bloodGroup: _selectedBloodGroup!,
        email: _emailController.text.trim(),
      );

      await _patientService.updateProfile(
        mrNo: widget.mrNo,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _selectedGender,
        cnic: _cnicController.text.trim(),
        contactNo: _contactController.text.trim(),
        bloodGroup: _selectedBloodGroup,
        emailAddress: _emailController.text.trim(),
        dateOfBirth: _dateOfBirth,
      );

      if (!mounted) return;

      final mrNo = AuthSession.mrNo ?? widget.mrNo;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PatientMainShell(
            patientMrNo: mrNo,
            patientName: _displayName,
            isLoggedIn: true,
          ),
        ),
        (_) => false,
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomMessageDialog.showError(context, 'Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateName(String? value, {required String label}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$label is required';
    return null;
  }

  String? _validateCnic(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'CNIC is required';
    if (!CnicInputFormatter.isValid(trimmed)) {
      return 'Enter CNIC as 12345-1234567-1';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.blush,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoginWaveHeader(
              title: 'Patient Profile',
              subtitle:
                  'Your hospital record is shown below. Complete any missing details, then continue.',
              showBackButton: false,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryRed,
                      ),
                    )
                  : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.roboto(
                          fontSize: 12,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: AuthSession.hasValidToken
                          ? _loadProfile
                          : () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (_) => false,
                              );
                            },
                      child: Text(
                        AuthSession.hasValidToken ? 'Retry' : 'Sign In',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildIdentityStrip(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _firstNameController,
                    label: 'First Name',
                    validator: (v) => _validateName(v, label: 'First name'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    required: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnly(
                    label: 'MR No.',
                    value: widget.mrNo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateOfBirth != null
                      ? _buildReadOnly(
                          label: 'Date of Birth',
                          value: _dobLabel,
                        )
                      : _buildDateOfBirthPicker(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _cnicController,
              label: 'CNIC',
              keyboardType: TextInputType.number,
              inputFormatters: [CnicInputFormatter()],
              validator: _validateCnic,
            ),
            const SizedBox(height: 12),
            _buildGenderSelector(),
            const SizedBox(height: 12),
            _buildBloodGroupSelector(),
            const SizedBox(height: 12),
            _buildField(
              controller: _contactController,
              label: 'Contact',
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Contact is required' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              required: false,
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Save & Continue',
              loading: _saving,
              useBrandGradient: true,
              onPressed: _saving ? null : _saveAndContinue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.softRed,
            child: Text(
              _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'P',
              style: AppTypography.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryRed,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: AppTypography.raleway(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                Text(
                  'MR No: ${widget.mrNo}',
                  style: AppTypography.roboto(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
          (required
              ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
              : null),
      style: AppTypography.roboto(fontSize: 15, color: AppColors.darkText),
      decoration: authUnderlineFieldDecoration(hint: label),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
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
      setState(() {
        _dateOfBirth = picked;
        _dobLabel = _formatDate(picked.toIso8601String());
      });
    }
  }

  Widget _buildDateOfBirthPicker() {
    final hasValue = _dobLabel != 'Not available';

    return TapFeedback(
      onTap: _saving ? null : _pickDateOfBirth,
      borderRadius: BorderRadius.circular(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasValue ? 'Date of Birth' : 'Select date of birth',
            style: AppTypography.roboto(
              fontSize: hasValue ? 12 : 14,
              color: AppColors.greyText,
            ),
          ),
          if (hasValue) ...[
            const SizedBox(height: 4),
            Text(
              _dobLabel,
              style: AppTypography.roboto(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.darkText,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            height: 1.2,
            color: AppColors.hairline,
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnly({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.roboto(
            fontSize: 12,
            color: AppColors.greyText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1.2,
          color: AppColors.hairline,
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return FormField<String>(
      initialValue: _selectedGender,
      validator: (_) =>
          _selectedGender == null ? 'Select gender' : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gender',
              style: AppTypography.roboto(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: _genderOptions.map((option) {
                final selected = _selectedGender == option.key;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: option.key == 'M' ? 6 : 0,
                      left: option.key == 'F' ? 6 : 0,
                    ),
                    child: TapFeedback(
                      onTap: _saving
                          ? null
                          : () {
                              setState(() => _selectedGender = option.key);
                              state.didChange(option.key);
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: _fieldHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.softRed : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryRed
                                : AppColors.fieldBorder,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              option.key == 'M'
                                  ? Icons.male_rounded
                                  : Icons.female_rounded,
                              size: 18,
                              color: selected
                                  ? AppColors.primaryRed
                                  : AppColors.greyText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              option.value,
                              style: AppTypography.roboto(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.primaryRed
                                    : AppColors.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  state.errorText!,
                  style: AppTypography.roboto(
                    fontSize: 11,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBloodGroupSelector() {
    return FormField<String>(
      initialValue: _selectedBloodGroup,
      validator: (_) =>
          _selectedBloodGroup == null ? 'Select a blood group' : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blood Group',
              style: AppTypography.roboto(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 6),
            TapFeedback(
              onTap: _saving ? null : () => _pickBloodGroup(state),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: _fieldHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bloodtype_outlined,
                      color: AppColors.primaryRed,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedBloodGroup ?? 'Select blood group',
                        style: AppTypography.roboto(
                          fontSize: 14,
                          color: _selectedBloodGroup != null
                              ? AppColors.darkText
                              : AppColors.greyText,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.greyText,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  state.errorText!,
                  style: AppTypography.roboto(
                    fontSize: 11,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickBloodGroup(FormFieldState<String> state) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _bloodGroups
                .map(
                  (group) => ListTile(
                    title: Text(group),
                    onTap: () => Navigator.pop(ctx, group),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedBloodGroup = picked);
      state.didChange(picked);
    }
  }
}
