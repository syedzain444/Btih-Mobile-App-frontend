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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryRed, AppColors.deepRed],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRed.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Paid Total',
                value: _isVisible
                    ? formatBillingCurrency(widget.totalAmount)
                    : 'Rs. *****',
              ),
            ),
            Container(
              width: 1,
              height: 28,
              color: AppColors.white.withValues(alpha: 0.28),
            ),
            Expanded(
              child: _Metric(
                label: 'Total Bills',
                value: widget.billCount == 1
                    ? '1 bill'
                    : '${widget.billCount} bills',
                alignEnd: true,
              ),
            ),
            const SizedBox(width: 8),
            TapFeedback(
              onTap: () => setState(() => _isVisible = !_isVisible),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _isVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _Metric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: alignEnd ? 12 : 0,
        right: alignEnd ? 0 : 12,
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.roboto(
              fontSize: 11,
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
