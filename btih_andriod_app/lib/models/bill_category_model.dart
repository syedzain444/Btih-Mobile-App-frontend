class BillCategory {
  final int billCatId;
  final String billCatName;
  final String isActive;
  final String dcType;

  BillCategory({
    required this.billCatId,
    required this.billCatName,
    required this.isActive,
    required this.dcType,
  });

  factory BillCategory.fromJson(Map<String, dynamic> json) {
    return BillCategory(
      billCatId: json['bilL_CAT_ID'],
      billCatName: json['bilL_CAT_NAME'],
      isActive: json['iS_ACTIVE'],
      dcType: json['dC_TYPE'],
    );
  }
}