import 'dart:convert';
import 'package:btih_andriod_app/screens/guest_patient_info_screen.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/database_helper.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/doctor_schedule_model.dart';
import '../models/doctors_model.dart';
import '../models/local_appointment.dart';
import '../services/auth_service.dart';
import '../services/doctors_service.dart';
import '../services/appointment_service.dart';
import '../services/booking_service.dart';

class DoctorScheduleScreen extends StatefulWidget {
  final int doctorId;
  final String doctorName;
  final String patientMrNo;
  final String patientName;
  final bool? isForSelf;
  final int departmentId;
  final bool isLoggedIn;
  final bool isRescheduleMode;
  final String? rescheduleAppointmentId;
  final String? rescheduleReason;

  const DoctorScheduleScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.patientMrNo,
    required this.patientName,
    required this.departmentId,
    this.isForSelf,
    this.isLoggedIn = false,
    this.isRescheduleMode = false,
    this.rescheduleAppointmentId,
    this.rescheduleReason,
  });

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

bool _isBookingInProgress = false;
final BookingService _bookingService = BookingService();
final AppointmentService _appointmentService = AppointmentService();

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  final DoctorService _doctorService = DoctorService();
  List<DoctorSchedule> schedules = [];
  List<Doctor> doctors = [];
  bool isLoading = true;
  DoctorSchedule? selectedSchedule;
  late bool _isForSelf;
  final TextEditingController _relativeNameController = TextEditingController();
  final TextEditingController _relativeRelationController = TextEditingController();
  final TextEditingController _relativePhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isForSelf = widget.isForSelf ?? true;
    loadData();
  }

@override
void dispose() {
  _relativeNameController.dispose();
  _relativeRelationController.dispose();
  _relativePhoneController.dispose();
  super.dispose();
}
void loadData() async {
  try {
    final scheduleData = await _doctorService.getDoctorSchedule(widget.doctorId);
    
    // Instead of fetching all doctors, create a basic doctor object from passed data
    final currentDoctor = Doctor(
      serialNumber: 0,
      id: widget.doctorId,
      doctorName: widget.doctorName,
      departmentId: widget.departmentId,
      doctorDescription: "", // You might not have this
      specializationName: "", // You might not have this
      doctorImagePath: null,
    );
    
    // Try to get full doctor details if possible, but use basic one as fallback
    try {
      final doctorsData = await _doctorService.getDoctorsPaginated(pageNumber: 1, pageSize: 100);
      final foundDoctor = doctorsData.data.firstWhere(
        (d) => d.id == widget.doctorId,
        orElse: () => currentDoctor,
      );
      
      setState(() {
        schedules = scheduleData;
        doctors = [foundDoctor];
        isLoading = false;
      });
    } catch (e) {
      // Fallback to basic doctor info
      setState(() {
        schedules = scheduleData;
        doctors = [currentDoctor];
        isLoading = false;
      });
    }
  } catch (e) {
    print("Data Load Error: $e");
    setState(() {
      isLoading = false;
    });
  }
}
  // void loadData() async {
  //   try {
  //     final scheduleData = await _doctorService.getDoctorSchedule(widget.doctorId);
  //     final doctorsData = await _doctorService.getDoctors();
  //     final currentDoctor = doctorsData.where((d) => d.id == widget.doctorId).toList();

  //     setState(() {
  //       schedules = scheduleData;
  //       doctors = currentDoctor;
  //       isLoading = false;
  //     });
  //   } catch (e) {
  //     print("Data Load Error: $e");
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }

  // Modified: Show booking type dialog only when logged in
  void _showBookingTypeDialog() {
    if (!widget.isLoggedIn) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Book Appointment For',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryRed,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Who would you like to book this appointment for?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isForSelf = true;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isForSelf 
                              ? AppColors.primaryRed 
                              : AppColors.primaryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryRed,
                            width: _isForSelf ? 0 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person,
                              color: _isForSelf ? Colors.white : AppColors.primaryRed,
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'For Myself',
                              style: TextStyle(
                                color: _isForSelf ? Colors.white : AppColors.primaryRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isForSelf = false;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isForSelf 
                              ? AppColors.primaryRed 
                              : AppColors.primaryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryRed,
                            width: !_isForSelf ? 0 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group,
                              color: !_isForSelf ? Colors.white : AppColors.primaryRed,
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'For Relative',
                              style: TextStyle(
                                color: !_isForSelf ? Colors.white : AppColors.primaryRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

void _showBookingConfirmationDialog(DoctorSchedule schedule) {
  if (!widget.isLoggedIn && !GuestSession.isComplete) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Please complete patient information first',
          style: AppTypography.roboto(color: AppColors.white),
        ),
        backgroundColor: AppColors.primaryRed,
      ),
    );
    return;
  }

  String bookingFor;
  String patientDisplayName;
  bool isGuestBooking = !widget.isLoggedIn;

  if (isGuestBooking) {
    bookingFor = 'Guest';
    patientDisplayName = GuestSession.displayName;
  } else {
    bookingFor = _isForSelf ? "Yourself" : "Relative";
    patientDisplayName = _isForSelf 
        ? widget.patientName 
        : (_relativeNameController.text.isNotEmpty 
            ? _relativeNameController.text 
            : "Relative of ${widget.patientName}");
  }

  String formattedScheduleForDb = '${schedule.dayName}: ${_formatTimeForDb(schedule.timeFrom)} - ${_formatTimeForDb(schedule.timeTo)}';
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Confirm Appointment',
              style: AppTypography.raleway(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.primaryRed,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appointment Details',
                    style: AppTypography.roboto(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Doctor', widget.doctorName),
                  _buildDetailRow('Day', schedule.dayName),
                  _buildDetailRow(
                    'Time',
                    '${_formatTime(schedule.timeFrom)} - ${_formatTime(schedule.timeTo)}',
                  ),
                  _buildDetailRow('Booking For', bookingFor),
                  
                  // Show guest details if guest booking
                  if (isGuestBooking) ...[
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'Guest Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name', GuestSession.fullName ?? 'Guest'),
                    if ((GuestSession.mobileNumber ?? '').isNotEmpty)
                      _buildDetailRow('Phone', GuestSession.mobileNumber!),
                    if ((GuestSession.dateOfBirth ?? '').isNotEmpty)
                      _buildDetailRow('DOB', _formatGuestDob()),
                    if ((GuestSession.gender ?? '').isNotEmpty)
                      _buildDetailRow('Gender', GuestSession.gender!),
                  ],
                  
                  // Show relative details form if booking for relative (logged in)
                  if (!isGuestBooking && !_isForSelf) ...[
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'Relative Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRelativeTextField(
                      controller: _relativeNameController,
                      label: 'Relative Name *',
                      icon: Icons.person_outline,
                      hintText: 'Enter relative\'s full name',
                    ),
                    const SizedBox(height: 10),
                    _buildRelativeTextField(
                      controller: _relativeRelationController,
                      label: 'Relation',
                      icon: Icons.family_restroom,
                      hintText: 'e.g., Son, Daughter, Father',
                    ),
                    const SizedBox(height: 10),
                    _buildRelativeTextField(
                      controller: _relativePhoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      hintText: 'Enter relative\'s phone number',
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Loading indicator
                  if (_isBookingInProgress)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                        ),
                      ),
                    ),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softRed,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primaryRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please arrive 15 minutes before your appointment time',
                            style: AppTypography.roboto(
                              fontSize: 12,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: _isBookingInProgress
                    ? null
                    : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppTypography.roboto(
                    color: AppColors.greyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                onPressed: _isBookingInProgress
                    ? null
                    : () {
                        if (!isGuestBooking &&
                            !_isForSelf &&
                            !_validateRelativeFields()) {
                          return;
                        }
                        _bookAppointment(
                          schedule,
                          context,
                          setDialogState,
                          formattedScheduleForDb,
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isBookingInProgress
                      ? (widget.isRescheduleMode
                          ? 'Submitting...'
                          : 'Booking...')
                      : (widget.isRescheduleMode
                          ? 'Submit Reschedule Request'
                          : 'Confirm Booking'),
                  style: AppTypography.roboto(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
Widget _buildRelativeTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  String? hintText,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppColors.primaryRed),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
      ),
    ),
  );
}
bool _validateRelativeFields() {
  if (_relativeNameController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter relative name'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
  return true;
}
  // In your BookingService class, add this method:

Future<void> _bookAppointment(
  DoctorSchedule schedule, 
  BuildContext dialogContext, 
  StateSetter setDialogState,
  String formattedScheduleForDb,
) async {
  setDialogState(() {
    _isBookingInProgress = true;
  });

  try {
    if (widget.isRescheduleMode) {
      await _submitRescheduleRequest(
        schedule: schedule,
        dialogContext: dialogContext,
        formattedScheduleForDb: formattedScheduleForDb,
      );
      return;
    }

    String patientNameForBooking;
    String phoneNo;
    String mrNo;
    String purpose;
    String email = "string"; // Default email
    String appointmentId = "";
    String doctorName = schedule.doctorName ?? "Doctor";

    if (!widget.isLoggedIn) {
      patientNameForBooking = GuestSession.fullName ?? 'Guest';
      phoneNo = GuestSession.mobileNumber?.isNotEmpty == true
          ? GuestSession.mobileNumber!
          : '0';
      mrNo = '';
      purpose = "Guest Appointment";
      email = "guest@example.com";
      
       final response = await _bookingService.insertChallan(
        name: patientNameForBooking,
        phoneNo: phoneNo,
        mrno: mrNo,
        email: email,
        weekId: schedule.weekId ?? 0,
        appointmentTime: formattedScheduleForDb,
        status: "Pending",
        doctorId: widget.doctorId,
        departmentId: widget.departmentId,
        purpose: purpose,
        isActive: true,
      );

      // Create a unique appointment ID for guest
      appointmentId = "GUEST_${DateTime.now().millisecondsSinceEpoch}";
      
      // Create local appointment object
      final localAppointment = LocalAppointment(
        appointmentId: appointmentId,
        name: patientNameForBooking,
        phoneNo: phoneNo,
        mrNo: mrNo,
        email: email,
        weekId: schedule.weekId ?? 0,
        appointmentTime: formattedScheduleForDb,
        status: "Pending",
        doctorName: doctorName,
        purpose: purpose,
        createdAt: DateTime.now().toIso8601String(),
        doctorId: widget.doctorId,
        departmentId: widget.departmentId,
        isGuestAppointment: true,
      );
      
      // Save to local database
      await DatabaseHelper().insertAppointment(localAppointment);
      
      Navigator.pop(dialogContext);
      
      // Show success message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Appointment booked successfully!'),
      //     backgroundColor: Colors.green,
      //     duration: Duration(seconds: 2),
      //   ),
      // );
      
      // // Optional: Show a dialog with booking details
      // _showGuestSuccessDialog(localAppointment);
      if (response['message'] != null) {
        _showGuestSuccessDialog(localAppointment);
      } else {
        _showErrorDialog('Failed to book appointment');
      }
      
    } else {
      // Logged in user booking - Save to server
      if (_isForSelf) {
        try {
          final verificationResponse =
              await AuthService().verifyPhoneByMrNo(widget.patientMrNo ?? '');

          final contactNo = verificationResponse['contactNo']?.toString() ??
              verificationResponse['contactno']?.toString();
          if (contactNo != null && contactNo.isNotEmpty) {
            phoneNo = contactNo;
            patientNameForBooking = widget.patientName;
            mrNo = widget.patientMrNo ?? "";
            purpose = "NILL";
          } else {
            throw Exception('MR number not found in response');
          }
        } catch (e) {
          print("Phone verification failed: $e");
          patientNameForBooking = widget.patientName;
          phoneNo = "0";
          mrNo = widget.patientMrNo ?? "";
          purpose = "NILL";
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not verify phone. Using existing data.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        patientNameForBooking = _relativeNameController.text;
        phoneNo = _relativePhoneController.text.isNotEmpty 
            ? _relativePhoneController.text 
            : "0";
        mrNo = widget.patientMrNo ?? "";
        purpose = "Relative Appointment - ${_relativeRelationController.text.isNotEmpty ? _relativeRelationController.text : "Relative"} of ${widget.patientName}";
      }

      // Insert the challan with the collected data
      final response = await _bookingService.insertChallan(
        name: patientNameForBooking,
        phoneNo: phoneNo,
        mrno: mrNo,
        email: email,
        weekId: schedule.weekId ?? 0,
        appointmentTime: formattedScheduleForDb,
        status: "Pending",
        doctorId: widget.doctorId,
        departmentId: widget.departmentId,
        purpose: purpose,
        isActive: true,
      );

      Navigator.pop(dialogContext);

      if (response['message'] != null) {
        if (mrNo.isNotEmpty) {
          await NotificationService.instance.notifyAppointmentConfirmed(
            mrNo: mrNo,
            doctorName: doctorName,
            appointmentTime: formattedScheduleForDb,
          );
        }
        _showSuccessDialog(response['message']);
      } else {
        _showErrorDialog('Failed to book appointment');
      }
    }
  } catch (e) {
    Navigator.pop(dialogContext);
    _showErrorDialog('Error booking appointment: ${e.toString()}');
  } finally {
    setState(() {
      _isBookingInProgress = false;
    });
  }
}

Future<void> _submitRescheduleRequest({
  required DoctorSchedule schedule,
  required BuildContext dialogContext,
  required String formattedScheduleForDb,
}) async {
  final appointmentId = widget.rescheduleAppointmentId?.trim() ?? '';
  final reason = widget.rescheduleReason?.trim() ?? '';

  if (appointmentId.isEmpty || reason.isEmpty) {
    Navigator.pop(dialogContext);
    _showErrorDialog('Reschedule details are incomplete.');
    return;
  }

  if (!widget.isLoggedIn) {
    await DatabaseHelper().updateAppointmentStatus(
      appointmentId: appointmentId,
      status: 'Reschedule Pending',
      purposeAppend:
          '[RESCHEDULE REQUEST: weekId=${schedule.weekId}, time=$formattedScheduleForDb, reason=$reason]',
    );
    Navigator.pop(dialogContext);
    if (mounted) Navigator.pop(context, true);
    return;
  }

  await _appointmentService.requestReschedule(
    appointmentId: appointmentId,
    mrNo: widget.patientMrNo,
    reason: reason,
    weekId: schedule.weekId ?? 0,
    appointmentTime: formattedScheduleForDb,
    doctorId: widget.doctorId,
    departmentId: widget.departmentId,
  );

  Navigator.pop(dialogContext);
  if (mounted) Navigator.pop(context, true);
}

// Add this helper method for guest success dialog
void _showGuestSuccessDialog(LocalAppointment appointment) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Appointment Booked Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${appointment.name}'),
            const SizedBox(height: 8),
            Text('Time: ${appointment.appointmentTime}'),
            const SizedBox(height: 8),
            Text('Doctor: ${appointment.doctorName}'),
            const SizedBox(height: 8),
            Text('Status: ${appointment.status}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: const Text(
                'Note: Your appointment has been saved locally. Please login to sync with server.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}


  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Booking Failed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(errorMessage),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
 
  void _showSuccessDialog([String message = 'Appointment Booked Successfully!']) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your appointment with ${widget.doctorName} has been confirmed.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close success dialog
                    Navigator.pop(context); // Go back to doctors list
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppTypography.roboto(
                color: AppColors.greyText,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.roboto(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  String _formatTimeForDb(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Map<String, List<DoctorSchedule>> groupSchedulesByDay() {
    Map<String, List<DoctorSchedule>> grouped = {};
    
    final dayOrder = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    
    for (var schedule in schedules) {
      if (!grouped.containsKey(schedule.dayName)) {
        grouped[schedule.dayName] = [];
      }
      grouped[schedule.dayName]!.add(schedule);
    }
    
    var sortedKeys = grouped.keys.toList()
      ..sort((a, b) => (dayOrder[a] ?? 0).compareTo(dayOrder[b] ?? 0));
    
    Map<String, List<DoctorSchedule>> sortedGrouped = {};
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key] ?? [];
    }
    
    return sortedGrouped;
  }

  IconData _getDayIcon(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
      case 'tuesday':
      case 'wednesday':
      case 'thursday':
      case 'friday':
        return Icons.wb_sunny_outlined;
      case 'saturday':
        return Icons.weekend_outlined;
      case 'sunday':
        return Icons.bed_outlined;
      default:
        return Icons.calendar_today_outlined;
    }
  }

  bool _isScheduleSelected(DoctorSchedule schedule) {
    if (selectedSchedule == null) return false;
    return selectedSchedule!.serialNumber == schedule.serialNumber &&
        selectedSchedule!.dayName == schedule.dayName &&
        selectedSchedule!.timeFrom == schedule.timeFrom;
  }

  Future<void> _onBookAppointmentPressed() async {
    final schedule = selectedSchedule;
    if (schedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a time slot first',
            style: AppTypography.roboto(color: AppColors.white),
          ),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!widget.isLoggedIn && !GuestSession.isComplete) {
      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const GuestPatientInfoScreen()),
      );
      if (completed != true || !mounted) return;
    }

    _showBookingConfirmationDialog(schedule);
  }

  String _formatGuestDob() {
    final raw = GuestSession.dateOfBirth;
    if (raw == null || raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }

@override
Widget build(BuildContext context) {
  final doctor = doctors.isNotEmpty ? doctors.first : null;
  final groupedSchedules = groupSchedulesByDay();
  final hasSchedule = groupedSchedules.isNotEmpty;

  return Scaffold(
    backgroundColor: AppColors.scaffoldBg,
    appBar: AppBar(
      backgroundColor: AppColors.deepRed,
      foregroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.isRescheduleMode ? 'Reschedule Appointment' : 'Book Appointment',
        style: AppTypography.raleway(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      centerTitle: true,
      bottom: widget.isLoggedIn
          ? PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: TapFeedback(
                onTap: _showBookingTypeDialog,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.deepRed.withValues(alpha: 0.85),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isForSelf ? Icons.person_outline : Icons.group_outlined,
                        color: AppColors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Booking for: ${_isForSelf ? "Yourself" : "Relative"}',
                        style: AppTypography.roboto(
                          color: AppColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_outlined, color: AppColors.white, size: 14),
                    ],
                  ),
                ),
              ),
            )
          : null,
    ),
    bottomNavigationBar: !isLoading && doctor != null && hasSchedule
        ? SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: _onBookAppointmentPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                disabledBackgroundColor: AppColors.lightMaroon,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                selectedSchedule == null
                    ? 'Select a time slot to book'
                    : 'Book Appointment',
                style: AppTypography.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          )
        : null,
    body: isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          )
        : doctor == null
            ? Center(
                child: Text(
                  'Doctor details not found',
                  style: AppTypography.roboto(color: AppColors.greyText),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDoctorHeaderCard(doctor, groupedSchedules),
                    _buildScheduleSectionHeader(groupedSchedules),
                    groupedSchedules.isEmpty
                        ? _buildEmptyState()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: groupedSchedules.entries.map((entry) {
                                return _buildDayScheduleCard(
                                  entry.key,
                                  entry.value,
                                );
                              }).toList(),
                            ),
                          ),
                  ],
                ),
              ),
  );
}

Widget _buildDoctorHeaderCard(
  Doctor doctor,
  Map<String, List<DoctorSchedule>> groupedSchedules,
) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDoctorAvatar(doctor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.doctorName,
                    style: AppTypography.raleway(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  if (doctor.doctorDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      doctor.doctorDescription,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (doctor.specializationName.isNotEmpty)
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
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 18,
                color: AppColors.primaryRed,
              ),
              const SizedBox(width: 8),
              Text(
                'OPD Charges: Rs. ${_getOPDChargesFromSchedules(groupedSchedules)}',
                style: AppTypography.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildDoctorAvatar(Doctor doctor) {
  return Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      color: AppColors.softRed,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.fieldBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: doctor.doctorImagePath != null && doctor.doctorImagePath!.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: doctor.doctorImagePath!,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.person_rounded,
              size: 36,
              color: AppColors.primaryRed,
            ),
          )
        : const Icon(
            Icons.person_rounded,
            size: 36,
            color: AppColors.primaryRed,
          ),
  );
}

Widget _buildScheduleSectionHeader(
  Map<String, List<DoctorSchedule>> groupedSchedules,
) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.softRed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.primaryRed,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Schedule',
                style: AppTypography.raleway(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              Text(
                widget.isLoggedIn
                    ? 'Select a time slot, then tap Book Appointment'
                    : 'Select a slot to book as guest',
                style: AppTypography.roboto(
                  fontSize: 12,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
        if (!widget.isLoggedIn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.softRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Guest',
              style: AppTypography.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryRed,
              ),
            ),
          ),
      ],
    ),
  );
}

// Helper method to get OPD charges from schedules
String _getOPDChargesFromSchedules(Map<String, List<DoctorSchedule>> groupedSchedules) {
  for (var schedules in groupedSchedules.values) {
    if (schedules.isNotEmpty && schedules.first.opD_Charges > 0) {
      return schedules.first.opD_Charges.toString();
    }
  }
  return "N/A";
}
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppColors.softRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                size: 48,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No schedule available',
              style: AppTypography.raleway(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for appointment slots',
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

  Widget _buildDayScheduleCard(String day, List<DoctorSchedule> daySchedules) {
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
            children: [
              Icon(_getDayIcon(day), color: AppColors.primaryRed, size: 18),
              const SizedBox(width: 8),
              Text(
                day,
                style: AppTypography.raleway(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const Spacer(),
              Text(
                '${daySchedules.length} slot${daySchedules.length > 1 ? 's' : ''}',
                style: AppTypography.roboto(
                  fontSize: 11,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: daySchedules.map((schedule) {
              final isSelected = _isScheduleSelected(schedule);
              final timeLabel =
                  '${_formatTime(schedule.timeFrom)} - ${_formatTime(schedule.timeTo)}';

              return TapFeedback(
                onTap: () => setState(() => selectedSchedule = schedule),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryRed : AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryRed
                          : AppColors.fieldBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: isSelected ? AppColors.white : AppColors.primaryRed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeLabel,
                        style: AppTypography.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.white : AppColors.darkText,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
