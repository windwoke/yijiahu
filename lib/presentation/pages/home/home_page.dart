/// 首页 - 今日待办
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/env/env_config.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../providers/providers.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/medication_check_in_card.dart';
import '../../widgets/appointment_task_detail_sheets.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final recipientsAsync = ref.watch(careRecipientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 主体内容（滚动）
          recipientsAsync.when(
            data: (recipients) {
              if (recipients.isEmpty) {
                return _buildEmptyStateBody(context);
              }
              return _buildContentBody(context, recipients);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('加载失败: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(careRecipientsProvider),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          // 固定顶栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassTopBar(context),
          ),
        ],
      ),
      // SOS 按钮固定在底部
      bottomNavigationBar: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SafeArea(
          top: false,
          child: const SosButton(),
        ),
      ),
    );
  }

  Widget _buildGlassTopBar(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    // 在线人数：后端暂无 presence 追踪，默认至少显示当前用户自己（1）
    final onlineCount = 1;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 家庭头像
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: family?.avatarUrl != null && family!.avatarUrl!.isNotEmpty
                          ? Image.network(
                              ApiConfig.avatarUrl(family.avatarUrl!) ?? '',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 18)),
                              ),
                            )
                          : const Center(
                              child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 18)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 家庭名称 + 在线人数
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          family?.name ?? '我的家庭',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$onlineCount人在线',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 通知图标
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onRefreshEmpty() async {
    ref.invalidate(careRecipientsProvider);
    await ref.read(careRecipientsProvider.future);
  }

  Widget _buildEmptyStateBody(BuildContext context) {
    final topHeight = MediaQuery.of(context).padding.top + 72;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _onRefreshEmpty(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topHeight)),
          SliverToBoxAdapter(child: _buildEmptyStateContent(context)),
          const SliverFillRemaining(hasScrollBody: false, child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyStateContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.shadowSoft2,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              AppTexts.noCareRecipients,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppTexts.addCareRecipientHint,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (ref.watch(currentFamilyProvider)?.myRole.canManageRecipients ?? false)
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.addCareRecipient),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    AppTexts.addCareRecipientBtn,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh(List<CareRecipient> recipients) async {
    // 刷新照护对象列表
    ref.invalidate(careRecipientsProvider);

    // 刷新每个照护对象的今日用药数据
    for (final r in recipients) {
      ref.invalidate(todayMedicationProvider(r.id));
    }

    // 等待数据重新加载完成
    await ref.read(careRecipientsProvider.future);
  }

  Widget _buildContentBody(
    BuildContext context,
    List<CareRecipient> recipients,
  ) {
    final topHeight = MediaQuery.of(context).padding.top + 72;
    final recipientIds = recipients.map((r) => r.id).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _onRefresh(recipients),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topHeight)),
          SliverToBoxAdapter(
            child: _DailyCareBanner(recipientIds: recipientIds, recipients: recipients),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // 第一个区块：日历摘要
                  if (index == 0) {
                    return _buildCalendarSummarySection(context);
                  }
                  // 照护对象列表
                  final recipientIndex = index - 1;
                  if (recipientIndex < recipients.length) {
                    return _buildRecipientSection(context, recipients[recipientIndex]);
                  }
                  return const SizedBox.shrink();
                },
                childCount: recipients.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSummarySection(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final query = CalendarQuery(
      familyId: family.id,
      year: now.year,
      month: now.month,
    );
    final appointmentsAsync = ref.watch(calendarAppointmentsProvider(query));
    final tasksAsync = ref.watch(upcomingTasksProvider(family.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 复诊提醒
        appointmentsAsync.when(
          data: (appointments) {
            final upcoming = appointments.where((a) =>
                a.status == 'upcoming' &&
                a.appointmentTime.isAfter(now) &&
                a.appointmentTime.isBefore(now.add(const Duration(days: 7)))).toList();
            if (upcoming.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  Icons.local_hospital_rounded, '复诊提醒', AppColors.coral, () => context.push('${AppRoutes.calendarManagement}?tab=appointments'),
                ),
                const SizedBox(height: 8),
                ...upcoming.take(2).map((a) => _AppointmentHomeCard(
                      appointment: a,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (c) => AppointmentDetailSheet(appointment: a),
                      ),
                    )),
                const SizedBox(height: 20),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // 今日任务：按 nextDueAt 是否到期过滤（不用 status，周期任务 status 永远是 pending）
        tasksAsync.when(
          data: (tasks) {
            final todayStart = DateTime(now.year, now.month, now.day);
            final todayEnd = todayStart.add(const Duration(days: 1));
            final todayTasks = tasks.where((t) {
              if (t.nextDueAt == null) return false;
              if (t.status == 'completed') return false; // 一次性任务已完成
              // 今天内到期的任务
              return t.nextDueAt!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
                  t.nextDueAt!.isBefore(todayEnd);
            }).toList();
            if (todayTasks.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  Icons.task_alt_rounded, '今日任务', AppColors.blue, () => context.push('${AppRoutes.calendarManagement}?tab=tasks'),
                ),
                const SizedBox(height: 8),
                ...todayTasks.take(2).map((t) => _TaskHomeCard(
                      task: t,
                      familyId: family.id,
                      onTap: () {
                        final now = DateTime.now();
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (c) => TaskDetailSheet(
                            task: t,
                            familyId: family.id,
                            scheduledDate: t.nextDueAt != null ? '${t.nextDueAt!.year}-${t.nextDueAt!.month.toString().padLeft(2, '0')}-${t.nextDueAt!.day.toString().padLeft(2, '0')}' : null,
                            onComplete: () {
                              ref.invalidate(upcomingTasksProvider(family.id));
                              ref.invalidate(familyTasksProvider(family.id));
                              ref.invalidate(calendarEventsProvider(CalendarQuery(
                                familyId: family.id,
                                year: now.year,
                                month: now.month,
                              )));
                            },
                          ),
                        );
                      },
                    )),
                const SizedBox(height: 20),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color, VoidCallback onSeeAll, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
        if (trailing != null) const SizedBox(width: 4),
        InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Text(
                  '查看全部',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: color),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientSection(
    BuildContext context,
    CareRecipient recipient,
  ) {
    final todayAsync = ref.watch(todayMedicationProvider(recipient.id));
    final caregiverAsync = ref.watch(currentCaregiverProvider(recipient.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 照护对象头部：emoji + 姓名 + 年龄 + 进度条
          _buildRecipientHeader(context, todayAsync, caregiverAsync, recipient),
          const SizedBox(height: 12),
          // 今日用药 2 列 Grid
          todayAsync.when(
            data: (today) => MedicationCheckInCard(
              today: today,
              onCheckIn: (item) async {
                if (item.id == null) return;
                final dio = ref.read(dioProvider);
                final familyId = ref.read(currentFamilyProvider)?.id;
                await dio.post('/medication-logs/${item.id}/check-in',
                    data: {'familyId': familyId, 'status': 'taken'});
                ref.invalidate(todayMedicationProvider(recipient.id));
              },
            ),
            loading: () => Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('加载失败'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientHeader(
    BuildContext context,
    AsyncValue<TodayMedicationSummary> todayAsync,
    AsyncValue<CaregiverRecord?> caregiverAsync,
    CareRecipient recipient,
  ) {
    final progress = todayAsync.whenOrNull(
      data: (today) =>
          today.total > 0 ? today.completed / today.total : 0.0,
    );

    return GestureDetector(
      onTap: () => context.push(AppRoutes.careRecipientDetail, extra: recipient),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 2)),
            BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            // 头像（优先真实照片，fallback emoji）
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (recipient.avatarUrl != null && recipient.avatarUrl!.isNotEmpty)
                    ? Image.network(
                        ApiConfig.avatarUrl(recipient.avatarUrl!) ?? '',
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        errorBuilder: (_, __, ___) => Text(recipient.displayAvatar, style: const TextStyle(fontSize: 24)),
                      )
                    : Center(
                        child: Text(recipient.displayAvatar, style: const TextStyle(fontSize: 24)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 姓名 + 年龄 + 主要负责人
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        recipient.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (recipient.age != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${recipient.age}岁',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 主要负责人
                  caregiverAsync.when(
                    data: (caregiver) {
                      if (caregiver?.caregiver == null) {
                        return Text(
                          '暂无主要照护人',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        );
                      }
                      return Row(
                        children: [
                          Icon(
                            Icons.person_pin_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '主要照护人：${caregiver!.displayName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  // 进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress ?? 0,
                      backgroundColor: AppColors.grey200,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 完成数 badge
            todayAsync.whenOrNull(
              data: (today) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: today.completed == today.total && today.total > 0
                      ? AppColors.medicationDone.withValues(alpha: 0.12)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${today.completed}/${today.total}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: today.completed == today.total && today.total > 0
                        ? AppColors.medicationDone
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ) ?? const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// 首页复诊卡片（紧凑）
class _AppointmentHomeCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onTap;

  const _AppointmentHomeCard({required this.appointment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final recipient = appointment.recipient;
    final d = appointment.appointmentTime;
    final bd = d.add(const Duration(hours: 8));
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final dateStr = '${bd.month}月${bd.day}日（${weekdays[bd.weekday - 1]}）';
    final timeStr = '${bd.hour.toString().padLeft(2, '0')}:${bd.minute.toString().padLeft(2, '0')}';

    Widget content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
        ],
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // 左侧色块
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (recipient != null) ...[
                      Text(recipient.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        recipient.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        appointment.hospital,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右侧日期时间
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.coral,
                  ),
                ),
              ),
            ],
          ),
          // 联系医生
          if (appointment.doctorPhone != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.parse('tel:${appointment.doctorPhone}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_rounded,
                    size: 16, color: AppColors.coral),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: content);
    }
    return content;
  }
}

/// 首页任务卡片（紧凑）
class _TaskHomeCard extends ConsumerWidget {
  final FamilyTask task;
  final String familyId;
  final VoidCallback? onTap;

  const _TaskHomeCard({required this.task, required this.familyId, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2)),
        ],
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // 左侧色块
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (task.recipient != null) ...[
                      Text(task.recipient!.avatarEmoji ?? '👤',
                          style: const TextStyle(fontSize: 16)),
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
                        overflow: TextOverflow.ellipsis,
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
                Row(
                  children: [
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
                        task.assignee!.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 完成按钮
          InkWell(
            onTap: () async {
              try {
                final dio = ref.read(dioProvider);
                final dueDate = task.nextDueAt;
                final scheduledDate = dueDate != null
                    ? '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}'
                    : null;
                await dio.post('/family-tasks/${task.id}/complete',
                    queryParameters: {'familyId': familyId},
                    data: scheduledDate != null ? {'scheduledDate': scheduledDate} : null);
                // 即时更新本地缓存
                if (dueDate != null) {
                  ref.read(completedInstancesProvider.notifier).update(
                      (s) => {...s, '${task.id}_$scheduledDate'});
                }
                final now = DateTime.now();
                ref.invalidate(upcomingTasksProvider(familyId));
                ref.invalidate(familyTasksProvider(familyId));
                ref.invalidate(calendarEventsProvider(CalendarQuery(
                  familyId: familyId,
                  year: now.year,
                  month: now.month,
                )));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('任务已完成')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('操作失败: $e')),
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 18, color: AppColors.success),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: content);
    }
    return content;
  }
}

/// 每日护理打卡横幅（独立 Consumer，避免在父级同步 build 中 ref.watch）
class _DailyCareBanner extends ConsumerWidget {
  final List<String> recipientIds;
  final List<CareRecipient> recipients;

  const _DailyCareBanner({required this.recipientIds, required this.recipients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(todayCheckinsProvider(recipientIds));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: _buildBanner(context, ref, checkinsAsync),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, DailyCareCheckin>> checkinsAsync,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 20, color: AppColors.coral),
              const SizedBox(width: 8),
              const Text(
                '今日护理打卡',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              if (checkinsAsync.isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          checkinsAsync.when(
            data: (checkins) {
              if (recipients.isEmpty) {
                return const Text('暂无照护对象', style: TextStyle(color: AppColors.textTertiary, fontSize: 13));
              }
              final visible = recipients.take(2).toList();
              final hasMore = recipients.length > 2;
              return Column(
                children: [
                  ...visible.map((r) => _buildRow(context, r, checkins[r.id])),
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => context.push(AppRoutes.dailyCare),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '查看全部 ${recipients.length} 人',
                              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => Column(
              children: List.generate(
                2,
                (i) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            error: (_, __) => const Text('加载失败', style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// 根据打卡状态返回图标和颜色（遵循设计搞语义色）
  (IconData, Color) _statusIcon(CheckinStatus? status, bool isCheckedIn) {
    if (!isCheckedIn) return (Icons.schedule_rounded, AppColors.textTertiary);
    switch (status!) {
      case CheckinStatus.normal:    return (Icons.check_circle_rounded, AppColors.success);  // 鼠尾草绿系
      case CheckinStatus.concerning: return (Icons.info_rounded, AppColors.warning);         // 暖琥珀
      case CheckinStatus.poor:      return (Icons.warning_rounded, AppColors.coral);          // 暖杏/陶土
      case CheckinStatus.critical:   return (Icons.error_rounded, AppColors.coral);           // 暖杏/陶土
    }
  }

  Widget _buildRow(BuildContext context, CareRecipient recipient, DailyCareCheckin? checkin) {
    final isCheckedIn = checkin != null;
    final status = checkin?.status;
    final (icon, iconColor) = _statusIcon(status, isCheckedIn);
    final isAlert = isCheckedIn && status != CheckinStatus.normal;
    final isCritical = isCheckedIn && status == CheckinStatus.critical;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.dailyCare, extra: {
          'recipientId': recipient.id,
          'recipient': recipient,
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCritical
                ? AppColors.coral.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isCritical
                ? Border.all(color: AppColors.coral, width: 2)
                : isAlert
                    ? Border.all(color: iconColor.withValues(alpha: 0.4), width: 1.5)
                    : Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: isCritical ? 24 : (isAlert ? 22 : 18), color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCritical ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 状态标签 + 用药情况
                    if (isCheckedIn) ...[
                      Row(
                        children: [
                          // 状态 chip：图标 + 文字
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: isCritical ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 11, color: iconColor),
                                const SizedBox(width: 3),
                                Text(
                                  status!.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: iconColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              checkin.medicationLabel,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        '今日尚未打卡',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCritical
                      ? AppColors.coral
                      : isCheckedIn
                          ? iconColor.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCheckedIn ? '已打卡' : '去打卡',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCritical
                        ? Colors.white
                        : isCheckedIn
                            ? iconColor
                            : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
