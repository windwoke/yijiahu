/// 家庭任务管理页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class FamilyTasksPage extends ConsumerStatefulWidget {
  const FamilyTasksPage({super.key});

  @override
  ConsumerState<FamilyTasksPage> createState() => _FamilyTasksPageState();
}

class _FamilyTasksPageState extends ConsumerState<FamilyTasksPage> {
  String _filterStatus = 'all'; // all, pending, completed

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('家庭任务')),
        body: const EmptyState(
          emoji: '🏠',
          title: '请先加入一个家庭',
          subtitle: '在"我的"页面加入或创建家庭',
        ),
      );
    }

    final familyId = family.id;
    final tasksAsync = ref.watch(familyTasksProvider(familyId));
    final role = family.myRole;
    final canManage = role.canManageTask;
    final canComplete = role.canCompleteTask;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('家庭任务'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: '添加任务',
              onPressed: () => context.push(AppRoutes.addTask),
            ),
        ],
      ),
      body: Column(
        children: [
          // 过滤器
          _buildFilterBar(),
          // 任务列表
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => _buildTaskList(tasks, familyId, canManage, canComplete),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('全部', 'all'),
      ('待完成', 'pending'),
      ('已完成', 'completed'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: filters.map((f) {
          final selected = _filterStatus == f.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _filterStatus = f.$2),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  f.$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskList(List<FamilyTask> allTasks, String familyId, bool canManage, bool canComplete) {
    final filtered = allTasks.where((t) {
      if (_filterStatus == 'all') return t.status != 'cancelled';
      return t.status == _filterStatus;
    }).toList();

    // 排序：待完成优先，按截止时间排
    filtered.sort((a, b) {
      if (a.status == 'pending' && b.status != 'pending') return -1;
      if (a.status != 'pending' && b.status == 'pending') return 1;
      if (a.nextDueAt != null && b.nextDueAt != null) {
        return a.nextDueAt!.compareTo(b.nextDueAt!);
      }
      return 0;
    });

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: EmptyState(
          emoji: _filterStatus == 'pending' ? '✅' : '📝',
          title: _filterStatus == 'pending'
              ? '暂无待完成任务'
              : _filterStatus == 'completed'
                  ? '暂无已完成任务'
                  : '暂无任务',
          subtitle: _filterStatus == 'all'
              ? (canManage ? '点击右上角"+"添加任务' : null)
              : null,
        ),
      );
    }

    // 按状态分组
    final pending = filtered.where((t) => t.status == 'pending').toList();
    final completed = filtered.where((t) => t.status == 'completed').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (pending.isNotEmpty) ...[
          _buildGroupHeader('待完成', pending.length, AppColors.coral),
          const SizedBox(height: 8),
          ...pending.map((t) => _TaskListCard(
                task: t,
                familyId: familyId,
                canManage: canManage,
                canComplete: canComplete,
                onComplete: canComplete ? () => _completeTask(t, familyId) : null,
                onCancel: canManage ? () => _cancelTask(t, familyId) : null,
                onEdit: canManage ? () => context.push(AppRoutes.addTask, extra: t) : null,
                onDelete: canManage ? () => _deleteTask(t, familyId) : null,
              )),
          const SizedBox(height: 16),
        ],
        if (completed.isNotEmpty) ...[
          _buildGroupHeader('已完成', completed.length, AppColors.success),
          const SizedBox(height: 8),
          ...completed.map((t) => _TaskListCard(
                task: t,
                familyId: familyId,
                canManage: canManage,
                canComplete: false,
                onComplete: null,
                onCancel: null,
                onEdit: null,
                onDelete: canManage ? () => _deleteTask(t, familyId) : null,
              )),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _completeTask(FamilyTask task, String familyId) async {
    try {
      final dio = ref.read(dioProvider);
      // 周期任务：scheduledDate 传今天日期
      // 单次任务：scheduledDate 传 nextDueAt 对应日期
      String? scheduledDate;
      if (task.frequency != 'once') {
        final now = DateTime.now();
        scheduledDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      } else if (task.nextDueAt != null) {
        scheduledDate = '${task.nextDueAt!.year}-${task.nextDueAt!.month.toString().padLeft(2, '0')}-${task.nextDueAt!.day.toString().padLeft(2, '0')}';
      }
      await dio.post('/family-tasks/${task.id}/complete',
          data: scheduledDate != null ? {'scheduledDate': scheduledDate} : {},
          queryParameters: {'familyId': familyId});
      ref.invalidate(familyTasksProvider(familyId));
      ref.invalidate(upcomingTasksProvider(familyId));
      // 递增刷新计数器，CalendarPage 自动重新拉取
      ref.read(calendarRefreshProvider.notifier).update((s) => s + 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务已完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _cancelTask(FamilyTask task, String familyId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/family-tasks/${task.id}',
          data: {'status': 'cancelled', 'familyId': familyId},
          queryParameters: {'familyId': familyId});
      ref.invalidate(familyTasksProvider(familyId));
      // 递增刷新计数器，CalendarPage 自动重新拉取
      ref.read(calendarRefreshProvider.notifier).update((s) => s + 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务已取消')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(FamilyTask task, String familyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除任务"${task.title}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/family-tasks/${task.id}',
          queryParameters: {'familyId': familyId});
      ref.invalidate(familyTasksProvider(familyId));
      // 递增刷新计数器，CalendarPage 自动重新拉取
      ref.read(calendarRefreshProvider.notifier).update((s) => s + 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}

/// 任务列表卡片
class _TaskListCard extends StatelessWidget {
  final FamilyTask task;
  final String familyId;
  final bool canManage;
  final bool canComplete;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TaskListCard({
    required this.task,
    required this.familyId,
    required this.canManage,
    required this.canComplete,
    this.onComplete,
    this.onCancel,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final recipient = task.recipient;
    final recipientEmoji = recipient?.avatarEmoji ?? '';
    final isPending = task.status == 'pending';

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
          // 顶部色条
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isPending ? AppColors.primary : AppColors.success,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：标题 + 状态
                Row(
                  children: [
                    if (recipientEmoji.isNotEmpty) ...[
                      Text(recipientEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                          decoration:
                              isPending ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    // 状态标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPending ? AppColors.primary : AppColors.success)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPending ? AppColors.primary : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // 第二行：标签行
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      icon: Icons.repeat_rounded,
                      label: task.frequencyLabel,
                      color: AppColors.blue,
                    ),
                    if (task.scheduledTime != null)
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        label: task.scheduledTime!,
                        color: AppColors.coral,
                      ),
                    if (task.nextDueAt != null)
                      _InfoChip(
                        icon: Icons.event_rounded,
                        label: task.displayDueAt,
                        color: AppColors.textTertiary,
                      ),
                    if (task.assignee != null)
                      _InfoChip(
                        icon: Icons.person_outline_rounded,
                        label: task.assignee!.fullDisplayName,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
                // 操作按钮行
                if (isPending && (onComplete != null || onCancel != null)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (onComplete != null)
                        _ActionChip(
                          icon: Icons.check_rounded,
                          label: '完成',
                          color: AppColors.success,
                          onTap: onComplete!,
                        ),
                      if (onComplete != null && onCancel != null)
                        const SizedBox(width: 8),
                      if (onCancel != null)
                        _ActionChip(
                          icon: Icons.close_rounded,
                          label: '取消',
                          color: AppColors.textTertiary,
                          onTap: onCancel!,
                        ),
                      const Spacer(),
                      if (canManage && onEdit != null)
                        _ActionChip(
                          icon: Icons.edit_rounded,
                          label: '编辑',
                          color: AppColors.primary,
                          onTap: onEdit!,
                        ),
                      if (canManage && onDelete != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline_rounded,
                                color: AppColors.textTertiary, size: 18),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
