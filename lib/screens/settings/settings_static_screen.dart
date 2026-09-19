import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

enum SettingsStaticPage { privacyPolicy }

class SettingsStaticScreen extends StatelessWidget {
  const SettingsStaticScreen({
    super.key,
    required this.page,
  });

  final SettingsStaticPage page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F4),
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: const [
          AppBarIconBadge(icon: Icons.lock_outline_rounded),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const _PrivacyHeroCard(),
          const SizedBox(height: 12),
          for (final section in _privacyCards) ...[
            _PrivacySectionCard(section: section),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          const _PrivacyFooterCard(),
        ],
      ),
    );
  }
}

class _PrivacyHeroCard extends StatelessWidget {
  const _PrivacyHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDECEE), Color(0xFFF8E4E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.softRed),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.deepRed,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy Matters',
                  style: AppTypography.raleway(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'At Bahria Town International Hospital Karachi, we are '
                  'committed to protecting your personal and medical information.',
                  style: AppTypography.roboto(
                    fontSize: 13.5,
                    color: AppColors.darkText,
                    height: 1.45,
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

class _PrivacySectionCard extends StatefulWidget {
  const _PrivacySectionCard({required this.section});

  final _PrivacyCard section;

  @override
  State<_PrivacySectionCard> createState() => _PrivacySectionCardState();
}

class _PrivacySectionCardState extends State<_PrivacySectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return TapFeedback(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
        decoration: BoxDecoration(
          color: _expanded ? AppColors.blush : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded ? AppColors.softRed : AppColors.fieldBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: section.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(section.icon, color: section.iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      height: 1.25,
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        section.body,
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: AppColors.greyText,
                          height: 1.45,
                        ),
                      ),
                    ),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AnimatedRotation(
                turns: _expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.greyText.withValues(alpha: 0.55),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyFooterCard extends StatelessWidget {
  const _PrivacyFooterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      // padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
      // decoration: BoxDecoration(
      //   color: const Color(0xFFFDECEE),
      //   borderRadius: BorderRadius.circular(14),
      //   border: Border.all(color: AppColors.softRed),
      // ),
      // child: Row(
      //   children: [
      //     Container(
      //       width: 36,
      //       height: 36,
      //       decoration: const BoxDecoration(
      //         color: AppColors.deepRed,
      //         shape: BoxShape.circle,
      //       ),
      //       child: const Icon(
      //         Icons.favorite_rounded,
      //         color: AppColors.white,
      //         size: 18,
      //       ),
      //     ),
      //     const SizedBox(width: 12),
      //     Container(
      //       width: 1.5,
      //       height: 36,
      //       color: AppColors.primaryRed.withValues(alpha: 0.35),
      //     ),
      //     const SizedBox(width: 12),
      //     Expanded(
      //       child: Column(
      //         crossAxisAlignment: CrossAxisAlignment.start,
      //         children: [
      //           Text(
      //             'Together for a Healthier Tomorrow',
      //             style: AppTypography.raleway(
      //               fontSize: 14,
      //               fontWeight: FontWeight.w700,
      //               color: AppColors.deepRed,
      //               height: 1.25,
      //             ),
      //           ),
      //           const SizedBox(height: 4),
      //           Text(
      //             'Your privacy is an important part of our commitment to you.',
      //             style: AppTypography.roboto(
      //               fontSize: 12.5,
      //               color: AppColors.darkText,
      //               height: 1.4,
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //   ],
      // ),
    );
  }
}

class _PrivacyCard {
  const _PrivacyCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
}

const _privacyCards = [
  _PrivacyCard(
    title: 'Our Commitment',
    body: 'We respect the privacy and confidentiality of our patients and users.',
    icon: Icons.groups_rounded,
    iconColor: AppColors.deepRed,
    iconBg: Color(0xFFF6DEE1),
  ),
  _PrivacyCard(
    title: 'Information We Collect',
    body:
        'We may collect personal and medical information to provide healthcare '
        'services, manage appointments, and maintain records.',
    icon: Icons.description_outlined,
    iconColor: Color(0xFF2F6FED),
    iconBg: Color(0xFFE4EDFF),
  ),
  _PrivacyCard(
    title: 'How We Use Your Information',
    body:
        'Your information is used only for legitimate healthcare, administrative, '
        'and communication purposes related to your care.',
    icon: Icons.medical_services_outlined,
    iconColor: Color(0xFF2B7A74),
    iconBg: Color(0xFFD9EFEB),
  ),
  _PrivacyCard(
    title: 'Data Security',
    body:
        'We take appropriate measures to protect your information from unauthorized '
        'access, misuse, or disclosure. Access is limited to authorized personnel only.',
    icon: Icons.verified_user_outlined,
    iconColor: Color(0xFF6A4C93),
    iconBg: Color(0xFFEAE3F3),
  ),
  _PrivacyCard(
    title: 'Feedback & Confidentiality',
    body:
        'Any feedback, suggestions, concerns, or complaints you share with us are '
        'handled with the highest level of confidentiality and used only to improve '
        'our services.',
    icon: Icons.chat_bubble_outline_rounded,
    iconColor: Color(0xFFB56A3A),
    iconBg: Color(0xFFF8E8DC),
  ),
  _PrivacyCard(
    title: 'Your Responsibilities',
    body:
        'Please keep your login credentials, passwords, and verification codes '
        'confidential and do not share them with others.',
    icon: Icons.person_outline_rounded,
    iconColor: Color(0xFF1F8A8A),
    iconBg: Color(0xFFD9F0F0),
  ),
  _PrivacyCard(
    title: 'Contact Us',
    body:
        'For any privacy-related questions or concerns, please contact Bahria Town '
        'International Hospital Karachi through our official communication channels.',
    icon: Icons.phone_in_talk_outlined,
    iconColor: Color(0xFF9A7B4F),
    iconBg: Color(0xFFF3EAD9),
  ),
];
