import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/patient_model.dart';
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
  final _bloodGroupController = TextEditingController();

  String _genderLabel = 'Not specified';
  String _dobLabel = 'Not available';

  static const double _fieldHeight = 56;

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
    _bloodGroupController.dispose();
    super.dispose();
  }

  Future<void> fetchPatientData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/Patient?MR_NO=${widget.mrNo}"),
        headers: {'accept': '*/*'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No patient data found';
          });
          return;
        }

        final visit = PatientVisit.fromJson(data.first as Map<String, dynamic>);
        final info = PatientInfo.fromPatientVisit(visit);

        setState(() {
          patientInfo = info;
          _firstNameController.text = info.firstName;
          _lastNameController.text = info.lastName;
          _contactController.text = info.contactNo;
          _emailController.text = info.email;
          _bloodGroupController.text = info.bloodGroup;
          _genderLabel = _formatGender(info.gender);
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

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/Patient/updateProfile'),
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: jsonEncode({
          'mrNo': widget.mrNo,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'contactNo': _contactController.text.trim(),
          'email': _emailController.text.trim(),
          'cnic': patientInfo?.cnic ?? '',
          'bloodGroup': _bloodGroupController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        CustomMessageDialog.showSuccess(
          context,
          'Profile updated successfully',
        );
        await fetchPatientData();
      } else {
        final body = jsonDecode(response.body);
        final message = body is Map ? body['message']?.toString() : null;
        CustomMessageDialog.showError(
          context,
          message ?? 'Failed to update profile',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomMessageDialog.showError(context, 'Error updating profile: $e');
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String _formatGender(String gender) {
    if (gender == 'M') return 'Male';
    if (gender == 'F') return 'Female';
    return gender.isNotEmpty ? gender : 'Not specified';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Patient Profile',
          style: AppTypography.raleway(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.deepRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.white, size: 20),
          splashRadius: 22,
          splashColor: AppColors.white.withValues(alpha: 0.12),
          highlightColor: AppColors.white.withValues(alpha: 0.08),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isSaving
                  ? AppColors.white.withValues(alpha: 0.45)
                  : AppColors.white,
              size: 22,
            ),
            splashRadius: 22,
            splashColor: AppColors.white.withValues(alpha: 0.12),
            highlightColor: AppColors.white.withValues(alpha: 0.08),
            onPressed: isSaving ? null : fetchPatientData,
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

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.lightMaroon.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPersonalInfoHeader(),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Hospital Record',
              icon: Icons.local_hospital_outlined,
              children: [
                _buildReadOnlyField(
                  label: 'MR No.',
                  value: widget.mrNo,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildReadOnlyField(
                        label: 'Gender',
                        value: _genderLabel,
                        icon: Icons.wc_outlined,
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
                  controller: _bloodGroupController,
                  label: 'Blood Group',
                  icon: Icons.bloodtype_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              title: 'Full Name',
              icon: Icons.person_outline_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        icon: Icons.person_outline,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'First name is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        icon: Icons.person_outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              title: 'Contact Details',
              icon: Icons.contact_phone_outlined,
              children: [
                _buildTextField(
                  controller: _contactController,
                  label: 'Contact Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Contact number is required'
                      : null,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TapFeedback(
              onTap: isSaving ? null : _updateProfile,
              borderRadius: BorderRadius.circular(16),
              materialColor: AppColors.primaryRed,
              splashColor: AppColors.white.withValues(alpha: 0.18),
              highlightColor: AppColors.deepRed.withValues(alpha: 0.35),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSaving)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    else
                      const Icon(Icons.save_outlined, size: 20, color: AppColors.white),
                    const SizedBox(width: 8),
                    Text(
                      isSaving ? 'Updating...' : 'Update Profile',
                      style: AppTypography.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.lightMaroon,
                AppColors.softRed.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Text(
            'Personal Information',
            style: AppTypography.raleway(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Update your contact and profile details below.',
          style: AppTypography.roboto(
            fontSize: 12,
            color: AppColors.greyText,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primaryRed),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.raleway(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.roboto(
        fontSize: 13,
        color: AppColors.greyText,
      ),
      prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
      filled: true,
      fillColor: AppColors.fieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      constraints: const BoxConstraints(minHeight: _fieldHeight),
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTypography.roboto(fontSize: 14, color: AppColors.darkText),
      decoration: _fieldDecoration(label: label, icon: icon),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      height: _fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.roboto(
                    fontSize: 11,
                    color: AppColors.greyText,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
