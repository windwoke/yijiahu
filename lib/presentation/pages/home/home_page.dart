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

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipientsAsync = ref.watch(careRecipientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 主体内容（滚动）
          recipientsAsync.when(
            data: (recipients) {
              if (recipients.isEmpty) {
                return _buildEmptyStateBody(context, ref);
              }
              return _buildContentBody(context, ref, recipients);
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
            child: _buildGlassTopBar(context, ref),
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

  Widget _buildGlassTopBar(BuildContext context, WidgetRef ref) {
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
                              errorBuilder: (_, __, ___) => const Center(
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

  Widget _buildEmptyStateBody(BuildContext context, WidgetRef ref) {
    final topHeight = MediaQuery.of(context).padding.top + 72;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topHeight)),
        SliverToBoxAdapter(child: _buildEmptyStateContent(context)),
        const SliverFillRemaining(hasScrollBody: false, child: SizedBox(height: 100)),
      ],
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

  Widget _buildContentBody(
    BuildContext context,
    WidgetRef ref,
    List<CareRecipient> recipients,
  ) {
    final topHeight = MediaQuery.of(context).padding.top + 72;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topHeight)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final recipient = recipients[index];
                return _buildRecipientSection(context, ref, recipient);
              },
              childCount: recipients.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientSection(
    BuildContext context,
    WidgetRef ref,
    CareRecipient recipient,
  ) {
    final todayAsync = ref.watch(todayMedicationProvider(recipient.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 照护对象头部：emoji + 姓名 + 年龄 + 进度条
          _buildRecipientHeader(context, todayAsync, recipient),
          const SizedBox(height: 12),
          // 今日用药 2 列 Grid
          todayAsync.when(
            data: (today) => MedicationCheckInCard(
              today: today,
              onCheckIn: (item) async {
                if (item.id == null) return;
                final dio = ref.read(dioProvider);
                await dio.post('/medication-logs/${item.id}/check-in',
                    data: {'status': 'taken'});
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
    CareRecipient recipient,
  ) {
    final progress = todayAsync.whenOrNull(
      data: (today) =>
          today.total > 0 ? today.completed / today.total : 0.0,
    );

    return GestureDetector(
      onTap: () => context.push(AppRoutes.careRecipientDetail, extra: recipient),
      child: Row(
        children: [
          // emoji 头像
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                recipient.displayAvatar,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 姓名 + 年龄
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
    );
  }
}
