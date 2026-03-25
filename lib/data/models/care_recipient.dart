/// 照护对象（老人）模型
library;

import 'package:equatable/equatable.dart';

/// 照护对象（老人）
class CareRecipient extends Equatable {
  final String id;
  final String name;
  final String? avatarEmoji;
  final String? avatarUrl;
  final DateTime? birthDate;
  final int? age;
  final String? gender;
  final String? bloodType;
  final List<String> allergies;
  final List<String> chronicConditions;
  final String? medicalHistory;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? hospital;
  final String? department;
  final String? doctorName;
  final String? doctorPhone;
  final String? currentAddress;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final TodayMedicationStatus? todayMedicationStatus;

  const CareRecipient({
    required this.id,
    required this.name,
    this.avatarEmoji,
    this.avatarUrl,
    this.birthDate,
    this.age,
    this.gender,
    this.bloodType,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.medicalHistory,
    this.emergencyContact,
    this.emergencyPhone,
    this.hospital,
    this.department,
    this.doctorName,
    this.doctorPhone,
    this.currentAddress,
    this.latitude,
    this.longitude,
    this.isActive = true,
    this.todayMedicationStatus,
  });

  factory CareRecipient.fromJson(Map<String, dynamic> json) {
    // 解析 allergies: 可能是逗号分隔字符串或数组
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    // 解析 birthDate
    DateTime? parseBirthDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) { return null; }
      }
      return null;
    }

    // 计算年龄
    int? calcAge(DateTime? birth) {
      if (birth == null) return null;
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    }

    final birth = parseBirthDate(
        json['birthDate'] ?? json['birth_date']);
    final allergiesRaw = json['allergies'];
    final conditionsRaw = json['chronicConditions'] ?? json['chronic_conditions'];

    return CareRecipient(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarEmoji: json['avatarEmoji'] as String? ?? json['avatar'] as String? ?? json['avatar_emoji'] as String? ?? '👤',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      birthDate: birth,
      age: calcAge(birth),
      gender: json['gender'] as String?,
      bloodType: json['bloodType'] as String? ?? json['blood_type'] as String?,
      allergies: parseList(allergiesRaw),
      chronicConditions: parseList(conditionsRaw),
      medicalHistory: json['medicalHistory'] as String? ?? json['medical_history'] as String?,
      emergencyContact: json['emergencyContact'] as String? ?? json['emergency_contact'] as String?,
      emergencyPhone: json['emergencyPhone'] as String? ?? json['emergency_phone'] as String?,
      hospital: json['hospital'] as String?,
      department: json['department'] as String?,
      doctorName: json['doctorName'] as String? ?? json['doctor_name'] as String?,
      doctorPhone: json['doctorPhone'] as String? ?? json['doctor_phone'] as String?,
      currentAddress: json['currentAddress'] as String? ?? json['current_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      todayMedicationStatus: json['todayMedicationStatus'] != null
          ? TodayMedicationStatus.fromJson(
              json['todayMedicationStatus'] as Map<String, dynamic>)
          : (json['today_medication_status'] != null
              ? TodayMedicationStatus.fromJson(
                  json['today_medication_status'] as Map<String, dynamic>)
              : null),
    );
  }

  String get displayAvatar => avatarEmoji ?? '👤';

  @override
  List<Object?> get props => [id, name, isActive];
}

/// 今日用药状态
class TodayMedicationStatus extends Equatable {
  final int completed;
  final int total;
  final int pending;

  const TodayMedicationStatus({
    required this.completed,
    required this.total,
    required this.pending,
  });

  factory TodayMedicationStatus.fromJson(Map<String, dynamic> json) {
    return TodayMedicationStatus(
      completed: json['completed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
    );
  }

  double get progress => total > 0 ? completed / total : 0;

  @override
  List<Object?> get props => [completed, total, pending];
}

/// 健康记录
class HealthRecord extends Equatable {
  final String id;
  final String recipientId;
  final String recordType;
  final Map<String, dynamic> value;
  final DateTime recordedAt;
  final String? note;
  final String? recordedById;

  const HealthRecord({
    required this.id,
    required this.recipientId,
    required this.recordType,
    required this.value,
    required this.recordedAt,
    this.note,
    this.recordedById,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String? ?? '',
      recordType: json['recordType'] as String? ?? json['record_type'] as String? ?? '',
      value: (json['value'] as Map<String, dynamic>?) ?? {},
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? json['recorded_at'] as String? ?? '') ?? DateTime.now(),
      note: json['note'] as String?,
      recordedById: json['recordedById'] as String? ?? json['recorded_by_id'] as String?,
    );
  }

  /// 血压收缩压
  int? get systolic => (value['systolic'] as num?)?.toInt();
  /// 血压舒张压
  int? get diastolic => (value['diastolic'] as num?)?.toInt();
  /// 血糖值
  double? get glucoseValue => (value['value'] as num?)?.toDouble();
  /// 血糖类型 (fasting/postprandial)
  String? get glucoseType => value['type'] as String?;

  @override
  List<Object?> get props => [id, recipientId, recordType, recordedAt];
}
