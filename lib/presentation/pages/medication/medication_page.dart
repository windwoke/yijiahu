/// 用药管理页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class MedicationPage extends ConsumerWidget {
  const MedicationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipients = ref.watch(careRecipientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppTexts.medications),
        actions: [
          recipients.when(
            data: (list) => list.isEmpty
                ? const SizedBox()
                : IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => context.go(AppRoutes.addMedication),
                  ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: recipients.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              emoji: '👨‍👩‍👧',
              title: '还没有添加照护对象',
              subtitle: '添加爷爷、奶奶等照护对象，开始管理用药和健康',
            );
          }
          // 默认显示第一个照护对象的药品
          final recipient = list.first;
          final medsAsync = ref.watch(medicationsProvider(recipient.id));

          return Column(
            children: [
              // 照护对象选择器
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(recipient.displayAvatar, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(recipient.name, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              // 药品列表
              Expanded(
                child: medsAsync.when(
                  data: (meds) {
                    if (meds.isEmpty) {
                      return EmptyState(
                        emoji: '💊',
                        title: '还没有添加药品',
                        subtitle: '为 ${recipient.name} 添加用药计划',
                        actionLabel: '添加药品',
                        onAction: () => context.go(AppRoutes.addMedication),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: meds.length,
                      itemBuilder: (context, index) {
                        final med = meds[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.medication,
                                  color: AppColors.primary),
                            ),
                            title: Text(med.name),
                            subtitle: Text(
                              '${med.dosage} · ${med.times.join(", ")}',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              context.push('/medication/${med.id}');
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败: $e')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}
