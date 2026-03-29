/// 每日护理打卡模型
library;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'user.dart';

enum CheckinStatus {
  normal,
  concerning,
  poor,
  critical;

  String get label {
    switch (this) {
      case CheckinStatus.normal: return '状态良好';
      case CheckinStatus.concerning: return '需要关注';
      case CheckinStatus.poor: return '状态较差';
      case CheckinStatus.critical: return '危急';
    }
  }

  String get emoji {
    switch (this) {
      case CheckinStatus.normal: return '😊';
      case CheckinStatus.concerning: return '😐';
      case CheckinStatus.poor: return '😔';
      case CheckinStatus.critical: return '🤒';
    }
  }

  Color get color {
    switch (this) {
      case CheckinStatus.normal:    return const Color(0xFF6BA07E); // 成功-鼠尾草绿系
      case CheckinStatus.concerning: return const Color(0xFFD4A855); // 警告-暖琥珀
      case CheckinStatus.poor:      return const Color(0xFFE07B5D); // 错误-暖杏/陶土
      case CheckinStatus.critical:   return const Color(0xFFE07B5D); // 错误-暖杏/陶土（更强烈由UI表达）
    }
  }

  static CheckinStatus fromString(String? v) {
    switch (v) {
      case 'concerning': return CheckinStatus.concerning;
      case 'poor': return CheckinStatus.poor;
      case 'critical': return CheckinStatus.critical;
      default: return CheckinStatus.normal;
    }
  }
}

/// 每日护理打卡
class DailyCareCheckin extends Equatable {
  final String id;
  final String careRecipientId;
  final DateTime checkinDate;
  final CheckinStatus status;
  final int medicationCompleted;
  final int medicationTotal;
  final String? specialNote;
  final User? checkedInBy;
  final DateTime createdAt;

  const DailyCareCheckin({
    required this.id,
    required this.careRecipientId,
    required this.checkinDate,
    required this.status,
    required this.medicationCompleted,
    required this.medicationTotal,
    this.specialNote,
    this.checkedInBy,
    required this.createdAt,
  });

  factory DailyCareCheckin.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) { return null; }
      }
      return null;
    }

    return DailyCareCheckin(
      id: json['id'] as String? ?? '',
      careRecipientId: json['careRecipientId'] as String? ?? json['care_recipient_id'] as String? ?? '',
      checkinDate: parseDate(json['checkinDate'] ?? json['checkin_date']) ?? DateTime.now(),
      status: CheckinStatus.fromString(json['status'] as String?),
      medicationCompleted: json['medicationCompleted'] as int? ?? json['medication_completed'] as int? ?? 0,
      medicationTotal: json['medicationTotal'] as int? ?? json['medication_total'] as int? ?? 0,
      specialNote: json['specialNote'] as String? ?? json['special_note'] as String?,
      checkedInBy: json['checkedInBy'] != null
          ? User.fromJson(json['checkedInBy'] as Map<String, dynamic>)
          : null,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }

  String get medicationLabel {
    if (medicationTotal == 0) return '未关联药品';
    return '$medicationCompleted/$medicationTotal 项已完成';
  }

  @override
  List<Object?> get props => [id, careRecipientId, checkinDate, status, medicationCompleted, medicationTotal];
}
