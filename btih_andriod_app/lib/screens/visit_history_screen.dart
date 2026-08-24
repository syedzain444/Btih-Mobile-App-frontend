import 'dart:convert';

import 'package:btih_andriod_app/models/patient_model.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/material.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:http/http.dart' as http;

class VisitHistoryScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;

  const VisitHistoryScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
  });

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  List<PatientVisit> _visits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/Patient?MR_NO=${widget.patientMrNo}'),
        headers: {'accept': '*/*'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        setState(() {
          _visits = data.map((e) => PatientVisit.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load visit history';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading visits';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return 'Date unavailable';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.darkText,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Visit History',
          style: AppTypography.raleway(
            fontWeight: FontWeight.w700,
            color: AppColors.deepRed,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : _error != null
              ? _buildError()
              : _visits.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppColors.primaryRed,
                      onRefresh: _fetchVisits,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: _visits.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final visit = _visits[index];
                          return _VisitCard(
                            visit: visit,
                            formatDate: _formatDate,
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.softRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, color: AppColors.primaryRed, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No visits yet',
              style: AppTypography.raleway(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your hospital visit records will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.roboto(color: AppColors.greyText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, style: const TextStyle(color: AppColors.greyText)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchVisits,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final PatientVisit visit;
  final String Function(String) formatDate;

  const _VisitCard({required this.visit, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softRed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${visit.serialNumber}',
                style: AppTypography.mono(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.greyText),
                    const SizedBox(width: 6),
                    Text(
                      formatDate(visit.visitDate),
                      style: AppTypography.raleway(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.medical_services_outlined,
                        size: 14, color: AppColors.primaryRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        visit.doctorName.isNotEmpty ? visit.doctorName : 'Doctor not assigned',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          color: AppColors.greyText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
