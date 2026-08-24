import 'package:btih_andriod_app/screens/login_screen.dart';
import 'package:btih_andriod_app/screens/signup_screen.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';

/// Entry screen after splash — login, sign up, or hospital staff login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.white)),

          // Rounded decorative bubbles — deep red, peeking from edges.
          Positioned(
            top: -70,
            right: -60,
            child: _decorativeBlob(220, AppColors.deepRed.withValues(alpha: 0.18)),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _decorativeBlob(180, AppColors.deepRed.withValues(alpha: 0.10)),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 26),
                        _buildHospitalTitle(),
                        const SizedBox(height: 14),
                        _buildTaglineChip(),
                      ],
                    ),
                  ),
                ),
                _buildBottomSheet(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.rustRed.withValues(alpha: 0.80), //0.28
            AppColors.softRed.withValues(alpha: 0.50), //0.05
            Colors.transparent,
          ],
          stops: const [0.35, 0.7, 1.0],
        ),
      ),
      child: Center(
        child: Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.rustRed.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.softRed.withValues(alpha: 0.8),
                blurRadius: 0,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/hospital_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalTitle() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTypography.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
              height: 1.28,
            ),
            children: const [
              TextSpan(text: 'Bahria Town\n'),
              TextSpan(
                text: 'International Hospital',
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaglineChip() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            AppColors.softRed,
            AppColors.white.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(
          color: AppColors.rustRed.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rustRed.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Text(
          'Compassionate Care, Always Here.',
          textAlign: TextAlign.center,
          style: AppTypography.raleway(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.deepRed,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        border: Border(
          top: BorderSide(color: AppColors.softRed.withValues(alpha: 0.9)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRed.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.rustRed, AppColors.primaryRed, AppColors.deepRed],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
                height: 1.32,
              ),
              children: const [
                TextSpan(text: 'Welcome to\n'),
                TextSpan(
                  text: 'Bahria Town International Hospital',
                  style: TextStyle(color: AppColors.primaryRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your health is our priority.',
            textAlign: TextAlign.center,
            style: AppTypography.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.greyText,
            ),
          ),
          const SizedBox(height: 28),
          _GradientButton(
            label: 'Login',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [
                    AppColors.softRed.withValues(alpha: 0.7),
                    AppColors.fieldFill,
                  ],
                ),
                border: Border.all(color: AppColors.primaryRed, width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rustRed.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.primaryRed,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  'Sign Up',
                  style: AppTypography.raleway(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.fieldBorder.withValues(alpha: 0.2),
                        AppColors.rustRed.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
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
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.rustRed.withValues(alpha: 0.45),
                        AppColors.fieldBorder.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _StaffLoginCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(isStaffLogin: true),
              ),
            ),
          ),
        ],
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

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.rustRed, AppColors.primaryRed, AppColors.deepRed],
            stops: [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryRed.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffLoginCard extends StatelessWidget {
  final VoidCallback onTap;

  const _StaffLoginCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.softRed.withValues(alpha: 0.55),
                AppColors.white,
              ],
            ),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.rustRed.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                margin: const EdgeInsets.only(left: 0),
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.rustRed, AppColors.primaryRed],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hospital Staff Login',
                      style: AppTypography.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'For Doctors & Admins',
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.softRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
