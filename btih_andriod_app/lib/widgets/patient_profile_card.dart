import 'dart:convert';

import 'package:btih_andriod_app/models/patient_model.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PatientProfileCard extends StatefulWidget {
  final String patientMrNo;
  final String patientName;

  const PatientProfileCard({
    super.key,
    required this.patientMrNo,
    required this.patientName,
  });

  @override
  State<PatientProfileCard> createState() => _PatientProfileCardState();
}

class _PatientProfileCardState extends State<PatientProfileCard> {
  PatientInfo? _patientInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatientProfile();
  }

  Future<void> _fetchPatientProfile() async {
    if (widget.patientMrNo.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/Patient?MR_NO=${widget.patientMrNo}'),
        headers: {'accept': '*/*'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final visit = PatientVisit.fromJson(data.first as Map<String, dynamic>);
          setState(() {
            _patientInfo = PatientInfo.fromPatientVisit(visit);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {
      // Fall back to passed-in name when the API is unavailable.
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String get _displayName {
    if (_patientInfo != null) {
      final name = '${_patientInfo!.firstName} ${_patientInfo!.lastName}'.trim();
      if (name.isNotEmpty) return name;
    }
    return widget.patientName.isNotEmpty ? widget.patientName : 'Patient';
  }

  String get _avatarInitial {
    final source = _patientInfo?.firstName.isNotEmpty == true
        ? _patientInfo!.firstName
        : widget.patientName;
    if (source.isNotEmpty) return source[0].toUpperCase();
    return 'P';
  }

  int? _calculateAge(String dob) {
    if (dob.isEmpty) return null;
    try {
      final birth = DateTime.parse(dob);
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 168,
        decoration: BoxDecoration(
          color: AppColors.softRed.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
      );
    }

    final age = _calculateAge(_patientInfo?.dateOfBirth ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepRed, AppColors.primaryRed, AppColors.rustRed],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.32),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -10,
            bottom: -14,
            child: Icon(
              Icons.person_rounded,
              size: 100,
              color: AppColors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.85),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppColors.softRed,
                      child: Text(
                        _avatarInitial,
                        style: AppTypography.montserrat(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: AppTypography.montserrat(
                            color: AppColors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.patientMrNo.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.white.withValues(alpha: 0.38),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 16,
                                  color: AppColors.white.withValues(alpha: 0.92),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'MR No',
                                  style: AppTypography.roboto(
                                    color: AppColors.softRed.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.patientMrNo,
                                  style: AppTypography.mono(
                                    color: AppColors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  ProfileStatChip(
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: age != null ? '$age yrs' : '—',
                  ),
                  const SizedBox(width: 10),
                  const ProfileStatChip(
                    icon: Icons.height_rounded,
                    label: 'Height',
                    value: '—',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: AppColors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.roboto(
                      color: AppColors.softRed.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    value,
                    style: AppTypography.raleway(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
