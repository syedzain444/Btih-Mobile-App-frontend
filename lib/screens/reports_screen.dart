// import 'dart:io';
// import 'package:btih_andriod_app/utils/ip_file.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:dio/dio.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:share_plus/share_plus.dart';

// class ReportsScreen extends StatefulWidget {
//   final String patientMrNo;
//   final String patientName;

//   const ReportsScreen({
//     super.key,
//     required this.patientMrNo,
//     required this.patientName,
//   });

//   @override
//   State<ReportsScreen> createState() => _ReportsScreenState();
// }

// class _ReportsScreenState extends State<ReportsScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;

//   List<Map<String, dynamic>> laboratoryReports = [];
//   List<Map<String, dynamic>> gastroReports = [];
//   List<Map<String, dynamic>> radiologyReports = [];
//   List<Map<String, dynamic>> prescriptionReports = [];

//   bool isLoading = true;
//   String? errorMessage;

//   // Color scheme
//   final Color primaryColor = const Color(0xFF1FC9C0);
//   final Color accentColor = const Color(0xFF2E3B4E);
//   final Color backgroundColor = Colors.white;
//   final Color cardBackgroundColor = Colors.white;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 4, vsync: this);
//     fetchAllReports();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> fetchAllReports() async {
//     setState(() {
//       isLoading = true;
//       errorMessage = null;
//     });

//     try {
//       await Future.wait([
//         fetchLaboratoryReports(),
//         fetchGastroReports(),
//         fetchRadiologyReports(),
//         fetchPrescriptionReports(),
//       ]);

//       setState(() {
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         errorMessage = 'Error fetching reports: $e';
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> fetchLaboratoryReports() async {
//     try {
//       final response = await ApiConfig.client.get(
//         Uri.parse(
//             "${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/labReports"),
//       );

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);
//         setState(() {
//           laboratoryReports = data.map((item) => {
//             'name': item['diagnostiC_NAME'] ?? 'Unknown Test',
//             'date': item['dT_SAMPLECOLLECTION'] ?? '',
//             'pat_diag_id': item['paT_DIAG_ID'],
//             'modality': item['modalitY_NM'] ?? '',
//             'testtype': item['testtype'] ?? '',
//             'icon': _getIconForTest(item['diagnostiC_NAME'] ?? ''),
//             'type': 'Laboratory',
//           }).toList();
//         });
//       }
//     } catch (e) {
//       print('Error fetching laboratory reports: $e');
//     }
//   }

//   Future<void> fetchGastroReports() async {
//     try {
//       final response = await ApiConfig.client.get(
//         Uri.parse("${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/gastroReports"),
//       );

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);
//         setState(() {
//           gastroReports = data.map((item) => {
//             'name': item['diagnostiC_NAME'] ?? 'Unknown Test',
//             'date': item['dT_SAMPLECOLLECTION'] ?? '',
//             'pat_diag_id': item['paT_DIAG_ID'],
//             'modality': item['modalitY_NM'] ?? '',
//             'testtype': item['testtype'] ?? '',
//             'icon': Icons.medical_services,
//             'type': 'Gastro',
//           }).toList();
//         });
//       }
//     } catch (e) {
//       print('Error fetching gastro reports: $e');
//     }
//   }

//   Future<void> fetchRadiologyReports() async {
//     try {
//       final response = await ApiConfig.client.get(
//         Uri.parse(
//             "${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/radiologyReports"),
//       );

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);
//         setState(() {
//           radiologyReports = data.map((item) => {
//             'name': item['diagnostiC_NAME'] ?? 'Unknown Test',
//             'date': item['dT_SAMPLECOLLECTION'] ?? '',
//             'pat_diag_id': item['paT_DIAG_ID'],
//             'modality': item['modalitY_NM'] ?? '',
//             'testtype': item['testtype'] ?? '',
//             'icon': Icons.radio,
//             'type': 'Radiology',
//           }).toList();
//         });
//       }
//     } catch (e) {
//       print('Error fetching radiology reports: $e');
//     }
//   }

//   Future<void> fetchPrescriptionReports() async {
//     try {
//       final response = await ApiConfig.client.get(
//         Uri.parse(
//             "${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/prescriptionReports"),
//       );

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);
//         setState(() {
//           prescriptionReports = data.map((item) => {
//             'name': 'Prescription',
//             'date': item['visiT_DATE'] ?? '',
//             'pat_visit_id': item['paT_VISIT_ID'],
//             'doctor': item['doctor'] ?? 'Unknown Doctor',
//             'department': item['department'] ?? 'Unknown Department',
//             'icon': Icons.description_outlined,
//             'visit_date': item['visiT_DATE'] ?? '',
//             'type': 'Prescription',
//           }).toList();
//         });
//       }
//     } catch (e) {
//       print('Error fetching prescription reports: $e');
//     }
//   }

//   IconData _getIconForTest(String testName) {
//     String name = testName.toLowerCase();
//     if (name.contains('glucose')) return Icons.bloodtype_outlined;
//     if (name.contains('lipid')) return Icons.opacity_outlined;
//     if (name.contains('liver')) return Icons.healing_outlined;
//     if (name.contains('thyroid')) return Icons.monitor_heart_outlined;
//     if (name.contains('urine')) return Icons.water_drop_outlined;
//     if (name.contains('vitamin')) return Icons.wb_sunny_outlined;
//     if (name.contains('x-ray')) return Icons.medical_services_outlined;
//     if (name.contains('mri')) return Icons.monitor_heart_outlined;
//     if (name.contains('ct')) return Icons.view_in_ar_outlined;
//     return Icons.science_outlined;
//   }

//   String _formatDateFromAPI(String dateString) {
//     if (dateString.isEmpty) return '';
//     try {
//       DateTime dateTime = DateTime.parse(dateString);
//       final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
//       return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
//     } catch (e) {
//       return dateString;
//     }
//   }
// Future<void> _downloadReport(String url, String fileName, String reportName) async {
//   // Show download progress dialog
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (BuildContext context) {
//       return Dialog(
//         elevation: 0,
//         backgroundColor: Colors.transparent,
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.2),
//                 spreadRadius: 2,
//                 blurRadius: 10,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 60,
//                 height: 60,
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.withOpacity(0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const CircularProgressIndicator(
//                   color: Colors.blue,
//                   strokeWidth: 3,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 reportName,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF2E3B4E),
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'Downloading report',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey,
//                 ),
//               ),
//               const Text(
//                 'Please wait...',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     },
//   );

//   try {
//     final dio = Dio();
//     dio.options.connectTimeout = const Duration(seconds: 30);
//     dio.options.receiveTimeout = const Duration(seconds: 30);

//     final response = await dio.get(
//       url,
//       options: Options(responseType: ResponseType.bytes),
//     );

//     // For Android 10 and above, we need to use the Downloads folder
//     Directory? downloadsDir;
    
//     if (Platform.isAndroid) {
//       // Try to get the Downloads directory
//       downloadsDir = Directory('/storage/emulated/0/Download');
      
//       // Check if directory exists, if not try alternative paths
//       if (!await downloadsDir.exists()) {
//         downloadsDir = Directory('/sdcard/Download');
//       }
//       if (!await downloadsDir.exists()) {
//         downloadsDir = Directory('/storage/self/primary/Download');
//       }
      
//       // If still not found, fallback to app documents
//       if (!await downloadsDir.exists()) {
//         downloadsDir = await getExternalStorageDirectory();
//       }
//     } else if (Platform.isIOS) {
//       downloadsDir = await getApplicationDocumentsDirectory();
//     }

//     // If we couldn't get downloads directory, fallback to app documents
//     if (downloadsDir == null || !await downloadsDir.exists()) {
//       downloadsDir = await getApplicationDocumentsDirectory();
//     }

//     // Create a clean filename
//     String cleanFileName = fileName.replaceAll(' ', '_');
//     String filePath = '${downloadsDir.path}/$cleanFileName';
    
//     File file = File(filePath);
    
//     // If file exists, add number to avoid overwriting
//     if (await file.exists()) {
//       int counter = 1;
//       final nameWithoutExt = cleanFileName.substring(0, cleanFileName.lastIndexOf('.'));
//       final ext = cleanFileName.substring(cleanFileName.lastIndexOf('.'));
      
//       // Generate new filename with counter
//       String newFileName;
//       do {
//         newFileName = '${nameWithoutExt}_$counter$ext';
//         filePath = '${downloadsDir.path}/$newFileName';
//         file = File(filePath);
//         counter++;
//       } while (await file.exists());
      
//       cleanFileName = newFileName;
//     }

//     await file.writeAsBytes(response.data, flush: true);

//     if (Navigator.canPop(context)) {
//       Navigator.pop(context); // Close download dialog
//     }

//     // Show success message with option to open
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Row(
//               children: [
//                 Icon(Icons.check_circle, color: Colors.white),
//                 SizedBox(width: 8),
//                 Text(
//                   'Download Complete',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 4),
//             Text(
//               'Saved to: $cleanFileName',
//               style: const TextStyle(fontSize: 12),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.green,
//         duration: const Duration(seconds: 4),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//         action: SnackBarAction(
//           label: 'OPEN',
//           textColor: Colors.white,
//           onPressed: () {
//             _openPDF(filePath, cleanFileName);
//           },
//         ),
//       ),
//     );
//   } catch (e) {
//     if (Navigator.canPop(context)) {
//       Navigator.pop(context); // Close download dialog
//     }
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.error_outline, color: Colors.white),
//             const SizedBox(width: 8),
//             Expanded(child: Text("Download failed: ${e.toString()}")),
//           ],
//         ),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//     );
//   }
// }
//   void _openPDF(String filePath, String fileName) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => Scaffold(
//           appBar: AppBar(
//             title: Text(
//               fileName,
//               style: const TextStyle(fontSize: 16),
//             ),
//             backgroundColor: primaryColor,
//             elevation: 0,
//             actions: [
//               IconButton(
//                 icon: const Icon(Icons.share),
//                 onPressed: () {
//                   // Share functionality can be added here
//                   // ScaffoldMessenger.of(context).showSnackBar(
//                   //   const SnackBar(content: Text('Share feature coming soon')),
//                   // );
//                   _sharePDF(filePath, fileName);
//                 },
//               ),
//             ],
//           ),
//           body: SfPdfViewer.file(
//   File(filePath),
//   pageLayoutMode: PdfPageLayoutMode.single, // Important
//   canShowScrollHead: true,
//   canShowScrollStatus: true,
//   enableDoubleTapZooming: true,
// ),
//         ),
//       ),
//     );
//   }

// Future<void> _sharePDF(String filePath, String reportName) async {
//   try {
//     final file = File(filePath);
//     if (await file.exists()) {
//       final xFile = XFile(filePath);
//       await Share.shareXFiles(
//         [xFile],
//         text: 'Here is your $reportName',
//       );
//     }
//   } catch (e) {
//     print('Share error: $e');
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error sharing file: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
// }

// void _openReport(Map<String, dynamic> report) async {
//   final patDiagId = report['pat_diag_id'];
//   final patVisitId = report['pat_visit_id'];
  
//   String reportName = '';
//   String rptId = '';
//   String parameters = '';
  
//   if (patVisitId != null) {
//     parameters = patVisitId.toString();
//     reportName = 'PRESCRIPTION_A4';
//     rptId = '141';
//   } else if (patDiagId != null) {
//     parameters = patDiagId.toString();
    
//     final testType = report['testtype']?.toString().toUpperCase() ?? '';
//     final modality = report['modality']?.toString().toUpperCase() ?? '';

//     if (testType == 'LABORATORY' || modality.contains('LAB')) {
//       reportName = 'Labrpt';
//       rptId = '19';
//     } else if (testType == 'GASTRO' || modality.contains('GASTRO')) {
//       reportName = 'GastRpt';
//       rptId = '64';
//     } else if (testType == 'RADIOLOGY' || modality.contains('RADIOLOGY')) {
//       reportName = 'RadRpt';
//       rptId = '22';
//     } else {
//       reportName = 'PRESCRIPTION_A4';
//       rptId = '141';
//     }
//   } else {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Cannot open report: No valid ID found")),
//     );
//     return;
//   }

//   final String pdfUrl =
//       "${ApiConfig.baseUrl}/api/PatientReport/GenerateReport"
//       "?rptId=$rptId"
//       "&reportName=$reportName"
//       "&parameters=$parameters"
//       "&user=MobileApp";
  
//   // Show loading dialog
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (BuildContext context) {
//       return Dialog(
//         elevation: 0,
//         backgroundColor: Colors.transparent,
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.2),
//                 spreadRadius: 2,
//                 blurRadius: 10,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Animated circular progress with container
//               Container(
//                 width: 60,
//                 height: 60,
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: primaryColor.withOpacity(0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const CircularProgressIndicator(
//                   color: Color(0xFF1FC9C0),
//                   strokeWidth: 3,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               // Report name
//               Text(
//                 report['name'] ?? 'Report',
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF2E3B4E),
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 8),
//               // Loading text with animated dots
//               const Text(
//                 'Generating your report',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               const Text(
//                 'Please wait...',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     },
//   );

//   try {
//     final dir = await getApplicationDocumentsDirectory();
//     final fileName = '${reportName}_$parameters.pdf';
//     final filePath = '${dir.path}/$fileName';

//     final dio = Dio();
//     dio.options.connectTimeout = const Duration(seconds: 30);
//     dio.options.receiveTimeout = const Duration(seconds: 30);

//     final response = await dio.get(
//       pdfUrl,
//       options: Options(responseType: ResponseType.bytes),
//     );

//     final contentType = response.headers.value("content-type");

//     if (contentType == null || !contentType.contains("application/pdf")) {
//       Navigator.pop(context); // Close loading dialog
//       throw Exception("Server did not return a valid PDF");
//     }

//     final file = File(filePath);
//     await file.writeAsBytes(response.data, flush: true);

//     Navigator.pop(context); // Close loading dialog

//     // Directly open the PDF without showing options
//     _openPDF(filePath, fileName);
    
//   } catch (e) {
//     if (Navigator.canPop(context)) {
//       Navigator.pop(context); // Close loading dialog
//     }
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.error_outline, color: Colors.white),
//             const SizedBox(width: 8),
//             Expanded(child: Text("Error generating report: ${e.toString()}")),
//           ],
//         ),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//     );
//   }
// }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         backgroundColor: primaryColor,
//         elevation: 0,
//         leading: IconButton(
//           icon: Container(
//             padding: const EdgeInsets.all(8),
//             child: const Icon(Icons.arrow_back_ios, color: Colors.white),
//           ),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Medical Reports',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.w700,
//                 fontSize: 18,
//                 letterSpacing: 0.5,
//               ),
//             ),
//             const SizedBox(height: 2),
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(
//                     'MR: ${widget.patientMrNo}',
//                     style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     widget.patientName,
//                     style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 11,
//                       fontWeight: FontWeight.w500,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.white,
//           indicatorWeight: 3,
//           indicatorSize: TabBarIndicatorSize.tab,
//           labelColor: Colors.white,
//           unselectedLabelColor: Colors.white,
//           labelStyle: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 13,
//           ),
//           unselectedLabelStyle: const TextStyle(
//             fontWeight: FontWeight.w700,
//             fontSize: 14,
//           ),
//           isScrollable: true,
//           tabs: const [
//             Tab(text: 'Laboratory'),
//             Tab(text: 'Gastro'),
//             Tab(text: 'Radiology'),
//             Tab(text: 'Prescription'),
//           ],
//         ),
//       ),
//       body: isLoading
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(
//                     color: primaryColor,
//                     strokeWidth: 3,
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Loading reports...',
//                     style: TextStyle(
//                       color: Colors.grey[600],
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : errorMessage != null
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.error_outline,
//                         size: 48,
//                         color: Colors.red[300],
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         errorMessage!,
//                         style: TextStyle(
//                           color: Colors.grey[600],
//                           fontSize: 14,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 16),
//                       ElevatedButton(
//                         onPressed: fetchAllReports,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: primaryColor,
//                           foregroundColor: Colors.white,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                         child: const Text('Retry'),
//                       ),
//                     ],
//                   ),
//                 )
//               : TabBarView(
//                   controller: _tabController,
//                   children: [
//                     _buildReportsGrid(laboratoryReports),
//                     _buildReportsGrid(gastroReports),
//                     _buildReportsGrid(radiologyReports),
//                     _buildReportsGrid(prescriptionReports),
//                   ],
//                 ),
//     );
//   }

//   Widget _buildReportsGrid(List<Map<String, dynamic>> reports) {
//     if (reports.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.grey[100],
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 Icons.folder_open_outlined,
//                 size: 48,
//                 color: Colors.grey[400],
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'No reports available',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey[600],
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Check back later for updates',
//               style: TextStyle(
//                 fontSize: 13,
//                 color: Colors.grey[500],
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     return Padding(
//       padding: const EdgeInsets.all(12),
//       child: GridView.builder(
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 12,
//           mainAxisSpacing: 12,
//           childAspectRatio: 1.1,
//         ),
//         itemCount: reports.length,
//         itemBuilder: (context, index) {
//           final report = reports[index];
//           String formattedDate = _formatDateFromAPI(report['date'] ?? '');
//           bool isPrescription = report['type'] == 'Prescription';
          
//           return GestureDetector(
//             onTap: () => _openReport(report),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: cardBackgroundColor,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.08),
//                     spreadRadius: 2,
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: Stack(
//                   children: [
//                     // Gradient overlay at top
//                     Positioned(
//                       top: 0,
//                       left: 0,
//                       right: 0,
//                       child: Container(
//                         height: 60,
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                             colors: [
//                               primaryColor.withOpacity(0.05),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
                    
//                     Padding(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           // Header with icon and date
//                           Row(
//                             children: [
//                               Container(
//                                 padding: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: primaryColor.withOpacity(0.1),
//                                   borderRadius: BorderRadius.circular(14),
//                                 ),
//                                 child: Icon(
//                                   report['icon'] ?? Icons.description_outlined,
//                                   color: primaryColor,
//                                   size: 18,
//                                 ),
//                               ),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 8,
//                                     vertical: 4,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: Colors.grey[50],
//                                     borderRadius: BorderRadius.circular(20),
//                                     border: Border.all(
//                                       color: Colors.grey[200]!,
//                                       width: 1,
//                                     ),
//                                   ),
//                                   child: Text(
//                                     formattedDate,
//                                     style: TextStyle(
//                                       fontSize: 9,
//                                       fontWeight: FontWeight.w600,
//                                       color: Colors.grey[700],
//                                     ),
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
                          
//                           const SizedBox(height: 10),
                          
//                           // Report name/type
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 8,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: primaryColor.withOpacity(0.05),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Text(
//                               report['name'] ?? '',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 11,
//                                 color: Color(0xFF2E3B4E),
//                                 letterSpacing: 0.3,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
                          
//                           const SizedBox(height: 8),
                          
//                           // Doctor name (for prescriptions) or modality
//                           if (isPrescription && report['doctor'] != null) ...[
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 6,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.blue.withOpacity(0.05),
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(
//                                   color: Colors.blue.withOpacity(0.1),
//                                   width: 1,
//                                 ),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Icon(
//                                     Icons.person_outline,
//                                     size: 12,
//                                     color: Colors.blue[700],
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Expanded(
//                                     child: Text(
//                                       report['doctor'],
//                                       style: TextStyle(
//                                         fontSize: 10,
//                                         fontWeight: FontWeight.w600,
//                                         color: Colors.blue[800],
//                                         letterSpacing: 0.2,
//                                       ),
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ] else if (report['modality'] != null && report['modality'].isNotEmpty) ...[
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.orange.withOpacity(0.05),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Text(
//                                 report['modality'],
//                                 style: TextStyle(
//                                   fontSize: 9,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.orange[800],
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ],
                          
//                           const SizedBox(height: 8),
                          
//                           // Department badge (for prescriptions)
//                           if (isPrescription && report['department'] != null) ...[
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.purple.withOpacity(0.05),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     Icons.business_outlined,
//                                     size: 10,
//                                     color: Colors.purple[600],
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Flexible(
//                                     child: Text(
//                                       report['department'],
//                                       style: TextStyle(
//                                         fontSize: 9,
//                                         fontWeight: FontWeight.w600,
//                                         color: Colors.purple[700],
//                                       ),
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ],
//                       ),
//                     ),
                    
//                     // Subtle border accent
//                     Positioned(
//                       top: 0,
//                       left: 0,
//                       child: Container(
//                         width: 4,
//                         height: 30,
//                         decoration: BoxDecoration(
//                           color: primaryColor,
//                           borderRadius: const BorderRadius.only(
//                             topLeft: Radius.circular(20),
//                             bottomRight: Radius.circular(4),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

import 'dart:io';
import 'dart:typed_data';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/services/recent_activity_service.dart';
import 'package:btih_andriod_app/utils/download_location_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/utils/report_download_helper.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:flutter/material.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';

enum ReportSortOrder { newestFirst, oldestFirst }

class CategoryReportFilters {
  final int? year;
  final String? testCategory;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const CategoryReportFilters({
    this.year,
    this.testCategory,
    this.dateFrom,
    this.dateTo,
  });

  static const empty = CategoryReportFilters();

  int get activeCount {
    var count = 0;
    if (year != null) count++;
    if (testCategory != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    return count;
  }

  CategoryReportFilters copyWith({
    int? year,
    String? testCategory,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearYear = false,
    bool clearTestCategory = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return CategoryReportFilters(
      year: clearYear ? null : (year ?? this.year),
      testCategory:
          clearTestCategory ? null : (testCategory ?? this.testCategory),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

class _ReportPdfRequest {
  final String url;
  final String fileName;
  final String displayTitle;

  const _ReportPdfRequest({
    required this.url,
    required this.fileName,
    required this.displayTitle,
  });
}

class ReportsScreen extends StatefulWidget {
  final String patientMrNo;
  final String patientName;
  final int initialTabIndex;
  final Map<String, dynamic>? autoOpenReport;

  const ReportsScreen({
    super.key,
    required this.patientMrNo,
    required this.patientName,
    this.initialTabIndex = 0,
    this.autoOpenReport,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> laboratoryReports = [];
  List<Map<String, dynamic>> gastroReports = [];
  List<Map<String, dynamic>> radiologyReports = [];
  List<Map<String, dynamic>> prescriptionReports = [];

  // Filtered reports for each tab
  List<Map<String, dynamic>> filteredLaboratoryReports = [];
  List<Map<String, dynamic>> filteredGastroReports = [];
  List<Map<String, dynamic>> filteredRadiologyReports = [];
  List<Map<String, dynamic>> filteredPrescriptionReports = [];

  // Search controllers for each tab
  final TextEditingController labSearchController = TextEditingController();
  final TextEditingController gastroSearchController = TextEditingController();
  final TextEditingController radiologySearchController = TextEditingController();
  final TextEditingController prescriptionSearchController = TextEditingController();

  final List<CategoryReportFilters> _categoryFilters =
      List.filled(4, CategoryReportFilters.empty);
  final List<ReportSortOrder> _sortOrders =
      List.filled(4, ReportSortOrder.newestFirst);

  /// Prescription care-setting filter: null = All, else OPD | IPD | Emergency.
  String? _prescriptionCareSetting;

  bool isLoading = true;
  String? errorMessage;
  late int _selectedCategoryIndex;
  bool _reportDownloadInProgress = false;
  bool _didAutoOpenReport = false;

  // Color scheme
  final Color primaryColor = const Color(0xFF1FC9C0);
  final Color accentColor = const Color(0xFF2E3B4E);
  final Color backgroundColor = Colors.white;
  final Color cardBackgroundColor = Colors.white;

  final List<Map<String, dynamic>> categories = [
    {
      'name': 'Laboratory',
      'subtitle': 'Blood tests, pathology & lab results',
      'icon': Icons.science_outlined,
      'color': const Color(0xFF26A69A),
      'bg': const Color(0xFFE0F2F1),
    },
    {
      'name': 'Gastro',
      'subtitle': 'Endoscopy & gastro reports',
      'icon': Icons.medical_services_outlined,
      'color': const Color(0xFFFF7043),
      'bg': const Color(0xFFFBE9E7),
    },
    {
      'name': 'Radiology',
      'subtitle': 'X-ray, MRI, CT & imaging',
      'icon': Icons.radio_rounded,
      'color': const Color(0xFF7E57C2),
      'bg': const Color(0xFFEDE7F6),
    },
    {
      'name': 'Prescription',
      'subtitle': 'Doctor prescriptions & medications',
      'icon': Icons.medication_outlined,
      'color': AppColors.primaryRed,
      'bg': AppColors.softRed,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategoryIndex = widget.initialTabIndex.clamp(0, 3);
    labSearchController.addListener(_onSearchChanged);
    gastroSearchController.addListener(_onSearchChanged);
    radiologySearchController.addListener(_onSearchChanged);
    prescriptionSearchController.addListener(_onSearchChanged);
    fetchAllReports();
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    labSearchController.dispose();
    gastroSearchController.dispose();
    radiologySearchController.dispose();
    prescriptionSearchController.dispose();
    super.dispose();
  }

  // Filter and sort reports for a category
  TextEditingController _searchControllerFor(int index) {
    switch (index) {
      case 0:
        return labSearchController;
      case 1:
        return gastroSearchController;
      case 2:
        return radiologySearchController;
      case 3:
        return prescriptionSearchController;
      default:
        return labSearchController;
    }
  }

  static const _searchHints = {
    0: 'Search tests...',
    1: 'Search gastro reports...',
    2: 'Search imaging reports...',
    3: 'Search by doctor, date, OPD, IPD...',
  };

  static const _emptyMessages = {
    0: 'No laboratory reports available yet.',
    1: 'No gastro reports available yet.',
    2: 'No radiology reports available yet.',
    3: 'No prescription reports available yet.',
  };

  DateTime? _parseReportDate(Map<String, dynamic> report) {
    final raw = report['date']?.toString() ?? '';
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  String? _reportTestCategory(Map<String, dynamic> report) {
    final modality =
        report['modalityName'] ?? report['modalitY_NM'] ?? report['modality'];
    final modalityText = modality?.toString().trim();
    if (modalityText != null && modalityText.isNotEmpty) return modalityText;
    final careSetting = report['careSetting']?.toString().trim();
    if (careSetting != null && careSetting.isNotEmpty) return careSetting;
    final department = report['department']?.toString().trim();
    if (department != null && department.isNotEmpty) return department;
    final type = report['type']?.toString().trim();
    if (type != null && type.isNotEmpty) return type;
    return null;
  }

  /// Normalize API department into OPD | IPD | Emergency (or Other).
  String _normalizePrescriptionCareSetting(String? rawDepartment) {
    final raw = (rawDepartment ?? '').trim().toUpperCase();
    if (raw.isEmpty) return 'Other';
    if (raw.contains('EMERGENCY') ||
        raw == 'ER' ||
        raw.contains('A&E') ||
        raw.startsWith('ED ') ||
        raw == 'ED') {
      return 'Emergency';
    }
    if (raw.contains('IPD') ||
        raw.contains('INPATIENT') ||
        raw.contains('IN-PATIENT') ||
        raw.contains('IN PATIENT')) {
      return 'IPD';
    }
    if (raw.contains('OPD') ||
        raw.contains('OUTPATIENT') ||
        raw.contains('OUT-PATIENT') ||
        raw.contains('OUT PATIENT')) {
      return 'OPD';
    }
    return 'Other';
  }

  String _prescriptionCareSettingOf(Map<String, dynamic> report) {
    final stored = report['careSetting']?.toString().trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return _normalizePrescriptionCareSetting(
      report['department']?.toString(),
    );
  }

  Map<String, int> _prescriptionCareSettingCounts() {
    final counts = <String, int>{
      'OPD': 0,
      'IPD': 0,
      'Emergency': 0,
      'Other': 0,
    };
    for (final report in prescriptionReports) {
      final key = _prescriptionCareSettingOf(report);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  String _prescriptionDisplayTitle({
    required String doctor,
    required String careSetting,
    required dynamic visitId,
  }) {
    if (doctor.isNotEmpty) return doctor;
    if (careSetting.isNotEmpty && careSetting != 'Other') return careSetting;
    final id = visitId?.toString().trim();
    if (id != null && id.isNotEmpty) return 'Visit $id';
    return 'Untitled visit';
  }

  List<String> _availableTestCategories(int index) {
    final values = _reportsForCategory(index)
        .map(_reportTestCategory)
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<int> _availableYears(int index) {
    final years = _reportsForCategory(index)
        .map(_parseReportDate)
        .whereType<DateTime>()
        .map((d) => d.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  bool _matchesSearch(Map<String, dynamic> report, String query, int index) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final haystack = [
      report['diagnosticName'] ??
          report['diagnostiC_NAME'] ??
          report['name'] ??
          '',
      report['modalityName'] ??
          report['modalitY_NM'] ??
          report['modality'] ??
          '',
      report['patDiagId'] ?? report['paT_DIAG_ID'] ?? report['pat_diag_id'] ?? '',
      report['sampleCollectionDate'] ??
          report['dT_SAMPLECOLLECTION'] ??
          report['date'] ??
          '',
      report['doctor'] ?? '',
      report['department'] ?? '',
      report['careSetting'] ?? '',
      _reportTestCategory(report) ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  bool _matchesFilters(Map<String, dynamic> report, CategoryReportFilters filters) {
    final date = _parseReportDate(report);

    if (filters.year != null && date?.year != filters.year) return false;

    if (filters.testCategory != null &&
        _reportTestCategory(report) != filters.testCategory) {
      return false;
    }

    if (filters.dateFrom != null && date != null) {
      final from = DateTime(
        filters.dateFrom!.year,
        filters.dateFrom!.month,
        filters.dateFrom!.day,
      );
      if (date.isBefore(from)) return false;
    }

    if (filters.dateTo != null && date != null) {
      final to = DateTime(
        filters.dateTo!.year,
        filters.dateTo!.month,
        filters.dateTo!.day,
        23,
        59,
        59,
      );
      if (date.isAfter(to)) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _filteredReportsForCategory(int index) {
    final raw = _reportsForCategory(index);
    final query = _searchControllerFor(index).text.trim();
    final filters = _categoryFilters[index];
    final sortOrder = _sortOrders[index];

    final list = raw.where((r) {
      if (!_matchesSearch(r, query, index) || !_matchesFilters(r, filters)) {
        return false;
      }
      if (index == 3 && _prescriptionCareSetting != null) {
        return _prescriptionCareSettingOf(r) == _prescriptionCareSetting;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final da = _parseReportDate(a);
      final db = _parseReportDate(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return sortOrder == ReportSortOrder.newestFirst
          ? db.compareTo(da)
          : da.compareTo(db);
    });

    return list;
  }

  String _formatDateGroupLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _sortLabelFor(int index) =>
      _sortOrders[index] == ReportSortOrder.newestFirst
          ? 'Newest First'
          : 'Oldest First';

  void _showCategoryFilterSheet(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportFilterSheet(
        filters: _categoryFilters[index],
        sortOrder: _sortOrders[index],
        years: _availableYears(index),
        testCategories: _availableTestCategories(index),
        categoryLabel: categories[index]['name'] as String,
        onApply: (filters, sortOrder) {
          setState(() {
            _categoryFilters[index] = filters;
            _sortOrders[index] = sortOrder;
          });
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() {
            _categoryFilters[index] = CategoryReportFilters.empty;
            _sortOrders[index] = ReportSortOrder.newestFirst;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> fetchAllReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await Future.wait([
        fetchLaboratoryReports(),
        fetchGastroReports(),
        fetchRadiologyReports(),
        fetchPrescriptionReports(),
      ]);

      filteredLaboratoryReports = List.from(laboratoryReports);
      filteredGastroReports = List.from(gastroReports);
      filteredRadiologyReports = List.from(radiologyReports);
      filteredPrescriptionReports = List.from(prescriptionReports);

      setState(() {
        isLoading = false;
      });
      _maybeAutoOpenReport();
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching reports: $e';
        isLoading = false;
      });
    }
  }

  void _maybeAutoOpenReport() {
    final report = widget.autoOpenReport;
    if (_didAutoOpenReport || report == null || !mounted) return;
    _didAutoOpenReport = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openReport(Map<String, dynamic>.from(report));
    });
  }

  Map<String, dynamic> _mapDiagnosticReport(
    Map<String, dynamic> raw, {
    required String type,
    required IconData icon,
  }) {
    final diagnosticName = _readString(raw, [
          'diagnosticName',
          'diagnostiC_NAME',
          'diagnostic_name',
        ]) ??
        'Unknown Test';
    final sampleDate = _readString(raw, [
          'sampleCollectionDate',
          'dT_SAMPLECOLLECTION',
          'sample_collection_date',
        ]) ??
        '';
    final patDiagId =
        raw['patDiagId'] ?? raw['paT_DIAG_ID'] ?? raw['pat_diag_id'];
    final modalityName = _readString(raw, [
          'modalityName',
          'modalitY_NM',
          'modality',
        ]) ??
        '';

    return {
      ...raw,
      'name': diagnosticName,
      'diagnosticName': diagnosticName,
      'diagnostiC_NAME': diagnosticName,
      'date': sampleDate,
      'sampleCollectionDate': sampleDate,
      'dT_SAMPLECOLLECTION': sampleDate,
      'pat_diag_id': patDiagId,
      'patDiagId': patDiagId,
      'paT_DIAG_ID': patDiagId,
      'modality': modalityName,
      'modalityName': modalityName,
      'modalitY_NM': modalityName,
      'icon': icon,
      'type': type,
      'testType': type,
      'testtype': type,
    };
  }

  String? _readString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  List<dynamic> _decodeReportList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) return [decoded];
    if (decoded is Map) return [Map<String, dynamic>.from(decoded)];
    return [];
  }

  String _diagnosticNameFromRaw(Map<String, dynamic> raw) {
    return _readString(raw, [
          'diagnosticName',
          'diagnostiC_NAME',
          'diagnostic_name',
        ]) ??
        '';
  }

  bool _isEmptyReportsResponse(int statusCode) =>
      statusCode == 200 || statusCode == 204 || statusCode == 404;

  Future<void> fetchLaboratoryReports() async {
    try {
      final response = await ApiConfig.client.get(
        Uri.parse(
            "${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/labReports"),
      );

      if (_isEmptyReportsResponse(response.statusCode)) {
        final data = response.statusCode == 200
            ? _decodeReportList(json.decode(response.body))
            : <dynamic>[];
        setState(() {
          laboratoryReports = data.map((item) {
            final raw = Map<String, dynamic>.from(item as Map);
            return _mapDiagnosticReport(
              raw,
              type: 'Laboratory',
              icon: _getIconForTest(_diagnosticNameFromRaw(raw)),
            );
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching laboratory reports: $e');
    }
  }

  Future<void> fetchGastroReports() async {
    try {
      final response = await ApiConfig.client.get(
        Uri.parse("${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/gastroReports"),
      );

      if (_isEmptyReportsResponse(response.statusCode)) {
        final data = response.statusCode == 200
            ? _decodeReportList(json.decode(response.body))
            : <dynamic>[];
        setState(() {
          gastroReports = data.map((item) {
            final raw = Map<String, dynamic>.from(item as Map);
            return _mapDiagnosticReport(
              raw,
              type: 'Gastro',
              icon: _getIconForGastroTest(_diagnosticNameFromRaw(raw)),
            );
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching gastro reports: $e');
    }
  }

  Future<void> fetchRadiologyReports() async {
    try {
      final response = await ApiConfig.client.get(
        Uri.parse(
            "${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/radiologyReports"),
      );

      if (_isEmptyReportsResponse(response.statusCode)) {
        final data = response.statusCode == 200
            ? _decodeReportList(json.decode(response.body))
            : <dynamic>[];
        setState(() {
          radiologyReports = data.map((item) {
            final raw = Map<String, dynamic>.from(item as Map);
            return _mapDiagnosticReport(
              raw,
              type: 'Radiology',
              icon: Icons.radio_rounded,
            );
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching radiology reports: $e');
    }
  }

  Future<void> fetchPrescriptionReports() async {
    try {
      final response = await ApiConfig.client.get(
        Uri.parse(
            "${ApiConfig.baseUrl}/api/Patient/${widget.patientMrNo}/prescriptionReports"),
      );

      if (_isEmptyReportsResponse(response.statusCode)) {
        final data = response.statusCode == 200
            ? _decodeReportList(json.decode(response.body))
            : <dynamic>[];
        setState(() {
          prescriptionReports = data.map((item) {
            final raw = Map<String, dynamic>.from(item as Map);
            final visitDate = _readString(raw, [
                  'visitDate',
                  'visiT_DATE',
                  'VISIT_DATE',
                  'visit_date',
                ]) ??
                '';
            final doctor = _readString(raw, ['doctor', 'DOCTOR']) ?? '';
            final department =
                _readString(raw, ['department', 'DEPARTMENT']) ?? '';
            final careSetting = _normalizePrescriptionCareSetting(department);
            final visitId = raw['patVisitId'] ??
                raw['paT_VISIT_ID'] ??
                raw['pat_visit_id'] ??
                raw['PAT_VISIT_ID'];
            final title = _prescriptionDisplayTitle(
              doctor: doctor,
              careSetting: careSetting,
              visitId: visitId,
            );
            return {
              ...raw,
              'name': title,
              'diagnosticName': title,
              'date': visitDate,
              'visiT_DATE': visitDate,
              'visitDate': visitDate,
              'visit_date': visitDate,
              'doctor': doctor,
              'department': department,
              'careSetting': careSetting,
              'pat_visit_id': visitId,
              'paT_VISIT_ID': visitId,
              'patVisitId': visitId,
              'icon': Icons.description_outlined,
              'type': 'Prescription',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching prescription reports: $e');
    }
  }

  IconData _getIconForGastroTest(String testName) {
    final name = testName.toLowerCase();
    if (name.contains('colonoscopy')) return Icons.biotech_outlined;
    if (name.contains('endoscopy') || name.contains('gastro')) {
      return Icons.medical_services_outlined;
    }
    return Icons.medical_services_outlined;
  }

  IconData _getIconForTest(String testName) {
    String name = testName.toLowerCase();
    if (name.contains('glucose')) return Icons.bloodtype_outlined;
    if (name.contains('lipid')) return Icons.opacity_outlined;
    if (name.contains('liver')) return Icons.healing_outlined;
    if (name.contains('thyroid')) return Icons.monitor_heart_outlined;
    if (name.contains('urine')) return Icons.water_drop_outlined;
    if (name.contains('vitamin')) return Icons.wb_sunny_outlined;
    if (name.contains('x-ray')) return Icons.medical_services_outlined;
    if (name.contains('mri')) return Icons.monitor_heart_outlined;
    if (name.contains('ct')) return Icons.view_in_ar_outlined;
    return Icons.science_outlined;
  }

  String _formatDateFromAPI(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      DateTime dateTime = DateTime.parse(dateString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateForDisplay(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String formatTime(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? "PM" : "AM";
      return "$hour:$minute $period";
    } catch (e) {
      return '';
    }
  }

  Widget _buildMaroonLoadingDialog({required String title, required String subtitle}) {
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
              decoration: BoxDecoration(
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
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please wait...',
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

  Future<void> _downloadReport(String url, String fileName, String reportName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _buildMaroonLoadingDialog(
        title: reportName,
        subtitle: 'Downloading report',
      ),
    );

    try {
      final dio = ApiConfig.createDio();
      dio.options.connectTimeout = const Duration(seconds: 60);
      dio.options.receiveTimeout = const Duration(seconds: 60);

      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final contentType = response.headers.value('content-type');
      if (!_looksLikePdf(response.data) &&
          (contentType == null || !contentType.contains('application/pdf'))) {
        throw Exception('Server did not return a valid PDF');
      }

      final savedFile = await ReportDownloadHelper.savePdfBytes(
        bytes: response.data,
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
    }
  }

// void _openPDF(String filePath, String fileName) {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => Scaffold(
//         appBar: AppBar(
//           title: Text(
//             fileName,
//             style: const TextStyle(
//               fontSize: 16,
//               color: Colors.white,
//             ),
//           ),
//           backgroundColor: primaryColor,
//           elevation: 1,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//             onPressed: () => Navigator.pop(context),
//           ),
//           actions: [
//             // Download Icon Button
//             IconButton(
//               icon: const Icon(Icons.download, color: Colors.white),
//               onPressed: () {
//                 _downloadExistingPDF(filePath, fileName);
//               },
//               tooltip: 'Download PDF',
//             ),
//             // Share Icon Button
//             IconButton(
//               icon: const Icon(Icons.share, color: Colors.white),
//               onPressed: () {
//                 _sharePDF(filePath, fileName);
//               },
//               tooltip: 'Share PDF',
//             ),
//           ],
//         ),
//         body: SfPdfViewer.file(
//           File(filePath),
//           pageLayoutMode: PdfPageLayoutMode.single,
//           canShowScrollHead: true,
//           canShowScrollStatus: true,
//           enableDoubleTapZooming: true,
//         ),
//       ),
//     ),
//   );
// }

  void _openPDF(String filePath, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppAppBar(
            title: Text(
              fileName,
              style: AppTypography.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.white),
                onPressed: () => _sharePDF(filePath, fileName),
                tooltip: 'Share PDF',
              ),
            ],
          ),
          body: ColoredBox(
            color: AppColors.white,
            child: SfPdfViewer.file(
              File(filePath),
              pageLayoutMode: PdfPageLayoutMode.single,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sharePDF(String filePath, String reportName) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final xFile = XFile(filePath);
        await Share.shareXFiles(
          [xFile],
          text: 'Here is your $reportName',
        );
      }
    } catch (e) {
      print('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openReport(Map<String, dynamic> report) async {
    final request = _resolveReportPdfRequest(report);
    if (request == null) return;

    final categoryLabel =
        (categories[_selectedCategoryIndex]['name'] as String?) ?? 'Report';
    RecentActivityService.instance.trackMedicalReport(
      scopeId: RecentActivityService.instance.resolveScope(
        patientMrNo: widget.patientMrNo,
      ),
      categoryIndex: _selectedCategoryIndex,
      categoryLabel: categoryLabel,
      report: report,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _buildMaroonLoadingDialog(
        title: request.displayTitle,
        subtitle: 'Generating your report',
      ),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${request.fileName}';

      final dio = ApiConfig.createDio();
      dio.options.connectTimeout = const Duration(seconds: 60);
      dio.options.receiveTimeout = const Duration(seconds: 60);

      final response = await dio.get(
        request.url,
        options: Options(responseType: ResponseType.bytes),
      );

      final contentType = response.headers.value("content-type");
      final bytes = response.data;
      if (!_looksLikePdf(bytes) &&
          (contentType == null || !contentType.contains("application/pdf"))) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        throw Exception("Server did not return a valid PDF");
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _openPDF(filePath, request.fileName);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text("Error generating report: ${e.toString()}")),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _downloadReportRecord(Map<String, dynamic> report) async {
    if (_reportDownloadInProgress) return;

    final request = _resolveReportPdfRequest(report);
    if (request == null) return;

    _reportDownloadInProgress = true;
    try {
      await _downloadReport(request.url, request.fileName, request.displayTitle);
    } finally {
      _reportDownloadInProgress = false;
    }
  }

  _ReportPdfRequest? _resolveReportPdfRequest(Map<String, dynamic> report) {
    final patDiagId =
        report['patDiagId'] ?? report['paT_DIAG_ID'] ?? report['pat_diag_id'];
    final patVisitId = report['patVisitId'] ??
        report['paT_VISIT_ID'] ??
        report['pat_visit_id'] ??
        report['PAT_VISIT_ID'];
    final mappedType =
        (report['type'] ?? report['testType'] ?? report['testtype'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
    final modality = (report['modalityName'] ??
                report['modalitY_NM'] ??
                report['modality'] ??
                '')
            .toString()
            .toUpperCase();

    String reportName = '';
    String rptId = '';
    String parameters = '';

    // Prefer the open screen category so Radiology/Gastro never fall through to Labrpt.
    final categoryDefaults = <int, List<String>>{
      0: ['Labrpt', '19'],
      1: ['GastRpt', '64'],
      2: ['RadRpt', '22'],
      3: ['PRESCRIPTION_A4', '141'],
    };

    final isPrescription = _selectedCategoryIndex == 3 ||
        mappedType == 'PRESCRIPTION' ||
        (patVisitId != null && patDiagId == null);

    if (isPrescription && patVisitId != null) {
      parameters = patVisitId.toString();
      reportName = 'PRESCRIPTION_A4';
      rptId = '141';
    } else if (patDiagId != null) {
      parameters = patDiagId.toString();

      if (_selectedCategoryIndex == 2 ||
          mappedType == 'RADIOLOGY' ||
          mappedType.contains('RAD') ||
          modality.contains('RADIOLOGY') ||
          modality.contains('XRAY') ||
          modality.contains('X-RAY') ||
          modality.contains('MRI') ||
          modality.contains('CT') ||
          modality.contains('ULTRASOUND') ||
          modality.contains('U/S')) {
        reportName = 'RadRpt';
        rptId = '22';
      } else if (_selectedCategoryIndex == 1 ||
          mappedType == 'GASTRO' ||
          mappedType.contains('GASTRO') ||
          mappedType.contains('ENDOSCOPY') ||
          modality.contains('GASTRO')) {
        reportName = 'GastRpt';
        rptId = '64';
      } else if (_selectedCategoryIndex == 0 ||
          mappedType == 'LABORATORY' ||
          mappedType.contains('LAB') ||
          modality.contains('LAB')) {
        reportName = 'Labrpt';
        rptId = '19';
      } else {
        final defaults =
            categoryDefaults[_selectedCategoryIndex] ?? ['Labrpt', '19'];
        reportName = defaults[0];
        rptId = defaults[1];
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot open report: No valid ID found")),
      );
      return null;
    }

    final displayTitle = _reportDisplayTitle(report);
    final safeTitle = displayTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_');
    final fileName = '${safeTitle}_$parameters.pdf';
    final url =
        "${ApiConfig.baseUrl}/api/PatientReport/GenerateReport"
        "?rptId=${Uri.encodeQueryComponent(rptId)}"
        "&reportName=${Uri.encodeQueryComponent(reportName)}"
        "&parameters=${Uri.encodeQueryComponent(parameters)}"
        "&user=MobileApp";

    return _ReportPdfRequest(
      url: url,
      fileName: fileName,
      displayTitle: displayTitle,
    );
  }

  String _reportDisplayTitle(Map<String, dynamic> report) {
    final diagnosticName = report['diagnosticName'] ??
        report['diagnostiC_NAME'] ??
        report['name'];
    if (diagnosticName != null && diagnosticName.toString().trim().isNotEmpty) {
      return diagnosticName.toString().trim();
    }
    return (report['type'] ?? 'Report').toString();
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  PreferredSizeWidget _buildCategoryAppBar(int index) {
    final category = categories[index];
    final categoryName = category['name'] as String;
    final categoryIcon = category['icon'] as IconData;

    return AppAppBar(
      leading: AppAppBar.backButton(context, onPressed: _handleBack),
      title: Text(
        categoryName,
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
            child: Icon(
              categoryIcon,
              color: AppColors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _reportsForCategory(int index) {
    switch (index) {
      case 0:
        return laboratoryReports;
      case 1:
        return gastroReports;
      case 2:
        return radiologyReports;
      case 3:
        return prescriptionReports;
      default:
        return [];
    }
  }

  Widget _buildCategoryDetailScreen(int index) {
    final category = categories[index];
    final categoryName = category['name'] as String;
    final tabColor = category['color'] as Color;
    final bg = category['bg'] as Color;
    final defaultIcon = category['icon'] as IconData;
    final allReports = _reportsForCategory(index);
    final filteredReports = _filteredReportsForCategory(index);
    final searchController = _searchControllerFor(index);
    final filterCount = _categoryFilters[index].activeCount;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: _buildCategoryAppBar(index),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: searchController,
              style: AppTypography.roboto(fontSize: 14, color: AppColors.darkText),
              decoration: InputDecoration(
                hintText: _searchHints[index] ?? 'Search...',
                hintStyle: AppTypography.roboto(
                  fontSize: 13,
                  color: AppColors.greyText.withValues(alpha: 0.8),
                ),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.greyText),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.greyText,
                        onPressed: searchController.clear,
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
                  borderSide: const BorderSide(
                    color: AppColors.primaryRed,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (index == 3) _buildPrescriptionCareSettingChips(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TapFeedback(
                    onTap: () => _showCategoryFilterSheet(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: filterCount > 0
                            ? AppColors.softRed
                            : AppColors.white,
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
                PopupMenuButton<ReportSortOrder>(
                  initialValue: _sortOrders[index],
                  onSelected: (value) =>
                      setState(() => _sortOrders[index] = value),
                  offset: const Offset(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    _sortMenuItem(
                      ReportSortOrder.newestFirst,
                      'Newest First',
                      Icons.arrow_downward_rounded,
                      index,
                    ),
                    _sortMenuItem(
                      ReportSortOrder.oldestFirst,
                      'Oldest First',
                      Icons.arrow_upward_rounded,
                      index,
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
                          _sortLabelFor(index),
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '${filteredReports.length} ${filteredReports.length == 1 ? 'Record' : 'Records'}',
              style: AppTypography.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ),
          Expanded(
            child: _buildReportsList(
              categoryIndex: index,
              allReports: allReports,
              reports: filteredReports,
              categoryName: categoryName,
              tabColor: tabColor,
              bg: bg,
              defaultIcon: defaultIcon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCareSettingChips() {
    final counts = _prescriptionCareSettingCounts();
    final total = prescriptionReports.length;
    final options = <MapEntry<String?, String>>[
      MapEntry(null, 'All'),
      const MapEntry('OPD', 'OPD'),
      const MapEntry('IPD', 'IPD'),
      const MapEntry('Emergency', 'Emergency'),
    ];
    if ((counts['Other'] ?? 0) > 0) {
      options.add(const MapEntry('Other', 'Other'));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _prescriptionCareSettingChip(
                label: options[i].value,
                value: options[i].key,
                count: options[i].key == null
                    ? total
                    : (counts[options[i].key] ?? 0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _prescriptionCareSettingChip({
    required String label,
    required String? value,
    required int count,
  }) {
    final selected = _prescriptionCareSetting == value;
    return TapFeedback(
      onTap: () => setState(() => _prescriptionCareSetting = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryRed : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primaryRed
                : AppColors.fieldBorder,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: AppTypography.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.darkText,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<ReportSortOrder> _sortMenuItem(
    ReportSortOrder value,
    String label,
    IconData icon,
    int index,
  ) {
    final selected = _sortOrders[index] == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppColors.primaryRed : AppColors.greyText,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.roboto(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.primaryRed : AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: _buildCategoryAppBar(_selectedCategoryIndex),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primaryRed,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading reports...',
                style: AppTypography.roboto(
                  color: AppColors.greyText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: _buildCategoryAppBar(_selectedCategoryIndex),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: AppTypography.roboto(
                  color: AppColors.greyText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchAllReports,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
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

    return _buildCategoryDetailScreen(_selectedCategoryIndex);
  }

  Widget _buildReportsList({
    required int categoryIndex,
    required List<Map<String, dynamic>> allReports,
    required List<Map<String, dynamic>> reports,
    required String categoryName,
    required Color tabColor,
    required Color bg,
    required IconData defaultIcon,
  }) {
    if (allReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                defaultIcon,
                size: 56,
                color: AppColors.greyText.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              Text(
                'No reports yet',
                style: AppTypography.raleway(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _emptyMessages[categoryIndex] ??
                    'No $categoryName reports available yet.',
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

    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.greyText,
              ),
              const SizedBox(height: 12),
              Text(
                'No reports match your search or filters',
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
                    _searchControllerFor(categoryIndex).clear();
                    _categoryFilters[categoryIndex] =
                        CategoryReportFilters.empty;
                    _sortOrders[categoryIndex] = ReportSortOrder.newestFirst;
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

    final widgets = <Widget>[];
    String? lastDateKey;
    String? lastTimeKey;

    for (final report in reports) {
      final dt = _parseReportDate(report);
      final dateKey = dt != null
          ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
          : 'unknown';
      final timeKey = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '';

      if (dateKey != lastDateKey) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dt != null ? _formatDateGroupLabel(dt) : 'Unknown date',
                  style: AppTypography.raleway(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: AppColors.fieldBorder.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        );
        lastDateKey = dateKey;
        lastTimeKey = null;
      }

      if (timeKey.isNotEmpty && timeKey != lastTimeKey) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: Text(
              formatTime(report['date'] ?? ''),
              style: AppTypography.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
          ),
        );
        lastTimeKey = timeKey;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ReportRecordCard(
            report: report,
            categoryIndex: categoryIndex,
            categoryName: categoryName,
            tabColor: tabColor,
            bg: bg,
            defaultIcon: defaultIcon,
            formatTime: formatTime,
            onView: () => _openReport(report),
            onDownload: () => _downloadReportRecord(report),
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: widgets,
    );
  }
}

class _ReportRecordCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final int categoryIndex;
  final String categoryName;
  final Color tabColor;
  final Color bg;
  final IconData defaultIcon;
  final String Function(String) formatTime;
  final VoidCallback onView;
  final VoidCallback onDownload;

  const _ReportRecordCard({
    required this.report,
    required this.categoryIndex,
    required this.categoryName,
    required this.tabColor,
    required this.bg,
    required this.defaultIcon,
    required this.formatTime,
    required this.onView,
    required this.onDownload,
  });

  String _displayValue(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text;
  }

  String _formatDateTimeField(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final date = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      if (dt.hour == 0 && dt.minute == 0 && dt.second == 0) {
        return date;
      }
      final time = formatTime(raw);
      return time.isNotEmpty ? '$date · $time' : date;
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPrescription = categoryIndex == 3;
    final isDiagnosticReport = categoryIndex < 3;
    final diagnosticName = _displayValue(
      report['diagnosticName'] ??
          report['diagnostiC_NAME'] ??
          report['name'],
    );
    final modality = _displayValue(
      report['modalityName'] ?? report['modalitY_NM'] ?? report['modality'],
    );
    final department = _displayValue(report['department']);
    final careSetting = _displayValue(
      report['careSetting'] ?? department,
    );
    final doctor = _displayValue(report['doctor']);
    final diagId =
        report['patDiagId'] ?? report['paT_DIAG_ID'] ?? report['pat_diag_id'];
    final visitId = report['paT_VISIT_ID'] ?? report['pat_visit_id'];
    final sampleCollected = _displayValue(
      report['sampleCollectionDate'] ??
          report['dT_SAMPLECOLLECTION'] ??
          report['date'],
    );
    final visitDate = _displayValue(
      report['visiT_DATE'] ?? report['visit_date'] ?? report['date'],
    );
    final categoryLabel = isDiagnosticReport && modality.isNotEmpty
        ? modality
        : isPrescription && careSetting.isNotEmpty
            ? careSetting
            : (report['type'] ?? categoryName).toString();

    final titleText = isPrescription
        ? (diagnosticName.isNotEmpty &&
                diagnosticName.toLowerCase() != 'prescription'
            ? diagnosticName
            : (doctor.isNotEmpty
                ? doctor
                : (careSetting.isNotEmpty ? careSetting : 'Untitled visit')))
        : (diagnosticName.isNotEmpty ? diagnosticName : 'Unknown Test');

    return Container(
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
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    report['icon'] ?? defaultIcon,
                    color: tabColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: AppTypography.raleway(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              categoryLabel,
                              style: AppTypography.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tabColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                Icon(
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
                      if (isDiagnosticReport) ...[
                        if (sampleCollected.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabDetailRow(
                            label: 'Sample collected',
                            value: _formatDateTimeField(sampleCollected),
                          ),
                        ],
                        if (diagId != null &&
                            _displayValue(diagId).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _LabDetailRow(
                            label: 'Diagnosis ID',
                            value: _displayValue(diagId),
                          ),
                        ],
                      ],
                      if (isPrescription) ...[
                        if (visitDate.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabDetailRow(
                            label: 'Visit date',
                            value: _formatDateTimeField(visitDate),
                          ),
                        ],
                        if (doctor.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _LabDetailRow(
                            label: 'Doctor',
                            value: doctor,
                          ),
                        ],
                        if (visitId != null &&
                            _displayValue(visitId).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _LabDetailRow(
                            label: 'Visit ID',
                            value: _displayValue(visitId),
                          ),
                        ],
                      ],
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
                    onTap: onDownload,
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
                    onTap: onView,
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
    );
  }
}

class _LabDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _LabDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: AppTypography.roboto(
            fontSize: 11,
            color: AppColors.greyText,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportFilterSheet extends StatefulWidget {
  final CategoryReportFilters filters;
  final ReportSortOrder sortOrder;
  final List<int> years;
  final List<String> testCategories;
  final String categoryLabel;
  final void Function(CategoryReportFilters filters, ReportSortOrder sortOrder)
      onApply;
  final VoidCallback onClear;

  const _ReportFilterSheet({
    required this.filters,
    required this.sortOrder,
    required this.years,
    required this.testCategories,
    required this.categoryLabel,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_ReportFilterSheet> createState() => _ReportFilterSheetState();
}

class _ReportFilterSheetState extends State<_ReportFilterSheet> {
  late int? _year;
  late String? _testCategory;
  late ReportSortOrder _sortOrder;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _year = widget.filters.year;
    _testCategory = widget.filters.testCategory;
    _sortOrder = widget.sortOrder;
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
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
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
                  'Filter ${widget.categoryLabel}',
                  style: AppTypography.raleway(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRed,
                  ),
                ),
                const SizedBox(height: 20),
                _FilterSectionTitle('Year'),
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
                if (widget.testCategories.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _FilterSectionTitle('Test Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _testCategory == null,
                        onTap: () => setState(() => _testCategory = null),
                      ),
                      ...widget.testCategories.map(
                        (c) => _FilterChip(
                          label: c,
                          selected: _testCategory == c,
                          onTap: () => setState(() => _testCategory = c),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _FilterSectionTitle('Date Range'),
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
                const SizedBox(height: 20),
                _FilterSectionTitle('Sort'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Newest First',
                      selected: _sortOrder == ReportSortOrder.newestFirst,
                      onTap: () => setState(
                        () => _sortOrder = ReportSortOrder.newestFirst,
                      ),
                    ),
                    _FilterChip(
                      label: 'Oldest First',
                      selected: _sortOrder == ReportSortOrder.oldestFirst,
                      onTap: () => setState(
                        () => _sortOrder = ReportSortOrder.oldestFirst,
                      ),
                    ),
                  ],
                ),
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
                        onPressed: () => widget.onApply(
                          CategoryReportFilters(
                            year: _year,
                            testCategory: _testCategory,
                            dateFrom: _dateFrom,
                            dateTo: _dateTo,
                          ),
                          _sortOrder,
                        ),
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