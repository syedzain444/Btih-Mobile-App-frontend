import 'package:btih_andriod_app/screens/support/support_tickets_screen.dart';
import 'package:btih_andriod_app/services/support_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _service = SupportService();

  SupportContact _contact = const SupportContact(
    hospitalName: 'Bahria Town International Hospital',
    phone: '03491660025',
    email: 'info@btkhospital.com',
    address: 'Bahria Town, Karachi',
    workingHours: '24/7 Emergency | OPD 8:00 AM – 8:00 PM',
  );
  List<SupportFaqItem> _faqItems = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getContact(),
        _service.getFaq(lang: 'en'),
      ]);
      if (!mounted) return;
      setState(() {
        _contact = results[0] as SupportContact;
        _faqItems = results[1] as List<SupportFaqItem>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _phoneDigits =>
      _contact.phone.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _launchTel(String digits) async {
    final cleaned = digits.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchMaps() async {
    final query = _contact.address.isNotEmpty
        ? _contact.address
        : _contact.hospitalName;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showFaqAnswer(SupportFaqItem item) {
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

  void _showAllFaqs() {
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
                          _showFaqAnswer(item);
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
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: AppColors.primaryRed,
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
    final phoneDisplay =
        _contact.phone.isNotEmpty ? _contact.phone : '—';
    final emailDisplay =
        _contact.email.isNotEmpty ? _contact.email : '—';
    final addressDisplay =
        _contact.address.isNotEmpty ? _contact.address : 'Hospital location';
    final hoursDisplay = _contact.workingHours.isNotEmpty
        ? _contact.workingHours
        : '24/7 Emergency';

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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [
                  const _SectionHeading(title: 'Get in Touch'),
                  const SizedBox(height: 6),
                  Text(
                    'Reach out to ${_contact.hospitalName}.',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      color: AppColors.greyText,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    children: [
                      _ContactCard(
                        icon: Icons.phone_in_talk_outlined,
                        title: 'Call Us',
                        subtitle: 'General Enquiries',
                        detail: phoneDisplay,
                        onTap: () => _launchTel(_phoneDigits),
                      ),
                      _ContactCard(
                        icon: Icons.mail_outline_rounded,
                        title: 'Email Us',
                        subtitle: 'Send Us An Email',
                        detail: emailDisplay,
                        onTap: () => _launchEmail(_contact.email),
                      ),
                      _ContactCard(
                        icon: Icons.location_on_outlined,
                        title: 'Visit Us',
                        subtitle: 'Find Our Location',
                        detail: addressDisplay,
                        onTap: _launchMaps,
                      ),
                      _ContactCard(
                        icon: Icons.access_time_rounded,
                        title: 'Hours',
                        subtitle: 'Working Hours',
                        detail: hoursDisplay,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TapFeedback(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportTicketsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blush,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.softRed),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            color: AppColors.primaryRed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Support tickets',
                              style: AppTypography.raleway(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primaryRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(child: _SectionHeading(title: 'FAQ')),
                      if (_faqItems.isNotEmpty)
                        TapFeedback(
                          onTap: _showAllFaqs,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View All',
                                  style: AppTypography.roboto(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.deepRed,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppColors.deepRed,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_faqItems.isEmpty)
                    Text(
                      'FAQ will appear here when available from the server.',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    )
                  else
                    ..._faqItems.take(4).map(
                          (item) => _FaqRow(
                            question: item.question,
                            onTap: () => _showFaqAnswer(item),
                          ),
                        ),
                  const SizedBox(height: 24),
                  _AssistanceBanner(
                    onCall: () => _launchTel(_phoneDigits),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.softRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryRed, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: AppTypography.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.roboto(
                fontSize: 11,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.deepRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.question, required this.onTap});

  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
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
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.primaryRed,
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
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryRed, AppColors.deepRed],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Need immediate assistance?',
              style: AppTypography.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
          TapFeedback(
            onTap: onCall,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 14, color: AppColors.white),
                  const SizedBox(width: 5),
                  Text(
                    'Call',
                    style: AppTypography.roboto(
                      fontSize: 12,
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
