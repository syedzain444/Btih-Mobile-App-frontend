import 'package:btih_andriod_app/models/refill_request_model.dart';
import 'package:btih_andriod_app/services/medication_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class MedicationRefillDetailScreen extends StatefulWidget {
  final String mrNo;
  final int refillId;
  final RefillRequest? initialRefill;

  const MedicationRefillDetailScreen({
    super.key,
    required this.mrNo,
    required this.refillId,
    this.initialRefill,
  });

  @override
  State<MedicationRefillDetailScreen> createState() =>
      _MedicationRefillDetailScreenState();
}

class _MedicationRefillDetailScreenState extends State<MedicationRefillDetailScreen> {
  final _service = MedicationService();
  RefillRequest? _refill;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialRefill != null) {
      _refill = widget.initialRefill;
      _isLoading = false;
    }
    _loadStatus(refresh: widget.initialRefill == null);
  }

  Future<void> _loadStatus({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final refill = await _service.getRefillStatus(
        refillId: widget.refillId,
        mrNo: widget.mrNo,
      );
      if (!mounted) return;
      setState(() {
        _refill = refill;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'COMPLETED':
        return AppColors.medsTeal;
      case 'REJECTED':
      case 'DECLINED':
        return AppColors.primaryRed;
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return AppColors.rustRed;
      default:
        return AppColors.greyText;
    }
  }

  Color _statusBg(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'COMPLETED':
        return AppColors.medsTealBg;
      case 'REJECTED':
      case 'DECLINED':
        return AppColors.softRed;
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return AppColors.lightMaroon;
      default:
        return AppColors.fieldFill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppAppBar(
        title: Text(
          'Refill Status',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          TapFeedback(
            onTap: () => _loadStatus(),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && _refill == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : _error != null && _refill == null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.primaryRed),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load refill status',
              textAlign: TextAlign.center,
              style: AppTypography.roboto(fontSize: 14, color: AppColors.greyText),
            ),
            const SizedBox(height: 16),
            TapFeedback(
              onTap: () => _loadStatus(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Retry',
                  style: AppTypography.raleway(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final refill = _refill!;
    final statusColor = _statusColor(refill.status);
    final statusBg = _statusBg(refill.status);

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: () => _loadStatus(refresh: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        refill.displayStatus,
                        style: AppTypography.raleway(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '#${refill.refillId}',
                      style: AppTypography.mono(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  refill.medicationName ?? 'Medication refill',
                  style: AppTypography.raleway(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
                if (refill.statusMessage != null &&
                    refill.statusMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      refill.statusMessage!,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: statusColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _infoCard(
            title: 'Request details',
            rows: [
              if (refill.quantity != null)
                ('Quantity requested', '${refill.quantity}'),
              if (refill.notes != null && refill.notes!.trim().isNotEmpty)
                ('Notes', refill.notes!.trim()),
              ('Submitted', refill.formattedCreatedDate),
              ('Last updated', refill.formattedUpdatedDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.raleway(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      row.$1,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: AppTypography.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkText,
                        height: 1.35,
                      ),
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
}
