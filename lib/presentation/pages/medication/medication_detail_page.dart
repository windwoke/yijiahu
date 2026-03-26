/// 药品详情页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/models.dart';
import '../../providers/family_provider.dart';

class MedicationDetailPage extends ConsumerWidget {
  final String medicationId;

  const MedicationDetailPage({super.key, required this.medicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medAsync = ref.watch(medicationDetailProvider(medicationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('药品详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textPrimary),
            onPressed: () {
              final med = medAsync.valueOrNull;
              if (med == null) return;
              context.push(AppRoutes.addMedication, extra: med);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => medAsync.whenOrNull(
              data: (med) => _confirmDelete(context, ref, med),
            ),
          ),
        ],
      ),
      body: medAsync.when(
        data: (med) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context, med),
            const SizedBox(height: 20),
            _buildInfoCard(context, med),
            const SizedBox(height: 16),
            _buildTimeCard(context, med),
            const SizedBox(height: 16),
            _buildHistoryCard(context, ref, med),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Medication med) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.medication, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (med.realName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    med.realName!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: med.isActive
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.grey200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    med.isActive ? '在用' : '已停用',
                    style: TextStyle(
                      fontSize: 12,
                      color: med.isActive ? AppColors.success : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Medication med) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本信息',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('剂量', '${med.dosage}${med.unit ?? ''}'),
          _buildInfoRow('频率', _frequencyLabel(med.frequency)),
          _buildInfoRow('开始日期', _formatDate(med.startDate)),
          _buildInfoRow('结束日期', med.endDate != null ? _formatDate(med.endDate!) : '长期服用'),
          if (med.prescribedBy != null && med.prescribedBy!.isNotEmpty)
            _buildInfoRow('开药医生', med.prescribedBy!),
          if (med.instructions != null && med.instructions!.isNotEmpty)
            _buildInfoRow('用药说明', med.instructions!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(BuildContext context, Medication med) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '服药时间',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: med.times.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(t, style: const TextStyle(fontSize: 15, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, Medication med) {
    final historyAsync = ref.watch(medicationHistoryProvider(med.id));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '用药记录',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                '近7天',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          historyAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Icon(Icons.history, size: 40, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      Text('暂无用药记录', style: TextStyle(color: AppColors.textTertiary)),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }
              return Column(
                children: logs.map((log) => _buildHistoryItem(log)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, s) => Center(
              child: Text(
                '加载失败',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(MedicationLog log) {
    final isTaken = log.status == MedicationLogStatus.taken;
    final statusColor = isTaken ? AppColors.success : AppColors.textTertiary;
    final statusText = isTaken ? '已服用' : '已跳过';

    String timeStr = '';
    if (log.actualTime != null) {
      timeStr =
          '${log.actualTime!.month}/${log.actualTime!.day} ${log.actualTime!.hour.toString().padLeft(2, '0')}:${log.actualTime!.minute.toString().padLeft(2, '0')}';
    } else if (log.scheduledTime.isNotEmpty) {
      timeStr = log.scheduledTime;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // 状态指示
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // 时间
          SizedBox(
            width: 80,
            child: Text(
              timeStr,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          // 状态文字
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
            ),
          ),
          const Spacer(),
          // 打人
          if (log.takenBy != null)
            Text(
              log.takenBy!.name,
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }

  String _frequencyLabel(MedicationFrequency f) {
    switch (f) {
      case MedicationFrequency.daily:
        return '每日';
      case MedicationFrequency.weekly:
        return '每周';
      case MedicationFrequency.asNeeded:
        return '按需';
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Medication med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${med.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTexts.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final dio = ref.read(dioProvider);
              await dio.delete('/medications/${med.id}');
              ref.invalidate(medicationsProvider(med.recipientId));
              if (context.mounted) context.pop();
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
