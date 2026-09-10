class RefillRequest {
  final int refillId;
  final String mrNo;
  final int? medicationId;
  final String? medicationName;
  final int? quantity;
  final String? notes;
  final String status;
  final String? statusMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RefillRequest({
    required this.refillId,
    required this.mrNo,
    this.medicationId,
    this.medicationName,
    this.quantity,
    this.notes,
    required this.status,
    this.statusMessage,
    this.createdAt,
    this.updatedAt,
  });

  factory RefillRequest.fromJson(Map<String, dynamic> json) {
    return RefillRequest(
      refillId: _asInt(json['refillId'] ?? json['REFILL_ID']),
      mrNo: json['mrNo']?.toString() ?? json['MR_NO']?.toString() ?? '',
      medicationId: _nullableInt(json['medicationId'] ?? json['MEDICATION_ID']),
      medicationName:
          json['medicationName']?.toString() ?? json['MEDICATION_NAME']?.toString(),
      quantity: _nullableInt(json['quantity'] ?? json['QUANTITY']),
      notes: json['notes']?.toString() ?? json['NOTES']?.toString(),
      status: json['status']?.toString() ?? json['STATUS']?.toString() ?? 'PENDING',
      statusMessage:
          json['statusMessage']?.toString() ?? json['STATUS_MESSAGE']?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['CREATED_AT']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['UPDATED_AT']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String get displayStatus {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'APPROVED':
      case 'COMPLETED':
        return 'Approved';
      case 'REJECTED':
      case 'DECLINED':
        return 'Declined';
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return 'Processing';
      default:
        return status;
    }
  }

  String get formattedDate => _formatDate(updatedAt ?? createdAt);

  String get formattedCreatedDate => _formatDate(createdAt);

  String get formattedUpdatedDate => _formatDate(updatedAt);

  static String _formatDate(DateTime? value) {
    final d = value?.toLocal();
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
