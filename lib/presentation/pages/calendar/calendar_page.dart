/// 日历页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('日历')),
        body: const EmptyState(
          emoji: '🏠',
          title: '请先加入一个家庭',
          subtitle: '在"我的"页面加入或创建家庭后使用日历功能',
        ),
      );
    }

    final familyId = family.id;
    final query = CalendarQuery(
      familyId: familyId,
      year: _focusedDay.year,
      month: _focusedDay.month,
    );

    final eventsAsync = ref.watch(calendarEventsProvider(query));
    final upcomingAsync = ref.watch(upcomingTasksProvider(familyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 月份导航
          _buildMonthHeader(),
          // 日历
          eventsAsync.when(
            data: (events) => _buildCalendar(events),
            loading: () => _buildCalendar({}),
            error: (e, _) => _buildCalendar({}),
          ),
          const Divider(height: 1),
          // 即将到来
          Expanded(
            child: _buildUpcomingList(familyId, upcomingAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                _selectedDay = _focusedDay;
              });
            },
          ),
          Text(
            '${_focusedDay.year}年${_focusedDay.month}月',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                _selectedDay = _focusedDay;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<CalendarEvent>> events) {
    return TableCalendar<CalendarEvent>(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      eventLoader: (day) {
        final key = DateTime(day.year, day.month, day.day);
        return events[key] ?? [];
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() => _calendarFormat = format);
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
        weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
        outsideTextStyle: const TextStyle(color: AppColors.textTertiary),
        markerDecoration: const BoxDecoration(
          color: AppColors.coral,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        markerSize: 5,
        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
      ),
      headerVisible: false,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          final hasAppointment = events.any((e) => e.type == EventType.appointment);
          final hasTask = events.any((e) => e.type == EventType.task);
          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasAppointment)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasTask)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingList(String familyId, AsyncValue<List<FamilyTask>> upcomingAsync) {
    if (_selectedDay == null) return const SizedBox();

    final query = CalendarQuery(
      familyId: familyId,
      year: _focusedDay.year,
      month: _focusedDay.month,
    );
    final eventsAsync = ref.watch(calendarEventsProvider(query));

    return eventsAsync.when(
      data: (allEvents) {
        final dayEvents = allEvents[DateTime(
          _selectedDay!.year,
          _selectedDay!.month,
          _selectedDay!.day,
        )] ?? [];

        if (dayEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_selectedDay!.month}月${_selectedDay!.day}日',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '暂无安排',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        final appointments =
            dayEvents.where((e) => e.type == EventType.appointment).toList();
        final tasks = dayEvents.where((e) => e.type == EventType.task).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (appointments.isNotEmpty) ...[
              const Text(
                '复诊',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...appointments.map((e) => _AppointmentCard(
                    appointment: e.appointment!,
                    familyId: familyId,
                  )),
              const SizedBox(height: 16),
            ],
            if (tasks.isNotEmpty) ...[
              const Text(
                '任务',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...tasks.map((e) => _TaskCard(
                    task: e.task!,
                    familyId: familyId,
                  )),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '添加',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _AddOption(
                icon: Icons.local_hospital_rounded,
                iconColor: AppColors.coral,
                label: '添加复诊',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.addAppointment);
                },
              ),
              const SizedBox(height: 12),
              _AddOption(
                icon: Icons.task_alt_rounded,
                iconColor: AppColors.blue,
                label: '添加任务',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.addTask);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _AddOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 操作按钮
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 复诊卡片
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String familyId;

  const _AppointmentCard({required this.appointment, required this.familyId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: AppColors.coral,
            width: 3,
          ),
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded,
                  color: AppColors.coral, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  appointment.hospital,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                appointment.displayTime,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (appointment.department != null) ...[
            const SizedBox(height: 6),
            Text(
              '${appointment.department} ${appointment.doctorName ?? ''}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (appointment.assignedDriver != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_rounded,
                    color: AppColors.textTertiary, size: 14),
                const SizedBox(width: 4),
                Text(
                  '接送: ${appointment.assignedDriver!.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (appointment.doctorPhone != null)
                _ActionBtn(
                  icon: Icons.phone_rounded,
                  label: '联系',
                  color: AppColors.primary,
                  onTap: () => _callDoctor(appointment.doctorPhone!),
                ),
              if (appointment.address != null) ...[
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.map_rounded,
                  label: '导航',
                  color: AppColors.blue,
                  onTap: () => _openMap(appointment),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _callDoctor(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openMap(Appointment apt) async {
    if (apt.latitude != null && apt.longitude != null) {
      final uri = Uri.parse(
          'https://maps.apple.com/?ll=${apt.latitude},${apt.longitude}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (apt.address != null) {
      final encoded = Uri.encodeComponent(apt.address!);
      final uri = Uri.parse('https://maps.apple.com/?q=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

/// 任务卡片
class _TaskCard extends ConsumerWidget {
  final FamilyTask task;
  final String familyId;

  const _TaskCard({required this.task, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: task.isPending ? AppColors.blue : AppColors.success,
            width: 3,
          ),
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          decoration: task.status == 'completed'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.isRecurring
                            ? AppColors.blue.withValues(alpha: 0.1)
                            : AppColors.textTertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.frequencyLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: task.isRecurring
                              ? AppColors.blue
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.assignee?.name ?? ''} · ${task.displayDueAt}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (task.isPending)
            IconButton(
              icon: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 16,
                ),
              ),
              onPressed: () => _completeTask(context, ref),
            ),
        ],
      ),
    );
  }

  void _completeTask(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认完成'),
        content: Text('确定完成任务"${task.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/family-tasks/${task.id}/complete',
                    queryParameters: {'familyId': familyId});
                ref.invalidate(upcomingTasksProvider(familyId));
                ref.invalidate(calendarEventsProvider(CalendarQuery(
                  familyId: familyId,
                  year: DateTime.now().year,
                  month: DateTime.now().month,
                )));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('任务已完成')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('完成失败: $e')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
