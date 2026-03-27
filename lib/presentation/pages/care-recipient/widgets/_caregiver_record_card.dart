/// 照护记录卡片组件
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/constants.dart';
import '../../../../data/models/models.dart';
import '../../../providers/providers.dart';

/// 照护记录卡片（当前照护人 + 切换入口）
class CaregiverRecordCard extends ConsumerWidget {
  final CareRecipient recipient;

  const CaregiverRecordCard({super.key, required this.recipient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(currentCaregiverProvider(recipient.id));

    return currentAsync.when(
      data: (current) => _buildCard(context, ref, current),
      loading: () => _buildCard(context, ref, null),
      error: (_, __) => _buildCard(context, ref, null),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, CaregiverRecord? current) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRecordSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 头像
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: current?.caregiver?.avatarUrl != null
                      ? NetworkImage(current!.caregiver!.avatarUrl!)
                      : null,
                  child: current?.caregiver != null
                      ? null
                      : Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            current?.caregiver?.name ?? '未设置照护人',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (current != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '当前',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current?.periodLabel ?? '点击添加照护记录',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 切换按钮
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CaregiverRecordSheet(recipient: recipient),
    );
  }
}

/// 照护记录底部弹层
class _CaregiverRecordSheet extends ConsumerStatefulWidget {
  final CareRecipient recipient;

  const _CaregiverRecordSheet({required this.recipient});

  @override
  ConsumerState<_CaregiverRecordSheet> createState() => _CaregiverRecordSheetState();
}

class _CaregiverRecordSheetState extends ConsumerState<_CaregiverRecordSheet> {
  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(caregiverRecordsProvider(widget.recipient.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  '照护记录',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddRecordDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加记录'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 列表
          Flexible(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: AppColors.textTertiary),
                        SizedBox(height: 12),
                        Text(
                          '暂无照护记录',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 0),
                  itemBuilder: (ctx, i) => _buildRecordItem(ctx, ref, records[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildRecordItem(BuildContext ctx, WidgetRef ref, CaregiverRecord record) {
    final isCurrent = record.isCurrent;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.grey100, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isCurrent
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.grey100,
            child: record.caregiver != null
                ? Text(
                    record.caregiver!.name?.isNotEmpty == true
                        ? record.caregiver!.name![0]
                        : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                    ),
                  )
                : Icon(Icons.person_rounded,
                    size: 18,
                    color: isCurrent ? AppColors.primary : AppColors.textTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.caregiver?.name ?? '未知用户',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '当前',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  record.periodLabel,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (record.note != null && record.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.note!,
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (!isCurrent)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              onPressed: () => _confirmDeleteRecord(ctx, ref, record),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteRecord(BuildContext ctx, WidgetRef ref, CaregiverRecord record) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定要删除"${record.caregiver?.name ?? '该照护人'}"的照护记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(AppTexts.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && ctx.mounted) {
      final familyId = ref.read(currentFamilyProvider)?.id ?? '';
      await deleteCaregiverRecord(ref: ref, id: record.id, familyId: familyId);
      ref.invalidate(caregiverRecordsProvider(widget.recipient.id));
      ref.invalidate(currentCaregiverProvider(widget.recipient.id));
    }
  }

  void _showAddRecordDialog(BuildContext dialogCtx) {
    FamilyMember? selectedMember;
    DateTime periodStart = DateTime.now();
    final noteController = TextEditingController();

    showDialog(
      context: dialogCtx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final membersAsync = ref.watch(
            familyMembersProvider(ref.watch(currentFamilyProvider)?.id ?? ''),
          );

          return AlertDialog(
            title: const Text('添加照护记录'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('照护人', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  membersAsync.when(
                    data: (members) {
                      if (members.isEmpty) {
                        return const Text('家庭中暂无成员');
                      }
                      selectedMember ??= members.first;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<FamilyMember>(
                            value: selectedMember,
                            isExpanded: true,
                            items: members.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Text(m.nickname),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setDialogState(() => selectedMember = v);
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('加载失败'),
                  ),
                  const SizedBox(height: 16),
                  const Text('开始日期', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: periodStart,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setDialogState(() => periodStart = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${periodStart.year}年${periodStart.month}月${periodStart.day}日',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('备注（选填）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '如：因工作原因暂时照顾',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(AppTexts.cancel)),
              ElevatedButton(
                onPressed: () async {
                  if (selectedMember == null) return;
                  Navigator.pop(dialogContext);
                  await createCaregiverRecord(
                    ref: ref,
                    careRecipientId: widget.recipient.id,
                    caregiverId: selectedMember!.userId ?? '',
                    periodStart:
                        '${periodStart.year}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day.toString().padLeft(2, '0')}',
                    note: noteController.text.isNotEmpty ? noteController.text : null,
                  );
                  ref.invalidate(caregiverRecordsProvider(widget.recipient.id));
                  ref.invalidate(currentCaregiverProvider(widget.recipient.id));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }
}
