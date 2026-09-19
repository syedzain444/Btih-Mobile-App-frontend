import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

enum GuestProfileRequiredAction { cancelled, goToDoctors }

Future<GuestProfileRequiredAction> showGuestProfileRequiredDialog(
  BuildContext context,
) async {
  final result = await showDialog<GuestProfileRequiredAction>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'No Appointments',
          style: AppTypography.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryRed,
          ),
        ),
        content: Text(
          'Visit the Doctors section, register yourself, \nfind a doctor and book your appointment.',
          style: AppTypography.roboto(fontSize: 14, color: AppColors.greyText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              GuestProfileRequiredAction.cancelled,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              GuestProfileRequiredAction.goToDoctors,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Go to Doctors'),
          ),
        ],
      );
    },
  );

  return result ?? GuestProfileRequiredAction.cancelled;
}
