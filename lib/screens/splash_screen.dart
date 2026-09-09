import 'package:btih_andriod_app/screens/dashboard_screen.dart';
import 'package:btih_andriod_app/screens/welcome_screen.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:flutter/material.dart';

class _HospitalLogo extends StatelessWidget {
  final Animation<double> pulse;

  const _HospitalLogo({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(pulse);

    return AnimatedBuilder(
      animation: scale,
      builder: (context, child) => Transform.scale(
        scale: scale.value,
        child: child,
      ),
      child: Image.asset(
        'assets/images/hospital_logo.png',
        width: 118,
        height: 118,
        fit: BoxFit.contain,
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late Animation<double> _logoAnim;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();

    _logoAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    );

    _entranceController.forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateNext() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      await AuthSession.ensureValidSession();

      if (!mounted) return;

      final restored = AuthSession.restoredDashboardRoute();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) {
            if (restored != null) {
              return DashboardScreen(
                patientMrNo: AuthSession.mrNo!,
                patientName: AuthSession.displayName,
                isLoggedIn: true,
              );
            }
            return const WelcomeScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _logoAnim,
          child: ScaleTransition(
            scale: Tween(begin: 0.7, end: 1.0).animate(_logoAnim),
            child: _HospitalLogo(pulse: _pulseController),
          ),
        ),
      ),
    );
  }
}
