import 'package:btih_andriod_app/screens/more/offer_detail_screen.dart';
import 'package:btih_andriod_app/services/offer_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  late Future<List<OfferItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = OfferService.instance.fetchActive();
  }

  Future<void> _reload() async {
    setState(() {
      _future = OfferService.instance.fetchActive();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFB),
      appBar: AppAppBar(
        title: Text(
          'Offers & Packages',
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
      body: RefreshIndicator(
        color: AppColors.deepRed,
        onRefresh: _reload,
        child: FutureBuilder<List<OfferItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            final items = snapshot.data ?? const <OfferItem>[];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 48,
                    color: AppColors.greyText.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No offers right now',
                    textAlign: TextAlign.center,
                    style: AppTypography.raleway(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull to refresh — new packages from the hospital will appear here.',
                    textAlign: TextAlign.center,
                    style: AppTypography.roboto(
                      fontSize: 13.5,
                      color: AppColors.greyText,
                      height: 1.4,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final offer = items[index];
                return _OfferCard(
                  offer: offer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OfferDetailScreen(offer: offer),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final OfferItem offer;
  final VoidCallback onTap;

  const _OfferCard({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = offer.absoluteImageUrl;
    final price = offer.displayPrice;
    final crossed = offer.strikethroughPrice;

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRed.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.softRed,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.deepRed,
                      size: 36,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 88,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.deepRed, Color(0xFFC24957)],
                  ),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_offer_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      offer.category,
                      style: AppTypography.raleway(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      offer.category,
                      style: AppTypography.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    offer.title,
                    style: AppTypography.raleway(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  if ((offer.subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      offer.subtitle!,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (price.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          price,
                          style: AppTypography.raleway(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepRed,
                          ),
                        ),
                        if (crossed != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            crossed,
                            style: AppTypography.roboto(
                              fontSize: 13,
                              color: AppColors.greyText,
                            ).copyWith(decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
