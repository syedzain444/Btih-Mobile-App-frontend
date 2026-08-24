import 'package:btih_andriod_app/screens/discharge_history_screen.dart';
import 'package:btih_andriod_app/screens/reports_screen.dart';
import 'package:btih_andriod_app/screens/visit_history_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/patient_profile_card.dart';
import 'package:flutter/material.dart';

class PatientRecordsScreen extends StatelessWidget {
  final String patientMrNo;
  final String patientName;

  const PatientRecordsScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    final modules = [
      _RecordModule(
        title: 'Laboratory',
        subtitle: 'Blood tests, pathology & lab results',
        icon: Icons.science_outlined,
        tint: const Color(0xFF26A69A),
        bg: const Color(0xFFE0F2F1),
        onTap: () => _openReports(context, categoryIndex: 0),
      ),
      _RecordModule(
        title: 'Gastro',
        subtitle: 'Endoscopy & gastro reports',
        icon: Icons.medical_services_outlined,
        tint: const Color(0xFFFF7043),
        bg: const Color(0xFFFBE9E7),
        onTap: () => _openReports(context, categoryIndex: 1),
      ),
      _RecordModule(
        title: 'Radiology',
        subtitle: 'X-ray, MRI, CT & imaging',
        icon: Icons.radio_rounded,
        tint: const Color(0xFF7E57C2),
        bg: const Color(0xFFEDE7F6),
        onTap: () => _openReports(context, categoryIndex: 2),
      ),
      _RecordModule(
        title: 'Prescription',
        subtitle: 'Doctor prescriptions & medications',
        icon: Icons.medication_outlined,
        tint: AppColors.primaryRed,
        bg: AppColors.softRed,
        onTap: () => _openReports(context, categoryIndex: 3),
      ),
      _RecordModule(
        title: 'Discharge History',
        subtitle: 'Discharge summaries & records',
        icon: Icons.summarize_outlined,
        tint: const Color(0xFFFF7043),
        bg: const Color(0xFFFBE9E7),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DischargeHistoryScreen(patientMrNo: patientMrNo),
          ),
        ),
      ),
      _RecordModule(
        title: 'Visit History',
        subtitle: 'Past hospital visits & doctors',
        icon: Icons.history_rounded,
        tint: const Color(0xFF7E57C2),
        bg: const Color(0xFFEDE7F6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitHistoryScreen(
              patientMrNo: patientMrNo,
              patientName: patientName,
            ),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: _blob(180, AppColors.softRed.withValues(alpha: 0.4)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        color: AppColors.darkText,
                      ),
                      Expanded(
                        child: Text(
                          'Records',
                          textAlign: TextAlign.center,
                          style: AppTypography.raleway(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: PatientProfileCard(
                    patientMrNo: patientMrNo,
                    patientName: patientName,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical Records',
                        style: AppTypography.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Access lab reports, prescriptions, discharge summaries and visit history.',
                        style: AppTypography.roboto(
                          fontSize: 14,
                          color: AppColors.greyText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: modules.length,
                      itemBuilder: (context, index) =>
                          _RecordCard(module: modules[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openReports(BuildContext context, {required int categoryIndex}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportsScreen(
          patientMrNo: patientMrNo,
          patientName: patientName,
          initialTabIndex: categoryIndex,
          openCategoryDirectly: true,
        ),
      ),
    );
  }

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _RecordModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color bg;
  final VoidCallback onTap;

  const _RecordModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.bg,
    required this.onTap,
  });
}

class _RecordCard extends StatelessWidget {
  final _RecordModule module;

  const _RecordCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: module.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: module.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: module.tint, size: 22),
              ),
              const Spacer(),
              Text(
                module.title,
                style: AppTypography.raleway(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                module.subtitle,
                style: AppTypography.roboto(
                  fontSize: 12,
                  color: AppColors.greyText,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
