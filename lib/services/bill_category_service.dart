import 'dart:convert';

import 'package:btih_andriod_app/models/bill_category_model.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';

class BillCategoryService {
  static String get baseUrl => '${ApiConfig.baseUrl}/api/BillData';

  Future<List<BillCategory>> getBillCategories() async {
    final response = await ApiConfig.client.get(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((e) => BillCategory.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load bill categories');
    }
  }
}
