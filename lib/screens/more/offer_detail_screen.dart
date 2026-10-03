import 'package:btih_andriod_app/services/offer_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OfferDetailScreen extends StatelessWidget {
  final OfferItem offer;

  const OfferDetailScreen({super.key, required this.offer});

  Future<void> _launchCta(BuildContext context) async {
    final phone = offer.ctaPhone?.trim() ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use Help & Support to reach the hospital.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = offer.absoluteImageUrl;
    final price = offer.displayPrice;
    final crossed = offer.strikethroughPrice;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          offer.category,
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.local_offer_rounded),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (imageUrl.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.softRed,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.local_offer_rounded,
                          color: AppColors.deepRed,
                          size: 48,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.deepRed, Color(0xFFC24957)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: AppTypography.raleway(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          height: 1.25,
                        ),
                      ),
                      if ((offer.subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          offer.subtitle!,
                          style: AppTypography.roboto(
                            fontSize: 14.5,
                            color: AppColors.greyText,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (price.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              price,
                              style: AppTypography.raleway(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepRed,
                              ),
                            ),
                            if (crossed != null) ...[
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  crossed,
                                  style: AppTypography.roboto(
                                    fontSize: 14,
                                    color: AppColors.greyText,
                                  ).copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if ((offer.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'About this package',
                          style: AppTypography.raleway(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          offer.description!,
                          style: AppTypography.roboto(
                            fontSize: 14,
                            color: AppColors.greyText,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (offer.highlights.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text(
                          'Includes',
                          style: AppTypography.raleway(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...offer.highlights.map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: AppColors.deepRed,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: AppTypography.roboto(
                                      fontSize: 13.5,
                                      color: AppColors.darkText,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomInset * 0.15),
              child: TapFeedback(
                onTap: () => _launchCta(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.deepRed,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepRed.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    offer.ctaLabel,
                    style: AppTypography.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
