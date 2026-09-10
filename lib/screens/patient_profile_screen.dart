import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
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
        if (widget.isLoggedIn) {
          await AuthSession.updateProfileName(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );
        }
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

  TextStyle _fieldLabelStyle(bool active) {
    return AppTypography.roboto(
      fontSize: 13,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      color: active ? AppColors.deepRed : AppColors.greyText,
    );
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
      body: ColoredBox(
        color: AppColors.blush,
        child: isLoading
            ? _buildLoadingShimmer()
            : errorMessage.isNotEmpty
                ? _buildErrorWidget()
                : _buildProfileContent(),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return AppPrimaryButton(
      label: 'Update Profile',
      loading: isSaving,
      useBrandGradient: true,
      height: 52,
      onPressed: isSaving ? null : _updateProfile,
    );
  }

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: List.generate(
          6,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1.2,
                  color: AppColors.hairline,
                ),
              ],
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIntroBanner(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildLineTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-Z\s'.-]"),
                      ),
                    ],
                    validator: (v) => _validateName(v, label: 'First name'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLineTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
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
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildReadOnlyLineField(
                    label: 'MR No.',
                    value: widget.mrNo,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildReadOnlyLineField(
                    label: 'Date of Birth',
                    value: _dobLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLineTextField(
              controller: _cnicController,
              label: 'CNIC',
              keyboardType: TextInputType.number,
              inputFormatters: [CnicInputFormatter()],
              validator: _validateCnic,
            ),
            const SizedBox(height: 20),
            _buildGenderSelector(),
            const SizedBox(height: 20),
            _buildBloodGroupSelector(),
            const SizedBox(height: 20),
            _buildLineTextField(
              controller: _contactController,
              label: 'Contact Number',
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Contact is required'
                  : null,
            ),
            const SizedBox(height: 20),
            _buildLineTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),
            _buildUpdateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepRed.withValues(alpha: 0.08),
            AppColors.softRed.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.manage_accounts_outlined,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your profile details',
                  style: AppTypography.raleway(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your personal information up to date.',
                  style: AppTypography.roboto(
                    fontSize: 13,
                    color: AppColors.greyText,
                    height: 1.35,
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
        final borderColor = state.hasError
            ? AppColors.primaryRed.withValues(alpha: 0.7)
            : AppColors.hairline;

        final hasSelection = _selectedGender != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: _fieldLabelStyle(hasSelection),
              child: const Text('Gender'),
            ),
            const SizedBox(height: 10),
            Row(
              children: _genderOptions.map((option) {
                final selected = _selectedGender == option.key;
                return Expanded(
                  child: TapFeedback(
                    onTap: () {
                      setState(() => _selectedGender = option.key);
                      state.didChange(option.key);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [
                        Row(
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
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? AppColors.primaryRed
                                    : AppColors.darkText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: selected ? 2 : 0,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            Container(
              height: 1.2,
              color: borderColor,
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText!,
                  style: AppTypography.roboto(
                    fontSize: 12,
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
        final borderColor = state.hasError
            ? AppColors.primaryRed.withValues(alpha: 0.7)
            : AppColors.hairline;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TapFeedback(
              onTap: () => _showBloodGroupPicker(state),
              borderRadius: BorderRadius.circular(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: _fieldLabelStyle(hasValue),
                    child: const Text('Blood Group'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasValue ? _selectedBloodGroup! : 'Select blood group',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.roboto(
                            fontSize: 15,
                            fontWeight:
                                hasValue ? FontWeight.w500 : FontWeight.w400,
                            color: hasValue
                                ? AppColors.darkText
                                : AppColors.greyText,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.greyText,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1.2,
                    color: borderColor,
                  ),
                ],
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText!,
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  InputDecoration _lineFieldDecoration({bool hasError = false}) {
    final errorSide = BorderSide(
      color: AppColors.primaryRed.withValues(alpha: 0.7),
    );
    const normalSide = BorderSide(color: AppColors.hairline, width: 1.2);
    const focusedSide = BorderSide(color: AppColors.primaryRed, width: 2);

    return InputDecoration(
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.only(top: 2, bottom: 12),
      enabledBorder: UnderlineInputBorder(
        borderSide: hasError ? errorSide : normalSide,
      ),
      focusedBorder: const UnderlineInputBorder(borderSide: focusedSide),
      errorBorder: UnderlineInputBorder(borderSide: errorSide),
      focusedErrorBorder: const UnderlineInputBorder(borderSide: focusedSide),
      errorStyle: AppTypography.roboto(
        fontSize: 12,
        color: AppColors.primaryRed,
      ),
    );
  }

  Widget _buildLineTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final hasValue = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: _fieldLabelStyle(hasValue),
          child: Text(label),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: AppTypography.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText,
          ),
          decoration: _lineFieldDecoration(),
          onChanged: (_) {
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildReadOnlyLineField({
    required String label,
    required String value,
  }) {
    final hasValue = value.trim().isNotEmpty &&
        value.trim().toLowerCase() != 'not available';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: _fieldLabelStyle(hasValue),
          child: Text(label),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.greyText.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(
          color: AppColors.hairline,
          height: 1,
          thickness: 1.2,
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
