import 'package:btih_andriod_app/screens/welcome_screen.dart';
import 'package:btih_andriod_app/services/promotion_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen launch promotions after splash, before welcome.
/// Shows progress bars, Skip, and images fitted to the device screen ratio.
class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key, this.initialItems = const []});

  /// Prefetched during splash — avoids a post-splash spinner.
  final List<PromotionItem> initialItems;

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen>
    with SingleTickerProviderStateMixin {
  late List<PromotionItem> _items;
  int _index = 0;
  bool _navigated = false;
  bool _advancing = false;

  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _items = List<PromotionItem>.from(widget.initialItems);
    _progress = AnimationController(vsync: this)
      ..addStatusListener(_onProgressStatus);

    if (_items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToWelcome();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playCurrent();
    });
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigated) return;
      _goNext();
    });
  }

  void _playCurrent() {
    if (!mounted || _navigated || _items.isEmpty) return;
    final seconds = _items[_index].durationSeconds.clamp(2, 60);
    _progress.duration = Duration(seconds: seconds);
    _progress.forward(from: 0);
  }

  void _goNext() {
    if (_navigated || _advancing || !mounted) return;
    if (_index >= _items.length - 1) {
      _goToWelcome();
      return;
    }
    _advancing = true;
    setState(() => _index += 1);
    _playCurrent();
    _advancing = false;
  }

  void _goPrevious() {
    if (_navigated || _advancing || !mounted) return;
    if (_index <= 0) {
      _playCurrent();
      return;
    }
    _advancing = true;
    setState(() => _index -= 1);
    _playCurrent();
    _advancing = false;
  }

  void _onTapDown(TapDownDetails details) {
    if (_navigated || _items.isEmpty) return;
    final width = MediaQuery.sizeOf(context).width;
    if (details.localPosition.dx < width * 0.35) {
      _goPrevious();
    } else {
      _goNext();
    }
  }

  void _goToWelcome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _progress.stop();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const WelcomeScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _progress.removeStatusListener(_onProgressStatus);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final size = media.size;
    final safeIndex = _index.clamp(0, _items.length - 1);
    final item = _items[safeIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: _PromotionImage(
                key: ValueKey<String>(
                  '${item.promotionId}_${item.absoluteImageUrl}',
                ),
                item: item,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: topInset + 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 10,
            left: 12,
            right: 72,
            child: IgnorePointer(
              child: Row(
                children: List.generate(_items.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == _items.length - 1 ? 0 : 4,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 3,
                          child: i < safeIndex
                              ? const ColoredBox(color: Colors.white)
                              : i > safeIndex
                                  ? ColoredBox(
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                    )
                                  : AnimatedBuilder(
                                      animation: _progress,
                                      builder: (context, child) {
                                        return LinearProgressIndicator(
                                          value: _progress.value.clamp(0.0, 1.0),
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.35),
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                          minHeight: 3,
                                        );
                                      },
                                    ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Positioned(
            top: topInset + 22,
            right: 12,
            child: TextButton(
              onPressed: _goToWelcome,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Skip',
                style: AppTypography.raleway(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionImage extends StatelessWidget {
  const _PromotionImage({super.key, required this.item});

  final PromotionItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.absoluteImageUrl;
    if (url.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      fadeInDuration: const Duration(milliseconds: 180),
      memCacheWidth: (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(480, 1600),
      placeholder: (context, url) => const ColoredBox(color: Colors.black),
      errorWidget: (context, url, error) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.softRed,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        item.title.isEmpty ? 'Promotion' : item.title,
        textAlign: TextAlign.center,
        style: AppTypography.montserrat(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.deepRed,
        ),
      ),
    );
  }
}
