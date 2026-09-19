import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/services/recent_activity_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/billing_departments.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/billing/billing_amount_card.dart';
import 'package:btih_andriod_app/widgets/billing/invoice_details_modal.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

enum BillSortOrder {
  latestFirst,
  oldestFirst,
  amountHigh,
  amountLow,
}

class BillHistoryFilters {
  final int? year;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const BillHistoryFilters({this.year, this.dateFrom, this.dateTo});

  static const empty = BillHistoryFilters();

  bool get hasActive => year != null || dateFrom != null || dateTo != null;

  int get activeCount {
    var count = 0;
    if (year != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    return count;
  }

  BillHistoryFilters copyWith({
    int? year,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearYear = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return BillHistoryFilters(
      year: clearYear ? null : (year ?? this.year),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

class DepartmentBillsScreen extends StatefulWidget {
  final String patientMrNo;
  final BillingDepartment department;
  final List<PatientReport> reports;

  const DepartmentBillsScreen({
    super.key,
    required this.patientMrNo,
    required this.department,
    required this.reports,
  });

  @override
  State<DepartmentBillsScreen> createState() => _DepartmentBillsScreenState();
}

class _DepartmentBillsScreenState extends State<DepartmentBillsScreen> {
  final _searchController = TextEditingController();
  BillSortOrder _sortOrder = BillSortOrder.latestFirst;
  BillHistoryFilters _filters = BillHistoryFilters.empty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _departmentTotal =>
      widget.reports.fold(0, (sum, item) => sum + item.amount);

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  int? _billYear(PatientReport report) => _parseDate(report.paymentDate)?.year;

  List<int> get _availableYears {
    return widget.reports
        .map(_billYear)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  bool _matchesFilters(PatientReport report) {
    final date = _parseDate(report.paymentDate);
    if (_filters.year != null && _billYear(report) != _filters.year) {
      return false;
    }
    if (_filters.dateFrom != null && date != null) {
      final from = DateTime(
        _filters.dateFrom!.year,
        _filters.dateFrom!.month,
        _filters.dateFrom!.day,
      );
      if (date.isBefore(from)) return false;
    }
    if (_filters.dateTo != null && date != null) {
      final to = DateTime(
        _filters.dateTo!.year,
        _filters.dateTo!.month,
        _filters.dateTo!.day,
        23,
        59,
        59,
      );
      if (date.isAfter(to)) return false;
    }
    return true;
  }

  List<PatientReport> get _filteredReports {
    final query = _searchController.text.trim().toLowerCase();
    var list = widget.reports.where(_matchesFilters).where((report) {
      if (query.isEmpty) return true;
      return report.billId.toLowerCase().contains(query) ||
          report.invoiceNo.toLowerCase().contains(query) ||
          report.amount.toString().contains(query) ||
          report.paymentDate.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) {
      final dateA = _parseDate(a.paymentDate);
      final dateB = _parseDate(b.paymentDate);
      switch (_sortOrder) {
        case BillSortOrder.amountHigh:
          return b.amount.compareTo(a.amount);
        case BillSortOrder.amountLow:
          return a.amount.compareTo(b.amount);
        case BillSortOrder.latestFirst:
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        case BillSortOrder.oldestFirst:
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateA.compareTo(dateB);
      }
    });

    return list;
  }

  String get _sortLabel {
    switch (_sortOrder) {
      case BillSortOrder.latestFirst:
        return 'Latest';
      case BillSortOrder.oldestFirst:
        return 'Oldest';
      case BillSortOrder.amountHigh:
        return 'Amount ↓';
      case BillSortOrder.amountLow:
        return 'Amount ↑';
    }
  }

  String _formatDayMonth(String dateTimeString) {
    final dateTime = _parseDate(dateTimeString);
    if (dateTime == null) return '--';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }

  String _formatYear(String dateTimeString) {
    final dateTime = _parseDate(dateTimeString);
    return dateTime == null ? '' : '${dateTime.year}';
  }

  String _formatTime(String dateTimeString) {
    final dateTime = _parseDate(dateTimeString);
    if (dateTime == null) return '';
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _openInvoiceDetails(PatientReport report) {
    RecentActivityService.instance.trackBill(
      scopeId: RecentActivityService.instance.resolveScope(
        patientMrNo: widget.patientMrNo,
      ),
      report: report.toJson(),
      departmentCode: widget.department.code,
      departmentName: widget.department.name,
      rptId: report.reportId ?? widget.department.rptId,
    );

    return showInvoiceDetailsModal(
      context: context,
      patientMrNo: widget.patientMrNo,
      report: report,
      rptId: report.reportId ?? widget.department.rptId,
    );
  }

  Future<void> _showFilterSheet() async {
    var draft = _filters;
    final years = _availableYears;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.fieldBorder,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Filter Bills',
                        style: AppTypography.raleway(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Year',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greyText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'All years',
                            selected: draft.year == null,
                            onTap: () => setSheetState(
                              () => draft = draft.copyWith(clearYear: true),
                            ),
                          ),
                          ...years.map(
                            (year) => _FilterChip(
                              label: '$year',
                              selected: draft.year == year,
                              onTap: () => setSheetState(
                                () => draft = draft.copyWith(year: year),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _filters = BillHistoryFilters.empty;
                                });
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepRed,
                                foregroundColor: AppColors.white,
                              ),
                              onPressed: () {
                                setState(() => _filters = draft);
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppAppBar(
      centerTitle: true,
      title: Text(
        widget.department.name,
        style: AppTypography.raleway(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      actions: [
        AppBarIconBadge(icon: widget.department.icon),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReports;
    final tint = widget.department.gradient.first;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BillingAmountCard(
            billCount: widget.reports.length,
            totalAmount: _departmentTotal,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildSearchBar(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilterSortRow(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.reports.isEmpty
                ? _buildEmpty()
                : filtered.isEmpty
                    ? _buildNoResults()
                    : ListView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        children: [
                          ..._buildTimeline(filtered, tint),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'No more records',
                              style: AppTypography.roboto(
                                fontSize: 13,
                                color: AppColors.greyText
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: AppTypography.roboto(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: 'Search bill ID, invoice, amount...',
        hintStyle: AppTypography.roboto(
          fontSize: 13,
          color: AppColors.greyText.withValues(alpha: 0.8),
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.greyText),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.greyText,
                onPressed: _searchController.clear,
              )
            : null,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilterSortRow() {
    final filterCount = _filters.activeCount;

    return Row(
      children: [
        Expanded(
          child: TapFeedback(
            onTap: _showFilterSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: filterCount > 0 ? AppColors.softRed : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: filterCount > 0
                      ? AppColors.primaryRed.withValues(alpha: 0.35)
                      : AppColors.fieldBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: filterCount > 0
                        ? AppColors.primaryRed
                        : AppColors.greyText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filterCount > 0 ? 'Filter ($filterCount)' : 'Filter',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: filterCount > 0
                          ? AppColors.primaryRed
                          : AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<BillSortOrder>(
          initialValue: _sortOrder,
          onSelected: (value) => setState(() => _sortOrder = value),
          offset: const Offset(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            _sortMenuItem('Latest First', BillSortOrder.latestFirst),
            _sortMenuItem('Oldest First', BillSortOrder.oldestFirst),
            _sortMenuItem('Amount High → Low', BillSortOrder.amountHigh),
            _sortMenuItem('Amount Low → High', BillSortOrder.amountLow),
          ],
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sort: ',
                  style: AppTypography.roboto(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
                Text(
                  _sortLabel,
                  style: AppTypography.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.primaryRed,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<BillSortOrder> _sortMenuItem(String label, BillSortOrder value) {
    return PopupMenuItem(
      value: value,
      child: Text(
        label,
        style: AppTypography.roboto(
          fontWeight:
              _sortOrder == value ? FontWeight.w700 : FontWeight.w400,
          color: _sortOrder == value
              ? AppColors.primaryRed
              : AppColors.darkText,
        ),
      ),
    );
  }

  List<Widget> _buildTimeline(List<PatientReport> reports, Color tint) {
    final widgets = <Widget>[];
    int? lastYear;

    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      final year = _billYear(report);

      if (year != null && year != lastYear) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 4));
        widgets.add(_YearBadge(year: year));
        widgets.add(const SizedBox(height: 12));
        lastYear = year;
      }

      final isLast = i == reports.length - 1;
      widgets.add(
        _BillTimelineRow(
          report: report,
          tint: tint,
          isLast: isLast,
          formatDayMonth: _formatDayMonth,
          formatYear: _formatYear,
          formatTime: _formatTime,
          onOpenDetails: () => _openInvoiceDetails(report),
        ),
      );
      if (!isLast) widgets.add(const SizedBox(height: 4));
    }

    return widgets;
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.greyText.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              'No bills found',
              style: AppTypography.raleway(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No ${widget.department.name} bills are available yet.',
              textAlign: TextAlign.center,
              style: AppTypography.roboto(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.greyText),
            const SizedBox(height: 12),
            Text(
              'No bills match your search or filters',
              textAlign: TextAlign.center,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _filters = BillHistoryFilters.empty;
                });
              },
              child: Text(
                'Clear all',
                style: AppTypography.roboto(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.softRed : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryRed : AppColors.fieldBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryRed : AppColors.darkText,
          ),
        ),
      ),
    );
  }
}

class _YearBadge extends StatelessWidget {
  final int year;

  const _YearBadge({required this.year});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 78),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepRed, AppColors.primaryRed],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$year',
            style: AppTypography.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillTimelineRow extends StatelessWidget {
  final PatientReport report;
  final Color tint;
  final bool isLast;
  final String Function(String) formatDayMonth;
  final String Function(String) formatYear;
  final String Function(String) formatTime;
  final VoidCallback onOpenDetails;

  const _BillTimelineRow({
    required this.report,
    required this.tint,
    required this.isLast,
    required this.formatDayMonth,
    required this.formatYear,
    required this.formatTime,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final date = report.paymentDate;
    final isCancelled = report.isCancel == true;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatDayMonth(date),
                    textAlign: TextAlign.right,
                    style: AppTypography.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  Text(
                    formatYear(date),
                    textAlign: TextAlign.right,
                    style: AppTypography.roboto(
                      fontSize: 11,
                      color: AppColors.greyText,
                    ),
                  ),
                  Text(
                    formatTime(date),
                    textAlign: TextAlign.right,
                    style: AppTypography.roboto(
                      fontSize: 11,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 22),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryRed, width: 2.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.lightMaroon,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TapFeedback(
              onTap: onOpenDetails,
              borderRadius: BorderRadius.circular(16),
              child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCancelled
                      ? AppColors.primaryRed.withValues(alpha: 0.35)
                      : AppColors.fieldBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_outlined,
                          size: 18,
                          color: tint,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill #${report.billId}',
                              style: AppTypography.raleway(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                            Text(
                              'Invoice ${report.invoiceNo}',
                              style: AppTypography.roboto(
                                fontSize: 12,
                                color: AppColors.greyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCancelled)
                        Icon(
                          Icons.cancel_outlined,
                          size: 18,
                          color: AppColors.primaryRed.withValues(alpha: 0.8),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatBillingCurrency(report.amount),
                    style: AppTypography.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.duskMaroon,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TapFeedback(
                      onTap: onOpenDetails,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.softRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.remove_red_eye_outlined,
                          color: AppColors.deepRed,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
