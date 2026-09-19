import 'package:btih_andriod_app/models/doctors_model.dart';
import 'package:btih_andriod_app/models/specialization_model.dart';
import 'package:btih_andriod_app/services/doctors_service.dart';
import 'package:btih_andriod_app/services/recent_activity_service.dart';
import 'package:btih_andriod_app/services/specialization_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/doctor_image_helper.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'doctor_schedule_screen.dart';

class DoctorsListScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final bool isLoggedIn;

  const DoctorsListScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.isLoggedIn = false,
  });

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  final DoctorService _doctorService = DoctorService();
  final SpecializationService _specializationService = SpecializationService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Doctor> allDoctors = [];
  List<Doctor> filteredDoctors = [];
  List<Specialization> specializations = [];

  bool isLoading = true;
  bool isPageLoading = false;
  String searchQuery = '';
  String? selectedSpecialization;

  int currentPage = 1;
  int totalRecords = 0;
  int totalPages = 1;

  static const int _pageSize = 10;
  bool get _hasActiveFilter =>
      searchQuery.isNotEmpty || selectedSpecialization != null;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    setState(() => isLoading = true);

    List<Specialization> loadedSpecializations = [];
    DoctorResponse? doctorResponse;
    Object? doctorsError;

    try {
      loadedSpecializations = await _specializationService.getSpecializations();
    } catch (_) {}

    try {
      doctorResponse = await _doctorService.getDoctorsPaginated(
        pageNumber: 1,
        pageSize: _pageSize,
      );
    } catch (e) {
      doctorsError = e;
    }

    if (!mounted) return;

    if (doctorResponse != null) {
      setState(() {
        specializations = loadedSpecializations;
        _applyDoctorResponse(doctorResponse!, reset: true);
        isLoading = false;
      });
      _precacheDoctorImages(doctorResponse.data);
    } else {
      setState(() => isLoading = false);
      var message = doctorsError.toString().replaceFirst('Exception: ', '');
      if (message.isEmpty) {
        message = 'Failed to load doctors. Please try again.';
      }
      _showErrorSnackBar(message);
    }
  }

  Future<void> _fetchPage(int page, {bool showFullLoader = false}) async {
    if (isPageLoading) return;

    setState(() {
      isPageLoading = true;
      if (showFullLoader) isLoading = true;
    });

    try {
      final doctorResponse = await _doctorService.getDoctorsPaginated(
        pageNumber: page,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _applyDoctorResponse(doctorResponse, reset: true);
        isPageLoading = false;
        isLoading = false;
      });
      _precacheDoctorImages(doctorResponse.data);
      _scrollController.jumpTo(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isPageLoading = false;
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load doctors.');
    }
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > totalPages || page == currentPage) return;
    await _fetchPage(page);
  }

  Future<void> refreshDoctors() async {
    await _fetchPage(1, showFullLoader: true);
  }

  void _precacheDoctorImages(Iterable<Doctor> doctors) {
    DoctorImageHelper.precacheAvatars(
      context,
      doctors.map((doctor) => doctor.doctorImagePath),
      maxUrls: _pageSize,
    );
  }

  void _applyDoctorResponse(DoctorResponse response, {required bool reset}) {
    if (reset) {
      allDoctors = response.data;
    } else {
      allDoctors.addAll(response.data);
    }
    currentPage = response.pagination.pageNumber;
    totalPages = response.pagination.totalPages;
    totalRecords = response.pagination.totalRecords;
    _applySearchFilter();
  }

  void _applySearchFilter() {
    var results = List<Doctor>.from(allDoctors);

    if (selectedSpecialization != null && selectedSpecialization!.isNotEmpty) {
      results = results
          .where((doctor) => doctor.specializationName == selectedSpecialization)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      results = results.where((doctor) {
        return doctor.doctorName.toLowerCase().contains(query) ||
            doctor.specializationName.toLowerCase().contains(query) ||
            doctor.doctorDescription.toLowerCase().contains(query);
      }).toList();
    }

    final hasActiveFilter =
        searchQuery.isNotEmpty || selectedSpecialization != null;
    if (hasActiveFilter) {
      results.sort((a, b) => a.doctorName.compareTo(b.doctorName));
    } else {
      results.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
    }

    filteredDoctors = results;
  }

  Future<void> _maybeLoadMoreForFilter() async {
    if (!_hasActiveFilter || isPageLoading) return;
    if (currentPage >= totalPages) return;
    if (filteredDoctors.length >= 8) return;

    setState(() => isPageLoading = true);

    try {
      final doctorResponse = await _doctorService.getDoctorsPaginated(
        pageNumber: currentPage + 1,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _applyDoctorResponse(doctorResponse, reset: false);
        isPageLoading = false;
      });
      _precacheDoctorImages(doctorResponse.data);
      _maybeLoadMoreForFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => isPageLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim();
    final wasFiltering = _hasActiveFilter;

    setState(() {
      searchQuery = trimmed;
      _applySearchFilter();
    });

    if (wasFiltering && !_hasActiveFilter) {
      _fetchPage(1);
    } else if (!wasFiltering && _hasActiveFilter) {
      _loadAllForFilter();
    } else {
      _maybeLoadMoreForFilter();
    }
  }

  void _selectSpecialization(String? specialization) {
    final wasFiltering = _hasActiveFilter;

    setState(() {
      selectedSpecialization = specialization;
      _applySearchFilter();
    });

    if (wasFiltering && !_hasActiveFilter) {
      _fetchPage(1);
    } else if (!wasFiltering && _hasActiveFilter) {
      _loadAllForFilter();
    } else {
      _maybeLoadMoreForFilter();
    }
  }

  Future<void> _loadAllForFilter() async {
    while (mounted && _hasActiveFilter && currentPage < totalPages) {
      if (isPageLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      await _maybeLoadMoreForFilter();
    }
  }

  List<Specialization> get _sortedSpecializations {
    final items = List<Specialization>.from(specializations)
      ..sort(
        (a, b) => a.specializationName.compareTo(b.specializationName),
      );
    return items;
  }

  Future<void> _openAllSpecialtiesSheet() async {
    if (specializations.isEmpty) {
      _showErrorSnackBar('Specialties are not available right now.');
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _AllSpecialtiesSheet(
          specializations: _sortedSpecializations,
          selectedSpecialization: selectedSpecialization,
        );
      },
    );

    if (!mounted || selected == null) return;
    // Empty string means user cleared the current specialty.
    _selectSpecialization(selected.isEmpty ? null : selected);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _openDoctorSchedule(Doctor doctor) {
    final scopeId = RecentActivityService.instance.resolveScope(
      patientMrNo: widget.patientMrNo,
    );
    RecentActivityService.instance.trackDoctor(
      scopeId: scopeId,
      doctorId: doctor.id,
      doctorName: doctor.doctorName,
      departmentId: doctor.departmentId,
      specializationName: doctor.specializationName,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorScheduleScreen(
          doctor: doctor,
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          isLoggedIn: widget.isLoggedIn,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Find a Doctor',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.medical_services_outlined),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchAndFiltersSection(),
                Expanded(child: _buildDoctorList()),
              ],
            ),
    );
  }

  Widget _buildSearchAndFiltersSection() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search doctor name, specialization...',
          hintStyle: AppTypography.roboto(
            color: AppColors.greyText,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryRed),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded, color: AppColors.greyText),
                )
              : null,
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
          ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          if (specializations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSpecializationTab(),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecializationTab() {
    final label = selectedSpecialization?.trim().isNotEmpty == true
        ? selectedSpecialization!.trim()
        : 'Specialization';

    return TapFeedback(
      onTap: _openAllSpecialtiesSheet,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.blush,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.tune_rounded,
              size: 20,
              color: AppColors.primaryRed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.raleway(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: AppColors.primaryRed,
            ),
          ],
        ),
      ),
    );
  }

  double _paginationReserveHeight(BuildContext context) {
    if (_hasActiveFilter || totalPages <= 1) return 16;
    return 88 + MediaQuery.paddingOf(context).bottom;
  }

  Widget _buildPaginationBar() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Material(
        color: AppColors.white,
        elevation: 10,
        shadowColor: AppColors.shadow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.fieldBorder.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            children: [
              _PaginationTextButton(
                label: 'Previous',
                icon: Icons.chevron_left_rounded,
                iconFirst: true,
                enabled: currentPage > 1 && !isPageLoading,
                onTap: () => _goToPage(currentPage - 1),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _visiblePageNumbers().map((page) {
                    final isActive = page == currentPage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: TapFeedback(
                        onTap: isPageLoading || isActive
                            ? null
                            : () => _goToPage(page),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primaryRed
                                : AppColors.softRed,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$page',
                            style: AppTypography.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.white
                                  : AppColors.primaryRed,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              _PaginationTextButton(
                label: 'Next',
                icon: Icons.chevron_right_rounded,
                enabled: currentPage < totalPages && !isPageLoading,
                onTap: () => _goToPage(currentPage + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<int> _visiblePageNumbers() {
    if (totalPages <= 5) {
      return List.generate(totalPages, (index) => index + 1);
    }

    var start = currentPage - 2;
    if (start < 1) start = 1;
    if (start + 4 > totalPages) start = totalPages - 4;

    return List.generate(5, (index) => start + index);
  }

  Widget _buildDoctorList() {
    if (filteredDoctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: AppColors.softRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  size: 48,
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No doctors found',
                style: AppTypography.raleway(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _hasActiveFilter
                    ? 'Try another search or specialty.'
                    : 'No doctors on this page.',
                textAlign: TextAlign.center,
                style: AppTypography.roboto(
                  fontSize: 13,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final showPagination = !_hasActiveFilter && totalPages > 1;
    final bottomReserve = _paginationReserveHeight(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        RefreshIndicator(
          color: AppColors.primaryRed,
          onRefresh: refreshDoctors,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16, 4, 16, bottomReserve),
            itemCount: filteredDoctors.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.hairline,
            ),
            itemBuilder: (context, index) {
              final doctor = filteredDoctors[index];
              return _DoctorListRow(
                doctor: doctor,
                index: index,
                onTap: () => _openDoctorSchedule(doctor),
              );
            },
          ),
        ),
        if (isPageLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primaryRed,
              backgroundColor: AppColors.softRed,
            ),
          ),
        if (showPagination)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildPaginationBar(),
          ),
      ],
    );
  }
}

class _PaginationTextButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconFirst;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationTextButton({
    required this.label,
    required this.icon,
    this.iconFirst = false,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primaryRed : AppColors.greyText;

    return TapFeedback(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconFirst
              ? [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 2),
                  Text(
                    label,
                    style: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ]
              : [
                  Text(
                    label,
                    style: AppTypography.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(icon, size: 18, color: color),
                ],
        ),
      ),
    );
  }
}

class _DoctorListRow extends StatelessWidget {
  final Doctor doctor;
  final int index;
  final VoidCallback onTap;

  const _DoctorListRow({
    required this.doctor,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qualification = doctor.doctorDescription.trim();
    final specialty = doctor.specializationName.trim();
    final accent =
        AppColors.activityPalette[index % AppColors.activityPalette.length];

    return TapFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DoctorAvatar(
              imageUrl: doctor.doctorImagePath,
              accent: accent,
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.doctorName,
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (qualification.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      qualification,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (specialty.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softRed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        specialty,
                        style: AppTypography.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryRed,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.softRed,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.primaryRed.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  final String? imageUrl;
  final ({Color icon, Color background}) accent;
  final double size;

  const _DoctorAvatar({
    required this.imageUrl,
    required this.accent,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = DoctorImageHelper.resolve(imageUrl);
    final hasImage = resolvedUrl != null && resolvedUrl.isNotEmpty;
    final iconSize = size * 0.5;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.18), // fixed theme color, no longer tied to accent
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
        imageUrl: resolvedUrl,
        fit: BoxFit.cover,
        memCacheWidth: DoctorImageHelper.avatarCachePx,
        memCacheHeight: DoctorImageHelper.avatarCachePx,
        maxWidthDiskCache: DoctorImageHelper.avatarCachePx,
        maxHeightDiskCache: DoctorImageHelper.avatarCachePx,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accent.icon,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.person_rounded,
          size: iconSize,
          color: accent.icon,
        ),
      )
          : Icon(
        Icons.person_rounded,
        size: iconSize,
        color: accent.icon,
      ),
    );
  }
}

class _AllSpecialtiesSheet extends StatefulWidget {
  final List<Specialization> specializations;
  final String? selectedSpecialization;

  const _AllSpecialtiesSheet({
    required this.specializations,
    required this.selectedSpecialization,
  });

  @override
  State<_AllSpecialtiesSheet> createState() => _AllSpecialtiesSheetState();
}

class _AllSpecialtiesSheetState extends State<_AllSpecialtiesSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _closeWithResult(String? value) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Let the keyboard dismiss before the sheet route is torn down.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;
    final query = _query.trim().toLowerCase();
    final items = widget.specializations.where((item) {
      if (query.isEmpty) return true;
      return item.specializationName.toLowerCase().contains(query);
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _closeWithResult(null);
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.fieldBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All Specialties',
                    style: AppTypography.raleway(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search specialty...',
                      hintStyle: AppTypography.roboto(
                        color: AppColors.greyText,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.greyText.withValues(alpha: 0.95),
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFBDB4B2),
                          width: 1.4,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFBDB4B2),
                          width: 1.4,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primaryRed,
                          width: 1.6,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'No specialties match your search.',
                              textAlign: TextAlign.center,
                              style: AppTypography.roboto(
                                fontSize: 14,
                                color: AppColors.greyText,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.hairline,
                            ),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final selected =
                                  widget.selectedSpecialization ==
                                      item.specializationName;

                              return TapFeedback(
                                onTap: () {
                                  _closeWithResult(
                                    selected
                                        ? ''
                                        : item.specializationName,
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.specializationName,
                                          style: AppTypography.roboto(
                                            fontSize: 15,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: selected
                                                ? AppColors.primaryRed
                                                : AppColors.darkText,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: AppColors.primaryRed,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
