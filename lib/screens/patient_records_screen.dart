import 'package:btih_andriod_app/screens/discharge_history_screen.dart';
import 'package:btih_andriod_app/screens/reports_screen.dart';
import 'package:btih_andriod_app/screens/visit_history_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
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
    final reportModules = [
      _RecordModule(
        title: 'Laboratory',
        subtitle: 'Blood tests, pathology & lab results',
        icon: Icons.science_outlined,
        gradient: [AppColors.duskMaroon, AppColors.primaryRed],
        onTap: () => _openReports(context, categoryIndex: 0),
      ),
      _RecordModule(
        title: 'Gastro',
        subtitle: 'Endoscopy & gastro reports',
        icon: Icons.medical_services_outlined,
        gradient: [AppColors.deepRed, AppColors.rustRed],
        onTap: () => _openReports(context, categoryIndex: 1),
      ),
      _RecordModule(
        title: 'Radiology',
        subtitle: 'X-ray, MRI, CT & imaging',
        icon: Icons.radio_rounded,
        gradient: [AppColors.primaryRed, AppColors.rustRed],
        onTap: () => _openReports(context, categoryIndex: 2),
      ),
      _RecordModule(
        title: 'Prescription',
        subtitle: 'Doctor prescriptions & medications',
        icon: Icons.medication_outlined,
        gradient: const [AppColors.deepRed, AppColors.primaryRed],
        onTap: () => _openReports(context, categoryIndex: 3),
      ),
    ];

    final historyModules = [
      _RecordModule(
        title: 'Discharge History',
        subtitle: 'Discharge summaries & hospital records',
        icon: Icons.summarize_outlined,
        gradient: [AppColors.duskMaroon, AppColors.deepRed],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DischargeHistoryScreen(patientMrNo: patientMrNo),
          ),
        ),
      ),
      _RecordModule(
        title: 'Visit History',
        subtitle: 'Past hospital visits & doctors seen',
        icon: Icons.history_rounded,
        gradient: [AppColors.duskMaroon, AppColors.deepRed],
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
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Records',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.folder_copy_outlined),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          _buildSection(
            title: 'Reports & Results',
            icon: Icons.assignment_outlined,
            modules: reportModules,
          ),
          const SizedBox(height: 28),
          _buildSection(
            title: 'Medical History',
            icon: Icons.timeline_outlined,
            modules: historyModules,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<_RecordModule> modules,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.deepRed),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...modules.map(
          (module) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RecordTile(module: module),
          ),
        ),
      ],
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
        ),
      ),
    );
  }
}

class _RecordModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _RecordModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}

class _RecordTile extends StatelessWidget {
  final _RecordModule module;

  const _RecordTile({required this.module});

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: module.onTap,
      borderRadius: BorderRadius.circular(18),
      materialColor: AppColors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: module.gradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                module.gradient.first.withValues(alpha: 0.15),
                                module.gradient.last.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            module.icon,
                            color: module.gradient.first,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                module.title,
                                style: AppTypography.raleway(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                module.subtitle,
                                style: AppTypography.roboto(
                                  fontSize: 13,
                                  color: AppColors.greyText,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.fieldFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: module.gradient.first,
                          ),
                        ),
                      ],
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
