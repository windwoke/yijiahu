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
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? medicalHistory;
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
    this.emergencyContact,
    this.emergencyPhone,
    this.medicalHistory,
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
    return CareRecipient(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarEmoji: json['avatar_emoji'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      bloodType: json['blood_type'] as String?,
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      chronicConditions: (json['chronic_conditions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      emergencyContact: json['emergency_contact'] as String?,
      emergencyPhone: json['emergency_phone'] as String?,
      medicalHistory: json['medical_history'] as String?,
      hospital: json['hospital'] as String?,
      department: json['department'] as String?,
      doctorName: json['doctor_name'] as String?,
      doctorPhone: json['doctor_phone'] as String?,
      currentAddress: json['current_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      todayMedicationStatus: json['today_medication_status'] != null
          ? TodayMedicationStatus.fromJson(
              json['today_medication_status'] as Map<String, dynamic>)
          : null,
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
