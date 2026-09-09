import 'package:btih_andriod_app/models/doctors_model.dart';
import 'package:btih_andriod_app/models/specialization_model.dart';
import 'package:btih_andriod_app/services/doctors_service.dart';
import 'package:btih_andriod_app/services/specialization_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'doctor_schedule_screen.dart';

enum DoctorSortOrder { nameAsc, nameDesc, specialtyAsc }

enum DoctorAvailabilityFilter { all }

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

  List<Specialization> specializations = [];
  List<Doctor> allDoctors = [];
  List<Doctor> filteredDoctors = [];

  String? selectedSpecialization;
  DoctorSortOrder _sortOrder = DoctorSortOrder.nameAsc;
  DoctorAvailabilityFilter _availabilityFilter =
      DoctorAvailabilityFilter.all;

  bool isLoading = true;
  bool isLoadingMore = false;
  String searchQuery = '';

  int currentPage = 1;
  int totalRecords = 0;
  int totalPages = 1;
  bool hasMorePages = true;

  static const int _pageSize = 10;
  static const int _popularSpecialtyCount = 6;

  @override
  void initState() {
    super.initState();
    loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      loadMoreDoctors();
    }
  }

  List<Specialization> get _popularSpecialties {
    if (specializations.length <= _popularSpecialtyCount) {
      return specializations;
    }
    return specializations.take(_popularSpecialtyCount).toList();
  }

  Future<void> loadInitialData() async {
    setState(() => isLoading = true);

    List<Specialization> loadedSpecializations = [];
    DoctorResponse? doctorResponse;
    Object? doctorsError;
    Object? specializationError;

    try {
      loadedSpecializations = await _specializationService.getSpecializations();
    } catch (e) {
      specializationError = e;
    }

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
      if (specializationError != null && specializations.isEmpty) {
        _showErrorSnackBar(
          'Specialty filters unavailable right now. Showing all doctors.',
        );
      }
      return;
    }

    setState(() => isLoading = false);
    _showErrorSnackBar(
      doctorsError?.toString().replaceFirst('Exception: ', '') ??
          'Failed to load doctors. Please try again.',
    );
  }

  Future<void> loadMoreDoctors() async {
    if (isLoadingMore || !hasMorePages) return;

    setState(() => isLoadingMore = true);

    try {
      final doctorResponse = await _doctorService.getDoctorsPaginated(
        pageNumber: currentPage + 1,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        allDoctors.addAll(doctorResponse.data);
        currentPage = doctorResponse.pagination.pageNumber;
        totalPages = doctorResponse.pagination.totalPages;
        totalRecords = doctorResponse.pagination.totalRecords;
        hasMorePages = currentPage < totalPages;
        isLoadingMore = false;
        _applyFiltersAndSort();
      });
      _maybeLoadMoreForActiveFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingMore = false);
      _showErrorSnackBar('Failed to load more doctors.');
    }
  }

  Future<void> refreshDoctors() async {
    setState(() {
      currentPage = 1;
      hasMorePages = true;
      isLoading = true;
    });

    try {
      final doctorResponse = await _doctorService.getDoctorsPaginated(
        pageNumber: 1,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _applyDoctorResponse(doctorResponse, reset: true);
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to refresh doctors.');
    }
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
    hasMorePages = currentPage < totalPages;
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    var results = allDoctors.where((doctor) {
      if (selectedSpecialization != null &&
          selectedSpecialization!.isNotEmpty &&
          doctor.specializationName != selectedSpecialization) {
        return false;
      }

      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return doctor.doctorName.toLowerCase().contains(query) ||
            doctor.specializationName.toLowerCase().contains(query) ||
            doctor.doctorDescription.toLowerCase().contains(query);
      }

      return true;
    }).toList();

    switch (_sortOrder) {
      case DoctorSortOrder.nameAsc:
        results.sort((a, b) => a.doctorName.compareTo(b.doctorName));
      case DoctorSortOrder.nameDesc:
        results.sort((a, b) => b.doctorName.compareTo(a.doctorName));
      case DoctorSortOrder.specialtyAsc:
        results.sort(
          (a, b) => a.specializationName.compareTo(b.specializationName),
        );
    }

    filteredDoctors = results;
  }

  void _maybeLoadMoreForActiveFilter() {
    if (!hasMorePages || isLoadingMore) return;
    final hasActiveFilter =
        selectedSpecialization != null || searchQuery.isNotEmpty;
    if (hasActiveFilter && filteredDoctors.length < 8) {
      loadMoreDoctors();
    }
  }

  void _selectSpecialization(String? specializationName) {
    setState(() {
      selectedSpecialization = specializationName;
      _applyFiltersAndSort();
    });
    _maybeLoadMoreForActiveFilter();
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query.trim();
      _applyFiltersAndSort();
    });
    _maybeLoadMoreForActiveFilter();
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _openDoctorSchedule(Doctor doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorScheduleScreen(
          doctorId: doctor.id,
          doctorName: doctor.doctorName,
          patientMrNo: widget.patientMrNo,
          patientName: widget.patientName,
          departmentId: doctor.departmentId,
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

  Future<void> _openAllSpecialtiesSheet() async {
    final queryController = TextEditingController();
    var sheetQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final items = specializations.where((item) {
              if (sheetQuery.isEmpty) return true;
              return item.specializationName
                  .toLowerCase()
                  .contains(sheetQuery.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.fieldBorder,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'All Specialties',
                              style: AppTypography.raleway(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.greyText,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: queryController,
                        onChanged: (value) {
                          setSheetState(() => sheetQuery = value.trim());
                        },
                        decoration: InputDecoration(
                          hintText: 'Search specialties...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primaryRed,
                          ),
                          filled: true,
                          fillColor: AppColors.fieldFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: items.length + 1,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.fieldBorder),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final selected = selectedSpecialization == null;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.grid_view_rounded,
                                color: selected
                                    ? AppColors.primaryRed
                                    : AppColors.greyText,
                              ),
                              title: Text(
                                'All Specialties',
                                style: AppTypography.roboto(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppColors.primaryRed
                                      : AppColors.darkText,
                                ),
                              ),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: AppColors.primaryRed,
                                    )
                                  : null,
                              onTap: () {
                                _selectSpecialization(null);
                                Navigator.pop(context);
                              },
                            );
                          }

                          final item = items[index - 1];
                          final selected =
                              selectedSpecialization == item.specializationName;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.medical_services_outlined,
                              color: selected
                                  ? AppColors.primaryRed
                                  : AppColors.greyText,
                              size: 22,
                            ),
                            title: Text(
                              item.specializationName,
                              style: AppTypography.roboto(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.primaryRed
                                    : AppColors.darkText,
                              ),
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.primaryRed,
                                  )
                                : null,
                            onTap: () {
                              _selectSpecialization(item.specializationName);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    queryController.dispose();
  }

  Future<void> _openFilterSheet() async {
    String? tempSpecialty = selectedSpecialization;
    var tempSort = _sortOrder;
    var tempAvailability = _availabilityFilter;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filter & Sort',
                      style: AppTypography.raleway(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Specialty',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: tempSpecialty,
                      decoration: _sheetFieldDecoration(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Specialties'),
                        ),
                        ...specializations.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.specializationName,
                            child: Text(
                              item.specializationName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() => tempSpecialty = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Availability',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Slot details appear on the doctor profile.',
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DoctorAvailabilityFilter>(
                      value: tempAvailability,
                      decoration: _sheetFieldDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: DoctorAvailabilityFilter.all,
                          child: Text('All Doctors'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => tempAvailability = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sort',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DoctorSortOrder>(
                      value: tempSort,
                      decoration: _sheetFieldDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: DoctorSortOrder.nameAsc,
                          child: Text('Name (A–Z)'),
                        ),
                        DropdownMenuItem(
                          value: DoctorSortOrder.nameDesc,
                          child: Text('Name (Z–A)'),
                        ),
                        DropdownMenuItem(
                          value: DoctorSortOrder.specialtyAsc,
                          child: Text('Specialty (A–Z)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => tempSort = value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempSpecialty = null;
                                tempSort = DoctorSortOrder.nameAsc;
                                tempAvailability = DoctorAvailabilityFilter.all;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: const BorderSide(color: AppColors.fieldBorder),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                selectedSpecialization = tempSpecialty;
                                _sortOrder = tempSort;
                                _availabilityFilter = tempAvailability;
                                _applyFiltersAndSort();
                              });
                              Navigator.pop(context);
                              _maybeLoadMoreForActiveFilter();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _sheetFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  bool get _hasActiveFilters =>
      selectedSpecialization != null ||
      _sortOrder != DoctorSortOrder.nameAsc ||
      searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
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
                _buildSearchSection(),
                _buildPopularSpecialties(),
                _buildFilterRow(),
                _buildResultsHeader(),
                Expanded(child: _buildDoctorList()),
              ],
            ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search doctor name or specialization...',
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
          fillColor: AppColors.fieldFill,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPopularSpecialties() {
    if (specializations.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Popular Specialties',
                    style: AppTypography.raleway(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
                TapFeedback(
                  onTap: _openAllSpecialtiesSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'View All',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _popularSpecialties.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _popularSpecialties[index];
                final selected =
                    selectedSpecialization == item.specializationName;
                return TapFeedback(
                  onTap: () => _selectSpecialization(
                    selected ? null : item.specializationName,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryRed : AppColors.softRed,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryRed
                            : AppColors.fieldBorder,
                      ),
                    ),
                    child: Text(
                      item.specializationName,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.white : AppColors.primaryRed,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _FilterChipButton(
            label: selectedSpecialization ?? 'Specialty',
            icon: Icons.medical_information_outlined,
            active: selectedSpecialization != null,
            onTap: _openAllSpecialtiesSheet,
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Filter',
            icon: Icons.tune_rounded,
            active: _hasActiveFilters,
            onTap: _openFilterSheet,
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: _sortLabel(_sortOrder),
            icon: Icons.sort_rounded,
            active: _sortOrder != DoctorSortOrder.nameAsc,
            onTap: _openFilterSheet,
          ),
        ],
      ),
    );
  }

  String _sortLabel(DoctorSortOrder order) {
    switch (order) {
      case DoctorSortOrder.nameAsc:
        return 'Sort';
      case DoctorSortOrder.nameDesc:
        return 'Z–A';
      case DoctorSortOrder.specialtyAsc:
        return 'Specialty';
    }
  }

  Widget _buildResultsHeader() {
    final loadedLabel = totalRecords > 0
        ? '${filteredDoctors.length} shown · $totalRecords total'
        : '${filteredDoctors.length} doctors';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loadedLabel,
              style: AppTypography.roboto(
                fontSize: 12,
                color: AppColors.greyText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (hasMorePages && !isLoadingMore)
            Text(
              'Page $currentPage of $totalPages',
              style: AppTypography.roboto(
                fontSize: 11,
                color: AppColors.greyText,
              ),
            ),
        ],
      ),
    );
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
                hasMorePages
                    ? 'Try another specialty or scroll to load more doctors.'
                    : 'Try adjusting your search or filters.',
                textAlign: TextAlign.center,
                style: AppTypography.roboto(
                  fontSize: 13,
                  color: AppColors.greyText,
                ),
              ),
              if (hasMorePages) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: loadMoreDoctors,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    side: const BorderSide(color: AppColors.primaryRed),
                  ),
                  child: const Text('Load more doctors'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: refreshDoctors,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: filteredDoctors.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredDoctors.length && isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryRed,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return _DoctorCard(
            doctor: filteredDoctors[index],
            onBookAppointment: () => _openDoctorSchedule(filteredDoctors[index]),
          );
        },
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TapFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.softRed : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.primaryRed : AppColors.fieldBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.primaryRed : AppColors.greyText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.primaryRed : AppColors.darkText,
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

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onBookAppointment;

  const _DoctorCard({
    required this.doctor,
    required this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final qualification = doctor.doctorDescription.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DoctorAvatar(imageUrl: doctor.doctorImagePath),
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
                      ),
                    ),
                    if (qualification.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        qualification,
                        style: AppTypography.roboto(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        doctor.specializationName,
                        style: AppTypography.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBookAppointment,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Book Appointment',
                style: AppTypography.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  final String? imageUrl;

  const _DoctorAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.softRed,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: AppColors.primaryRed,
                size: 28,
              ),
            )
          : const Icon(
              Icons.person_rounded,
              color: AppColors.primaryRed,
              size: 28,
            ),
    );
  }
}
