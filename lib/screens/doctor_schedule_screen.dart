import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/database_helper.dart';
import 'package:btih_andriod_app/utils/doctor_image_helper.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/appointment_booking_success_sheet.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/doctor_schedule_model.dart';
import '../models/doctors_model.dart';
import '../models/local_appointment.dart';
import '../services/auth_service.dart';
import '../services/doctors_service.dart';
import '../services/appointment_service.dart';
import '../services/booking_service.dart';
import 'package:btih_andriod_app/screens/guest_patient_info_screen.dart';
import 'package:btih_andriod_app/services/guest_service.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/services/notification_service.dart';

class DoctorScheduleScreen extends StatefulWidget {
  final Doctor doctor;
  final String patientMrNo;
  final String patientName;
  final bool? isForSelf;
  final bool isLoggedIn;
  final bool isRescheduleMode;
  final String? rescheduleAppointmentId;
  final String? rescheduleReason;

  const DoctorScheduleScreen({
    super.key,
    required this.doctor,
    required this.patientMrNo,
    required this.patientName,
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

  Future<void> loadData() async {
    try {
      final scheduleData =
          await _doctorService.getDoctorSchedule(widget.doctor.id);
      if (!mounted) return;
      setState(() {
        schedules = scheduleData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Schedule load error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

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
                  _buildDetailRow('Doctor', widget.doctor.doctorName),
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
        doctorId: widget.doctor.id,
        departmentId: widget.doctor.departmentId,
        purpose: purpose,
        isActive: true,
      );

      // Persist in GUEST_APPOINTMENT (mobile portal DB) — source of truth for guest list.
      final hmisAppointmentId = response['appointmentId']?.toString() ??
          response['AppointmentId']?.toString();
      appointmentId = "GUEST_${DateTime.now().millisecondsSinceEpoch}";
      try {
        final guestSaved = await GuestService().bookAppointment(
          mobileNumber: phoneNo,
          fullName: patientNameForBooking,
          doctorId: widget.doctor.id,
          doctorName: doctorName,
          departmentId: widget.doctor.departmentId,
          weekId: schedule.weekId,
          guestId: GuestSession.guestId,
          appointmentTime: formattedScheduleForDb,
          status: 'Pending',
          purpose: purpose,
          hmisAppointmentId: hmisAppointmentId,
        );
        final serverId = guestSaved['appointmentId']?.toString() ??
            guestSaved['guestAppointmentId']?.toString();
        if (serverId != null && serverId.isNotEmpty) {
          appointmentId = serverId;
        }
      } catch (e) {
        debugPrint('Guest appointment DB save failed: $e');
      }

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
        doctorId: widget.doctor.id,
        departmentId: widget.doctor.departmentId,
        isGuestAppointment: true,
      );
      
      // Save to local database as cache
      await DatabaseHelper().insertAppointment(localAppointment);
      
      Navigator.pop(dialogContext);
      
      if (response['message'] != null) {
        final confirmationQr = _asStringKeyedMap(response['confirmationQr']) ??
            _asStringKeyedMap(response['ConfirmationQr']);
        await AppointmentBookingSuccessSheet.show(
          context,
          patientName: patientNameForBooking,
          doctorName: doctorName,
          appointmentTime: formattedScheduleForDb,
          status: 'Pending',
          appointmentId: hmisAppointmentId,
          mrNo: mrNo.isEmpty ? null : mrNo,
          phone: phoneNo,
          departmentHint: widget.doctor.specializationName,
          purpose: purpose,
          confirmationQr: confirmationQr,
          popTwiceOnDone: false,
        );
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
        doctorId: widget.doctor.id,
        departmentId: widget.doctor.departmentId,
        purpose: purpose,
        isActive: true,
      );

      Navigator.pop(dialogContext);

      if (response['message'] != null) {
        final confirmationAppointmentId =
            response['appointmentId']?.toString() ??
                response['AppointmentId']?.toString();
        final confirmationQr = _asStringKeyedMap(response['confirmationQr']) ??
            _asStringKeyedMap(response['ConfirmationQr']);
        if (mrNo.isNotEmpty) {
          await NotificationService.instance.notifyAppointmentConfirmed(
            mrNo: mrNo,
            doctorName: doctorName,
            appointmentTime: formattedScheduleForDb,
          );
        }
        await AppointmentBookingSuccessSheet.show(
          context,
          patientName: patientNameForBooking,
          doctorName: doctorName,
          appointmentTime: formattedScheduleForDb,
          status: 'Pending',
          appointmentId: confirmationAppointmentId,
          mrNo: mrNo.isEmpty ? null : mrNo,
          phone: phoneNo,
          departmentHint: widget.doctor.specializationName,
          purpose: purpose,
          confirmationQr: confirmationQr,
          popTwiceOnDone: true,
        );
      } else {
        _showErrorDialog('Failed to book appointment');
      }
    }
  } catch (e) {
    Navigator.pop(dialogContext);
    final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    _showErrorDialog(message.isEmpty ? 'Booking failed. Please try again.' : message);
  } finally {
    setState(() {
      _isBookingInProgress = false;
    });
  }
}

Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return null;
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
    doctorId: widget.doctor.id,
    departmentId: widget.doctor.departmentId,
  );

  Navigator.pop(dialogContext);
  if (mounted) Navigator.pop(context, true);
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
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatTimeForDb(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Map<String, List<DoctorSchedule>> groupSchedulesByDay() {
    final grouped = <String, List<DoctorSchedule>>{};
    const dayOrder = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };

    for (final schedule in schedules) {
      if (!schedule.hasValidTimes || schedule.dayName.trim().isEmpty) {
        continue;
      }
      grouped.putIfAbsent(schedule.dayName, () => []).add(schedule);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => (dayOrder[a] ?? 99).compareTo(dayOrder[b] ?? 99));

    final sortedGrouped = <String, List<DoctorSchedule>>{};
    for (final key in sortedKeys) {
      final daySlots = List<DoctorSchedule>.from(grouped[key]!)
        ..sort((a, b) => a.timeFrom.compareTo(b.timeFrom));
      sortedGrouped[key] = daySlots;
    }

    return sortedGrouped;
  }

  /// Builds compact schedule windows from the doctor's actual API slots.
  /// Only days/timings present in the schedule are returned — no generic Mon–Sun calendar.
  List<_DoctorScheduleWindow> buildScheduleWindows() {
    final grouped = groupSchedulesByDay();
    final windows = <_DoctorScheduleWindow>[];

    for (final entry in grouped.entries) {
      final daySlots = entry.value;
      if (daySlots.isEmpty) continue;

      var current = <DoctorSchedule>[daySlots.first];

      for (var i = 1; i < daySlots.length; i++) {
        final prev = current.last;
        final next = daySlots[i];
        final gapMinutes = next.timeFrom.difference(prev.timeTo).inMinutes;
        // Split into a new window when there is a real break between slots.
        if (gapMinutes > 1) {
          windows.add(_DoctorScheduleWindow.fromSlots(entry.key, current));
          current = <DoctorSchedule>[next];
        } else {
          current.add(next);
        }
      }

      if (current.isNotEmpty) {
        windows.add(_DoctorScheduleWindow.fromSlots(entry.key, current));
      }
    }

    return windows;
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
  final doctor = widget.doctor;
  final groupedSchedules = groupSchedulesByDay();
  final hasSchedule = groupedSchedules.isNotEmpty;

  return Scaffold(
    backgroundColor: AppColors.white,
    appBar: AppAppBar(
      title: Text(
        widget.isRescheduleMode ? 'Reschedule Appointment' : 'Book Appointment',
        style: AppTypography.raleway(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      centerTitle: true,
      actions: const [
        AppBarIconBadge(icon: Icons.calendar_month_outlined),
      ],
    ),
    bottomNavigationBar: !isLoading && hasSchedule
        ? Builder(
            builder: (context) {
              final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
              return Material(
                color: AppColors.white,
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    16 + bottomInset,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _onBookAppointmentPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepRed,
                        disabledBackgroundColor: AppColors.deepRed,
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        selectedSchedule == null
                            ? 'Choose Appointment Time'
                            : 'Book Appointment',
                        textAlign: TextAlign.center,
                        style: AppTypography.raleway(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          )
        : null,
    body: isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          )
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDoctorHeaderCard(context, doctor, groupedSchedules),
                _buildScheduleSectionHeader(),
                groupedSchedules.isEmpty
                    ? _buildEmptyState()
                    : _buildSchedulePanel(groupedSchedules),
              ],
            ),
          ),
  );
}

Widget _buildDoctorHeaderCard(
  BuildContext context,
  Doctor doctor,
  Map<String, List<DoctorSchedule>> groupedSchedules,
) {
  final avatarSize =
      (MediaQuery.sizeOf(context).width * 0.28).clamp(96.0, 118.0);

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    child: Column(
      children: [
        _buildDoctorAvatar(doctor, diameter: avatarSize),
        const SizedBox(height: 14),
        Text(
          doctor.doctorName,
          textAlign: TextAlign.center,
          style: AppTypography.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
            height: 1.25,
          ),
        ),
        if (doctor.doctorDescription.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            doctor.doctorDescription,
            textAlign: TextAlign.center,
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.greyText,
              height: 1.35,
            ),
          ),
        ],
        if (doctor.specializationName.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.softRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              doctor.specializationName,
              textAlign: TextAlign.center,
              style: AppTypography.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.deepRed,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _buildOpdChargesRow(groupedSchedules),
      ],
    ),
  );
}

Widget _buildOpdChargesRow(Map<String, List<DoctorSchedule>> groupedSchedules) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 10),
      Text(
        'OPD Charges',
        style: AppTypography.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.greyText,
        ),
      ),
      const SizedBox(width: 12),
      Container(width: 1, height: 22, color: AppColors.fieldBorder),
      const SizedBox(width: 12),
      _buildOpdChargesText(groupedSchedules),
    ],
  );
}

Widget _buildOpdChargesText(Map<String, List<DoctorSchedule>> groupedSchedules) {
  final amount = _getOPDChargesAmount(groupedSchedules);
  final style = AppTypography.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.deepRed,
  );

  if (amount == null) return Text('N/A', style: style);

  final formatted = amount.round().abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  return Text('Rs $formatted', style: style);
}

Widget _buildDoctorAvatar(
  Doctor doctor, {
  required double diameter,
}) {
  final resolvedUrl = DoctorImageHelper.resolve(doctor.doctorImagePath);
  final hasImage = resolvedUrl != null && resolvedUrl.isNotEmpty;
  final fallbackIconSize = diameter * 0.42;

  return Builder(
    builder: (context) {
      final cachePx = (diameter * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(96, 320);

      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.16),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: resolvedUrl,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  memCacheWidth: cachePx,
                  memCacheHeight: cachePx,
                  fadeInDuration: const Duration(milliseconds: 120),
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, __) => Center(
                    child: SizedBox(
                      width: diameter * 0.28,
                      height: diameter * 0.28,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    size: fallbackIconSize,
                    color: AppColors.greyText.withValues(alpha: 0.55),
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: fallbackIconSize,
                  color: AppColors.greyText.withValues(alpha: 0.55),
                ),
        ),
      );
    },
  );
}

Widget _buildScheduleSectionHeader() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Doctor's Schedule",
                style: AppTypography.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap a schedule to choose an appointment time',
                style: AppTypography.roboto(
                  fontSize: 12,
                  color: AppColors.greyText,
                  height: 1.35,
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
                color: AppColors.deepRed,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _buildSchedulePanel(Map<String, List<DoctorSchedule>> groupedSchedules) {
  // groupedSchedules keeps the empty-state gate in build(); windows are
  // derived from the same API source of truth.
  final windows = buildScheduleWindows();
  if (windows.isEmpty || groupedSchedules.isEmpty) return _buildEmptyState();

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < windows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildScheduleWindowRow(windows[i]),
        ],
        if (selectedSchedule != null) ...[
          const SizedBox(height: 14),
          _buildSelectedSlotSummary(),
        ],
      ],
    ),
  );
}

Widget _buildScheduleWindowRow(_DoctorScheduleWindow window) {
  final isActive = selectedSchedule != null &&
      window.contains(selectedSchedule!);
  final slotLabel =
      '${window.slotCount} slot${window.slotCount == 1 ? '' : 's'}';
  final rangeLabel =
      '${_formatTime(window.windowStart)} – ${_formatTime(window.windowEnd)}';

  return TapFeedback(
    onTap: () => _openTimePickerSheet(window),
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.softRed : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.deepRed.withValues(alpha: 0.55)
              : AppColors.fieldBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: isActive ? AppColors.deepRed : AppColors.primaryRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  window.dayName,
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rangeLabel,
                  style: AppTypography.roboto(
                    fontSize: 12.5,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                slotLabel,
                style: AppTypography.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.deepRed : AppColors.greyText,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 2),
                Text(
                  '${_formatTime(selectedSchedule!.timeFrom)}',
                  style: AppTypography.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRed,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: isActive ? AppColors.deepRed : AppColors.primaryRed,
          ),
        ],
      ),
    ),
  );
}

Widget _buildSelectedSlotSummary() {
  final schedule = selectedSchedule;
  if (schedule == null) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.blush,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.deepRed,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${schedule.dayName} · ${_formatTime(schedule.timeFrom)} – ${_formatTime(schedule.timeTo)}',
            style: AppTypography.roboto(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _openTimePickerSheet(_DoctorScheduleWindow window) async {
  final picked = await showModalBottomSheet<DoctorSchedule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      return _AppointmentTimePickerSheet(
        dayName: window.dayName,
        windowLabel:
            '${_formatTime(window.windowStart)} – ${_formatTime(window.windowEnd)}',
        slots: window.slots,
        selected: selectedSchedule,
        formatTime: _formatTime,
      );
    },
  );

  if (picked == null || !mounted) return;
  setState(() => selectedSchedule = picked);
}

double? _getOPDChargesAmount(Map<String, List<DoctorSchedule>> groupedSchedules) {
  for (var daySchedules in groupedSchedules.values) {
    if (daySchedules.isNotEmpty && daySchedules.first.opD_Charges > 0) {
      return daySchedules.first.opD_Charges.toDouble();
    }
  }
  return null;
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
}

class _DoctorScheduleWindow {
  final String dayName;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<DoctorSchedule> slots;

  const _DoctorScheduleWindow({
    required this.dayName,
    required this.windowStart,
    required this.windowEnd,
    required this.slots,
  });

  int get slotCount => slots.length;

  factory _DoctorScheduleWindow.fromSlots(
    String dayName,
    List<DoctorSchedule> slots,
  ) {
    final ordered = List<DoctorSchedule>.from(slots)
      ..sort((a, b) => a.timeFrom.compareTo(b.timeFrom));
    return _DoctorScheduleWindow(
      dayName: dayName,
      windowStart: ordered.first.timeFrom,
      windowEnd: ordered.last.timeTo,
      slots: ordered,
    );
  }

  bool contains(DoctorSchedule schedule) {
    return slots.any(
      (slot) =>
          slot.serialNumber == schedule.serialNumber &&
          slot.dayName == schedule.dayName &&
          slot.timeFrom == schedule.timeFrom,
    );
  }
}

class _AppointmentTimePickerSheet extends StatefulWidget {
  final String dayName;
  final String windowLabel;
  final List<DoctorSchedule> slots;
  final DoctorSchedule? selected;
  final String Function(DateTime) formatTime;

  const _AppointmentTimePickerSheet({
    required this.dayName,
    required this.windowLabel,
    required this.slots,
    required this.selected,
    required this.formatTime,
  });

  @override
  State<_AppointmentTimePickerSheet> createState() =>
      _AppointmentTimePickerSheetState();
}

class _AppointmentTimePickerSheetState
    extends State<_AppointmentTimePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DoctorSchedule> get _filteredSlots {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.slots;
    return widget.slots.where((slot) {
      final label =
          '${widget.formatTime(slot.timeFrom)} - ${widget.formatTime(slot.timeTo)}'
              .toLowerCase();
      return label.contains(q);
    }).toList();
  }

  bool _isSelected(DoctorSchedule schedule) {
    final selected = widget.selected;
    if (selected == null) return false;
    return selected.serialNumber == schedule.serialNumber &&
        selected.dayName == schedule.dayName &&
        selected.timeFrom == schedule.timeFrom;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final filtered = _filteredSlots;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.fieldBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Time',
                          style: AppTypography.raleway(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.dayName} · ${widget.windowLabel} · ${widget.slots.length} slots',
                          style: AppTypography.roboto(
                            fontSize: 12.5,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: AppTypography.roboto(
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
                decoration: InputDecoration(
                  hintText: 'Search time (e.g. 2:30 PM)',
                  hintStyle: AppTypography.roboto(
                    fontSize: 14,
                    color: AppColors.greyText,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryRed,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    //borderSide: BorderSide.none,
                    borderSide: const BorderSide(
                      color: AppColors.hairline,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    //borderSide: BorderSide.none,
                    borderSide: const BorderSide(
                      color: AppColors.hairline,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.deepRed,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching time slots',
                        style: AppTypography.roboto(
                          fontSize: 14,
                          color: AppColors.greyText,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: AppColors.hairline,
                      ),
                      itemBuilder: (context, index) {
                        final schedule = filtered[index];
                        final isSelected = _isSelected(schedule);
                        final label =
                            '${widget.formatTime(schedule.timeFrom)} - ${widget.formatTime(schedule.timeTo)}';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pop(context, schedule),
                          leading: Icon(
                            Icons.access_time_rounded,
                            color: isSelected
                                ? AppColors.deepRed
                                : AppColors.primaryRed,
                            size: 20,
                          ),
                          title: Text(
                            label,
                            style: AppTypography.roboto(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: AppColors.darkText,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.deepRed,
                                  size: 22,
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primaryRed,
                                  size: 22,
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
