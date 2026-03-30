/// 日历管理页（复诊/任务 Tab 切换）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/appointment_task_detail_sheets.dart';

class CalendarManagementPage extends ConsumerStatefulWidget {
  /// initialTab: 'appointments' 或 'tasks'
  final String initialTab;

  const CalendarManagementPage({
    super.key,
    this.initialTab = 'appointments',
  });

  @override
  ConsumerState<CalendarManagementPage> createState() => _CalendarManagementPageState();
}

class _CalendarManagementPageState extends ConsumerState<CalendarManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'tasks' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('日历管理')),
        body: const EmptyState(
          emoji: '🏠',
          title: '请先加入一个家庭',
          subtitle: '在"我的"页面加入或创建家庭后使用',
        ),
      );
    }

    final role = family.myRole;

    // 保姆模式只有任务Tab
    final isCaregiver = role == FamilyMemberRole.caregiver;

    if (isCaregiver) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('我的任务'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: _TaskTab(
          familyId: family.id,
          canManage: false,
          canComplete: role.canCompleteTask,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('日历管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '复诊', icon: Icon(Icons.local_hospital_rounded, size: 20)),
            Tab(text: '任务', icon: Icon(Icons.task_alt_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // === 复诊 Tab ===
          _AppointmentTab(
            familyId: family.id,
            canManage: role.canCreateAppointment,
          ),
          // === 任务 Tab ===
          _TaskTab(
            familyId: family.id,
            canManage: role.canManageTask,
            canComplete: role.canCompleteTask,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 复诊列表
// ═══════════════════════════════════════════════════════════════

class _AppointmentTab extends ConsumerStatefulWidget {
  final String familyId;
  final bool canManage;

  const _AppointmentTab({required this.familyId, required this.canManage});

  @override
  ConsumerState<_AppointmentTab> createState() => _AppointmentTabState();
}

class _AppointmentTabState extends ConsumerState<_AppointmentTab> {
  late int _queryYear;
  late int _queryMonth;
  String _filter = 'upcoming';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _queryYear = now.year;
    _queryMonth = now.month;
  }

  void _goPrevMonth() {
    setState(() {
      if (_queryMonth == 1) { _queryMonth = 12; _queryYear--; } else { _queryMonth--; }
    });
  }

  void _goNextMonth() {
    setState(() {
      if (_queryMonth == 12) { _queryMonth = 1; _queryYear++; } else { _queryMonth++; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = CalendarQuery(familyId: widget.familyId, year: _queryYear, month: _queryMonth);
    final appointmentsAsync = ref.watch(calendarAppointmentsProvider(query));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _goPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 8),
              Text(
                '$_queryYear年$_queryMonth月',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _goNextMonth,
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        _buildFilterBar(),
        Expanded(
          child: appointmentsAsync.when(
            data: (appointments) => _buildList(appointments),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final filters = [('全部', 'all'), ('待复诊', 'upcoming'), ('已完成', 'completed')];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _filter = f.$2),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.coral.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.coral.withValues(alpha: 0.4) : AppColors.border,
                  ),
                ),
                child: Text(
                  f.$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.coral : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(List<Appointment> appointments) {
    final now = DateTime.now();
    final filtered = appointments.where((a) {
      if (_filter == 'upcoming') return a.status == 'upcoming' && a.appointmentTime.isAfter(now.subtract(const Duration(hours: 1)));
      if (_filter == 'completed') return a.status == 'completed';
      return true;
    }).toList();

    filtered.sort((a, b) => b.appointmentTime.compareTo(a.appointmentTime));

    if (filtered.isEmpty) {
      return EmptyState(
        emoji: _filter == 'all' ? '🏥' : '✅',
        title: _filter == 'all' ? '暂无复诊记录' : '暂无${_filter == 'upcoming' ? '待复诊' : '已完成'}记录',
        subtitle: widget.canManage ? '点击右上角"+"添加复诊' : null,
      );
    }

    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () async {
        ref.invalidate(calendarAppointmentsProvider(CalendarQuery(
          familyId: widget.familyId,
          year: _queryYear,
          month: _queryMonth,
        )));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _AppointmentListCard(
          appointment: filtered[index],
          familyId: widget.familyId,
          onComplete: widget.canManage && filtered[index].status == 'upcoming'
              ? () => _completeAppointment(filtered[index])
              : null,
          onDelete: widget.canManage ? () => _deleteAppointment(filtered[index]) : null,
        ),
      ),
    );
  }

  Future<void> _deleteAppointment(Appointment appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 ${appt.hospital} 复诊吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/appointments/${appt.id}', queryParameters: {'familyId': widget.familyId});
      ref.invalidate(calendarAppointmentsProvider(CalendarQuery(
        familyId: widget.familyId,
        year: _queryYear,
        month: _queryMonth,
      )));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('复诊已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _completeAppointment(Appointment appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认完成'),
        content: Text('确定将 ${appt.hospital} 复诊标记为已完成吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/appointments/${appt.id}/status',
        queryParameters: {'familyId': widget.familyId},
        data: {'status': 'completed'},
      );
      ref.invalidate(calendarAppointmentsProvider(CalendarQuery(
        familyId: widget.familyId,
        year: _queryYear,
        month: _queryMonth,
      )));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('复诊已完成')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }
}

class _AppointmentListCard extends StatelessWidget {
  final Appointment appointment;
  final String familyId;
  final VoidCallback? onDelete;
  final VoidCallback? onComplete;

  const _AppointmentListCard({
    required this.appointment,
    required this.familyId,
    this.onDelete,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final r = appointment.recipient;
    final d = appointment.appointmentTime;
    final wd = ['一', '二', '三', '四', '五', '六', '日'];
    final isCompleted = appointment.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (c) => AppointmentDetailSheet(appointment: appointment),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
              ],
              border: Border(
                left: BorderSide(color: isCompleted ? AppColors.success : AppColors.coral, width: 4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(r?.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${r?.name ?? ''} · ${d.month}月${d.day}日（${wd[d.weekday - 1]}）',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.local_hospital_rounded, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              appointment.hospital,
                              style: TextStyle(fontSize: 13, color: isCompleted ? AppColors.textTertiary : AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (appointment.department != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          appointment.department!,
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onComplete != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onComplete,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_rounded, size: 18, color: AppColors.success),
                    ),
                  ),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, color: AppColors.textTertiary, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 任务列表（复用 FamilyTasksPage 的逻辑）
// ═══════════════════════════════════════════════════════════════

class _TaskTab extends ConsumerStatefulWidget {
  final String familyId;
  final bool canManage;
  final bool canComplete;

  const _TaskTab({
    required this.familyId,
    required this.canManage,
    required this.canComplete,
  });

  @override
  ConsumerState<_TaskTab> createState() => _TaskTabState();
}

class _TaskTabState extends ConsumerState<_TaskTab> {
  String _filter = 'pending';
  late int _queryYear;
  late int _queryMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _queryYear = now.year;
    _queryMonth = now.month;
  }

  void _goPrevMonth() {
    setState(() {
      if (_queryMonth == 1) {
        _queryMonth = 12;
        _queryYear--;
      } else {
        _queryMonth--;
      }
    });
  }

  void _goNextMonth() {
    setState(() {
      if (_queryMonth == 12) {
        _queryMonth = 1;
        _queryYear++;
      } else {
        _queryMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(managementTasksProvider(ManagementTasksQuery(
      familyId: widget.familyId,
      year: _queryYear,
      month: _queryMonth,
    )));

    return Column(
      children: [
        // 月份导航
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _goPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 8),
              Text(
                '$_queryYear年$_queryMonth月',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _goNextMonth,
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        _TaskFilterBar(
          filter: _filter,
          onFilterChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: tasksAsync.when(
            data: (tasks) => _TaskListView(
              tasks: tasks,
              familyId: widget.familyId,
              year: _queryYear,
              month: _queryMonth,
              canManage: widget.canManage,
              canComplete: widget.canComplete,
              filter: _filter,
              onDelete: widget.canManage ? _deleteTask : null,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteTask(FamilyTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除任务「${task.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/family-tasks/${task.id}', queryParameters: {'familyId': widget.familyId});
      // 递增刷新计数器，calendarTasksProvider 监听了它，所有月份缓存同步失效
      ref.read(calendarRefreshProvider.notifier).state++;
      ref.invalidate(managementTasksProvider(ManagementTasksQuery(familyId: widget.familyId, year: _queryYear, month: _queryMonth)));
      ref.invalidate(upcomingTasksProvider(widget.familyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }
}

class _TaskFilterBar extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _TaskFilterBar({
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [('全部', 'all'), ('待完成', 'pending'), ('已完成', 'completed')];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: filters.map((f) {
          final selected = filter == f.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onFilterChanged(f.$2),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.blue.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.blue.withValues(alpha: 0.4) : AppColors.border,
                  ),
                ),
                child: Text(
                  f.$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.blue : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TaskListView extends ConsumerWidget {
  final List<FamilyTask> tasks;
  final String familyId;
  final int year;
  final int month;
  final bool canManage;
  final bool canComplete;
  final String filter;
  final void Function(FamilyTask task)? onDelete;

  const _TaskListView({
    required this.tasks,
    required this.familyId,
    required this.year,
    required this.month,
    required this.canManage,
    required this.canComplete,
    required this.filter,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = tasks.where((t) {
      if (filter == 'pending') return t.status == 'pending' || t.status == 'overdue';
      if (filter == 'completed') return t.status == 'completed';
      return t.status != 'cancelled';
    }).toList();

    if (filtered.isEmpty) {
      return EmptyState(
        emoji: filter == 'pending' ? '✅' : '📝',
        title: filter == 'all' ? '暂无任务' : '暂无${filter == 'pending' ? '待完成' : '已完成'}任务',
        subtitle: canManage ? '点击右上角"+"添加任务' : null,
      );
    }

    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: () async {
        ref.invalidate(managementTasksProvider(ManagementTasksQuery(familyId: familyId, year: year, month: month)));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _TaskListCard(
          task: filtered[index],
          familyId: familyId,
          year: year,
          month: month,
          canManage: canManage,
          canComplete: canComplete,
          onDelete: canManage ? () => onDelete?.call(filtered[index]) : null,
        ),
      ),
    );
  }
}

class _TaskListCard extends ConsumerWidget {
  final FamilyTask task;
  final String familyId;
  final int year;
  final int month;
  final bool canManage;
  final bool canComplete;
  final VoidCallback? onDelete;

  const _TaskListCard({
    required this.task,
    required this.familyId,
    required this.year,
    required this.month,
    required this.canManage,
    required this.canComplete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = task.status == 'pending' || task.status == 'overdue';
    // 照护人只能完成分配给自己的任务
    final role = ref.watch(currentFamilyProvider)?.myRole ?? FamilyMemberRole.guest;
    final currentUserId = ref.watch(authStateProvider).user?.id;
    final canCompleteThis = role == FamilyMemberRole.caregiver
        ? (currentUserId != null && task.assigneeId == currentUserId)
        : canComplete;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (c) => TaskDetailSheet(
              task: task,
              familyId: familyId,
              scheduledDate: task.nextDueAt != null ? '${task.nextDueAt!.year}-${task.nextDueAt!.month.toString().padLeft(2, '0')}-${task.nextDueAt!.day.toString().padLeft(2, '0')}' : null,
              onComplete: () {
                ref.invalidate(familyTasksProvider(familyId));
                ref.invalidate(calendarTasksProvider(CalendarQuery(
                  familyId: familyId,
                  year: DateTime.now().year,
                  month: DateTime.now().month,
                )));
              },
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
              ],
              border: Border(
                left: BorderSide(color: isPending ? AppColors.blue : AppColors.success, width: 4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(task.recipient?.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isPending ? AppColors.textPrimary : AppColors.textTertiary,
                                decoration: isPending ? null : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.description != null && task.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.description!.length > 30
                              ? '${task.description!.substring(0, 30)}…'
                              : task.description!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Chip(label: task.frequencyLabel, color: AppColors.blue),
                          if (task.scheduledTime != null) _Chip(label: task.scheduledTime!, color: AppColors.textSecondary),
                          if (task.nextDueAt != null) _Chip(label: task.displayDueAt, color: AppColors.coral),
                          if (task.assignee != null) _Chip(label: task.assignee!.displayName, color: AppColors.textTertiary),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPending && canCompleteThis) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _completeTask(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_rounded, size: 18, color: AppColors.success),
                    ),
                  ),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, color: AppColors.textTertiary, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeTask(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      final dueDate = task.nextDueAt;
      final scheduledDate = dueDate != null
          ? '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}'
          : null;
      await dio.post('/family-tasks/${task.id}/complete',
          queryParameters: {'familyId': familyId},
          data: scheduledDate != null ? {'scheduledDate': scheduledDate} : {});
      ref.invalidate(managementTasksProvider(ManagementTasksQuery(familyId: familyId, year: year, month: month)));
      ref.invalidate(calendarTasksProvider(CalendarQuery(
        familyId: familyId,
        year: DateTime.now().year,
        month: DateTime.now().month,
      )));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已完成')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
