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
  bool _showList = true;

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
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      // 核心布局：Column + Flexible，无嵌套滚动
      body: Column(
        children: [
          _buildMonthHeader(),
          eventsAsync.when(
            data: (events) => _buildCalendar(events),
            loading: () => _buildCalendar({}),
            error: (_, __) => _buildCalendar({}),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(child: _buildEventsSection(familyId, eventsAsync)),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              _selectedDay = _focusedDay;
            }),
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
            onPressed: () => setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              _selectedDay = _focusedDay;
            }),
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
      daysOfWeekHeight: 28,
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
        todayTextStyle: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
        selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
        weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
        outsideTextStyle: const TextStyle(color: AppColors.textTertiary),
        cellMargin: const EdgeInsets.all(2),
        cellPadding: EdgeInsets.zero,
      ),
      headerVisible: false,
      // 日历只占所需高度，不滚动
      availableGestures: AvailableGestures.horizontalSwipe,
    );
  }

  Widget _buildEventsSection(
    String familyId,
    AsyncValue<Map<DateTime, List<CalendarEvent>>> eventsAsync,
  ) {
    return Column(
      children: [
        // 标签行（固定高度）
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
              _ToggleBtn(
                icon: Icons.view_agenda_rounded,
                label: '列表',
                selected: _showList,
                onTap: () => setState(() => _showList = true),
              ),
              const SizedBox(width: 4),
              _ToggleBtn(
                icon: Icons.calendar_today_rounded,
                label: '当天',
                selected: !_showList,
                onTap: () => setState(() => _showList = false),
              ),
            ],
          ),
        ),
        // 内容（占满剩余空间）
        Expanded(
          child: eventsAsync.when(
            data: (allEvents) {
              if (_showList) {
                return _EventListView(allEvents: allEvents, familyId: familyId);
              } else {
                return _DayEventsView(
                  allEvents: allEvents,
                  familyId: familyId,
                  selectedDay: _selectedDay,
                );
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _AddBtn(emoji: '🏥', label: '添加复诊', color: AppColors.coral, onTap: () { Navigator.pop(ctx); context.push(AppRoutes.addAppointment); })),
                    const SizedBox(width: 12),
                    Expanded(child: _AddBtn(emoji: '📝', label: '添加任务', color: AppColors.blue, onTap: () { Navigator.pop(ctx); context.push(AppRoutes.addTask); })),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _AddBtn(emoji: '📋', label: '查看所有任务', color: AppColors.primary, wide: true, onTap: () { Navigator.pop(ctx); context.push(AppRoutes.familyTasks); }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 视图切换按钮
class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? AppColors.primary : AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: selected ? AppColors.primary : AppColors.textTertiary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

/// 列表视图（按日期分组）
class _EventListView extends StatelessWidget {
  final Map<DateTime, List<CalendarEvent>> allEvents;
  final String familyId;
  const _EventListView({required this.allEvents, required this.familyId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final all = <_Item>[];
    for (final e in allEvents.entries) {
      for (final ev in e.value) {
        all.add(_Item(
          time: ev.type == EventType.appointment
              ? ev.appointment!.appointmentTime
              : ev.task!.nextDueAt ?? DateTime.now(),
          ev: ev,
        ));
      }
    }
    all.sort((a, b) => a.time.compareTo(b.time));
    final future = all.where((i) => i.time.isAfter(now.subtract(const Duration(days: 1)))).toList();

    if (future.isEmpty) {
      return const EmptyState(emoji: '📅', title: '本月暂无日程安排', subtitle: '点击右上角"+"添加复诊或任务');
    }

    final grouped = <String, List<_Item>>{};
    for (final i in future) {
      final k = '${i.time.year}-${i.time.month}-${i.time.day}';
      grouped.putIfAbsent(k, () => []).add(i);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final items = grouped.values.elementAt(i);
        final date = items.first.time;
        const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text('${date.month}月${date.day}日 · ${wd[date.weekday - 1]}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
            ),
            ...items.map((item) {
              if (item.ev.type == EventType.appointment) {
                return _AppointmentCard(appointment: item.ev.appointment!, familyId: familyId);
              } else {
                return _TaskCard(task: item.ev.task!, familyId: familyId);
              }
            }),
          ],
        );
      },
    );
  }
}

/// 当天视图
class _DayEventsView extends StatelessWidget {
  final Map<DateTime, List<CalendarEvent>> allEvents;
  final String familyId;
  final DateTime? selectedDay;
  const _DayEventsView({required this.allEvents, required this.familyId, this.selectedDay});

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) return const Center(child: Text('请选择日期'));
    final dayEvents = allEvents[DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day)] ?? [];
    if (dayEvents.isEmpty) {
      return const EmptyState(emoji: '📅', title: '当天暂无安排', subtitle: '点击右上角"+"添加');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (dayEvents.any((e) => e.type == EventType.appointment)) ...[
          const _SectionTag(label: '复诊', color: AppColors.coral),
          const SizedBox(height: 8),
          ...dayEvents.where((e) => e.type == EventType.appointment)
              .map((e) => _AppointmentCard(appointment: e.appointment!, familyId: familyId)),
          const SizedBox(height: 12),
        ],
        if (dayEvents.any((e) => e.type == EventType.task)) ...[
          const _SectionTag(label: '任务', color: AppColors.blue),
          const SizedBox(height: 8),
          ...dayEvents.where((e) => e.type == EventType.task)
              .map((e) => _TaskCard(task: e.task!, familyId: familyId)),
        ],
      ],
    );
  }
}

class _Item {
  final DateTime time;
  final CalendarEvent ev;
  _Item({required this.time, required this.ev});
}

/// 分组标题
class _SectionTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
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
    final r = appointment.recipient;
    final d = appointment.appointmentTime;
    const wd = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2))],
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
            child: Row(
              children: [
                Text('${d.month}月${d.day}日（${wd[d.weekday - 1]}）', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.coral)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.coral)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r?.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(r?.name ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('复诊', style: TextStyle(fontSize: 11, color: AppColors.primary))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text('${appointment.hospital}${appointment.department != null ? ' · ${appointment.department}' : ''}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                  ],
                ),
                if (appointment.doctorName != null) ...[
                  const SizedBox(height: 3),
                  Row(children: [const Icon(Icons.person_rounded, size: 14, color: AppColors.textSecondary), const SizedBox(width: 4), Text(appointment.doctorName!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))]),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (appointment.doctorPhone != null) _ActBtn(icon: Icons.phone_rounded, label: '联系医生', color: AppColors.primary, onTap: () async { final u = Uri.parse('tel:${appointment.doctorPhone}'); if (await canLaunchUrl(u)) await launchUrl(u); }),
                    if (appointment.address != null) ...[const SizedBox(width: 8), _ActBtn(icon: Icons.map_rounded, label: '导航', color: AppColors.blue, onTap: () async { final addr = Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(appointment.address!)}'); if (await canLaunchUrl(addr)) await launchUrl(addr, mode: LaunchMode.externalApplication); })],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2))],
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 44, decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(task.recipient?.avatarEmoji ?? '', style: const TextStyle(fontSize: 16)),
                    if (task.recipient != null) const SizedBox(width: 4),
                    Expanded(child: Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(task.frequencyLabel, style: const TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w500))),
                    if (task.scheduledTime != null) ...[const SizedBox(width: 6), Text(task.scheduledTime!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))],
                    if (task.assignee != null) ...[const SizedBox(width: 8), const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textTertiary), const SizedBox(width: 2), Text(task.assignee!.name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))],
                  ],
                ),
              ],
            ),
          ),
          if (task.isPending)
            InkWell(
              onTap: () => _complete(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  void _complete(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/family-tasks/${task.id}/complete', queryParameters: {'familyId': familyId});
      final now = DateTime.now();
      ref.invalidate(calendarEventsProvider(CalendarQuery(familyId: familyId, year: now.year, month: now.month)));
      ref.invalidate(familyTasksProvider(familyId));
      ref.invalidate(upcomingTasksProvider(familyId));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已完成')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }
}

/// 操作按钮
class _ActBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 15), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))]),
      ),
    );
  }
}

/// 添加按钮
class _AddBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool wide;
  const _AddBtn({required this.emoji, required this.label, required this.color, required this.onTap, this.wide = false});
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
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [Text(emoji, style: const TextStyle(fontSize: 28)), const SizedBox(height: 6), Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))]),
      ),
    );
  }
}
