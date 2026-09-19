import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _mainPhone = '021111284111';
  static const _emergencyPhone = '02199202121';

  Future<void> _launchTel(String digits) async {
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: subject != null ? 'subject=${Uri.encodeComponent(subject)}' : null,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchMaps() async {
    const query = 'Bahria Town International Hospital Karachi';
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showFaqAnswer(BuildContext context, _FaqItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.fieldBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.question,
              style: AppTypography.raleway(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.answer,
              style: AppTypography.roboto(
                fontSize: 14,
                color: AppColors.darkText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllFaqs(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.72;
        return SizedBox(
          height: height,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.fieldBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Frequently Asked Questions',
                    style: AppTypography.raleway(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepRed,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    itemCount: _faqItems.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.hairline,
                    ),
                    itemBuilder: (context, index) {
                      final item = _faqItems[index];
                      return TapFeedback(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showFaqAnswer(context, item);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.question,
                                  style: AppTypography.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: AppColors.primaryRed.withValues(alpha: 0.8),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Help & Support',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: const [
          AppBarIconBadge(icon: Icons.help_outline_rounded),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Text(
            "We're here to help. Reach out to us anytime.",
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.greyText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeading(title: 'Get in Touch'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              _ContactCard(
                icon: Icons.phone_in_talk_outlined,
                title: 'Call Us',
                subtitle: 'General inquiries',
                detail: '+92 3491660025',
                onTap: () => _launchTel(_mainPhone),
              ),
              _ContactCard(
                icon: Icons.mail_outline_rounded,
                title: 'Email Us',
                subtitle: 'Send us an email',
                detail: 'info@btkhospital.com',
                onTap: () => _launchEmail('info@btkhospital.com'),
              ),
              _ContactCard(
                icon: Icons.location_on_outlined,
                title: 'Visit Us',
                subtitle: 'Find our location',
                detail: '2nd Ave, Jinnah Ave Service Road',
                onTap: _launchMaps,
              ),
              _ContactCard(
                icon: Icons.local_hospital_outlined,
                title: 'Emergency',
                subtitle: '24/7 emergency line',
                detail: '021-37187111',
                onTap: () => _launchTel(_emergencyPhone),
              ),
              _ContactCard(
                icon: Icons.rate_review_outlined,
                title: 'Feedback',
                subtitle: 'Share your experience',
                detail: 'Submit Feedback',
                onTap: () => _launchEmail(
                  'info@btkhospital.com',
                  subject: 'Patient Portal Feedback',
                ),
              ),
              _ContactCard(
                icon: Icons.support_agent_outlined,
                title: 'Patient Support',
                subtitle: 'Dedicated assistance',
                detail: 'Contact Support',
                onTap: () => _launchTel(_mainPhone),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: _SectionHeading(title: 'FAQ')),
              TapFeedback(
                onTap: () => _showAllFaqs(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primaryRed.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._faqItems.take(4).map(
            (item) => _FaqRow(
              question: item.question,
              onTap: () => _showFaqAnswer(context, item),
            ),
          ),
          const SizedBox(height: 20),
          _AssistanceBanner(
            onCall: () => _launchTel(_mainPhone),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.raleway(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.deepRed,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.softRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryRed),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTypography.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRed,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.roboto(
                fontSize: 10,
                color: AppColors.greyText,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail,
                    style: AppTypography.roboto(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primaryRed.withValues(alpha: 0.75),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.question,
    required this.onTap,
  });

  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.softRed,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.primaryRed.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                question,
                style: AppTypography.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkText,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.primaryRed.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistanceBanner extends StatelessWidget {
  const _AssistanceBanner({required this.onCall});

  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softRed,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.headset_mic_outlined,
              size: 22,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need Immediate Assistance?',
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Our support team is available 24/7',
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TapFeedback(
            onTap: onCall,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 14,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Call Now',
                    style: AppTypography.roboto(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

const _faqItems = [
  _FaqItem(
    question: 'How can I book an appointment?',
    answer:
        'Open Find a Doctor from the dashboard, choose a specialist, pick an '
        'available slot, and confirm your booking. You can also view upcoming '
        'visits under Appointments.',
  ),
  _FaqItem(
    question: 'What are the visiting hours?',
    answer:
        'General OPD hours are typically 9:00 AM to 5:00 PM on weekdays. '
        'Emergency services are available 24/7. Ward visiting hours may vary—'
        'check with the nursing station on arrival.',
  ),
  _FaqItem(
    question: 'How can I get my test results?',
    answer:
        'Lab and radiology reports appear in Records once they are verified by '
        'the hospital. Open Records from the dashboard and select the report '
        'type you need.',
  ),
  _FaqItem(
    question: 'What should I do in case of an emergency?',
    answer:
        'For urgent medical help, tap Emergency Call on the dashboard or dial '
        'the hospital emergency line immediately. Do not use the app for '
        'life-threatening situations—call or visit the emergency department.',
  ),
  _FaqItem(
    question: 'How do I reset my password?',
    answer:
        'Open the menu → Security Settings → Change password. '
        'You will receive an OTP on your registered mobile number to verify '
        'your identity.',
  ),
  _FaqItem(
    question: 'Can I download my bills and reports?',
    answer:
        'Yes. Open Billing or Records, select the item you need, and use the '
        'download option when available to save a PDF to your device.',
  ),
];
