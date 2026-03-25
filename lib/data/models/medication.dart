/// 药品与用药记录模型
library;

import 'package:equatable/equatable.dart';

enum MedicationFrequency { daily, weekly, asNeeded }

enum MedicationLogStatus { pending, taken, skipped, missed }

/// 药品
class Medication extends Equatable {
  final String id;
  final String recipientId;
  final String name;
  final String? realName;
  final String dosage;
  final String? unit;
  final MedicationFrequency frequency;
  final List<String> times;
  final String? instructions;
  final DateTime startDate;
  final DateTime? endDate;
  final String? prescribedBy;
  final bool isActive;
  final Map<String, MedicationTimeStatus>? todayStatus;

  const Medication({
    required this.id,
    required this.recipientId,
    required this.name,
    this.realName,
    required this.dosage,
    this.unit,
    this.frequency = MedicationFrequency.daily,
    required this.times,
    this.instructions,
    required this.startDate,
    this.endDate,
    this.prescribedBy,
    this.isActive = true,
    this.todayStatus,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    final todayStatusMap = <String, MedicationTimeStatus>{};
    final todayStatus = json['todayStatus'] as Map<String, dynamic>? ??
        json['today_status'] as Map<String, dynamic>?;
    if (todayStatus != null) {
      todayStatus.forEach((key, value) {
        todayStatusMap[key] = MedicationTimeStatus.fromJson(
            value as Map<String, dynamic>);
      });
    }

    final timesRaw = json['times'];
    final times = timesRaw is List
        ? timesRaw.map((e) => e as String).toList()
        : <String>[];

    return Medication(
      id: json['id'] as String,
      recipientId: _str(json['recipientId']) ?? _str(json['recipient_id']) ?? '',
      name: json['name'] as String,
      realName: json['realName'] as String? ?? json['real_name'] as String?,
      dosage: json['dosage'] as String,
      unit: json['unit'] as String?,
      frequency: _parseFrequency(
          json['frequency'] as String? ?? json['frequency'] as String?),
      times: times,
      instructions: json['instructions'] as String?,
      startDate: _parseDate(json['startDate'] ?? json['start_date']) ?? DateTime.now(),
      endDate: _parseDate(json['endDate'] ?? json['end_date']),
      prescribedBy: json['prescribedBy'] as String? ?? json['prescribed_by'] as String?,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      todayStatus: todayStatusMap,
    );
  }

  static String? _str(dynamic v) => v as String?;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try { return DateTime.parse(v); } catch (_) { return null; }
    }
    return null;
  }

  static MedicationFrequency _parseFrequency(String? freq) {
    switch (freq) {
      case 'weekly':
        return MedicationFrequency.weekly;
      case 'as_needed':
        return MedicationFrequency.asNeeded;
      default:
        return MedicationFrequency.daily;
    }
  }

  bool get isLongTerm => endDate == null;

  @override
  List<Object?> get props => [id, recipientId, name, isActive];
}

/// 某个时间点的用药状态
class MedicationTimeStatus extends Equatable {
  final MedicationLogStatus status;
  final String? takenBy;
  final String? actualTime;
  final String? photoUrl;

  const MedicationTimeStatus({
    required this.status,
    this.takenBy,
    this.actualTime,
    this.photoUrl,
  });

  factory MedicationTimeStatus.fromJson(Map<String, dynamic> json) {
    return MedicationTimeStatus(
      status: _parseStatus(json['status'] as String?),
      takenBy: json['taken_by'] as String?,
      actualTime: json['actual_time'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  static MedicationLogStatus _parseStatus(String? status) {
    switch (status) {
      case 'taken':
        return MedicationLogStatus.taken;
      case 'skipped':
        return MedicationLogStatus.skipped;
      case 'missed':
        return MedicationLogStatus.missed;
      default:
        return MedicationLogStatus.pending;
    }
  }

  @override
  List<Object?> get props => [status, takenBy, actualTime];
}

/// 用药记录
class MedicationLog extends Equatable {
  final String id;
  final String medicationId;
  final String medicationName;
  final String scheduledTime;
  final DateTime? actualTime;
  final MedicationLogStatus status;
  final MedicationLogTaker? takenBy;
  final String? photoUrl;
  final String? skipReason;

  const MedicationLog({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
    this.takenBy,
    this.photoUrl,
    this.skipReason,
  });

  factory MedicationLog.fromJson(Map<String, dynamic> json) {
    return MedicationLog(
      id: json['id'] as String,
      medicationId: json['medicationId'] as String? ?? json['medication_id'] as String? ?? '',
      medicationName: json['medicationName'] as String? ?? json['medication_name'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? json['scheduled_time'] as String? ?? '',
      actualTime: json['actualTime'] != null
          ? DateTime.tryParse(json['actualTime'] as String? ?? '')
          : (json['actual_time'] != null ? DateTime.tryParse(json['actual_time'] as String? ?? '') : null),
      status: MedicationTimeStatus._parseStatus(json['status'] as String?),
      takenBy: null,
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String?,
      skipReason: json['note'] as String? ?? json['skip_reason'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, medicationId, scheduledTime, status];
}

/// 给药人
class MedicationLogTaker extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;

  const MedicationLogTaker({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory MedicationLogTaker.fromJson(Map<String, dynamic> json) {
    return MedicationLogTaker(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

/// 今日用药汇总
class TodayMedicationSummary extends Equatable {
  final String recipientId;
  final String? recipientName;
  final DateTime date;
  final List<MedicationLogItem> items;
  final int total;
  final int completed;
  final int pending;

  const TodayMedicationSummary({
    required this.recipientId,
    this.recipientName,
    required this.date,
    required this.items,
    required this.total,
    required this.completed,
    required this.pending,
  });

  factory TodayMedicationSummary.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>?)
        ?.map((e) => MedicationLogItem.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    final summary = json['summary'] as Map<String, dynamic>?;
    final total = summary?['total'] as int? ?? 0;
    final completed = summary?['completed'] as int? ?? 0;
    return TodayMedicationSummary(
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String? ?? '',
      recipientName: json['recipientName'] as String? ?? json['recipient_name'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      items: items,
      total: total,
      completed: completed,
      pending: total - completed,
    );
  }

  @override
  List<Object?> get props => [recipientId, date, items];
}

/// 用药记录项
class MedicationLogItem extends Equatable {
  final String? id;
  final String medicationId;
  final String medicationName;
  final String dosage;
  final String scheduledTime;
  final DateTime? scheduledAt;
  final MedicationLogStatus status;
  final DateTime? actualTime;
  final MedicationLogTaker? takenBy;
  final String? photoUrl;

  const MedicationLogItem({
    this.id,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.scheduledTime,
    this.scheduledAt,
    required this.status,
    this.actualTime,
    this.takenBy,
    this.photoUrl,
  });

  factory MedicationLogItem.fromJson(Map<String, dynamic> json) {
    // takenBy 可以是 MedicationLogTaker 对象或 string
    MedicationLogTaker? takenByObj;
    final takenByRaw = json['taken_by'];
    if (takenByRaw is Map<String, dynamic>) {
      takenByObj = MedicationLogTaker.fromJson(takenByRaw);
    }

    return MedicationLogItem(
      id: json['id'] as String?,
      medicationId: json['medicationId'] as String? ?? json['medication_id'] as String? ?? '',
      medicationName: json['medicationName'] as String? ?? json['medication_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? json['scheduled_time'] as String? ?? '',
      scheduledAt: null,
      status: MedicationTimeStatus._parseStatus(json['status'] as String?),
      actualTime: json['actualTime'] != null
          ? DateTime.tryParse(json['actualTime'] as String? ?? '')
          : (json['actual_time'] != null ? DateTime.tryParse(json['actual_time'] as String? ?? '') : null),
      takenBy: takenByObj,
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String?,
    );
  }

  bool get canCheckIn =>
      status == MedicationLogStatus.pending ||
      status == MedicationLogStatus.missed;

  @override
  List<Object?> get props =>
      [id, medicationId, scheduledTime, status];
}
