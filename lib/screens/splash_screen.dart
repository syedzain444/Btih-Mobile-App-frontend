import 'dart:math' as math;

import 'package:btih_andriod_app/screens/patient_main_shell.dart';
import 'package:btih_andriod_app/screens/promotion_screen.dart';
import 'package:btih_andriod_app/screens/welcome_screen.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/promotion_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Branded splash — maroon theme matches [AppColors] / login / welcome.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Transparent lockup (crescent + hospital name) for dark maroon backgrounds.
  static const String _logoAsset = 'assets/images/logo_splash.png';

  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _ambientController;
  late final AnimationController _loaderController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _loaderFade;
  late final Animation<double> _pulseScale;
  late final Animation<double> _ambient;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.duskMaroon,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoSlide = Tween<double>(begin: 22, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.28, 0.75, curve: Curves.easeOut),
    );
    _textSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.28, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _loaderFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.028).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _ambient = CurvedAnimation(
      parent: _ambientController,
      curve: Curves.easeInOut,
    );

    _entranceController.forward();
    _pulseController.repeat(reverse: true);
    _ambientController.repeat(reverse: true);
    _loaderController.repeat();
    _navigateNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_logoAsset), context);
  }

  Future<void> _navigateNext() async {
    final promoFuture = PromotionService.instance.fetchActive();

    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;

    await AuthSession.ensureValidSession();
    if (!mounted) return;

    final restored = AuthSession.restoredDashboardRoute();
    final promotions =
        restored == null ? await promoFuture : const <PromotionItem>[];
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (context, animation, secondaryAnimation) {
          if (restored != null) {
            return PatientMainShell(
              patientMrNo: AuthSession.mrNo!,
              patientName: AuthSession.displayName,
              isLoggedIn: true,
            );
          }
          if (promotions.isEmpty) {
            return const WelcomeScreen();
          }
          return PromotionScreen(initialItems: promotions);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _ambientController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoWidth = math.min(300.0, size.width * 0.72);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.duskMaroon,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Theme-exact maroon field (matches login / welcome brand family).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.rustRed,
                  AppColors.primaryRed,
                  AppColors.deepRed,
                  AppColors.duskMaroon,
                ],
                stops: [0.0, 0.32, 0.72, 1.0],
              ),
            ),
          ),

          // Soft ambient blobs — same language as welcome screen.
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) {
              final t = _ambient.value;
              return Stack(
                children: [
                  Positioned(
                    top: -90 + (18 * t),
                    right: -70,
                    child: _blob(
                      240,
                      AppColors.white.withValues(alpha: 0.10 + 0.03 * t),
                    ),
                  ),
                  Positioned(
                    top: 140 - (12 * t),
                    left: -100,
                    child: _blob(
                      200,
                      AppColors.softRed.withValues(alpha: 0.12),
                    ),
                  ),
                  Positioned(
                    bottom: 80 + (20 * t),
                    right: -40,
                    child: _blob(
                      160,
                      AppColors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  Positioned(
                    bottom: -60,
                    left: -30,
                    child: _blob(
                      180,
                      AppColors.blush.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              );
            },
          ),

          // Centered brand lockup (logo + hospital name from asset).
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _entranceController,
                        _pulseController,
                      ]),
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoFade.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, _logoSlide.value),
                            child: Transform.scale(
                              scale: _logoScale.value * _pulseScale.value,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Image.asset(
                        _logoAsset,
                        width: logoWidth,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        semanticLabel:
                            'Bahria Town International Hospital Karachi',
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedBuilder(
                      animation: _entranceController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textFade.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, _textSlide.value),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.softRed.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Patient Care Portal',
                            textAlign: TextAlign.center,
                            style: AppTypography.raleway(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.softRed.withValues(alpha: 0.95),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom loader — subtle, branded.
          Positioned(
            left: 0,
            right: 0,
            bottom: 36 + bottomPad,
            child: FadeTransition(
              opacity: _loaderFade,
              child: Column(
                children: [
                  SizedBox(
                    width: 128,
                    child: AnimatedBuilder(
                      animation: _loaderController,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: null,
                            minHeight: 3,
                            backgroundColor:
                                AppColors.white.withValues(alpha: 0.18),
                            color: AppColors.softRed,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading…',
                    style: AppTypography.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.softRed.withValues(alpha: 0.8),
                      letterSpacing: 0.4,
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

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
