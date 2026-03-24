/// 首页 - 今日待办
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
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
      appBar: AppBar(
        title: const Text(AppTexts.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: recipientsAsync.when(
        data: (recipients) {
          if (recipients.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildContent(context, ref, recipients);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              '还没有添加照护对象',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '添加爷爷、奶奶等照护对象，开始管理用药和健康',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.addCareRecipient),
              icon: const Icon(Icons.add),
              label: const Text('添加照护对象'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<CareRecipient> recipients,
  ) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 120,
          ),
          itemCount: recipients.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildFamilyHeader(context, ref);
            }
            final recipient = recipients[index - 1];
            return _buildRecipientSection(context, ref, recipient);
          },
        ),
        // SOS 按钮固定在底部
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: const SafeArea(
              top: false,
              child: SosButton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyHeader(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    final membersAsync = family != null
        ? ref.watch(familyMembersProvider(family.id))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.family_restroom, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family?.name ?? '我的家庭',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '家庭成员 ${membersAsync?.value?.length ?? 0} 人',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('邀请'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientSection(
    BuildContext context,
    WidgetRef ref,
    CareRecipient recipient,
  ) {
    final todayAsync = ref.watch(todayMedicationProvider(recipient.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 照护对象标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Text(
                  recipient.displayAvatar,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  recipient.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (recipient.age != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${recipient.age}岁',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const Spacer(),
                todayAsync.whenOrNull(
                      data: (today) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: today.completed == today.total
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${today.completed}/${today.total}',
                          style: TextStyle(
                            color: today.completed == today.total
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ) ??
                    const SizedBox(),
              ],
            ),
          ),
          // 今日用药卡片
          todayAsync.when(
            data: (today) => MedicationCheckInCard(
              today: today,
              onCheckIn: (item) async {
                if (item.id == null) return;
                final dio = ref.read(dioProvider);
                await dio.post('/medication-logs/${item.id}/check-in', data: {
                  'status': 'taken',
                });
                ref.invalidate(todayMedicationProvider(recipient.id));
              },
            ),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, s) => Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('加载失败'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
