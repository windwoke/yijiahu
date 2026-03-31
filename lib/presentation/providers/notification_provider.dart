/// 通知 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification.dart';
import '../../core/network/api_client.dart';

/// 通知列表
final notificationListProvider = FutureProvider.family<List<AppNotification>, int>(
  (ref, page) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/notifications', queryParameters: {
        'page': page,
        'pageSize': 20,
      });
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return [];
      final list = data['list'] as List<dynamic>? ?? [];
      return list
          .map((e) {
            try { return AppNotification.fromJson(e as Map<String, dynamic>); }
            catch (_) { return null; }
          })
          .whereType<AppNotification>()
          .toList();
    } catch (_) {
      return [];
    }
  },
);

/// 未读数
final unreadCountProvider = FutureProvider<int>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/notifications/unread-count');
    final data = response.data as Map<String, dynamic>?;
    return data?['count'] as int? ?? 0;
  } catch (_) {
    return 0;
  }
});

/// 标记单条已读
Future<void> markAsRead(WidgetRef ref, String notificationId) async {
  final dio = ref.read(dioProvider);
  try {
    await dio.put('/notifications/$notificationId/read');
    // 刷新未读数
    ref.invalidate(unreadCountProvider);
  } catch (_) {}
}

/// 全部已读
Future<void> markAllAsRead(WidgetRef ref) async {
  final dio = ref.read(dioProvider);
  try {
    await dio.put('/notifications/read-all');
    ref.invalidate(unreadCountProvider);
  } catch (_) {}
}

/// 删除通知
Future<void> deleteNotification(WidgetRef ref, String notificationId) async {
  final dio = ref.read(dioProvider);
  try {
    await dio.delete('/notifications/$notificationId');
    ref.invalidate(unreadCountProvider);
  } catch (_) {}
}

// ─────────────────────────────────────────────
// 通知偏好
// ─────────────────────────────────────────────

class NotificationPreference {
  final String id;
  final String userId;
  final bool medicationReminder;
  final bool missedDose;
  final bool appointmentReminder;
  final bool taskReminder;
  final bool taskAssigned;
  final bool dailyCheckin;
  final bool dailyCheckinCompleted;
  final bool healthAlert;
  final bool sosEnabled;
  final bool memberJoined;
  final bool careLog;
  final int medicationLeadMinutes;
  final int appointmentLeadHours;
  final bool dndEnabled;
  final String dndStart;
  final String dndEnd;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const NotificationPreference({
    required this.id,
    required this.userId,
    this.medicationReminder = true,
    this.missedDose = true,
    this.appointmentReminder = true,
    this.taskReminder = true,
    this.taskAssigned = true,
    this.dailyCheckin = true,
    this.dailyCheckinCompleted = true,
    this.healthAlert = true,
    this.sosEnabled = true,
    this.memberJoined = true,
    this.careLog = true,
    this.medicationLeadMinutes = 5,
    this.appointmentLeadHours = 24,
    this.dndEnabled = false,
    this.dndStart = '22:00',
    this.dndEnd = '07:00',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      medicationReminder: json['medicationReminder'] as bool? ?? true,
      missedDose: json['missedDose'] as bool? ?? true,
      appointmentReminder: json['appointmentReminder'] as bool? ?? true,
      taskReminder: json['taskReminder'] as bool? ?? true,
      taskAssigned: json['taskAssigned'] as bool? ?? true,
      dailyCheckin: json['dailyCheckin'] as bool? ?? true,
      dailyCheckinCompleted: json['dailyCheckinCompleted'] as bool? ?? true,
      healthAlert: json['healthAlert'] as bool? ?? true,
      sosEnabled: json['sosEnabled'] as bool? ?? true,
      memberJoined: json['memberJoined'] as bool? ?? true,
      careLog: json['careLog'] as bool? ?? true,
      medicationLeadMinutes: json['medicationLeadMinutes'] as int? ?? 5,
      appointmentLeadHours: json['appointmentLeadHours'] as int? ?? 24,
      dndEnabled: json['dndEnabled'] as bool? ?? false,
      dndStart: json['dndStart'] as String? ?? '22:00',
      dndEnd: json['dndEnd'] as String? ?? '07:00',
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    );
  }

  NotificationPreference copyWith({
    String? id,
    String? userId,
    bool? medicationReminder,
    bool? missedDose,
    bool? appointmentReminder,
    bool? taskReminder,
    bool? taskAssigned,
    bool? dailyCheckin,
    bool? dailyCheckinCompleted,
    bool? healthAlert,
    bool? sosEnabled,
    bool? memberJoined,
    bool? careLog,
    int? medicationLeadMinutes,
    int? appointmentLeadHours,
    bool? dndEnabled,
    String? dndStart,
    String? dndEnd,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicationReminder: medicationReminder ?? this.medicationReminder,
      missedDose: missedDose ?? this.missedDose,
      appointmentReminder: appointmentReminder ?? this.appointmentReminder,
      taskReminder: taskReminder ?? this.taskReminder,
      taskAssigned: taskAssigned ?? this.taskAssigned,
      dailyCheckin: dailyCheckin ?? this.dailyCheckin,
      dailyCheckinCompleted: dailyCheckinCompleted ?? this.dailyCheckinCompleted,
      healthAlert: healthAlert ?? this.healthAlert,
      sosEnabled: sosEnabled ?? this.sosEnabled,
      memberJoined: memberJoined ?? this.memberJoined,
      careLog: careLog ?? this.careLog,
      medicationLeadMinutes: medicationLeadMinutes ?? this.medicationLeadMinutes,
      appointmentLeadHours: appointmentLeadHours ?? this.appointmentLeadHours,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

/// 通知偏好 Provider
final notificationPreferenceProvider = FutureProvider<NotificationPreference>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/notification-preferences');
    return NotificationPreference.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    return const NotificationPreference(id: '', userId: '');
  }
});

/// 更新通知偏好（单个字段）
/// 注意：不 invalidate 缓存，由 UI 本地 _pendingChanges 管理乐观更新
Future<NotificationPreference> updateNotificationPreference(
  WidgetRef ref,
  Map<String, dynamic> updates,
) async {
  final dio = ref.read(dioProvider);
  final response = await dio.put('/notification-preferences', data: updates);
  return NotificationPreference.fromJson(response.data as Map<String, dynamic>);
}
