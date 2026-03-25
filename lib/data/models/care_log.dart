/// 照护日志模型
library;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum CareLogType {
  medication,
  health,
  emotion,
  activity,
  meal,
  other;

  Color get color {
    switch (this) {
      case CareLogType.medication: return const Color(0xFF4A90D9);
      case CareLogType.health: return const Color(0xFFFF6B6B);
      case CareLogType.emotion: return const Color(0xFFFFB800);
      case CareLogType.activity: return const Color(0xFF34C759);
      case CareLogType.meal: return const Color(0xFFFF9F0A);
      case CareLogType.other: return const Color(0xFF8E8E93);
    }
  }

  String get label {
    switch (this) {
      case CareLogType.medication: return '服药';
      case CareLogType.health: return '健康';
      case CareLogType.emotion: return '情绪';
      case CareLogType.activity: return '活动';
      case CareLogType.meal: return '饮食';
      case CareLogType.other: return '其他';
    }
  }

  String get emoji {
    switch (this) {
      case CareLogType.medication: return '💊';
      case CareLogType.health: return '🩺';
      case CareLogType.emotion: return '😊';
      case CareLogType.activity: return '🚶';
      case CareLogType.meal: return '🍽️';
      case CareLogType.other: return '📝';
    }
  }

  static CareLogType fromString(String? s) {
    switch (s) {
      case 'medication': return CareLogType.medication;
      case 'health': return CareLogType.health;
      case 'emotion': return CareLogType.emotion;
      case 'activity': return CareLogType.activity;
      case 'meal': return CareLogType.meal;
      default: return CareLogType.other;
    }
  }
}

/// 统一时间线条目
class TimelineEntry extends Equatable {
  final String id;
  final DateTime time;
  final CareLogType type;
  final String content;
  final String author;
  final String? authorId;
  final String recipientId;
  final String? source; // 'care_log' or 'medication_log'

  const TimelineEntry({
    required this.id,
    required this.time,
    required this.type,
    required this.content,
    required this.author,
    this.authorId,
    required this.recipientId,
    this.source,
  });

  factory TimelineEntry.fromCareLog(Map<String, dynamic> json) {
    return TimelineEntry(
      id: json['id'] as String? ?? '',
      time: DateTime.tryParse(json['createdAt'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now(),
      type: CareLogType.fromString(json['type'] as String?),
      content: json['content'] as String? ?? '',
      author: json['authorName'] as String? ?? json['author_name'] as String? ?? '家庭成员',
      authorId: json['authorId'] as String? ?? json['author_id'] as String?,
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String? ?? '',
      source: 'care_log',
    );
  }

  factory TimelineEntry.fromMedicationLog(Map<String, dynamic> json) {
    return TimelineEntry(
      id: json['id'] as String? ?? '',
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      type: CareLogType.medication,
      content: json['content'] as String? ?? '',
      author: json['authorName'] as String? ?? json['author_name'] as String? ?? '家庭成员',
      authorId: json['authorId'] as String? ?? json['author_id'] as String?,
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String? ?? '',
      source: 'medication_log',
    );
  }

  @override
  List<Object?> get props => [id, time, type, content, author, recipientId, source];
}

/// 时间线查询参数（用于 Provider Family Key）
class TimelineQuery {
  final String familyId;
  final String? recipientId;

  TimelineQuery({required this.familyId, this.recipientId});

  @override
  bool operator ==(Object other) =>
      other is TimelineQuery &&
      other.familyId == familyId &&
      other.recipientId == recipientId;

  @override
  int get hashCode => familyId.hashCode ^ (recipientId?.hashCode ?? 0);
}
