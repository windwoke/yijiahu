/// 日历模块 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart' as models;
import '../../core/network/api_client.dart';

/// 复诊列表
final appointmentsProvider =
    FutureProvider.family<List<models.Appointment>, String>((
  ref,
  familyId,
) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/appointments/calendar', queryParameters: {
    'familyId': familyId,
    'year': DateTime.now().year,
    'month': DateTime.now().month,
  });
  final data = response.data as List<dynamic>;
  return data
      .map((e) => models.Appointment.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 复诊月历视图
final calendarAppointmentsProvider =
    FutureProvider.family<List<models.Appointment>, CalendarQuery>((
  ref,
  query,
) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/appointments/calendar', queryParameters: {
    'familyId': query.familyId,
    'year': query.year,
    'month': query.month,
  });
  final data = response.data as List<dynamic>;
  return data
      .map((e) => models.Appointment.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 任务列表
final familyTasksProvider =
    FutureProvider.family<List<models.FamilyTask>, String>((
  ref,
  familyId,
) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/family-tasks', queryParameters: {
    'familyId': familyId,
  });
  final data = response.data as List<dynamic>;
  return data
      .map((e) => models.FamilyTask.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 即将到期的任务
final upcomingTasksProvider =
    FutureProvider.family<List<models.FamilyTask>, String>((
  ref,
  familyId,
) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/family-tasks/upcoming', queryParameters: {
    'familyId': familyId,
  });
  final data = response.data as List<dynamic>;
  return data
      .map((e) => models.FamilyTask.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 任务月历视图
final calendarTasksProvider =
    FutureProvider.family<List<models.FamilyTask>, CalendarQuery>((
  ref,
  query,
) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/family-tasks/calendar', queryParameters: {
    'familyId': query.familyId,
    'year': query.year,
    'month': query.month,
  });
  final data = response.data as List<dynamic>;
  return data
      .map((e) => models.FamilyTask.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 日历查询参数
class CalendarQuery {
  final String familyId;
  final int year;
  final int month;

  CalendarQuery({
    required this.familyId,
    required this.year,
    required this.month,
  });

  @override
  bool operator ==(Object other) =>
      other is CalendarQuery &&
      other.familyId == familyId &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(familyId, year, month);
}

/// 日历数据（复诊+任务按日期聚合）
final calendarEventsProvider =
    FutureProvider.family<Map<DateTime, List<CalendarEvent>>, CalendarQuery>((
  ref,
  query,
) async {
  final appointments = await ref.watch(calendarAppointmentsProvider(query).future);
  final tasks = await ref.watch(calendarTasksProvider(query).future);

  final Map<DateTime, List<CalendarEvent>> result = {};

  for (final apt in appointments) {
    final date = DateTime(
      apt.appointmentTime.year,
      apt.appointmentTime.month,
      apt.appointmentTime.day,
    );
    result.putIfAbsent(date, () => []);
    result[date]!.add(CalendarEvent(
      type: EventType.appointment,
      date: date,
      appointment: apt,
    ));
  }

  for (final task in tasks) {
    if (task.nextDueAt == null) continue;
    final date = DateTime(
      task.nextDueAt!.year,
      task.nextDueAt!.month,
      task.nextDueAt!.day,
    );
    result.putIfAbsent(date, () => []);
    result[date]!.add(CalendarEvent(
      type: EventType.task,
      date: date,
      task: task,
    ));
  }

  return result;
});

/// 日历事件
enum EventType { appointment, task }

class CalendarEvent {
  final EventType type;
  final DateTime date;
  final models.Appointment? appointment;
  final models.FamilyTask? task;

  CalendarEvent({
    required this.type,
    required this.date,
    this.appointment,
    this.task,
  });
}

/// 完成任务
final completeTaskProvider =
    FutureProvider.family<void, CompleteTaskParams>((ref, params) async {
  final dio = ref.read(dioProvider);
  await dio.post('/family-tasks/${params.taskId}/complete', queryParameters: {
    'familyId': params.familyId,
  });
  // 刷新数据
  ref.invalidate(familyTasksProvider(params.familyId));
  ref.invalidate(upcomingTasksProvider(params.familyId));
});

class CompleteTaskParams {
  final String taskId;
  final String familyId;
  final String? note;

  CompleteTaskParams({
    required this.taskId,
    required this.familyId,
    this.note,
  });

  @override
  bool operator ==(Object other) =>
      other is CompleteTaskParams &&
      other.taskId == taskId &&
      other.familyId == familyId;

  @override
  int get hashCode => Object.hash(taskId, familyId);
}
