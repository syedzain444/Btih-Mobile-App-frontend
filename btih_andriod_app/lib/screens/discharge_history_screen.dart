import 'dart:io';

import 'package:btih_andriod_app/services/discharge_history_service.dart';
import 'package:btih_andriod_app/services/discharge_report_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/discharge_history_model.dart';

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
  
  List<DischargeRecord> dischargeRecords = [];
  bool isLoading = true;
  bool isGeneratingReport = false;
  bool hasMoreData = true;
  int currentPage = 1;
  final int pageSize = 10;
  int totalRecords = 0;
  
  final Color primaryColor = const Color(0xFF1FC9C0);
  
  @override
  void initState() {
    super.initState();
    loadDischargeHistory();
  }
  
  Future<void> loadDischargeHistory({bool loadMore = false}) async {
    if (loadMore && !hasMoreData) return;
    if (loadMore) currentPage++;
    
    setState(() {
      if (!loadMore) {
        isLoading = true;
      }
    });
    
    try {
      final response = await _historyService.getDischargeHistory(
        mrNo: widget.patientMrNo,
        pageNumber: currentPage,
        pageSize: pageSize,
      );
      
      totalRecords = response.totalRecords;
      
      setState(() {
        if (loadMore) {
          dischargeRecords.addAll(response.data);
        } else {
          dischargeRecords = response.data;
        }
        hasMoreData = dischargeRecords.length < totalRecords;
        isLoading = false;
      });
    } catch (e) {
      print('Discharge History Error: $e');
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading discharge history: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  Future<void> generateDischargeReport(DischargeRecord record) async {
    setState(() {
      isGeneratingReport = true;
    });
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 2,
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
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF1FC9C0),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Generating Discharge Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1FC9C0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please wait...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      // Generate the report
      final response = await _reportService.generateDischargeReport(
        patientVisitId: record.patienT_VISIT_ID,
        empId: 82,
        rptId: 35,
      );
      
      // Save PDF
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Discharge_Visit_${record.patienT_VISIT_ID}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(response.data, flush: true);
      
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (!mounted) return;
      
      // Open PDF
      _openPDF(filePath, fileName, record);
      
    } catch (e) {
      print('Report generation error: $e');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text("Error: ${e.toString()}")),
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
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingReport = false;
        });
      }
    }
  }
  
  void _openPDF(String filePath, String fileName, DischargeRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              'Discharge Report - Visit #${record.patienT_VISIT_ID}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            backgroundColor: primaryColor,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  _sharePDF(filePath, fileName);
                },
              ),
            ],
          ),
          body: SfPdfViewer.file(
            File(filePath),
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
  
  String formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Discharge History',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              'MR No: ${widget.patientMrNo}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1FC9C0)),
                  ),
                )
              : dischargeRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Discharge Records',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No discharge history found for this patient',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        currentPage = 1;
                        hasMoreData = true;
                        await loadDischargeHistory();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        controller: ScrollController()..addListener(() {
                          if (ScrollController().position.pixels >= 
                              ScrollController().position.maxScrollExtent - 200) {
                            if (hasMoreData && !isLoading) {
                              loadDischargeHistory(loadMore: true);
                            }
                          }
                        }),
                        itemCount: dischargeRecords.length + (hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == dischargeRecords.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1FC9C0)),
                                ),
                              ),
                            );
                          }
                          
                          final record = dischargeRecords[index];
                          return GestureDetector(
                            onTap: () => generateDischargeReport(record),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Row
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.local_hospital,
                                          color: Color(0xFF1FC9C0),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Visit #${record.patienT_VISIT_ID}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Doctor: ${record.doctoR_NAME}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              record.stayDuration,
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Check-in Details
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.login,
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Check In',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${record.formattedCheckInDate} at ${record.formattedCheckInTime}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 8),
                                  
                                  // Discharge Details
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.logout,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Discharged On',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${record.formattedDischargeDate} at ${record.formattedDischargeTime}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Admission Officer
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 14,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Admission Officer: ${record.admissioN_OFFICER}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Generate Button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: TextButton.icon(
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                            color: Color(0xFF1FC9C0),
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'View Discharge Report',
                                            style: TextStyle(
                                              color: Color(0xFF1FC9C0),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          onPressed: () => generateDischargeReport(record),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          
          // Loading overlay for report generation
          if (isGeneratingReport)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1FC9C0)),
                        ),
                        SizedBox(height: 16),
                        Text('Generating Discharge Report...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}