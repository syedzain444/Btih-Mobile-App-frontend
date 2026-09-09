import 'dart:io';
import 'dart:typed_data';

import 'package:btih_andriod_app/models/discharge_history_model.dart';
import 'package:btih_andriod_app/services/discharge_history_service.dart';
import 'package:btih_andriod_app/services/discharge_report_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/dashboard_helpers.dart';
import 'package:btih_andriod_app/utils/download_location_helper.dart';
import 'package:btih_andriod_app/utils/report_download_helper.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

enum DischargeSortOrder { latestFirst, oldestFirst }

class DischargeHistoryFilters {
  final int? year;
  final String? doctor;
  final String? admissionOfficer;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const DischargeHistoryFilters({
    this.year,
    this.doctor,
    this.admissionOfficer,
    this.dateFrom,
    this.dateTo,
  });

  static const empty = DischargeHistoryFilters();

  bool get hasActive =>
      year != null ||
      doctor != null ||
      admissionOfficer != null ||
      dateFrom != null ||
      dateTo != null;

  int get activeCount {
    var count = 0;
    if (year != null) count++;
    if (doctor != null) count++;
    if (admissionOfficer != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    return count;
  }

  DischargeHistoryFilters copyWith({
    int? year,
    String? doctor,
    String? admissionOfficer,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearYear = false,
    bool clearDoctor = false,
    bool clearAdmissionOfficer = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return DischargeHistoryFilters(
      year: clearYear ? null : (year ?? this.year),
      doctor: clearDoctor ? null : (doctor ?? this.doctor),
      admissionOfficer: clearAdmissionOfficer
          ? null
          : (admissionOfficer ?? this.admissionOfficer),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

class DischargeHistoryScreen extends StatefulWidget {
  final String patientMrNo;

  const DischargeHistoryScreen({
    super.key,
    required this.patientMrNo,
  });

  @override
  State<DischargeHistoryScreen> createState() => _DischargeHistoryScreenState();
}

class _DischargeHistoryScreenState extends State<DischargeHistoryScreen> {
  final DischargeHistoryService _historyService = DischargeHistoryService();
  final DischargeReportService _reportService = DischargeReportService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<DischargeRecord> _pageRecords = [];
  bool _isLoading = true;
  bool _isPageLoading = false;
  bool _reportActionInProgress = false;
  String? _error;
  int _pageNumber = 1;
  int _pageSize = 10;
  int _totalRecords = 0;
  int _totalPages = 0;
  DischargeSortOrder _sortOrder = DischargeSortOrder.latestFirst;
  DischargeHistoryFilters _filters = DischargeHistoryFilters.empty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int pageNumber, {bool resetScroll = true}) async {
    if (_isPageLoading) return;

    setState(() {
      if (_pageRecords.isEmpty && pageNumber == 1) {
        _isLoading = true;
      } else {
        _isPageLoading = true;
      }
      _error = null;
    });

    try {
      final response = await _historyService.getDischargeHistory(
        mrNo: widget.patientMrNo,
        pageNumber: pageNumber,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _pageRecords = response.data;
        _pageNumber = response.pageNumber;
        _pageSize = response.pageSize;
        _totalRecords = response.totalRecords;
        _totalPages = response.totalPages;
        _isLoading = false;
        _isPageLoading = false;
        _error = null;
      });

      if (resetScroll && _scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isPageLoading = false;
        if (_pageRecords.isEmpty) {
          _error = e.toString();
        }
      });

      if (_pageRecords.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load page: ${e.toString()}'),
            backgroundColor: AppColors.primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _goToPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _totalPages || pageNumber == _pageNumber) {
      return;
    }
    _loadPage(pageNumber);
  }

  Future<void> _refreshCurrentPage() => _loadPage(_pageNumber, resetScroll: false);

  List<int> get _availableYears {
    final years = _pageRecords.map((r) => r.dR_OUT.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  List<String> get _availableDoctors {
    final doctors = _pageRecords
        .map((r) => r.doctoR_NAME.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return doctors;
  }

  List<String> get _availableAdmissionOfficers {
    final officers = _pageRecords
        .map((r) => r.admissioN_OFFICER.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return officers;
  }

  bool _matchesSearch(DischargeRecord record, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final haystack = [
      record.doctoR_NAME,
      record.admissioN_OFFICER,
      '${record.patienT_VISIT_ID}',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  bool _matchesFilters(DischargeRecord record) {
    if (_filters.year != null && record.dR_OUT.year != _filters.year) {
      return false;
    }
    if (_filters.doctor != null && record.doctoR_NAME != _filters.doctor) {
      return false;
    }
    if (_filters.admissionOfficer != null &&
        record.admissioN_OFFICER != _filters.admissionOfficer) {
      return false;
    }

    final dischargeDate = DateTime(
      record.dR_OUT.year,
      record.dR_OUT.month,
      record.dR_OUT.day,
    );

    if (_filters.dateFrom != null) {
      final from = DateTime(
        _filters.dateFrom!.year,
        _filters.dateFrom!.month,
        _filters.dateFrom!.day,
      );
      if (dischargeDate.isBefore(from)) return false;
    }

    if (_filters.dateTo != null) {
      final to = DateTime(
        _filters.dateTo!.year,
        _filters.dateTo!.month,
        _filters.dateTo!.day,
      );
      if (dischargeDate.isAfter(to)) return false;
    }

    return true;
  }

  List<DischargeRecord> get _filteredRecords {
    final query = _searchController.text.trim();
    var list = _pageRecords
        .where((r) => _matchesSearch(r, query) && _matchesFilters(r))
        .toList();

    list.sort((a, b) {
      return _sortOrder == DischargeSortOrder.latestFirst
          ? b.dR_OUT.compareTo(a.dR_OUT)
          : a.dR_OUT.compareTo(b.dR_OUT);
    });
    return list;
  }

  String get _sortLabel => _sortOrder == DischargeSortOrder.latestFirst
      ? 'Latest First'
      : 'Oldest First';

  String _dischargeFileName(DischargeRecord record) {
    return 'Discharge_Visit_${record.patienT_VISIT_ID}.pdf';
  }

  String _dischargeDisplayTitle(DischargeRecord record) {
    return 'Discharge · Visit #${record.patienT_VISIT_ID}';
  }

  bool _looksLikePdf(dynamic data) {
    if (data == null) return false;
    final List<int> bytes;
    if (data is List<int>) {
      bytes = data;
    } else if (data is Uint8List) {
      bytes = data;
    } else {
      return false;
    }
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  Future<List<int>> _fetchDischargePdfBytes(DischargeRecord record) async {
    final response = await _reportService.generateDischargeReport(
      patientVisitId: record.patienT_VISIT_ID,
      empId: 82,
      rptId: 35,
    );

    final contentType = response.headers.value('content-type');
    if (!_looksLikePdf(response.data) &&
        (contentType == null || !contentType.contains('application/pdf'))) {
      throw Exception('Server did not return a valid PDF');
    }

    return response.data;
  }

  Widget _buildLoadingDialog({
    required String title,
    required String subtitle,
  }) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.softRed,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: AppColors.primaryRed,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.deepRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.roboto(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewDischargeReport(DischargeRecord record) async {
    if (_reportActionInProgress) return;
    _reportActionInProgress = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(
        title: _dischargeDisplayTitle(record),
        subtitle: 'Generating your report',
      ),
    );

    try {
      final bytes = await _fetchDischargePdfBytes(record);
      final dir = await getApplicationDocumentsDirectory();
      final fileName = _dischargeFileName(record);
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _openPdf(filePath, fileName);
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error generating report: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      _reportActionInProgress = false;
    }
  }

  Future<void> _downloadDischargeReport(DischargeRecord record) async {
    if (_reportActionInProgress) return;
    _reportActionInProgress = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(
        title: _dischargeDisplayTitle(record),
        subtitle: 'Downloading report',
      ),
    );

    try {
      final bytes = await _fetchDischargePdfBytes(record);
      final fileName = _dischargeFileName(record);
      final savedFile = await ReportDownloadHelper.savePdfBytes(
        bytes: bytes,
        fileName: fileName,
      );

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      await CustomMessageDialog.showDownloadComplete(
        context,
        fileName: savedFile.fileName,
        locationLabel: savedFile.locationLabel,
        onOpenLocation: () => DownloadLocationHelper.openSavedLocation(savedFile),
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      CustomMessageDialog.showError(
        context,
        'Download failed. Please try again.\n\n${e.toString()}',
      );
    } finally {
      _reportActionInProgress = false;
    }
  }

  void _openPdf(String filePath, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppAppBar(
            title: Text(
              fileName,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.white),
                onPressed: () => _sharePdf(filePath, fileName),
                tooltip: 'Share PDF',
              ),
            ],
          ),
          body: SfPdfViewer.file(
            File(filePath),
            pageLayoutMode: PdfPageLayoutMode.single,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
          ),
        ),
      ),
    );
  }

  Future<void> _sharePdf(String filePath, String reportName) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Here is your $reportName',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: ${e.toString()}'),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    }
  }

  String _formatCardDate(DateTime dateTime) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatDateTimeField(DateTime dateTime) {
    return '${_formatCardDate(dateTime)} · ${_formatTime(dateTime)}';
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DischargeFilterSheet(
        filters: _filters,
        years: _availableYears,
        doctors: _availableDoctors,
        admissionOfficers: _availableAdmissionOfficers,
        onApply: (filters) {
          setState(() => _filters = filters);
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() => _filters = DischargeHistoryFilters.empty);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppAppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Discharge History',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.summarize_outlined,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : _error != null
              ? _buildErrorState()
              : _totalRecords == 0
                  ? _buildEmptyState()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          child: Stack(
                            children: [
                              _filteredRecords.isEmpty
                                  ? _buildNoResults()
                                  : RefreshIndicator(
                                      color: AppColors.primaryRed,
                                      onRefresh: _refreshCurrentPage,
                                      child: ListView(
                                        controller: _scrollController,
                                        physics:
                                            const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          12,
                                        ),
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.history_rounded,
                                                size: 18,
                                                color: AppColors.deepRed,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Discharge Records',
                                                style: AppTypography.raleway(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.deepRed,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ..._filteredRecords
                                              .map(_buildDischargeCard),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                              if (_isPageLoading)
                                Container(
                                  color: AppColors.white.withValues(alpha: 0.6),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryRed,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_totalPages > 1) _buildPaginationControls(),
                      ],
                    ),
    );
  }

  Widget _buildPaginationControls() {
    final canGoBack = _pageNumber > 1 && !_isPageLoading;
    final canGoForward = _pageNumber < _totalPages && !_isPageLoading;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.fieldBorder.withValues(alpha: 0.8)),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PaginationIconButton(
              icon: Icons.chevron_left_rounded,
              enabled: canGoBack,
              onTap: () => _goToPage(_pageNumber - 1),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (index) {
                    final page = index + 1;
                    final selected = page == _pageNumber;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: TapFeedback(
                        onTap: _isPageLoading ? null : () => _goToPage(page),
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: selected ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryRed
                                : AppColors.fieldBorder,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _PaginationIconButton(
              icon: Icons.chevron_right_rounded,
              enabled: canGoForward,
              onTap: () => _goToPage(_pageNumber + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: AppTypography.roboto(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: 'Search doctor, admission officer, visit ID...',
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
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
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
        PopupMenuButton<DischargeSortOrder>(
          initialValue: _sortOrder,
          onSelected: (value) => setState(() => _sortOrder = value),
          offset: const Offset(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: DischargeSortOrder.latestFirst,
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 18,
                    color: _sortOrder == DischargeSortOrder.latestFirst
                        ? AppColors.primaryRed
                        : AppColors.greyText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Latest First',
                    style: AppTypography.roboto(
                      fontWeight: _sortOrder == DischargeSortOrder.latestFirst
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: _sortOrder == DischargeSortOrder.latestFirst
                          ? AppColors.primaryRed
                          : AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: DischargeSortOrder.oldestFirst,
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    size: 18,
                    color: _sortOrder == DischargeSortOrder.oldestFirst
                        ? AppColors.primaryRed
                        : AppColors.greyText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Oldest First',
                    style: AppTypography.roboto(
                      fontWeight: _sortOrder == DischargeSortOrder.oldestFirst
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: _sortOrder == DischargeSortOrder.oldestFirst
                          ? AppColors.primaryRed
                          : AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildDischargeCard(DischargeRecord record) {
    final doctor = DashboardHelpers.normalizeDoctorName(record.doctoR_NAME);
    final admissionOfficer = record.admissioN_OFFICER.trim().isEmpty
        ? 'Not recorded'
        : record.admissioN_OFFICER.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Visit #${record.patienT_VISIT_ID}',
                              style: AppTypography.raleway(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                                height: 1.25,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  size: 12,
                                  color: AppColors.primaryRed,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'PDF',
                                  style: AppTypography.roboto(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          record.stayDuration,
                          style: AppTypography.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DischargeDetailRow(
                        label: 'Check-in',
                        value: _formatDateTimeField(record.checK_IN),
                      ),
                      const SizedBox(height: 4),
                      _DischargeDetailRow(
                        label: 'Discharged',
                        value: _formatDateTimeField(record.dR_OUT),
                      ),
                      const SizedBox(height: 4),
                      _DischargeDetailRow(
                        label: 'Doctor',
                        value: doctor,
                      ),
                      const SizedBox(height: 4),
                      _DischargeDetailRow(
                        label: 'Admission officer',
                        value: admissionOfficer,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TapFeedback(
                    onTap: () => _downloadDischargeReport(record),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.softRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TapFeedback(
                    onTap: () => _viewDischargeReport(record),
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
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                    ),
                  ),
                ],
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
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.greyText),
            const SizedBox(height: 12),
            Text(
              'No records match your search or filters',
              textAlign: TextAlign.center,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting filters or clearing the search.',
              textAlign: TextAlign.center,
              style: AppTypography.roboto(color: AppColors.greyText),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _filters = DischargeHistoryFilters.empty;
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.summarize_outlined,
              size: 64,
              color: AppColors.greyText.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No discharge records',
              style: AppTypography.raleway(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discharge summaries for this patient will appear here.',
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.primaryRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading discharge history',
              style: AppTypography.raleway(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _loadPage(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DischargeDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DischargeDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: AppTypography.roboto(
              fontSize: 12,
              color: AppColors.greyText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _DischargeFilterSheet extends StatefulWidget {
  final DischargeHistoryFilters filters;
  final List<int> years;
  final List<String> doctors;
  final List<String> admissionOfficers;
  final ValueChanged<DischargeHistoryFilters> onApply;
  final VoidCallback onClear;

  const _DischargeFilterSheet({
    required this.filters,
    required this.years,
    required this.doctors,
    required this.admissionOfficers,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_DischargeFilterSheet> createState() => _DischargeFilterSheetState();
}

class _DischargeFilterSheetState extends State<_DischargeFilterSheet> {
  late int? _year;
  late String? _doctor;
  late String? _admissionOfficer;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _year = widget.filters.year;
    _doctor = widget.filters.doctor;
    _admissionOfficer = widget.filters.admissionOfficer;
    _dateFrom = widget.filters.dateFrom;
    _dateTo = widget.filters.dateTo;
  }

  String _formatPickerDate(DateTime? date) {
    if (date == null) return 'Select date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? _dateFrom ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryRed,
              onPrimary: AppColors.white,
              onSurface: AppColors.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) {
          _dateTo = picked;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) {
          _dateFrom = picked;
        }
      }
    });
  }

  DischargeHistoryFilters _buildFilters() {
    return DischargeHistoryFilters(
      year: _year,
      doctor: _doctor,
      admissionOfficer: _admissionOfficer,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.fieldBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filter Discharge Records',
                  style: AppTypography.raleway(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 20),
                const _FilterSectionTitle('Year'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All Years',
                      selected: _year == null,
                      onTap: () => setState(() => _year = null),
                    ),
                    ...widget.years.map(
                      (y) => _FilterChip(
                        label: '$y',
                        selected: _year == y,
                        onTap: () => setState(() => _year = y),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _FilterSectionTitle('Doctor'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _doctor == null,
                      onTap: () => setState(() => _doctor = null),
                    ),
                    ...widget.doctors.map(
                      (d) => _FilterChip(
                        label: d,
                        selected: _doctor == d,
                        onTap: () => setState(() => _doctor = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _FilterSectionTitle('Admission Officer'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _admissionOfficer == null,
                      onTap: () => setState(() => _admissionOfficer = null),
                    ),
                    ...widget.admissionOfficers.map(
                      (o) => _FilterChip(
                        label: o,
                        selected: _admissionOfficer == o,
                        onTap: () => setState(() => _admissionOfficer = o),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _FilterSectionTitle('Discharge Date Range'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'From',
                        value: _formatPickerDate(_dateFrom),
                        onTap: () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DatePickerField(
                        label: 'To',
                        value: _formatPickerDate(_dateTo),
                        onTap: () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
                if (_dateFrom != null || _dateTo != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _dateFrom = null;
                        _dateTo = null;
                      }),
                      child: Text(
                        'Clear dates',
                        style: AppTypography.roboto(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onClear,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          side: const BorderSide(color: AppColors.primaryRed),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Clear All',
                          style: AppTypography.roboto(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => widget.onApply(_buildFilters()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Filters',
                          style: AppTypography.roboto(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final String title;

  const _FilterSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.raleway(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
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
            color: selected
                ? AppColors.primaryRed.withValues(alpha: 0.4)
                : AppColors.fieldBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.roboto(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primaryRed : AppColors.darkText,
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.roboto(
                fontSize: 11,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? AppColors.softRed : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? AppColors.primaryRed.withValues(alpha: 0.25)
                : AppColors.fieldBorder,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primaryRed : AppColors.greyText,
          size: 24,
        ),
      ),
    );
  }
}
