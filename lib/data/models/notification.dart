/// 通知模型
library;

import 'package:equatable/equatable.dart';

// 已实现（L0+L1）
// L2 后续实现：memberJoined / memberLeft / taskReminder / taskAssigned / taskCompleted / dailyCheckin / healthAlert / caregiverChanged / appointmentReminder48h

enum NotificationType {
  // L0+L1 已实现
  medicationReminder('medication_reminder', '💊', '用药提醒'),
  missedDose('missed_dose', '⚠️', '漏服提醒'),
  appointmentReminder('appointment_reminder', '📅', '复诊提醒'),
  sos('sos', '🚨', '紧急求助'),
  sosAcknowledged('sos_acknowledged', '✅', '求助已确认'),
  // L2 后续实现
  memberJoined('member_joined', '👥', '新成员加入'),
  memberLeft('member_left', '👤', '成员离开'),
  taskReminder('task_reminder', '📋', '任务提醒'),
  taskAssigned('task_assigned', '👋', '任务指派'),
  taskCompleted('task_completed', '✅', '任务已完成'),
  dailyCheckin('daily_checkin', '📝', '每日打卡'),
  healthAlert('health_alert', '🩺', '健康告警'),
  caregiverChanged('caregiver_changed', '🔄', '照护人变更');

  final String value;
  final String emoji;
  final String label;

  const NotificationType(this.value, this.emoji, this.label);

  static NotificationType fromString(String? v) {
    return NotificationType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => NotificationType.medicationReminder,
    );
  }
}

enum NotificationLevel { normal, high, urgent }

class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String? familyId;
  final NotificationType type;
  final String title;
  final String body;
  final NotificationLevel level;
  final String? sourceType;
  final String? sourceId;
  final String? sourceUserId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? dataJson;

  const AppNotification({
    required this.id,
    required this.userId,
    this.familyId,
    required this.type,
    required this.title,
    required this.body,
    this.level = NotificationLevel.normal,
    this.sourceType,
    this.sourceId,
    this.sourceUserId,
    this.isRead = false,
    required this.createdAt,
    this.dataJson,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      familyId: json['familyId'] as String?,
      type: NotificationType.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      level: NotificationLevel.values.firstWhere(
        (e) => e.name == (json['level'] as String? ?? 'normal'),
        orElse: () => NotificationLevel.normal,
      ),
      sourceType: json['sourceType'] as String?,
      sourceId: json['sourceId'] as String?,
      sourceUserId: json['sourceUserId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      dataJson: json['dataJson'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, title, isRead, createdAt];
}
