import 'package:btih_andriod_app/screens/more/offers_screen.dart';
import 'package:btih_andriod_app/screens/more/service_info_screen.dart';
import 'package:btih_andriod_app/screens/patient_report_history_screen.dart';
import 'package:btih_andriod_app/screens/settings/help_support_screen.dart';
import 'package:btih_andriod_app/screens/settings/settings_static_screen.dart';
import 'package:btih_andriod_app/screens/support/complaints_suggestions_screen.dart';
import 'package:btih_andriod_app/screens/telemedicine_screen.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Hub for extra patient services — opened from the More bottom-nav tab.
class MoreHubScreen extends StatelessWidget {
  final String patientMrNo;
  final String patientName;
  final bool isLoggedIn;

  const MoreHubScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.isLoggedIn = false,
  });

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openTelemedicine(BuildContext context) async {
    final mr = patientMrNo.trim().isNotEmpty
        ? patientMrNo.trim()
        : (AuthSession.mrNo?.trim() ?? '');
    if (mr.isEmpty || !isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to use telemedicine.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _open(context, TelemedicineScreen(patientMrNo: mr));
  }

  Future<void> _openBilling(BuildContext context) async {
    if (!isLoggedIn || patientMrNo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to view billing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _open(
      context,
      PatientReportHistoryScreen(
        patientMrNo: patientMrNo,
        patientName: patientName,
        isLoggedIn: isLoggedIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'More',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.apps_rounded),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            'Care Services',
            style: AppTypography.raleway(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.greyText,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FeatureTile(
                  title: 'Telemed',
                  subtitle: 'Video consult',
                  icon: Icons.videocam_rounded,
                  accent: const Color(0xFF7D1D2B),
                  onTap: () => _openTelemedicine(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FeatureTile(
                  title: 'Home Sampling',
                  subtitle: 'Lab at home',
                  icon: Icons.science_rounded,
                  accent: const Color(0xFF2B7A74),
                  onTap: () => _open(
                    context,
                    const ServiceInfoScreen(
                      title: 'Home Sampling',
                      subtitle: 'Lab collection at your doorstep',
                      description:
                          'Book a trained phlebotomist to collect samples from your home — ideal when travel is difficult or you prefer privacy.',
                      icon: Icons.science_rounded,
                      highlights: [
                        'Morning & evening collection slots',
                        'Reports linked to your MR number',
                        'Safe handling and cold-chain for samples',
                      ],
                      supportPhone: '021111111111',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WideFeatureTile(
            title: 'E-Pharmacy',
            subtitle: 'Order medicines linked to your prescriptions',
            icon: Icons.local_pharmacy_rounded,
            accent: const Color(0xFF8A4B2E),
            onTap: () => _open(
              context,
              const ServiceInfoScreen(
                title: 'E-Pharmacy',
                subtitle: 'Medicines delivered with care',
                description:
                    'Request medicines against your hospital prescriptions. Our pharmacy team verifies orders before dispatch.',
                icon: Icons.local_pharmacy_rounded,
                highlights: [
                  'Upload or use active prescriptions',
                  'Pharmacist verification before packing',
                  'Delivery coordination with hospital pharmacy',
                ],
                supportPhone: '021111111111',
              ),
            ),
          ),
          const SizedBox(height: 10),
          _WideFeatureTile(
            title: 'Offers & Packages',
            subtitle: 'Health checkups and special packages',
            icon: Icons.local_offer_rounded,
            accent: const Color(0xFF9B2D3C),
            onTap: () => _open(context, const OffersScreen()),
          ),
          const SizedBox(height: 28),
          Text(
            'Hospital services',
            style: AppTypography.raleway(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.greyText,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          _ListCard(
            children: [
              _ListRow(
                icon: Icons.receipt_long_rounded,
                title: 'Billing & invoices',
                subtitle: 'Statements and payment history',
                onTap: () => _openBilling(context),
              ),
              _ListRow(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'FAQs, call, email, visit hours',
                onTap: () => _open(context, const HelpSupportScreen()),
              ),
              _ListRow(
                icon: Icons.feedback_outlined,
                title: 'Complaints & Suggestions',
                subtitle: 'Tell us how we can improve',
                onTap: () =>
                    _open(context, const ComplaintsSuggestionsScreen()),
              ),
              _ListRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we protect your data',
                onTap: () => _open(
                  context,
                  const SettingsStaticScreen(
                    page: SettingsStaticPage.privacyPolicy,
                  ),
                ),
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 132,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: AppTypography.raleway(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.roboto(
                fontSize: 11.5,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideFeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _WideFeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.raleway(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.roboto(
                      fontSize: 12.5,
                      color: AppColors.greyText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.greyText.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final List<Widget> children;

  const _ListCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _ListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _ListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TapFeedback(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.softRed,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.deepRed, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.raleway(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.roboto(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.greyText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 68,
            endIndent: 14,
            color: AppColors.fieldBorder.withValues(alpha: 0.9),
          ),
      ],
    );
  }
}
