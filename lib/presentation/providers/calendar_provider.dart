/// 日历模块 Provider
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart' as models;
import '../../core/network/api_client.dart';

/// 已完成的日历实例缓存（taskId_scheduledDate），用于即时 UI 响应
/// 解决问题：FutureProvider 的 ref.watch 在异步函数内无法建立正确依赖，
/// 导致 ref.invalidate 后 UI 不刷新
final completedInstancesProvider = StateProvider<Set<String>>((ref) => {});

/// 日历页刷新计数器 — AddTaskPage 完成后递增，CalendarPage watch 此值触发刷新
final calendarRefreshProvider = StateProvider<int>((ref) => 0);

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
  debugPrint('[CalendarProvider] upcomingTasks familyId=$familyId');
  final response = await dio.get('/family-tasks/upcoming', queryParameters: {
    'familyId': familyId,
  });
  final data = response.data as List<dynamic>;
  debugPrint('[CalendarProvider] upcomingTasks count=${data.length}');
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
  final tasks = data
      .map((e) => models.FamilyTask.fromJson(e as Map<String, dynamic>))
      .toList();
  return tasks;
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
/// 使用 ref.watch 而非 .future，确保 invalidate 能触发重渲染
final calendarEventsProvider =
    FutureProvider.family<Map<DateTime, List<CalendarEvent>>, CalendarQuery>((
  ref,
  query,
) async {
  // watch 刷新计数器：AddTaskPage 完成后递增，强制重新拉取
  ref.watch(calendarRefreshProvider);
  // ref.watch(AsyncValue) 建立响应依赖，invalidate 子 provider 时外层自动重跑
  final appointmentsAsync = ref.watch(calendarAppointmentsProvider(query));
  final tasksAsync = ref.watch(calendarTasksProvider(query));

  final appointments = appointmentsAsync.valueOrNull ?? [];
  final tasks = tasksAsync.valueOrNull ?? [];

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
    // 检查本地缓存：即时显示已完成状态（解决 FutureProvider ref.watch 依赖链断裂的问题）
    final completedKey = '${task.id}_${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    final localCompleted = ref.watch(completedInstancesProvider).contains(completedKey);
    if (localCompleted && task.status != 'completed') {
      // 克隆任务对象，修改 status
      final completedTask = _cloneTaskWithStatus(task, 'completed');
      result[date]!.add(CalendarEvent(
        type: EventType.task,
        date: date,
        task: completedTask,
      ));
    } else {
      result[date]!.add(CalendarEvent(
        type: EventType.task,
        date: date,
        task: task,
      ));
    }
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

/// 克隆 FamilyTask 并修改 status（用于本地缓存覆盖 API 状态）
models.FamilyTask _cloneTaskWithStatus(models.FamilyTask task, String status) {
  return models.FamilyTask(
    id: task.id,
    familyId: task.familyId,
    recipientId: task.recipientId,
    recipient: task.recipient,
    title: task.title,
    description: task.description,
    frequency: task.frequency,
    scheduledTime: task.scheduledTime,
    scheduledDay: task.scheduledDay,
    assigneeId: task.assigneeId,
    assignee: task.assignee,
    status: status,
    nextDueAt: task.nextDueAt,
    note: task.note,
    createdAt: task.createdAt,
  );
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
