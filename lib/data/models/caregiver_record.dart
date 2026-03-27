/// 照护记录模型
library;

import 'package:equatable/equatable.dart';
import 'user.dart';

/// 照护记录
class CaregiverRecord extends Equatable {
  final String id;
  final String careRecipientId;
  final String caregiverId;
  final User? caregiver;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final String? note;
  final DateTime createdAt;

  const CaregiverRecord({
    required this.id,
    required this.careRecipientId,
    required this.caregiverId,
    this.caregiver,
    required this.periodStart,
    this.periodEnd,
    this.note,
    required this.createdAt,
  });

  bool get isCurrent => periodEnd == null;

  String get periodLabel {
    final start = '${periodStart.year}/${periodStart.month}/${periodStart.day}';
    if (periodEnd != null) {
      final end = '${periodEnd!.year}/${periodEnd!.month}/${periodEnd!.day}';
      return '$start - $end';
    }
    return '$start - 至今';
  }

  factory CaregiverRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) { return null; }
      }
      return null;
    }

    return CaregiverRecord(
      id: json['id'] as String? ?? '',
      careRecipientId: json['careRecipientId'] as String? ?? json['care_recipient_id'] as String? ?? '',
      caregiverId: json['caregiverId'] as String? ?? json['caregiver_id'] as String? ?? '',
      caregiver: json['caregiver'] != null
          ? User.fromJson(json['caregiver'] as Map<String, dynamic>)
          : null,
      periodStart: parseDate(json['periodStart'] ?? json['period_start']) ?? DateTime.now(),
      periodEnd: parseDate(json['periodEnd'] ?? json['period_end']),
      note: json['note'] as String?,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, careRecipientId, caregiverId, periodStart, periodEnd];
}
