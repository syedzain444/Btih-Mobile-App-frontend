import 'dart:convert';
import 'dart:io';
import 'package:btih_andriod_app/models/bill_category_model.dart';
import 'package:http/io_client.dart';

class BillCategoryService {
  static const String baseUrl =
      //"http://localhost:7107/api/BillData";
      //"https://10.0.2.2:7107/api/BillData";
      "https://172.16.40.56:80/api/BillData";
      

  Future<List<BillCategory>> getBillCategories() async {

    HttpClient client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    IOClient ioClient = IOClient(client);

    final response = await ioClient.get(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((e) => BillCategory.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load bill categories");
    }
  }
}


// class BillCategoryService {
//   static const String baseUrl = "https://10.0.2.2:7107/api/BillData";

//   Future<List<BillCategory>> getBillCategories() async {
//     final response = await http.get(Uri.parse(baseUrl));
//     if (response.statusCode == 200) {
//       List data = jsonDecode(response.body);
//       return data.map((e) => BillCategory.fromJson(e)).toList();
//     } else {
//       throw Exception("Failed to load bill categories");
//     }
//   }
// }
