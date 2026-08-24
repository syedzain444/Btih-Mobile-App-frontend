import 'dart:convert';
import 'package:btih_andriod_app/models/local_appointment.dart';
import 'package:btih_andriod_app/utils/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/doctor_schedule_model.dart';
import '../models/doctors_model.dart';
import '../services/doctors_service.dart';
import '../services/booking_service.dart';

class DoctorScheduleScreen extends StatefulWidget {
  final int doctorId;
  final String doctorName;
  final String patientMrNo;
  final String patientName;
  final bool? isForSelf;
  final int departmentId;
  final bool isLoggedIn;

  const DoctorScheduleScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.patientMrNo,
    required this.patientName,
    required this.departmentId,
    this.isForSelf,
    this.isLoggedIn = false,
  });

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

bool _isBookingInProgress = false;
final BookingService _bookingService = BookingService();

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  final DoctorService _doctorService = DoctorService();
  List<DoctorSchedule> schedules = [];
  List<Doctor> doctors = [];
  bool isLoading = true;
  DoctorSchedule? selectedSchedule;
  late bool _isForSelf;
  bool _guestDetailsEntered = false;

  // Controllers for guest/relative details
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestPhoneController = TextEditingController();
// Add these controllers at the class level with other controllers
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
  _guestNameController.dispose();
  _guestPhoneController.dispose();
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
    if (!widget.isLoggedIn) {
      // If not logged in, directly show guest booking form
      _showGuestBookingDialog();
      return;
    }

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
              color: Color(0xFF1FC9C0),
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
                              ? const Color(0xFF1FC9C0) 
                              : const Color(0xFF1FC9C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF1FC9C0),
                            width: _isForSelf ? 0 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person,
                              color: _isForSelf ? Colors.white : const Color(0xFF1FC9C0),
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'For Myself',
                              style: TextStyle(
                                color: _isForSelf ? Colors.white : const Color(0xFF1FC9C0),
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
                              ? const Color(0xFF1FC9C0) 
                              : const Color(0xFF1FC9C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF1FC9C0),
                            width: !_isForSelf ? 0 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group,
                              color: !_isForSelf ? Colors.white : const Color(0xFF1FC9C0),
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'For Relative',
                              style: TextStyle(
                                color: !_isForSelf ? Colors.white : const Color(0xFF1FC9C0),
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
Future<bool> _showGuestBookingDialog() async {
  // Reset guest details
  _guestNameController.clear();
  _guestPhoneController.clear();
  _guestDetailsEntered = false;
  
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Book as Guest',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1FC9C0),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FC9C0).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF1FC9C0),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please enter your details to continue with guest booking:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _guestNameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1FC9C0)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {}); // Rebuild to update UI if needed
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _guestPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your phone number',
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF1FC9C0)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {}); // Rebuild to update UI if needed
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_guestNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your name'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  // Store that guest details are entered
                  _guestDetailsEntered = true;
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FC9C0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  ) ?? false; // Return false if dialog is dismissed
}
 
void _showBookingConfirmationDialog(DoctorSchedule schedule) {
  // Validate guest details for non-logged in users
  if (!widget.isLoggedIn && _guestNameController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter guest details first'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  String bookingFor;
  String patientDisplayName;
  bool isGuestBooking = !widget.isLoggedIn;

  if (isGuestBooking) {
    bookingFor = "Guest";
    patientDisplayName = _guestNameController.text.isNotEmpty 
        ? _guestNameController.text 
        : "Guest";
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Confirm Appointment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1FC9C0),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appointment Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Doctor:', widget.doctorName),
                  _buildDetailRow('Day:', schedule.dayName),
                  _buildDetailRow('Time:', '${_formatTime(schedule.timeFrom)} - ${_formatTime(schedule.timeTo)}'),
                  _buildDetailRow('Booking For:', bookingFor),
                  
                  // Show guest details if guest booking
                  if (isGuestBooking) ...[
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'Guest Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1FC9C0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name:', _guestNameController.text),
                    if (_guestPhoneController.text.isNotEmpty)
                      _buildDetailRow('Phone:', _guestPhoneController.text),
                  ],
                  
                  // Show relative details form if booking for relative (logged in)
                  if (!isGuestBooking && !_isForSelf) ...[
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'Relative Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1FC9C0),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1FC9C0)),
                        ),
                      ),
                    ),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FC9C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF1FC9C0),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please arrive 15 minutes before your appointment time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isBookingInProgress 
                    ? null
                    : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: _isBookingInProgress
                    ? null
                    : () {
                        // Validate relative fields if booking for relative (logged in)
                        if (!isGuestBooking && !_isForSelf && !_validateRelativeFields()) {
                          return;
                        }
                        _bookAppointment(schedule, context, setDialogState, formattedScheduleForDb);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FC9C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(_isBookingInProgress ? 'Booking...' : 'Confirm Booking'),
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
      prefixIcon: Icon(icon, color: const Color(0xFF1FC9C0)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1FC9C0), width: 2),
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
    String patientNameForBooking;
    String phoneNo;
    String mrNo;
    String purpose;
    String email = "string"; // Default email
    String appointmentId = "";
    String doctorName = schedule.doctorName ?? "Doctor";

    if (!widget.isLoggedIn) {
      // Guest booking - Save to local storage
      patientNameForBooking = _guestNameController.text;
      phoneNo = _guestPhoneController.text.isNotEmpty ? _guestPhoneController.text : "0";
      mrNo = ""; // Empty MR No for guest
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
          final verificationResponse = await verifyPhoneNumber(widget.patientMrNo);
          
          if (verificationResponse['contactno'] != null) {
            phoneNo = verificationResponse['contactno'];
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


Future<Map<String, dynamic>> verifyPhoneNumber(String mrno) async {
  try {
    final response = await http.post(
      Uri.parse('http://172.16.40.10:8080/api/Auth/verifyPhoneNo?mrno=$mrno'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to verify phone number');
    }
  } catch (e) {
    throw Exception('Error verifying phone: $e');
  }
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
                backgroundColor: const Color(0xFF1FC9C0),
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
                  color: Color(0xFF1FC9C0),
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
                    backgroundColor: const Color(0xFF1FC9C0),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const Text(
            ':',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
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
        return Icons.wb_sunny;
      case 'saturday':
        return Icons.weekend;
      case 'sunday':
        return Icons.bed;
      default:
        return Icons.calendar_today;
    }
  }
@override
Widget build(BuildContext context) {
  final doctor = doctors.isNotEmpty ? doctors.first : null;
  final groupedSchedules = groupSchedulesByDay();

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(
        "Book Appointment",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF1FC9C0),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      // Show booking type bar only when logged in
      bottom: widget.isLoggedIn
          ? PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: GestureDetector(
                onTap: _showBookingTypeDialog,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isForSelf ? Icons.person : Icons.group,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Booking for: ${_isForSelf ? "Yourself" : "Relative"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    ),
    body: isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1FC9C0)),
            ),
          )
        : doctor == null
            ? const Center(child: Text("Doctor details not found"))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Profile Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FC9C0),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1FC9C0).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: doctor.doctorImagePath != null && 
                                         doctor.doctorImagePath!.isNotEmpty
                                      ? Image.network(
                                          doctor.doctorImagePath!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              color: Colors.white,
                                              child: const Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Color(0xFF1FC9C0),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.white,
                                              child: const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Color(0xFF1FC9C0),
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.white,
                                          child: const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Color(0xFF1FC9C0),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                doctor.doctorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  doctor.specializationName ?? 'General Doctor',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (doctor.doctorDescription.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    doctor.doctorDescription,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              // Add OPD Charges after description
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 6),
                                    Text(
                                      'OPD Charges: ${_getOPDChargesFromSchedules(groupedSchedules)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Schedule Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FC9C0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Color(0xFF1FC9C0),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Weekly Schedule',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.isLoggedIn 
                                      ? 'Tap on a time slot to book'
                                      : 'Book as guest - Tap to continue',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Guest indicator
                          if (!widget.isLoggedIn)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Guest',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Schedule Cards
                    groupedSchedules.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: groupedSchedules.length,
                            itemBuilder: (context, index) {
                              final day = groupedSchedules.keys.elementAt(index);
                              final daySchedules = groupedSchedules[day]!;
                              
                              return _buildDayScheduleCard(day, daySchedules);
                            },
                          ),
                    
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
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
            Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No schedule available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for appointment slots',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayScheduleCard(String day, List<DoctorSchedule> daySchedules) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1FC9C0).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getDayIcon(day),
                  color: const Color(0xFF1FC9C0),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  day,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1FC9C0),
                  ),
                ),
                const Spacer(),
                Text(
                  '${daySchedules.length} slot${daySchedules.length > 1 ? 's' : ''}',
              
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: daySchedules.length,
            separatorBuilder: (_, _) => const Divider(
              height: 16,
              thickness: 1,
              indent: 8,
              endIndent: 8,
            ),
            itemBuilder: (context, slotIndex) {
              final schedule = daySchedules[slotIndex];
              return InkWell(
                onTap: () async {
  if (!widget.isLoggedIn) {
    // If not logged in, first show guest details form and wait for result
    final guestDetailsConfirmed = await _showGuestBookingDialog();
    if (guestDetailsConfirmed && mounted) {
      // After guest details are entered, show confirmation
      _showBookingConfirmationDialog(schedule);
    }
  } else {
    _showBookingConfirmationDialog(schedule);
  }
},
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1FC9C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.access_time,
                          color: Color(0xFF1FC9C0),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_formatTime(schedule.timeFrom)} - ${_formatTime(schedule.timeTo)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isLoggedIn ? 'Tap to book' : 'Tap to book as guest',
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.isLoggedIn 
                                    ? const Color(0xFF1FC9C0)
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Available',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
