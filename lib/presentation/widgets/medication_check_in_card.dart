/// 用药打卡卡片组件
library;

import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';

class MedicationCheckInCard extends StatelessWidget {
  final TodayMedicationSummary today;
  final void Function(MedicationLogItem item) onCheckIn;

  const MedicationCheckInCard({
    super.key,
    required this.today,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    if (today.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '今日暂无用药计划',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
        ),
        itemCount: today.items.length,
        itemBuilder: (context, index) {
          return _buildMedicationItem(context, today.items[index]);
        },
      ),
    );
  }

  Color _getStatusColor(MedicationLogItem item) {
    final isTaken =
        item.status == MedicationLogStatus.taken || item.status == MedicationLogStatus.skipped;
    if (isTaken) {
      return AppColors.medicationDone;
    }

    final isPending = item.status == MedicationLogStatus.pending ||
        item.status == MedicationLogStatus.missed;
    if (isPending) {
      final now = TimeOfDay.now();
      final scheduled = TimeOfDay(
        hour: int.parse(item.scheduledTime.split(':')[0]),
        minute: int.parse(item.scheduledTime.split(':')[1]),
      );
      final isOverdue = _isOverdue(now, scheduled);
      if (isOverdue) {
        return AppColors.coral;
      }
    }

    return AppColors.grey300;
  }

  Widget _buildMedicationItem(BuildContext context, MedicationLogItem item) {
    final statusColor = _getStatusColor(item);
    final isTaken = item.status == MedicationLogStatus.taken;
    final isSkipped = item.status == MedicationLogStatus.skipped;
    final isDone = isTaken || isSkipped;
    final canCheckIn = item.canCheckIn;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: canCheckIn ? () => _showCheckInSheet(context, item) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.medicationName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          decoration: isSkipped ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isDone ? Icons.check_circle : Icons.schedule,
                      color: statusColor,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.dosage,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.scheduledTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // 底部：已打卡显示单行文字，未打卡显示按钮
                if (isDone && item.takenBy != null)
                  _buildDoneInfo(item, statusColor, isTaken)
                else if (canCheckIn)
                  SizedBox(
                    height: 32,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showCheckInSheet(context, item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        AppTexts.checkIn,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneInfo(MedicationLogItem item, Color statusColor, bool isTaken) {
    final timeStr = _formatTimeStr(item.actualTime);
    final action = isTaken ? '已服用' : '已跳过';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 第一行：时间 + 状态
        Row(
          children: [
            if (timeStr != null)
              Text(
                '$timeStr ',
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              action,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        // 第二行：谁记录的
        Text(
          '由 ${item.takenBy!.name} 记录',
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? _formatTimeStr(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return _formatTime(value);
    if (value is String && value.isNotEmpty) {
      // 后端返回 "YYYY-MM-DD HH:mm:ss"，取最后时分部分
      final parts = value.split(' ');
      if (parts.length >= 2) return parts[1].substring(0, 5);
    }
    return null;
  }

  bool _isOverdue(TimeOfDay now, TimeOfDay scheduled) {
    final nowMinutes = now.hour * 60 + now.minute;
    final scheduledMinutes = scheduled.hour * 60 + scheduled.minute;
    return nowMinutes > scheduledMinutes + 30;
  }

  void _showCheckInSheet(BuildContext context, MedicationLogItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.medicationName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${item.dosage} · ${item.scheduledTime}',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 120,
              height: 120,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  onCheckIn(item);
                  Navigator.pop(ctx);
                },
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 40, color: Colors.white),
                    SizedBox(height: 4),
                    Text(
                      AppTexts.taken,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppTexts.delayReminder),
            ),
          ],
        ),
      ),
    );
  }
}
