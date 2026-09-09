import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient_model.dart';
import '../utils/cnic_input_formatter.dart';
import '../utils/ip_file.dart';

class PatientProfilePage extends StatefulWidget {
  final String mrNo;
  final bool isLoggedIn;

  const PatientProfilePage({
    super.key,
    required this.mrNo,
    this.isLoggedIn = false,
  });

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  PatientInfo? patientInfo;
  bool isLoading = true;
  bool isSaving = false;
  String errorMessage = '';

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _cnicController = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedGender;
  String _dobLabel = 'Not available';
  String _dateOfBirthRaw = '';

  static const double _fieldHeight = 48;

  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const List<MapEntry<String, String>> _genderOptions = [
    MapEntry('M', 'Male'),
    MapEntry('F', 'Female'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchPatientData();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  Future<void> fetchPatientData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await ApiConfig.client.get(
        Uri.parse("${ApiConfig.baseUrl}/api/Patient?MR_NO=${widget.mrNo}"),
        headers: {'accept': '*/*'},
      );

      if (response.statusCode == 200) {
        final parsed =
            PatientApiResponse.fromDynamic(json.decode(response.body));
        if (parsed.profile == null && parsed.visitHistory.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No patient data found';
          });
          return;
        }

        final info = parsed.profile != null
            ? PatientInfo.fromProfile(parsed.profile!)
            : PatientInfo.fromPatientVisit(parsed.visitHistory.first);

        setState(() {
          patientInfo = info;
          _firstNameController.text = info.firstName;
          _lastNameController.text = info.lastName;
          _contactController.text = info.contactNo;
          _emailController.text = info.email;
          _cnicController.text = CnicInputFormatter.formatDigits(info.cnic);
          _selectedBloodGroup = _normalizeBloodGroup(info.bloodGroup);
          _selectedGender = _normalizeGender(info.gender);
          _dateOfBirthRaw = info.dateOfBirth;
          _dobLabel = _formatDate(info.dateOfBirth);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load patient data';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e';
      });
    }
  }

  Map<String, dynamic> _buildProfileUpdatePayload() {
    return {
      'mrNo': widget.mrNo,
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'gender': _selectedGender ?? '',
      'dateOfBirth': _dateOfBirthIso(),
      'cnic': _cnicController.text.trim(),
      'contactNo': _contactController.text.trim(),
      'bloodGroup': _selectedBloodGroup ?? '',
      'emailAddress': _emailController.text.trim(),
    };
  }

  String _dateOfBirthIso() {
    final raw = _dateOfBirthRaw.trim();
    if (raw.isEmpty) return '';
    try {
      return DateTime.parse(raw).toUtc().toIso8601String();
    } catch (_) {
      return raw;
    }
  }

  Future<http.Response> _sendProfileUpdate(Map<String, dynamic> payload) async {
    final headers = {
      'Content-Type': 'application/json',
      'accept': 'application/json',
    };
    final body = jsonEncode(payload);
    final profileUri = Uri.parse('${ApiConfig.baseUrl}/api/Patient/profile');
    final legacyUri =
        Uri.parse('${ApiConfig.baseUrl}/api/Patient/updateProfile');

    // POST first — many hospital IIS servers block PUT (HTTP 405).
    var response = await ApiConfig.client.post(
      profileUri,
      headers: headers,
      body: body,
    );
    if (response.statusCode == 200) return response;

    if (response.statusCode == 404 || response.statusCode == 405) {
      response = await ApiConfig.client.put(
        profileUri,
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) return response;
    }

    if (response.statusCode == 404 || response.statusCode == 405) {
      final legacyPayload = {
        'mrNo': payload['mrNo'],
        'firstName': payload['firstName'],
        'lastName': payload['lastName'],
        'contactNo': payload['contactNo'],
        'email': payload['emailAddress'],
        'cnic': payload['cnic'],
        'bloodGroup': payload['bloodGroup'],
        'gender': payload['gender'],
      };
      response = await ApiConfig.client.post(
        legacyUri,
        headers: headers,
        body: jsonEncode(legacyPayload),
      );
    }

    return response;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final payload = _buildProfileUpdatePayload();
      final response = await _sendProfileUpdate(payload);

      if (!mounted) return;

      final bodyText = response.body.trim();

      if (response.statusCode == 200) {
        CustomMessageDialog.showSuccess(
          context,
          _extractApiMessage(bodyText, response.statusCode,
              fallback: 'Profile updated successfully'),
        );
        await fetchPatientData();
      } else {
        CustomMessageDialog.showError(
          context,
          _extractApiMessage(bodyText, response.statusCode),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomMessageDialog.showError(
          context,
          'Could not update profile. Check network and API server.',
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String _extractApiMessage(
    String body,
    int statusCode, {
    String fallback = 'Failed to update profile',
  }) {
    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        body.startsWith('<HTML')) {
      if (statusCode == 405) {
        return 'Profile update was blocked (HTTP 405 — method not allowed). '
            'The server may not accept PUT/POST on this URL. '
            'Contact IT to enable POST on /api/Patient/profile or /api/Patient/updateProfile.';
      }
      if (statusCode == 404) {
        return 'Profile update endpoint not found.\n\n'
            'Expected: PUT /api/Patient/profile';
      }
      return 'Server returned an HTML error page (HTTP $statusCode). '
          'Contact IT to enable profile update on the API.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}

    return '$fallback (HTTP $statusCode)';
  }

  Future<void> _showBloodGroupPicker(FormFieldState<String> fieldState) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BloodGroupPickerSheet(
        groups: _bloodGroups,
        selected: _selectedBloodGroup,
      ),
    );

    if (picked != null) {
      setState(() => _selectedBloodGroup = picked);
      fieldState.didChange(picked);
    }
  }

  String? _normalizeBloodGroup(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
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

  String? _validateName(String? value, {required String label, bool required = true}) {
    final trimmed = value?.trim() ?? '';
    if (required && trimmed.isEmpty) return '$label is required';
    if (trimmed.isEmpty) return null;
    if (RegExp(r'\d').hasMatch(trimmed)) {
      return 'Numbers are not allowed in $label';
    }
    if (!RegExp(r"^[a-zA-Z\s'.-]+$").hasMatch(trimmed)) {
      return '$label can only contain letters';
    }
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

  String? _validateBloodGroup() {
    if (_selectedBloodGroup == null) return 'Select a blood group';
    return null;
  }

  String? _validateGender() {
    if (_selectedGender == null) return 'Select gender';
    return null;
  }

  String _formatDate(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Not available';
    try {
      final date = DateTime.parse(dateTimeString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateTimeString;
    }
  }

  String get _displayName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    return '$first $last'.trim().isEmpty ? 'Patient' : '$first $last'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Patient Profile',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TapFeedback(
              onTap: isSaving ? null : fetchPatientData,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: isSaving
                      ? AppColors.white.withValues(alpha: 0.45)
                      : AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _buildProfileContent(),
    );
  }

  Widget _buildUpdateButton() {
    return TapFeedback(
      onTap: isSaving ? null : _updateProfile,
      borderRadius: BorderRadius.circular(14),
      materialColor: AppColors.primaryRed,
      splashColor: AppColors.white.withValues(alpha: 0.18),
      highlightColor: AppColors.deepRed.withValues(alpha: 0.35),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primaryRed,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(
                'Update Profile',
                style: AppTypography.raleway(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.primaryRed),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: AppTypography.roboto(
                fontSize: 15,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchPatientData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIdentityStrip(),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person_outline,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-Z\s'.-]"),
                      ),
                    ],
                    validator: (v) => _validateName(v, label: 'First name'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-Z\s'.-]"),
                      ),
                    ],
                    validator: (v) =>
                        _validateName(v, label: 'Last name', required: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(
                    label: 'MR No.',
                    value: widget.mrNo,
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadOnlyField(
                    label: 'Date of Birth',
                    value: _dobLabel,
                    icon: Icons.cake_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _cnicController,
              label: 'CNIC',
              icon: Icons.credit_card_outlined,
              keyboardType: TextInputType.number,
              hintText: '12345-1234567-1',
              inputFormatters: [CnicInputFormatter()],
              validator: _validateCnic,
            ),
            const SizedBox(height: 10),
            _buildGenderSelector(),
            const SizedBox(height: 10),
            _buildBloodGroupSelector(),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _contactController,
              label: 'Contact',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Contact is required'
                  : null,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildUpdateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softRed,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryRed.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'P',
                style: AppTypography.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.raleway(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'MR No: ${widget.mrNo}',
                  style: AppTypography.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

  Widget _buildGenderSelector() {
    return FormField<String>(
      initialValue: _selectedGender,
      validator: (_) => _validateGender(),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gender',
              style: AppTypography.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
                      onTap: () {
                        setState(() => _selectedGender = option.key);
                        state.didChange(option.key);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: _fieldHeight,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.softRed
                              : AppColors.fieldFill,
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
      validator: (_) => _validateBloodGroup(),
      builder: (state) {
        final hasValue = _selectedBloodGroup != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blood Group',
              style: AppTypography.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 6),
            TapFeedback(
              onTap: () => _showBloodGroupPicker(state),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: _fieldHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.hasError
                        ? AppColors.primaryRed.withValues(alpha: 0.6)
                        : AppColors.fieldBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bloodtype_outlined,
                      color: AppColors.greyText,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasValue ? _selectedBloodGroup! : 'Tap to select',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.roboto(
                          fontSize: 14,
                          fontWeight:
                              hasValue ? FontWeight.w600 : FontWeight.w400,
                          color: hasValue
                              ? AppColors.darkText
                              : AppColors.greyText.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.primaryRed,
                      size: 22,
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

  InputDecoration _fieldDecoration({
    required IconData icon,
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.roboto(
        fontSize: 14,
        color: AppColors.greyText.withValues(alpha: 0.7),
      ),
      prefixIcon: Icon(icon, color: AppColors.greyText, size: 20),
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.6)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.greyText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          textAlignVertical: TextAlignVertical.center,
          style: AppTypography.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText,
          ),
          decoration: _fieldDecoration(
            icon: icon,
            hintText: hintText,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.greyText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: _fieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.fieldFill.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.greyText, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BloodGroupPickerSheet extends StatelessWidget {
  final List<String> groups;
  final String? selected;

  const _BloodGroupPickerSheet({
    required this.groups,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : 8),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.bloodtype_outlined, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Text(
                    'Select Blood Group',
                    style: AppTypography.raleway(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepRed,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: groups.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppColors.fieldBorder.withValues(alpha: 0.6),
                ),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final isSelected = group == selected;
                  return TapFeedback(
                    onTap: () => Navigator.pop(context, group),
                    borderRadius: BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            group,
                            style: AppTypography.roboto(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryRed
                                  : AppColors.darkText,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
