// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:btih_andriod_app/models/patient_model.dart';

// class PatientService {
//   static const String baseUrl = "http://your-api-url/api";

//   Future<Patient> getPatient(String mrNo) async {
//     final response = await http.get(Uri.parse('$baseUrl/patients/$mrNo'));
//     if (response.statusCode == 200) {
//       return Patient.fromJson(jsonDecode(response.body));
//     } else {
//       throw Exception("Failed to load patient");
//     }
//   }
// }