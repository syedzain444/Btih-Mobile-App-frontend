import 'package:btih_andriod_app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
const Color _brandRed = Color(0xFFCB0203);

/// Layered, softly-flowing wave illustration that fills the bottom of the
/// screen — several translucent pink "dunes" plus a few thin contour
/// lines running through them for texture, matching the reference art.
class _WaveBackgroundPainter extends CustomPainter {
  final double drift; // 0..1 looping, very slow horizontal drift

  _WaveBackgroundPainter({required this.drift});

  Path _dune(Size size, double baseFraction, double amplitude,
      double waveLength, double phase) {
    final baseY = size.height * baseFraction;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, baseY);

    var x = -waveLength;
    var up = true;
    while (x < size.width + waveLength) {
      final nextX = x + waveLength / 2;
      final controlX = (x + nextX) / 2 + phase;
      final controlY = baseY + (up ? -amplitude : amplitude);
      path.quadraticBezierTo(controlX, controlY, nextX, baseY);
      x = nextX;
      up = !up;
    }
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  Path _contourLine(Size size, double baseFraction, double amplitude,
      double waveLength, double phase) {
    final baseY = size.height * baseFraction;
    final path = Path()..moveTo(-waveLength, baseY);
    var x = -waveLength;
    var up = true;
    while (x < size.width + waveLength) {
      final nextX = x + waveLength / 2;
      final controlX = (x + nextX) / 2 + phase;
      final controlY = baseY + (up ? -amplitude : amplitude);
      path.quadraticBezierTo(controlX, controlY, nextX, baseY);
      x = nextX;
      up = !up;
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shift = drift * size.width;

    final dunes = <Path, Color>{
      _dune(size, 0.30, 22, size.width * 0.55, shift * 0.3):
      const Color(0xFFFFEDEE),
      _dune(size, 0.42, 26, size.width * 0.5, -shift * 0.4 + 40):
      const Color(0xFFFFDEE0),
      _dune(size, 0.58, 24, size.width * 0.6, shift * 0.5 - 30):
      const Color(0xFFFFC9CC),
      _dune(size, 0.74, 20, size.width * 0.55, -shift * 0.25 + 20):
      const Color(0xFFFFB3B7),
    };

    for (final entry in dunes.entries) {
      canvas.drawPath(entry.key, Paint()..color = entry.value);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < 5; i++) {
      final baseFraction = 0.20 + i * 0.09;
      linePaint.color = _brandRed.withValues(alpha: 0.10 + i * 0.02);
      final line = _contourLine(
        size,
        baseFraction,
        14 + i * 2,
        size.width * 0.42,
        (shift * (0.2 + i * 0.08)) - i * 25,
      );
      canvas.drawPath(line, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveBackgroundPainter oldDelegate) =>
      oldDelegate.drift != drift;
}

/// Hospital logo with a gentle pulse animation.
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
  late AnimationController _heartbeatController;
  late AnimationController _waveController;

  late Animation<double> _logoAnim;
  late Animation<double> _titleAnim;
  late Animation<double> _taglineAnim;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat();

    _logoAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    );
    _titleAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.72, curve: Curves.easeOut),
    );
    _taglineAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.62, 0.95, curve: Curves.easeOut),
    );

    _entranceController.forward();
    _navigateToWelcome();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _heartbeatController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _navigateToWelcome() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const WelcomeScreen(),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),

          // Layered wave illustration filling the lower ~42% of the screen.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.42,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) => CustomPaint(
                painter: _WaveBackgroundPainter(drift: _waveController.value),
              ),
            ),
          ),

          // Centered content: logo, wordmark, tagline.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 11),
                  FadeTransition(
                    opacity: _logoAnim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.7, end: 1.0).animate(_logoAnim),
                      child: _HospitalLogo(pulse: _heartbeatController),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _titleAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(_titleAnim),
                      child: Column(
                        children: [
                          Text(
                            'Bahria Town\nInternational Hospital',
                            textAlign: TextAlign.center,
                            style: AppTypography.montserrat(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B1A2B),
                              height: 1.25,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Karachi',
                            textAlign: TextAlign.center,
                            style: AppTypography.raleway(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 6,
                              color: const Color(0xFF8B1A2B).withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _taglineAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(_taglineAnim),
                      child: Text(
                        'Your heart deserves\nthe best care',
                        textAlign: TextAlign.center,
                        style: AppTypography.roboto(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF6B6B6B),
                          height: 1.55,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 16),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}