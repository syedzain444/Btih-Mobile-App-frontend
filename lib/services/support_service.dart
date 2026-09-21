import 'dart:convert';

import 'package:btih_andriod_app/utils/ip_file.dart';

class SupportContact {
  final String hospitalName;
  final String phone;
  final String email;
  final String address;
  final String workingHours;

  const SupportContact({
    required this.hospitalName,
    required this.phone,
    required this.email,
    required this.address,
    required this.workingHours,
  });

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    return SupportContact(
      hospitalName: json['hospitalName']?.toString() ??
          'Bahria Town International Hospital',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      workingHours: json['workingHours']?.toString() ?? '',
    );
  }
}

class SupportFaqItem {
  final int faqId;
  final String category;
  final String question;
  final String answer;

  const SupportFaqItem({
    required this.faqId,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory SupportFaqItem.fromJson(Map<String, dynamic> json) {
    return SupportFaqItem(
      faqId: (json['faqId'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
    );
  }
}

class SupportTicket {
  final int ticketId;
  final String? mrNo;
  final String contactName;
  final String category;
  final String subject;
  final String description;
  final String status;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupportTicket({
    required this.ticketId,
    this.mrNo,
    required this.contactName,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      ticketId: (json['ticketId'] as num?)?.toInt() ?? 0,
      mrNo: json['mrNo']?.toString(),
      contactName: json['contactName']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      adminNotes: json['adminNotes']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class SupportService {
  Future<SupportContact> getContact() async {
    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Support/contact'),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to load contact info');
    }
    final body = jsonDecode(response.body);
    if (body is Map && body['data'] is Map) {
      return SupportContact.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    }
    throw Exception('Invalid contact response');
  }

  Future<List<SupportFaqItem>> getFaq({
    String lang = 'en',
    String? category,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/Support/faq').replace(
      queryParameters: {
        'lang': lang,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    final response = await ApiConfig.client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Unable to load FAQ');
    }
    final body = jsonDecode(response.body);
    if (body is Map && body['data'] is List) {
      return (body['data'] as List)
          .whereType<Map>()
          .map((e) => SupportFaqItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<int> createTicket({
    String? mrNo,
    required String contactName,
    String? contactPhone,
    String? contactEmail,
    required String category,
    required String subject,
    required String description,
  }) async {
    final response = await ApiConfig.client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/Support/tickets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (mrNo != null && mrNo.isNotEmpty) 'mrNo': mrNo,
        'contactName': contactName,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (contactEmail != null) 'contactEmail': contactEmail,
        'category': category,
        'subject': subject,
        'description': description,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = body is Map ? body['message']?.toString() : null;
      throw Exception(msg ?? 'Unable to submit ticket');
    }
    if (body is Map) {
      return int.tryParse('${body['ticketId']}') ?? 0;
    }
    return 0;
  }

  Future<List<SupportTicket>> getTickets(String mrNo) async {
    final response = await ApiConfig.client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/Support/tickets/$mrNo'),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to load tickets');
    }
    final body = jsonDecode(response.body);
    if (body is Map && body['data'] is List) {
      return (body['data'] as List)
          .whereType<Map>()
          .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<SupportTicket?> getTicketDetail({
    required int ticketId,
    required String mrNo,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/Support/tickets/detail/$ticketId',
    ).replace(queryParameters: {'mrNo': mrNo});
    final response = await ApiConfig.client.get(uri);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Unable to load ticket');
    }
    final body = jsonDecode(response.body);
    if (body is Map && body['data'] is Map) {
      return SupportTicket.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    }
    return null;
  }
}
