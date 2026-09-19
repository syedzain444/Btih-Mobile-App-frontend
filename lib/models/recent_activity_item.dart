import 'package:flutter/material.dart';

enum RecentActivityKind {
  doctor,
  appointment,
  medicalReport,
  discharge,
  visit,
  bill,
}

class RecentActivityItem {
  final String id;
  final RecentActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime viewedAt;
  final Map<String, dynamic> payload;

  const RecentActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.viewedAt,
    required this.payload,
  });

  IconData get icon {
    switch (kind) {
      case RecentActivityKind.doctor:
        return Icons.medical_services_outlined;
      case RecentActivityKind.appointment:
        return Icons.event_available_outlined;
      case RecentActivityKind.medicalReport:
        return Icons.description_outlined;
      case RecentActivityKind.discharge:
        return Icons.logout_rounded;
      case RecentActivityKind.visit:
        return Icons.history_rounded;
      case RecentActivityKind.bill:
        return Icons.receipt_long_outlined;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'subtitle': subtitle,
        'viewedAt': viewedAt.toIso8601String(),
        'payload': payload,
      };

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString() ?? RecentActivityKind.visit.name;
    final kind = RecentActivityKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => RecentActivityKind.visit,
    );
    return RecentActivityItem(
      id: json['id']?.toString().isNotEmpty == true
          ? json['id'].toString()
          : (json['activityKey']?.toString() ?? ''),
      kind: kind,
      title: json['title']?.toString() ?? 'Activity',
      subtitle: json['subtitle']?.toString() ?? '',
      viewedAt: DateTime.tryParse(json['viewedAt']?.toString() ?? '') ??
          DateTime.now(),
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }
}
