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
  final String? source; // 'care_log' | 'medication_log' | 'health_record'
  /// 健康记录专用字段
  final Map<String, dynamic>? healthValue;
  final HealthMetricType? healthMetricType;
  /// 附件列表
  final List<CareLogAttachment> attachments;

  const TimelineEntry({
    required this.id,
    required this.time,
    required this.type,
    required this.content,
    required this.author,
    this.authorId,
    required this.recipientId,
    this.source,
    this.healthValue,
    this.healthMetricType,
    this.attachments = const [],
  });

  factory TimelineEntry.fromCareLog(Map<String, dynamic> json) {
    final attachmentsList = (json['attachments'] as List<dynamic>?)
            ?.map((a) => CareLogAttachment.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    return TimelineEntry(
      id: json['id'] as String? ?? '',
      time: DateTime.tryParse(json['createdAt'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now(),
      type: CareLogType.fromString(json['type'] as String?),
      content: json['content'] as String? ?? '',
      author: json['authorName'] as String? ?? json['author_name'] as String? ?? '家庭成员',
      authorId: json['authorId'] as String? ?? json['author_id'] as String?,
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String? ?? '',
      source: 'care_log',
      attachments: attachmentsList,
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

  factory TimelineEntry.fromHealthRecord(Map<String, dynamic> json) {
    final recordType = json['recordType'] as String? ?? '';
    final value = json['value'] as Map<String, dynamic>?;
    final metricType = _parseHealthMetricType(recordType);
    final content = metricType?.buildContent(value) ?? '健康记录';

    return TimelineEntry(
      id: json['id'] as String? ?? '',
      time: DateTime.tryParse(json['recordedAt'] as String? ?? '') ?? DateTime.now(),
      type: CareLogType.health,
      content: content,
      author: json['authorName'] as String? ?? '家庭成员',
      authorId: json['recordedById'] as String? ?? json['authorId'] as String?,
      recipientId: json['recipientId'] as String? ?? '',
      source: 'health_record',
      healthValue: value,
      healthMetricType: metricType,
    );
  }

  static HealthMetricType? _parseHealthMetricType(String recordType) {
    switch (recordType) {
      case 'blood_pressure': return HealthMetricType.bloodPressure;
      case 'blood_glucose': return HealthMetricType.bloodGlucose;
      case 'weight': return HealthMetricType.weight;
      default: return null;
    }
  }

  @override
  List<Object?> get props => [id, time, type, content, author, recipientId, source, healthValue, attachments];
}

// ─── 健康数据类型 ───────────────────────────────────────────────

/// 健康记录子类型（血压/血糖/体重）
enum HealthMetricType {
  bloodPressure,
  bloodGlucose,
  weight;

  String get label {
    switch (this) {
      case HealthMetricType.bloodPressure: return '血压';
      case HealthMetricType.bloodGlucose: return '血糖';
      case HealthMetricType.weight: return '体重';
    }
  }

  String get emoji {
    switch (this) {
      case HealthMetricType.bloodPressure: return '🫀';
      case HealthMetricType.bloodGlucose: return '🩸';
      case HealthMetricType.weight: return '⚖️';
    }
  }

  /// 正常范围描述
  String get normalRange {
    switch (this) {
      case HealthMetricType.bloodPressure: return '正常 90-140/60-90 mmHg';
      case HealthMetricType.bloodGlucose: return '空腹 3.9-6.1 mmol/L';
      case HealthMetricType.weight: return '参考个人基准';
    }
  }

  /// 记录类型的英文字符串
  String get recordType {
    switch (this) {
      case HealthMetricType.bloodPressure: return 'blood_pressure';
      case HealthMetricType.bloodGlucose: return 'blood_glucose';
      case HealthMetricType.weight: return 'weight';
    }
  }

  /// 是否超出正常范围（返回 null 表示无数据）
  HealthRangeResult? checkRange(Map<String, dynamic>? value) {
    switch (this) {
      case HealthMetricType.bloodPressure:
        final sys = (value?['systolic'] as num?)?.toInt();
        final dia = (value?['diastolic'] as num?)?.toInt();
        if (sys == null || dia == null) return null;
        if (sys >= 140 || dia >= 90) return HealthRangeResult.high;
        if (sys < 90 || dia < 60) return HealthRangeResult.low;
        return HealthRangeResult.normal;
      case HealthMetricType.bloodGlucose:
        final val = (value?['value'] as num?)?.toDouble();
        if (val == null) return null;
        if (val > 11.1 || val < 2.8) return HealthRangeResult.high;
        if (val > 7.8 || val < 3.9) return HealthRangeResult.low; // 餐后高/空腹低
        return HealthRangeResult.normal;
      case HealthMetricType.weight:
        // 体重没有绝对标准，返回 normal
        return HealthRangeResult.normal;
    }
  }

  /// 生成日志内容文本
  String buildContent(Map<String, dynamic>? value) {
    switch (this) {
      case HealthMetricType.bloodPressure:
        final sys = value?['systolic'] ?? '-';
        final dia = value?['diastolic'] ?? '-';
        return '血压 $sys/$dia mmHg';
      case HealthMetricType.bloodGlucose:
        final val = value?['value'] ?? '-';
        final t = value?['type'] == 'postprandial' ? '餐后' : '空腹';
        return '$t血糖 $val mmol/L';
      case HealthMetricType.weight:
        final val = value?['value'] ?? '-';
        final unit = value?['unit'] ?? 'kg';
        return '体重 $val $unit';
    }
  }
}

enum HealthRangeResult { normal, low, high }

/// 日志附件
class CareLogAttachment extends Equatable {
  final String id;
  final String type; // 'image' | 'video'
  final String url;
  final String? thumbnailUrl;
  final int? size;
  final int? duration; // 视频时长，秒
  final int? width;
  final int? height;
  final String? filename;

  const CareLogAttachment({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.size,
    this.duration,
    this.width,
    this.height,
    this.filename,
  });

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';

  factory CareLogAttachment.fromJson(Map<String, dynamic> json) {
    return CareLogAttachment(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'image',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      size: json['size'] as int?,
      duration: json['duration'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      filename: json['filename'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, type, url, thumbnailUrl];
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
