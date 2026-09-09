import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Gradient header with heartbeat line and wavy bottom — login screens.
/// Uses the same rust → primary → deep gradient as [WelcomeScreen].
class LoginWaveHeader extends StatelessWidget {
  const LoginWaveHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.stepIndicator,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final String? stepIndicator;

  static const double headerHeight = 292;
  static const double _heartbeatReserve = 52;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipPath(
      clipper: _LoginWaveClipper(),
      child: SizedBox(
        height: headerHeight + topInset,
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.brandGradient,
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -40,
                right: -50,
                child: _decorativeBlob(
                  180,
                  AppColors.white.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                top: topInset + 36,
                left: -70,
                child: _decorativeBlob(
                  140,
                  AppColors.white.withValues(alpha: 0.07),
                ),
              ),
              Positioned(
                top: topInset + 12,
                right: 24,
                child: _decorativeBlob(
                  56,
                  AppColors.white.withValues(alpha: 0.11),
                ),
              ),
              if (showBackButton)
                Positioned(
                  top: topInset + 8,
                  left: 16,
                  child: LoginBackButton(onPressed: onBack),
                ),
              if (stepIndicator != null)
                Positioned(
                  top: topInset + 14,
                  right: 20,
                  child: Text(
                    stepIndicator!,
                    style: AppTypography.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
              Positioned(
                left: 28,
                right: 28,
                top: topInset + 76,
                bottom: _heartbeatReserve,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.raleway(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        height: 1.18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: AppColors.white.withValues(alpha: 0.92),
                        height: 1.55,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 22,
                height: 18,
                child: CustomPaint(
                  painter: const _HeartbeatLinePainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _decorativeBlob(double size, Color color) {
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

/// Circular back control — matches login / forgot-password headers.
class LoginBackButton extends StatelessWidget {
  const LoginBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed ?? () => Navigator.maybePop(context),
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wavy bottom edge — dips lower on the right like the mockup.
class _LoginWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.74);
    path.quadraticBezierTo(
      size.width * 0.72,
      size.height * 1.0,
      size.width * 0.42,
      size.height * 0.86,
    );
    path.quadraticBezierTo(
      size.width * 0.14,
      size.height * 0.68,
      0,
      size.height * 0.88,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Single minimal pulse — fixed to bottom band of header, away from title text.
class _HeartbeatLinePainter extends CustomPainter {
  const _HeartbeatLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final y = size.height * 0.55;
    final w = size.width;

    final path = Path()
      ..moveTo(0, y)
      ..lineTo(w * 0.34, y)
      ..lineTo(w * 0.355, y - 3)
      ..lineTo(w * 0.372, y + 5)
      ..lineTo(w * 0.388, y - 2)
      ..lineTo(w * 0.404, y)
      ..lineTo(w, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
