/// 复诊日历页
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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showList = false; // 列表视图切换

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
        appBar: AppBar(title: const Text('复诊日历')),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('复诊日历'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加',
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMonthHeader(),
            SizedBox(
              height: 300,
              child: eventsAsync.when(
                data: (events) => _buildCalendar(events),
                loading: () => _buildCalendar({}),
                error: (e, _) => _buildCalendar({}),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.border,
            ),
            // 即将到来的复诊
            _buildUpcomingSection(familyId),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddBottomSheet(
        onAddAppointment: () {
          Navigator.pop(context);
          context.push(AppRoutes.addAppointment);
        },
        onAddTask: () {
          Navigator.pop(context);
          context.push(AppRoutes.addTask);
        },
        onViewTasks: () {
          Navigator.pop(context);
          context.push(AppRoutes.familyTasks);
        },
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              '${_focusedDay.year}年${_focusedDay.month}月',
              key: ValueKey('${_focusedDay.year}-${_focusedDay.month}'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
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
      locale: 'zh_CN',
      daysOfWeekHeight: 36,
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        weekendStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
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
        cellMargin: const EdgeInsets.all(4),
      ),
      headerVisible: false,
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _CalendarDayCell(
            day: day,
            isSelected: isSameDay(_selectedDay, day),
            events: events[DateTime(day.year, day.month, day.day)] ?? [],
          );
        },
        todayBuilder: (context, day, focusedDay) {
          return _CalendarDayCell(
            day: day,
            isToday: true,
            events: events[DateTime(day.year, day.month, day.day)] ?? [],
          );
        },
        selectedBuilder: (context, day, focusedDay) {
          return _CalendarDayCell(
            day: day,
            isSelected: true,
            events: events[DateTime(day.year, day.month, day.day)] ?? [],
          );
        },
      ),
    );
  }

  Widget _buildUpcomingSection(String familyId) {
    final query = CalendarQuery(
      familyId: familyId,
      year: _focusedDay.year,
      month: _focusedDay.month,
    );
    final eventsAsync = ref.watch(calendarEventsProvider(query));

    return Column(
      children: [
        // 切换标签
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Text(
                '本月日程',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _ViewToggle(
                icon: Icons.view_agenda_rounded,
                label: '列表',
                selected: _showList,
                onTap: () => setState(() => _showList = true),
              ),
              const SizedBox(width: 4),
              _ViewToggle(
                icon: Icons.calendar_today_rounded,
                label: '当天',
                selected: !_showList,
                onTap: () => setState(() => _showList = false),
              ),
            ],
          ),
        ),
        eventsAsync.when(
          data: (allEvents) {
            if (_showList) {
              return _buildListView(allEvents, familyId);
            } else {
              return _buildDayView(allEvents, familyId);
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ],
    );
  }

  Widget _buildListView(Map<DateTime, List<CalendarEvent>> allEvents, String familyId) {
    final now = DateTime.now();
    // 收集所有事件（复诊+任务），按时间排序
    final allEventsList = <_MergedEvent>[];
    for (final entry in allEvents.entries) {
      for (final ev in entry.value) {
        final time = ev.type == EventType.appointment
            ? ev.appointment!.appointmentTime
            : ev.task!.nextDueAt ?? DateTime.now();
        allEventsList.add(_MergedEvent(time: time, event: ev));
      }
    }
    allEventsList.sort((a, b) => a.time.compareTo(b.time));
    // 过滤过去的事件
    final futureEvents = allEventsList
        .where((e) => e.time.isAfter(now.subtract(const Duration(days: 1))))
        .toList();

    if (futureEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: EmptyState(
          emoji: '📅',
          title: '本月暂无日程安排',
          subtitle: '点击右上角"+"添加复诊或任务',
        ),
      );
    }

    // 按日期分组
    final Map<String, List<_MergedEvent>> grouped = {};
    for (final e in futureEvents) {
      final key = '${e.time.year}-${e.time.month}-${e.time.day}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final events = grouped[dateKey]!;
        final date = events.first.time;
        final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                '${date.month}月${date.day}日 · ${weekdays[date.weekday - 1]}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            ...events.map((me) {
              if (me.event.type == EventType.appointment) {
                return _AppointmentCard(
                  appointment: me.event.appointment!,
                  familyId: familyId,
                );
              } else {
                return _TaskCardCompact(
                  task: me.event.task!,
                  familyId: familyId,
                );
              }
            }),
          ],
        );
      },
    );
  }

  Widget _buildDayView(Map<DateTime, List<CalendarEvent>> allEvents, String familyId) {
    if (_selectedDay == null) {
      return const Center(child: Text('请选择日期'));
    }
    final dayEvents = allEvents[DateTime(
          _selectedDay!.year,
          _selectedDay!.month,
          _selectedDay!.day,
        )] ??
        [];

    if (dayEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: EmptyState(
          emoji: '📅',
          title: '当天暂无安排',
          subtitle: '点击右上角"+"添加',
        ),
      );
    }

    final appointments = dayEvents.where((e) => e.type == EventType.appointment).toList();
    final tasks = dayEvents.where((e) => e.type == EventType.task).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (appointments.isNotEmpty) ...[
          const _SectionTag(label: '复诊', color: AppColors.coral),
          const SizedBox(height: 8),
          ...appointments.map((e) => _AppointmentCard(
                appointment: e.appointment!,
                familyId: familyId,
              )),
          const SizedBox(height: 12),
        ],
        if (tasks.isNotEmpty) ...[
          const _SectionTag(label: '任务', color: AppColors.blue),
          const SizedBox(height: 8),
          ...tasks.map((e) => _TaskCardCompact(
                task: e.task!,
                familyId: familyId,
              )),
        ],
      ],
    );
  }
}

/// 视图切换按钮
class _ViewToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ViewToggle({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.primary : AppColors.textTertiary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 复诊卡片（设计稿风格）
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String familyId;
  const _AppointmentCard({required this.appointment, required this.familyId});

  String get _dateLabel {
    final d = appointment.appointmentTime;
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${d.month}月${d.day}日（${weekdays[d.weekday - 1]}）';
  }

  String get _timeLabel {
    final d = appointment.appointmentTime;
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recipient = appointment.recipient;
    final recipientEmoji = recipient?.avatarEmoji ?? '👤';
    final recipientName = recipient?.name ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          // 顶部：日期时间
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                Text(
                  _dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.coral,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _timeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 内容区
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 照护对象 + 类型
                Row(
                  children: [
                    Text(recipientEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      recipientName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '复诊',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 医院 + 科室 + 医生
                Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded,
                        color: AppColors.textSecondary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${appointment.hospital}${appointment.department != null ? ' · ${appointment.department}' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (appointment.doctorName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        appointment.doctorName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (appointment.address != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          appointment.address!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (appointment.assignedDriver != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_rounded,
                          color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '接送: ${appointment.assignedDriver!.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (appointment.note != null && appointment.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.sticky_note_2_rounded,
                          color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          appointment.note!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // 操作按钮行
                Row(
                  children: [
                    if (appointment.doctorPhone != null)
                      _ActionBtn(
                        icon: Icons.phone_rounded,
                        label: '联系医生',
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
                    const Spacer(),
                    // 提醒状态
                    Row(
                      children: [
                        const Icon(Icons.notifications_rounded,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          appointment.reminder48h ? '☑ 48h前' : '☐ 48h前',
                          style: TextStyle(
                            fontSize: 11,
                            color: appointment.reminder48h
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          appointment.reminder24h ? '☑ 24h前' : '☐ 24h前',
                          style: TextStyle(
                            fontSize: 11,
                            color: appointment.reminder24h
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _callDoctor(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openMap(Appointment apt) async {
    Uri uri;
    if (apt.latitude != null && apt.longitude != null) {
      uri = Uri.parse(
          'https://maps.apple.com/?ll=${apt.latitude},${apt.longitude}');
    } else if (apt.address != null) {
      uri = Uri.parse(
          'https://maps.apple.com/?q=${Uri.encodeComponent(apt.address!)}');
    } else {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 合并事件（复诊+任务统一排序）
class _MergedEvent {
  final DateTime time;
  final CalendarEvent event;
  _MergedEvent({required this.time, required this.event});
}

/// 分组标题标签
class _SectionTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 日历单元格（自定义，支持 emoji dot）
class _CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final List<CalendarEvent> events;

  const _CalendarDayCell({
    required this.day,
    this.isSelected = false,
    this.isToday = false,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final hasAppointment = events.any((e) => e.type == EventType.appointment);
    final hasTask = events.any((e) => e.type == EventType.task);
    final appointmentEmoji = events
        .where((e) => e.type == EventType.appointment)
        .firstOrNull
        ?.appointment
        ?.recipient
        ?.avatarEmoji;
    final isWeekend = day.weekday == 6 || day.weekday == 7;

    Color bgColor = Colors.transparent;
    Color textColor = isWeekend ? AppColors.textSecondary : AppColors.textPrimary;

    if (isSelected) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = AppColors.primary.withValues(alpha: 0.15);
      textColor = AppColors.primaryDark;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasAppointment && appointmentEmoji != null)
                  Text(appointmentEmoji, style: const TextStyle(fontSize: 7)),
                if (hasAppointment && appointmentEmoji == null)
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.coral, shape: BoxShape.circle,
                    ),
                  ),
                if (hasTask)
                  Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.only(left: 1),
                    decoration: const BoxDecoration(
                      color: AppColors.blue, shape: BoxShape.circle,
                    ),
                  ),
                if (events.length > 1)
                  Container(
                    margin: const EdgeInsets.only(left: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${events.length - 1}',
                      style: const TextStyle(fontSize: 6, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 任务紧凑卡片
class _TaskCardCompact extends ConsumerWidget {
  final FamilyTask task;
  final String familyId;

  const _TaskCardCompact({required this.task, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipient = task.recipient;
    final recipientEmoji = recipient?.avatarEmoji ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 左侧：复诊色块标识
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // 中间内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (recipientEmoji.isNotEmpty) ...[
                        Text(recipientEmoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 频率标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.frequencyLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (task.scheduledTime != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          task.scheduledTime!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (task.assignee != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.person_outline_rounded,
                            size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          task.assignee!.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (task.note != null && task.note!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      task.note!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 右侧：完成按钮
            if (task.isPending)
              _CompleteBtn(task: task, familyId: familyId),
          ],
        ),
      ),
    );
  }
}

/// 任务完成按钮
class _CompleteBtn extends ConsumerWidget {
  final FamilyTask task;
  final String familyId;

  const _CompleteBtn({required this.task, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showCompleteDialog(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppColors.success,
          size: 20,
        ),
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认完成'),
        content: Text('确定已完成任务"${task.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/family-tasks/${task.id}/complete',
                    queryParameters: {'familyId': familyId});
                ref.invalidate(familyTasksProvider(familyId));
                ref.invalidate(upcomingTasksProvider(familyId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('任务已完成')),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('操作失败: $e')),
                  );
                }
              }
            },
            child: const Text('确认', style: TextStyle(color: Colors.white)),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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

/// 添加选项底部弹层
class _AddBottomSheet extends StatelessWidget {
  final VoidCallback onAddAppointment;
  final VoidCallback onAddTask;
  final VoidCallback onViewTasks;

  const _AddBottomSheet({
    required this.onAddAppointment,
    required this.onAddTask,
    required this.onViewTasks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '添加',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AddSheetItem(
                      emoji: '🏥',
                      label: '添加复诊',
                      color: AppColors.coral,
                      onTap: onAddAppointment,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AddSheetItem(
                      emoji: '📝',
                      label: '添加任务',
                      color: AppColors.blue,
                      onTap: onAddTask,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _AddSheetItem(
                  emoji: '📋',
                  label: '查看所有任务',
                  color: AppColors.primary,
                  onTap: onViewTasks,
                  wide: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddSheetItem extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool wide;

  const _AddSheetItem({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

