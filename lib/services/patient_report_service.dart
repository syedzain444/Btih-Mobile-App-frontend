import 'package:btih_andriod_app/models/patient_report_model.dart';
import 'package:btih_andriod_app/services/billing_service.dart';

class PatientReportService {
  final BillingService _billingService = BillingService();

  Future<List<PatientReport>> getPatientReportHistory(String mrNo) async {
    try {
      final history = await _billingService.getHistory(mrNo);
      return history.items;
    } catch (e) {
      print('Error loading patient report history: $e');
      rethrow;
    }
  }
}
