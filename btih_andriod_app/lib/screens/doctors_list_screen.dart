// import 'package:btih_andriod_app/models/doctors_model.dart';
// import 'package:btih_andriod_app/models/specialization_model.dart';
// import 'package:btih_andriod_app/services/doctors_service.dart';
// import 'package:btih_andriod_app/services/specialization_service.dart';
// import 'package:flutter/material.dart';
// import 'doctor_schedule_screen.dart';

// class DoctorsListScreen extends StatefulWidget {
//   final String patientMrNo;
//   final String patientName;
//   final bool isLoggedIn;

//   const DoctorsListScreen({
//     super.key,
//     required this.patientMrNo,
//     required this.patientName,
//     this.isLoggedIn = false,
//   });

//   @override
//   State<DoctorsListScreen> createState() => _DoctorsListScreenState();
// }

// class _DoctorsListScreenState extends State<DoctorsListScreen> {
//   final DoctorService _doctorService = DoctorService();
//   final SpecializationService _specializationService = SpecializationService();
  
//   List<Specialization> specializations = [];
//   List<Doctor> allDoctors = [];
//   List<Doctor> filteredDoctors = [];
  
//   String? selectedSpecialization;
//   bool isLoading = true;
//   String searchQuery = '';

//   @override
//   void initState() {
//     super.initState();
//     loadData();
//   }

//   Future<void> loadData() async {
//     try {
//       // Load both specializations and doctors in parallel
//       final results = await Future.wait([
//         _specializationService.getSpecializations(),
//         _doctorService.getDoctors(),
//       ]);
      
//       setState(() {
//         specializations = results[0] as List<Specialization>;
//         allDoctors = results[1] as List<Doctor>;
//         filteredDoctors = allDoctors; // Initially show all doctors
//         isLoading = false;
//       });
//     } catch (e) {
//       print("Data Load Error: $e");
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   void filterDoctors() {
//     setState(() {
//       filteredDoctors = allDoctors.where((doctor) {
//         // Filter by specialization
//         if (selectedSpecialization != null && 
//             selectedSpecialization!.isNotEmpty &&
//             doctor.specializationName != selectedSpecialization) {
//           return false;
//         }
        
//         // Filter by search query
//         if (searchQuery.isNotEmpty) {
//           return doctor.doctorName.toLowerCase().contains(searchQuery.toLowerCase()) ||
//                  doctor.specializationName.toLowerCase().contains(searchQuery.toLowerCase());
//         }
        
//         return true;
//       }).toList();
//     });
//   }

//   void filterDoctorsBySpecialization(String? specializationName) {
//     selectedSpecialization = specializationName;
//     filterDoctors();
//   }

//   void searchDoctors(String query) {
//     searchQuery = query;
//     filterDoctors();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FA),
//       appBar: AppBar(
//         backgroundColor: const AppColors.primaryRed,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Find a Doctor',
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
//         ),
//         centerTitle: true,
//       ),
//       body: isLoading
//           ? const Center(
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
//               ),
//             )
//           : Column(
//               children: [
//                 // Search Bar
//                 Container(
//                   padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.grey.shade100,
//                         blurRadius: 8,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     children: [
//                       TextField(
//                         onChanged: searchDoctors,
//                         decoration: InputDecoration(
//                           hintText: 'Search by doctor name or specialization...',
//                           hintStyle: TextStyle(color: Colors.grey.shade400),
//                           prefixIcon: const Icon(Icons.search, color: AppColors.primaryRed),
//                           suffixIcon: searchQuery.isNotEmpty
//                               ? IconButton(
//                                   icon: const Icon(Icons.clear, color: Colors.grey),
//                                   onPressed: () {
//                                     searchDoctors('');
//                                     setState(() {
//                                       searchQuery = '';
//                                     });
//                                   },
//                                 )
//                               : null,
//                           filled: true,
//                           fillColor: const Color(0xFFF8F9FA),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(30),
//                             borderSide: BorderSide.none,
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(30),
//                             borderSide: BorderSide.none,
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(30),
//                             borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 20,
//                             vertical: 14,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       // Specialization Dropdown
//                       DropdownButtonFormField<String>(
//                         value: selectedSpecialization,
//                         decoration: InputDecoration(
//                           labelText: 'Select Specialization',
//                           labelStyle: TextStyle(color: Colors.grey.shade600),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(color: Colors.grey.shade300),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(color: Colors.grey.shade300),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: const BorderSide(color: AppColors.primaryRed),
//                           ),
//                           filled: true,
//                           fillColor: Colors.grey.shade50,
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 12,
//                           ),
//                         ),
//                         hint: const Text('All Specializations'),
//                         items: [
//                           const DropdownMenuItem<String>(
//                             value: null,
//                             child: Text('All Specializations'),
//                           ),
//                           ...specializations.map((specialization) {
//                             return DropdownMenuItem<String>(
//                               value: specialization.specializationName,
//                               child: Text(specialization.specializationName),
//                             );
//                           }),
//                         ],
//                         onChanged: filterDoctorsBySpecialization,
//                         icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryRed),
//                         dropdownColor: Colors.white,
//                         isExpanded: true,
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 // Results count
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         '${filteredDoctors.length} doctors available',
//                         style: TextStyle(
//                           color: Colors.grey.shade600,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: const AppColors.primaryRed.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             const Icon(
//                               Icons.list,
//                               size: 14,
//                               color: AppColors.primaryRed,
//                             ),
//                             const SizedBox(width: 4),
//                             const Text(
//                               'List View',
//                               style: TextStyle(
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.w600,
//                                 color: AppColors.primaryRed,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 // Doctors List
//                 Expanded(
//                   child: filteredDoctors.isEmpty
//                       ? Center(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Container(
//                                 padding: const EdgeInsets.all(24),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey.shade100,
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Icon(
//                                   Icons.medical_services,
//                                   size: 64,
//                                   color: Colors.grey.shade400,
//                                 ),
//                               ),
//                               const SizedBox(height: 20),
//                               Text(
//                                 'No doctors found',
//                                 style: TextStyle(
//                                   color: Colors.grey.shade700,
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 'Try adjusting your search or filters',
//                                 style: TextStyle(
//                                   color: Colors.grey.shade500,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         )
//                       : ListView.builder(
//                           padding: const EdgeInsets.all(16),
//                           itemCount: filteredDoctors.length,
//                           itemBuilder: (context, index) {
//                             final doctor = filteredDoctors[index];
//                             return _buildDoctorListItem(doctor);
//                           },
//                         ),
//                 ),
//               ],
//             ),
//     );
//   }

//   Widget _buildDoctorListItem(Doctor doctor) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => DoctorScheduleScreen(
//               doctorId: doctor.id,
//               doctorName: doctor.doctorName,
//               patientMrNo: widget.patientMrNo,
//               patientName: widget.patientName,
//               departmentId: doctor.departmentId,
//               isLoggedIn: widget.isLoggedIn,
//             ),
//           ),
//         );
//       },
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.shade200,
//               blurRadius: 10,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Doctor Image
//             Container(
//               width: 85,
//               height: 105,
//               decoration: BoxDecoration(
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(20),
//                   bottomLeft: Radius.circular(20),
//                 ),
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [
//                     const AppColors.primaryRed.withOpacity(0.1),
//                     const AppColors.primaryRed.withOpacity(0.05),
//                   ],
//                 ),
//               ),
//               child: ClipRRect(
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(20),
//                   bottomLeft: Radius.circular(20),
//                 ),
//                 child: doctor.doctorImagePath != null && doctor.doctorImagePath!.isNotEmpty
//                     ? Image.network(
//                         doctor.doctorImagePath!,
//                         fit: BoxFit.cover,
//                         errorBuilder: (context, error, stackTrace) {
//                           return Container(
//                             color: const AppColors.primaryRed.withOpacity(0.1),
//                             child: const Icon(
//                               Icons.person,
//                               size: 50,
//                               color: AppColors.primaryRed,
//                             ),
//                           );
//                         },
//                       )
//                     : Container(
//                         color: const AppColors.primaryRed.withOpacity(0.1),
//                         child: const Icon(
//                           Icons.person,
//                           size: 50,
//                           color: AppColors.primaryRed,
//                         ),
//                       ),
//               ),
//             ),
            
//             // Doctor Info
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                    // Row(
//                      // children: [
//                         //Expanded(
//                            Text(
//                             doctor.doctorName,
//                             style: const TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                               color: Color(0xFF1A1A1A),
//                             ),
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                           ),

//                     const SizedBox(height: 8),

//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: const AppColors.primaryRed.withOpacity(0.08),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Row(
//                        crossAxisAlignment: CrossAxisAlignment.start, // Changed to start

//                         children: [
//                           const Icon(
//                             Icons.medical_services,
//                             size: 14,
//                             color: AppColors.primaryRed,
//                           ),
//                           const SizedBox(width: 4),
//                           Expanded( // Added Expanded to allow text wrapping
//                           child: Text(
//                             doctor.specializationName,
//                             style: const TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w700,
//                               color: AppColors.primaryRed,
//                             ),
//                             maxLines: 2, // Allow up to 2 lines
//                         overflow: TextOverflow.ellipsis, // Show ellipsis if more than 2 lines
//                         softWrap: true, // Allow text wrapping
//                           ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         // Icon(
//                         //   Icons.schedule,
//                         //   size: 14,
//                         //   color: Colors.grey.shade500,
//                         // ),
//                         const SizedBox(width: 4),
//                         // Text(
//                         //   'Available Today',
//                         //   style: TextStyle(
//                         //     fontSize: 12,
//                         //     color: Colors.grey.shade600,
//                         //   ),
//                         // ),
//                         const Spacer(),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                           decoration: BoxDecoration(
//                             color: const AppColors.primaryRed,
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: const Text(
//                             'Schedule Appointment',
//                             style: TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w600,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// doctors_list_screen.dart - Complete updated screen with pagination

import 'package:btih_andriod_app/models/doctors_model.dart';
import 'package:btih_andriod_app/models/specialization_model.dart';
import 'package:btih_andriod_app/services/doctors_service.dart';
import 'package:btih_andriod_app/services/specialization_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'doctor_schedule_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  
  List<Specialization> specializations = [];
  List<Doctor> allDoctors = [];  // Now will store paginated data
  List<Doctor> filteredDoctors = [];
  
  String? selectedSpecialization;
  bool isLoading = true;
  bool isLoadingMore = false;
  String searchQuery = '';
  
  // Pagination variables
  int currentPage = 1;
  int totalPages = 1;
  bool hasMorePages = true;
  
  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      loadMoreDoctors();
    }
  }

  Future<void> loadInitialData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      // Load specializations and first page of doctors in parallel
      final results = await Future.wait([
        _specializationService.getSpecializations(),
        _doctorService.getDoctorsPaginated(pageNumber: 1, pageSize: 10),
      ]);
      
      setState(() {
        specializations = results[0] as List<Specialization>;
        final doctorResponse = results[1] as DoctorResponse;
        allDoctors = doctorResponse.data;
        filteredDoctors = allDoctors;
        currentPage = doctorResponse.pagination.pageNumber;
        totalPages = doctorResponse.pagination.totalPages;
        hasMorePages = currentPage < totalPages;
        isLoading = false;
      });
    } catch (e) {
      print("Data Load Error: $e");
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load doctors. Please try again.');
    }
  }

  Future<void> loadMoreDoctors() async {
    if (isLoadingMore || !hasMorePages) return;
    
    setState(() {
      isLoadingMore = true;
    });
    
    try {
      final nextPage = currentPage + 1;
      final doctorResponse = await _doctorService.getDoctorsPaginated(
        pageNumber: nextPage,
        pageSize: 10,
      );
      
      setState(() {
        allDoctors.addAll(doctorResponse.data);
        // Reapply filters to include newly loaded doctors
        filterDoctors();
        currentPage = doctorResponse.pagination.pageNumber;
        hasMorePages = currentPage < doctorResponse.pagination.totalPages;
        isLoadingMore = false;
      });
    } catch (e) {
      print("Load More Error: $e");
      setState(() {
        isLoadingMore = false;
      });
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
        pageSize: 10,
      );
      
      setState(() {
        allDoctors = doctorResponse.data;
        filterDoctors(); // Reapply filters
        currentPage = doctorResponse.pagination.pageNumber;
        totalPages = doctorResponse.pagination.totalPages;
        hasMorePages = currentPage < totalPages;
        isLoading = false;
      });
    } catch (e) {
      print("Refresh Error: $e");
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to refresh doctors.');
    }
  }

  void filterDoctors() {
    setState(() {
      filteredDoctors = allDoctors.where((doctor) {
        // Filter by specialization
        if (selectedSpecialization != null && 
            selectedSpecialization!.isNotEmpty &&
            doctor.specializationName != selectedSpecialization) {
          return false;
        }
        
        // Filter by search query
        if (searchQuery.isNotEmpty) {
          return doctor.doctorName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                 doctor.specializationName.toLowerCase().contains(searchQuery.toLowerCase());
        }
        
        return true;
      }).toList();
    });
  }

  void filterDoctorsBySpecialization(String? specializationName) {
    selectedSpecialization = specializationName;
    filterDoctors();
  }

  void searchDoctors(String query) {
    searchQuery = query;
    filterDoctors();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.deepRed,
        elevation: 0,
        foregroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find a Doctor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: refreshDoctors,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
              ),
            )
          : Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: searchDoctors,
                        decoration: InputDecoration(
                          hintText: 'Search by doctor name or specialization...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primaryRed),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    searchDoctors('');
                                    setState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.fieldFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Specialization Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedSpecialization,
                        decoration: InputDecoration(
                          labelText: 'Select Specialization',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primaryRed),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        hint: const Text('All Specializations'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Specializations'),
                          ),
                          ...specializations.map((specialization) {
                            return DropdownMenuItem<String>(
                              value: specialization.specializationName,
                              child: Text(specialization.specializationName),
                            );
                          }),
                        ],
                        onChanged: filterDoctorsBySpecialization,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryRed),
                        dropdownColor: Colors.white,
                        isExpanded: true,
                      ),
                    ],
                  ),
                ),
                
                // Results count with pagination info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${filteredDoctors.length} doctors available',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (hasMorePages && !isLoadingMore)
                            Text(
                              'Showing ${allDoctors.length} of $totalPages pages',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.list,
                              size: 14,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'List View',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Doctors List with pagination
                Expanded(
                  child: filteredDoctors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.medical_services,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No doctors found',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: refreshDoctors,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDoctors.length + (isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredDoctors.length && isLoadingMore) {
                                return _buildLoadingIndicator();
                              }
                              final doctor = filteredDoctors[index];
                              return _buildDoctorListItem(doctor);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
        strokeWidth: 2,
      ),
    );
  }

Widget _buildDoctorListItem(Doctor doctor) {
  return GestureDetector(
    onTap: () {
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
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor Image with caching
          Container(
            width: 85,
            height: 105,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryRed.withValues(alpha: 0.1),
                  AppColors.primaryRed.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: doctor.doctorImagePath != null && doctor.doctorImagePath!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: doctor.doctorImagePath!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                        child: const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      // Optional: Add image caching options
                      memCacheWidth: 170, // 2x display size for retina
                      memCacheHeight: 210,
                      maxWidthDiskCache: 170,
                      maxHeightDiskCache: 210,
                    )
                  : Container(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: AppColors.primaryRed,
                      ),
                    ),
            ),
          ),
          
          // Rest of your code...
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.doctorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.medical_services,
                          size: 14,
                          color: AppColors.primaryRed,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doctor.specializationName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryRed,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Schedule Appointment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
  
  
  // Widget _buildDoctorListItem(Doctor doctor) {
  //   return GestureDetector(
  //     onTap: () {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (_) => DoctorScheduleScreen(
  //             doctorId: doctor.id,
  //             doctorName: doctor.doctorName,
  //             patientMrNo: widget.patientMrNo,
  //             patientName: widget.patientName,
  //             departmentId: doctor.departmentId,
  //             isLoggedIn: widget.isLoggedIn,
  //           ),
  //         ),
  //       );
  //     },
  //     child: Container(
  //       margin: const EdgeInsets.only(bottom: 16),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(20),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.grey.shade200,
  //             blurRadius: 10,
  //             offset: const Offset(0, 4),
  //           ),
  //         ],
  //       ),
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // Doctor Image
  //           Container(
  //             width: 85,
  //             height: 105,
  //             decoration: BoxDecoration(
  //               borderRadius: const BorderRadius.only(
  //                 topLeft: Radius.circular(20),
  //                 bottomLeft: Radius.circular(20),
  //               ),
  //               gradient: LinearGradient(
  //                 begin: Alignment.topLeft,
  //                 end: Alignment.bottomRight,
  //                 colors: [
  //                   const AppColors.primaryRed.withOpacity(0.1),
  //                   const AppColors.primaryRed.withOpacity(0.05),
  //                 ],
  //               ),
  //             ),
  //             child: ClipRRect(
  //               borderRadius: const BorderRadius.only(
  //                 topLeft: Radius.circular(20),
  //                 bottomLeft: Radius.circular(20),
  //               ),
  //               child: doctor.doctorImagePath != null && doctor.doctorImagePath!.isNotEmpty
  //                   ? Image.network(
  //                       doctor.doctorImagePath!,
  //                       fit: BoxFit.cover,
  //                       errorBuilder: (context, error, stackTrace) {
  //                         return Container(
  //                           color: const AppColors.primaryRed.withOpacity(0.1),
  //                           child: const Icon(
  //                             Icons.person,
  //                             size: 50,
  //                             color: AppColors.primaryRed,
  //                           ),
  //                         );
  //                       },
  //                     )
  //                   : Container(
  //                       color: const AppColors.primaryRed.withOpacity(0.1),
  //                       child: const Icon(
  //                         Icons.person,
  //                         size: 50,
  //                         color: AppColors.primaryRed,
  //                       ),
  //                     ),
  //             ),
  //           ),
            
  //           // Doctor Info
  //           Expanded(
  //             child: Padding(
  //               padding: const EdgeInsets.all(12),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     doctor.doctorName,
  //                     style: const TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.bold,
  //                       color: Color(0xFF1A1A1A),
  //                     ),
  //                     maxLines: 2,
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                   const SizedBox(height: 8),
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                     decoration: BoxDecoration(
  //                       color: const AppColors.primaryRed.withOpacity(0.08),
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     child: Row(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         const Icon(
  //                           Icons.medical_services,
  //                           size: 14,
  //                           color: AppColors.primaryRed,
  //                         ),
  //                         const SizedBox(width: 4),
  //                         Expanded(
  //                           child: Text(
  //                             doctor.specializationName,
  //                             style: const TextStyle(
  //                               fontSize: 14,
  //                               fontWeight: FontWeight.w700,
  //                               color: AppColors.primaryRed,
  //                             ),
  //                             maxLines: 2,
  //                             overflow: TextOverflow.ellipsis,
  //                             softWrap: true,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   const SizedBox(height: 12),
  //                   Row(
  //                     children: [
  //                       const Spacer(),
  //                       Container(
  //                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //                         decoration: BoxDecoration(
  //                           color: const AppColors.primaryRed,
  //                           borderRadius: BorderRadius.circular(20),
  //                         ),
  //                         child: const Text(
  //                           'Schedule Appointment',
  //                           style: TextStyle(
  //                             fontSize: 12,
  //                             fontWeight: FontWeight.w600,
  //                             color: Colors.white,
  //                           ),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

}