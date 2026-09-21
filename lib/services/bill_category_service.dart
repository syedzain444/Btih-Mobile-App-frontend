import 'package:btih_andriod_app/utils/billing_departments.dart';

/// Bill categories come from the shared billing department catalog.
/// (Legacy `/api/BillData` does not exist on the backend.)
class BillCategory {
  final String id;
  final String name;
  final bool isActive;
  final String? dcType;

  const BillCategory({
    required this.id,
    required this.name,
    this.isActive = true,
    this.dcType,
  });
}

class BillCategoryService {
  Future<List<BillCategory>> getBillCategories() async {
    return BillingDepartments.departments
        .map(
          (d) => BillCategory(
            id: d.code,
            name: d.name,
            isActive: true,
            dcType: d.code,
          ),
        )
        .toList();
  }
}
