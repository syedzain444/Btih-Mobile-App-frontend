import 'package:btih_andriod_app/services/health_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

/// Thin offline banner driven by `GET /api/Health`.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_checking) return;
    setState(() => _checking = true);
    final ok = await HealthService.instance.check();
    if (!mounted) return;
    setState(() {
      _offline = !ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();

    return Material(
      color: AppColors.deepRed,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You appear offline. Some features may be unavailable.',
                  style: AppTypography.roboto(
                    fontSize: 12,
                    color: AppColors.white,
                  ),
                ),
              ),
              TapFeedback(
                onTap: _checking ? null : _refresh,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          'Retry',
                          style: AppTypography.raleway(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
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
}
