import 'package:btih_andriod_app/screens/AppointmentsInfoScreen.dart';
import 'package:btih_andriod_app/screens/reports_screen.dart';
import 'package:btih_andriod_app/screens/visit_history_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/patient_profile_card.dart';
import 'package:flutter/material.dart';

class PatientHistoryScreen extends StatelessWidget {
  final String patientMrNo;
  final String patientName;

  const PatientHistoryScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    final modules = [
      _HistoryModule(
        title: 'Prescriptions',
        subtitle: 'View your prescribed medications',
        icon: Icons.medication_outlined,
        tint: AppColors.primaryRed,
        bg: AppColors.softRed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportsScreen(
              patientMrNo: patientMrNo,
              patientName: patientName,
              initialTabIndex: 3,
            ),
          ),
        ),
      ),
      _HistoryModule(
        title: 'Reports',
        subtitle: 'Lab, radiology & diagnostic reports',
        icon: Icons.assignment_outlined,
        tint: const Color(0xFF26A69A),
        bg: const Color(0xFFE0F2F1),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportsScreen(
              patientMrNo: patientMrNo,
              patientName: patientName,
              initialTabIndex: 0,
            ),
          ),
        ),
      ),
      _HistoryModule(
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
      _HistoryModule(
        title: 'Appointments',
        subtitle: 'Upcoming & past appointments',
        icon: Icons.event_available_outlined,
        tint: const Color(0xFFFF7043),
        bg: const Color(0xFFFBE9E7),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentsInfoScreen(
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
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.blush,
                    AppColors.scaffoldBg,
                    AppColors.white,
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -40,
            child: _blob(180, AppColors.rustRed.withValues(alpha: 0.12)),
          ),
          Positioned(
            top: 120,
            left: -60,
            child: _blob(150, AppColors.deepRed.withValues(alpha: 0.07)),
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
                          'My History',
                          textAlign: TextAlign.center,
                          style: AppTypography.raleway(
                            fontSize: 18,
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
                        'Health Records',
                        style: AppTypography.montserrat(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Access your personal prescriptions, reports, visits and appointments.',
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
                      itemBuilder: (context, index) => _ModuleCard(module: modules[index]),
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

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _HistoryModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color bg;
  final VoidCallback onTap;

  const _HistoryModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.bg,
    required this.onTap,
  });
}

class _ModuleCard extends StatelessWidget {
  final _HistoryModule module;

  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: module.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: module.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: module.tint, size: 24),
              ),
              const Spacer(),
              Text(
                module.title,
                style: AppTypography.raleway(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                module.subtitle,
                style: AppTypography.roboto(
                  fontSize: 11,
                  color: AppColors.greyText,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 18, color: module.tint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
