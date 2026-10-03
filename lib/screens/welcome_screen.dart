import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/screens/patient_main_shell.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Entry screen after splash — patient login or continue as guest.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const String _hospitalAsset = 'assets/images/hospital.jpeg';
  static const String _logoAsset = 'assets/images/logo_splash.png';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.duskMaroon,
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Image.asset(
                  _hospitalAsset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
                // Splash-aligned maroon wash — stronger at top & bottom seam.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.duskMaroon.withValues(alpha: 0.72),
                        AppColors.deepRed.withValues(alpha: 0.22),
                        AppColors.primaryRed.withValues(alpha: 0.20),
                        AppColors.duskMaroon.withValues(alpha: 0.82),
                      ],
                      stops: const [0.0, 0.38, 0.68, 1.0],
                    ),
                  ),
                ),
                // Soft ambient blobs (splash language).
                Positioned(
                  top: -60,
                  right: -50,
                  child: _blob(200, AppColors.softRed.withValues(alpha: 0.21)),
                ),
                Positioned(
                  top: 90,
                  left: -70,
                  child: _blob(150, AppColors.softRed.withValues(alpha: 0.25)),
                ),
                // Small logo at the bottom of the hero, above the sheet.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Center(
                    child: Image.asset(
                      _logoAsset,
                      height: 48,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      semanticLabel:
                          'Bahria Town International Hospital Karachi',
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomCard(context, bottomInset),
        ],
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context, double bottomInset) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.blush,
            AppColors.white,
            AppColors.blush,
          ],
          stops: const [0.1, 0.4, 0.9],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppColors.white.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRed.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 14, 28, 18 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Welcome to',
                textAlign: TextAlign.center,
                style: AppTypography.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.greyText,
                  letterSpacing: 1.6,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bahria Town\nInternational Hospital',
                textAlign: TextAlign.center,
                style: AppTypography.roboto(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                  height: 1.18,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your health is our priority.',
                textAlign: TextAlign.center,
                style: AppTypography.raleway(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.greyText,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 22),
              // Soft maroon accent rule — echoes splash divider.
              Center(
                child: Container(
                  width: 48,
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: AppColors.brandGradient,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _PatientLoginButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.lightMaroon.withValues(alpha: 0.9),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'or',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.lightMaroon.withValues(alpha: 0.9),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: TapFeedback(
                  onTap: () => _loginAsGuest(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue as a Guest',
                              style: AppTypography.raleway(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryRed,
                              ).copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primaryRed,
                                decorationThickness: 1.2,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.primaryRed,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Browse doctors and book appointments without an account',
                          textAlign: TextAlign.center,
                          style: AppTypography.roboto(
                            fontSize: 12,
                            color: AppColors.greyText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginAsGuest(BuildContext context) async {
    await GuestSession.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const PatientMainShell(
          patientMrNo: '',
          patientName: 'Guest',
          isLoggedIn: false,
        ),
      ),
      (route) => false,
    );
  }

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _PatientLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PatientLoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.duskMaroon.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(26),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Patient Login',
                    style: AppTypography.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
