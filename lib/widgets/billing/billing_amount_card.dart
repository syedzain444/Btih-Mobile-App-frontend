import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class BillingAmountCard extends StatefulWidget {
  final int billCount;
  final double totalAmount;

  const BillingAmountCard({
    super.key,
    required this.billCount,
    required this.totalAmount,
  });

  @override
  State<BillingAmountCard> createState() => _BillingAmountCardState();
}

class _BillingAmountCardState extends State<BillingAmountCard> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Balance',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: AppColors.greyText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _isVisible
                              ? formatBillingCurrency(widget.totalAmount)
                              : 'Rs. ******',
                          key: ValueKey(_isVisible),
                          style: AppTypography.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                            letterSpacing: _isVisible ? -0.2 : 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Billing',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: AppColors.greyText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.billCount == 1
                            ? '1 bill'
                            : '${widget.billCount} bills',
                        style: AppTypography.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TapFeedback(
              onTap: () => setState(() => _isVisible = !_isVisible),
              borderRadius: BorderRadius.circular(8),
              materialColor: AppColors.softRed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                      color: AppColors.primaryRed,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isVisible ? 'Hide balance' : 'View balance',
                      style: AppTypography.raleway(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
