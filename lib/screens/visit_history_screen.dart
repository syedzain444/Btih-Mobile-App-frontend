import 'dart:convert';

import 'package:btih_andriod_app/models/patient_model.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

enum VisitSortOrder { latestFirst, oldestFirst }

class VisitHistoryFilters {
  final int? year;
  final String? department;
  final String? visitType; // All, Completed, Active
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const VisitHistoryFilters({
    this.year,
    this.department,
    this.visitType,
    this.dateFrom,
    this.dateTo,
  });

  static const empty = VisitHistoryFilters();

  bool get hasActive =>
      year != null ||
      department != null ||
      (visitType != null && visitType != 'All') ||
      dateFrom != null ||
      dateTo != null;

  int get activeCount {
    var count = 0;
    if (year != null) count++;
    if (department != null) count++;
    if (visitType != null && visitType != 'All') count++;
    if (dateFrom != null || dateTo != null) count++;
    return count;
  }

  VisitHistoryFilters copyWith({
    int? year,
    String? department,
    String? visitType,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearYear = false,
    bool clearDepartment = false,
    bool clearVisitType = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return VisitHistoryFilters(
      year: clearYear ? null : (year ?? this.year),
      department: clearDepartment ? null : (department ?? this.department),
      visitType: clearVisitType ? null : (visitType ?? this.visitType),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

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
  PatientProfileData? _profile;
  List<PatientVisit> _allVisits = [];
  bool _isLoading = true;
  String? _error;

  final _searchController = TextEditingController();
  VisitSortOrder _sortOrder = VisitSortOrder.latestFirst;
  VisitHistoryFilters _filters = VisitHistoryFilters.empty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchVisits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiConfig.client.get(
        Uri.parse('${ApiConfig.baseUrl}/api/Patient?MR_NO=${widget.patientMrNo}'),
        headers: {'accept': '*/*'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final parsed =
            PatientApiResponse.fromDynamic(json.decode(response.body));
        final visits = List<PatientVisit>.from(parsed.visitHistory);
        setState(() {
          _profile = parsed.profile;
          _allVisits = visits;
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

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String raw) {
    final dt = _parseDate(raw);
    if (dt == null) return raw.isNotEmpty ? raw.split('T').first : 'Not recorded';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDayMonth(String raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '--';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  String _formatYear(String raw) {
    final dt = _parseDate(raw);
    return dt != null ? '${dt.year}' : '';
  }

  String _formatTime(String raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return 'Not recorded';
    final time = _formatTime(raw);
    final date = _formatDate(raw);
    if (time.isEmpty) return date;
    return '$date · $time';
  }

  String _formatGender(String gender) {
    switch (gender.toUpperCase()) {
      case 'M':
        return 'Male';
      case 'F':
        return 'Female';
      default:
        return gender.isNotEmpty ? gender : 'Not recorded';
    }
  }

  int? _calculateAge(String dob) {
    final dt = _parseDate(dob);
    if (dt == null) return null;
    final now = DateTime.now();
    var age = now.year - dt.year;
    if (now.month < dt.month ||
        (now.month == dt.month && now.day < dt.day)) {
      age--;
    }
    return age;
  }

  String get _displayPatientName {
    if (_profile != null) {
      final name = '${_profile!.firstName} ${_profile!.lastName}'.trim();
      if (name.isNotEmpty) return name;
    }
    return widget.patientName.isNotEmpty ? widget.patientName : 'Patient';
  }

  String _visitPrimaryDate(PatientVisit visit) {
    if (visit.checkIn.isNotEmpty) return visit.checkIn;
    return visit.visitDate;
  }

  int? _visitYear(PatientVisit visit) =>
      _parseDate(_visitPrimaryDate(visit))?.year;

  List<String> get _availableDepartments {
    final depts = _allVisits
        .map((v) => v.displayDepartment)
        .where((d) => d.isNotEmpty && d != 'General')
        .toSet()
        .toList()
      ..sort();
    return depts;
  }

  List<int> get _availableYears {
    final years = _allVisits
        .map(_visitYear)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  bool _matchesSearch(PatientVisit visit, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final haystack = [
      visit.displayDoctor,
      visit.displayDepartment,
      visit.disease ?? '',
      visit.presentingComplaints ?? '',
      visit.admissionNo ?? '',
      visit.admissionOfficer,
      '${visit.patientVisitId}',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  bool _matchesFilters(PatientVisit visit) {
    final date = _parseDate(_visitPrimaryDate(visit));

    if (_filters.year != null && _visitYear(visit) != _filters.year) {
      return false;
    }
    if (_filters.department != null &&
        visit.displayDepartment != _filters.department) {
      return false;
    }
    if (_filters.visitType == 'Completed' && !visit.isDischarged) {
      return false;
    }
    if (_filters.visitType == 'Active' && visit.isDischarged) {
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

  List<PatientVisit> get _filteredVisits {
    final query = _searchController.text.trim();
    var list = _allVisits
        .where((v) => _matchesSearch(v, query) && _matchesFilters(v))
        .toList();

    list.sort((a, b) {
      final da = _parseDate(_visitPrimaryDate(a));
      final db = _parseDate(_visitPrimaryDate(b));
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return _sortOrder == VisitSortOrder.latestFirst
          ? db.compareTo(da)
          : da.compareTo(db);
    });
    return list;
  }

  String get _sortLabel => _sortOrder == VisitSortOrder.latestFirst
      ? 'Latest First'
      : 'Oldest First';

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VisitFilterSheet(
        filters: _filters,
        years: _availableYears,
        departments: _availableDepartments,
        onApply: (filters) {
          setState(() => _filters = filters);
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() => _filters = VisitHistoryFilters.empty);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showProfileSheet(PatientProfileData profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileBottomSheet(
        profile: profile,
        patientName: _displayPatientName,
        mrNo: widget.patientMrNo,
        formatGender: _formatGender,
        formatDate: _formatDate,
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
          'Patient Visit History',
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
                Icons.history_rounded,
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
              ? _buildError()
              : _allVisits.isEmpty
                  ? _buildEmpty()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: _profile != null
                              ? _PatientSummaryCard(
                                  name: _displayPatientName,
                                  mrNo: _profile!.mrNo.isNotEmpty
                                      ? _profile!.mrNo
                                      : widget.patientMrNo,
                                  gender: _formatGender(_profile!.gender),
                                  age: _calculateAge(_profile!.dateOfBirth),
                                  onViewProfile: () =>
                                      _showProfileSheet(_profile!),
                                )
                              : _PatientSummaryCard(
                                  name: _displayPatientName,
                                  mrNo: widget.patientMrNo,
                                  gender: 'Not recorded',
                                  age: null,
                                  onViewProfile: null,
                                ),
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
                          child: _filteredVisits.isEmpty
                              ? _buildNoResults()
                              : RefreshIndicator(
                                  color: AppColors.primaryRed,
                                  onRefresh: _fetchVisits,
                                  child: ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      28,
                                    ),
                                    children: [
                                      ..._buildTimeline(),
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
        hintText: 'Search doctor, department, diagnosis...',
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
        PopupMenuButton<VisitSortOrder>(
          initialValue: _sortOrder,
          onSelected: (value) => setState(() => _sortOrder = value),
          offset: const Offset(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: VisitSortOrder.latestFirst,
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 18,
                    color: _sortOrder == VisitSortOrder.latestFirst
                        ? AppColors.primaryRed
                        : AppColors.greyText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Latest First',
                    style: AppTypography.roboto(
                      fontWeight: _sortOrder == VisitSortOrder.latestFirst
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: _sortOrder == VisitSortOrder.latestFirst
                          ? AppColors.primaryRed
                          : AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: VisitSortOrder.oldestFirst,
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    size: 18,
                    color: _sortOrder == VisitSortOrder.oldestFirst
                        ? AppColors.primaryRed
                        : AppColors.greyText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Oldest First',
                    style: AppTypography.roboto(
                      fontWeight: _sortOrder == VisitSortOrder.oldestFirst
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: _sortOrder == VisitSortOrder.oldestFirst
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

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.greyText),
            const SizedBox(height: 12),
            Text(
              'No visits match your search or filters',
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
                  _filters = VisitHistoryFilters.empty;
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

  List<Widget> _buildTimeline() {
    final visits = _filteredVisits;
    final widgets = <Widget>[];
    int? lastYear;

    for (var i = 0; i < visits.length; i++) {
      final visit = visits[i];
      final year = _visitYear(visit);

      if (year != null && year != lastYear) {
        if (widgets.isNotEmpty) const SizedBox(height: 4);
        widgets.add(_YearBadge(year: year));
        widgets.add(const SizedBox(height: 12));
        lastYear = year;
      }

      final isLast = i == visits.length - 1;
      widgets.add(
        _TimelineVisitRow(
          visit: visit,
          primaryDate: _visitPrimaryDate(visit),
          isLast: isLast,
          formatDayMonth: _formatDayMonth,
          formatYear: _formatYear,
          formatTime: _formatTime,
          formatDateTime: _formatDateTime,
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
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.softRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.primaryRed,
                size: 36,
              ),
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

class _PatientSummaryCard extends StatelessWidget {
  final String name;
  final String mrNo;
  final String gender;
  final int? age;
  final VoidCallback? onViewProfile;

  const _PatientSummaryCard({
    required this.name,
    required this.mrNo,
    required this.gender,
    required this.age,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.softRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryRed.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: AppTypography.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.raleway(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MR No: $mrNo',
                        style: AppTypography.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.greyText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _DemographicChip(label: gender),
                          if (age != null) _DemographicChip(label: '$age Years'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onViewProfile != null)
            TapFeedback(
              onTap: onViewProfile!,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.fieldBorder),
                  ),
                ),
                child: Text(
                  'View Profile',
                  textAlign: TextAlign.center,
                  style: AppTypography.raleway(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemographicChip extends StatelessWidget {
  final String label;

  const _DemographicChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softRed,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryRed,
        ),
      ),
    );
  }
}

class _ProfileBottomSheet extends StatelessWidget {
  final PatientProfileData profile;
  final String patientName;
  final String mrNo;
  final String Function(String) formatGender;
  final String Function(String) formatDate;

  const _ProfileBottomSheet({
    required this.profile,
    required this.patientName,
    required this.mrNo,
    required this.formatGender,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
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
                'Patient Profile',
                style: AppTypography.raleway(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepRed,
                ),
              ),
              const SizedBox(height: 16),
              _ProfileDetailRow('Name', patientName),
              _ProfileDetailRow(
                'MR No',
                profile.mrNo.isNotEmpty ? profile.mrNo : mrNo,
              ),
              _ProfileDetailRow('Gender', formatGender(profile.gender)),
              _ProfileDetailRow(
                'Date of Birth',
                formatDate(profile.dateOfBirth),
              ),
              _ProfileDetailRow(
                'Blood Group',
                _VisitField.displayValue(profile.bloodGroup),
              ),
              _ProfileDetailRow(
                'Contact',
                _VisitField.displayValue(profile.contactNo),
              ),
              _ProfileDetailRow(
                'CNIC',
                _VisitField.displayValue(profile.cnic),
              ),
              _ProfileDetailRow(
                'Email',
                _VisitField.displayValue(profile.emailAddress),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.7)),
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
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.darkText,
              ),
            ),
          ],
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
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRed.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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

class _TimelineVisitRow extends StatelessWidget {
  final PatientVisit visit;
  final String primaryDate;
  final bool isLast;
  final String Function(String) formatDayMonth;
  final String Function(String) formatYear;
  final String Function(String) formatTime;
  final String Function(String) formatDateTime;

  const _TimelineVisitRow({
    required this.visit,
    required this.primaryDate,
    required this.isLast,
    required this.formatDayMonth,
    required this.formatYear,
    required this.formatTime,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
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
                    formatDayMonth(primaryDate),
                    textAlign: TextAlign.right,
                    style: AppTypography.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  Text(
                    formatYear(primaryDate),
                    textAlign: TextAlign.right,
                    style: AppTypography.roboto(
                      fontSize: 11,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatTime(primaryDate),
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
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
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
            child: _TimelineVisitCard(
              visit: visit,
              formatDateTime: formatDateTime,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineVisitCard extends StatefulWidget {
  final PatientVisit visit;
  final String Function(String) formatDateTime;

  const _TimelineVisitCard({
    required this.visit,
    required this.formatDateTime,
  });

  @override
  State<_TimelineVisitCard> createState() => _TimelineVisitCardState();
}

class _TimelineVisitCardState extends State<_TimelineVisitCard> {
  bool _expanded = false;

  static String displayValue(String? value) =>
      _VisitField.displayValue(value);

  Color _departmentColor(String department) {
    switch (department.toUpperCase()) {
      case 'EMERGENCY':
        return AppColors.moduleColor(0).icon;
      case 'OPD':
        return AppColors.moduleColor(1).icon;
      case 'IPD':
        return AppColors.moduleColor(2).icon;
      case 'PHARMACY':
        return AppColors.moduleColor(3).icon;
      case 'LABORATORY':
        return AppColors.moduleColor(4).icon;
      case 'RADIOLOGY':
        return AppColors.moduleColor(5).icon;
      case 'CARDIOLOGY':
        return AppColors.duskMaroon;
      case 'DERMATOLOGY':
        return AppColors.rustRed;
      default:
        return AppColors.primaryRed;
    }
  }

  IconData _departmentIcon(String department) {
    switch (department.toUpperCase()) {
      case 'EMERGENCY':
        return Icons.emergency_rounded;
      case 'OPD':
        return Icons.medical_information_outlined;
      case 'IPD':
        return Icons.local_hospital_outlined;
      case 'PHARMACY':
        return Icons.medication_outlined;
      case 'LABORATORY':
        return Icons.science_outlined;
      case 'RADIOLOGY':
        return Icons.radio_rounded;
      case 'CARDIOLOGY':
        return Icons.favorite_rounded;
      case 'DERMATOLOGY':
        return Icons.face_retouching_natural_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final dept = visit.displayDepartment;
    final deptColor = _departmentColor(dept);
    final deptBg = deptColor.withValues(alpha: 0.12);
    final isCompleted = visit.isDischarged;
    final disease = displayValue(visit.disease);
    final hasDiagnosis = disease != 'Not recorded';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? AppColors.primaryRed.withValues(alpha: 0.3)
              : AppColors.fieldBorder,
        ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: deptBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _departmentIcon(dept),
                    color: deptColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dept Visit',
                        style: AppTypography.raleway(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visit.displayDoctor,
                        style: AppTypography.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      Text(
                        '$dept Department',
                        style: AppTypography.roboto(
                          fontSize: 11,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.successBg
                        : AppColors.softRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'Active',
                    style: AppTypography.roboto(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? AppColors.success
                          : AppColors.primaryRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasDiagnosis) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 14,
                          color: AppColors.greyText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Diagnosis',
                          style: AppTypography.roboto(
                            fontSize: 11,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      disease,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_expanded) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Column(
                children: [
                  _VisitField(
                    label: 'Visit ID',
                    value: visit.patientVisitId > 0
                        ? '${visit.patientVisitId}'
                        : 'Not recorded',
                  ),
                  _VisitField(
                    label: 'Check-in',
                    value: widget.formatDateTime(visit.checkIn),
                  ),
                  _VisitField(
                    label: 'Discharge Date',
                    value: visit.dischargeDate != null
                        ? widget.formatDateTime(visit.dischargeDate!)
                        : 'Not recorded',
                  ),
                  _VisitField(
                    label: 'Discharge ID',
                    value: visit.dischargeId != null
                        ? '${visit.dischargeId}'
                        : 'Not recorded',
                  ),
                  _VisitField(
                    label: 'Doctor Name',
                    value: displayValue(visit.doctorName),
                  ),
                  _VisitField(
                    label: 'Department',
                    value: displayValue(visit.department),
                  ),
                  _VisitField(
                    label: 'Admission Officer',
                    value: displayValue(visit.admissionOfficer),
                  ),
                  _VisitField(
                    label: 'Admission No',
                    value: displayValue(visit.admissionNo),
                  ),
                  _VisitField(
                    label: 'Disease',
                    value: displayValue(visit.disease),
                  ),
                  _VisitField(
                    label: 'Presenting Complaints',
                    value: displayValue(visit.presentingComplaints),
                  ),
                ],
              ),
            ),
          ],
          TapFeedback(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _expanded ? 'Hide Details' : 'View Details',
                    style: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primaryRed,
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

class _VisitField extends StatelessWidget {
  final String label;
  final String value;

  const _VisitField({required this.label, required this.value});

  static String displayValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Not recorded';
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final isMissing = value == 'Not recorded';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.roboto(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isMissing ? AppColors.greyText : AppColors.darkText,
                fontStyle: isMissing ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitFilterSheet extends StatefulWidget {
  final VisitHistoryFilters filters;
  final List<int> years;
  final List<String> departments;
  final ValueChanged<VisitHistoryFilters> onApply;
  final VoidCallback onClear;

  const _VisitFilterSheet({
    required this.filters,
    required this.years,
    required this.departments,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_VisitFilterSheet> createState() => _VisitFilterSheetState();
}

class _VisitFilterSheetState extends State<_VisitFilterSheet> {
  late int? _year;
  late String? _department;
  late String _visitType;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _visitTypes = ['All', 'Completed', 'Active'];

  @override
  void initState() {
    super.initState();
    _year = widget.filters.year;
    _department = widget.filters.department;
    _visitType = widget.filters.visitType ?? 'All';
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

  VisitHistoryFilters _buildFilters() {
    return VisitHistoryFilters(
      year: _year,
      department: _department,
      visitType: _visitType == 'All' ? null : _visitType,
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
                  'Filter Visits',
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
                const _FilterSectionTitle('Department'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _department == null,
                      onTap: () => setState(() => _department = null),
                    ),
                    ...widget.departments.map(
                      (d) => _FilterChip(
                        label: d,
                        selected: _department == d,
                        onTap: () => setState(() => _department = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _FilterSectionTitle('Visit Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _visitTypes.map((type) {
                    return _FilterChip(
                      label: type,
                      selected: _visitType == type,
                      onTap: () => setState(() => _visitType = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const _FilterSectionTitle('Date Range'),
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
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
    final isPlaceholder = value == 'Select date';

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isPlaceholder
                          ? AppColors.greyText
                          : AppColors.darkText,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.primaryRed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

