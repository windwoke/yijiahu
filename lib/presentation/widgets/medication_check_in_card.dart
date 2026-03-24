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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              '今日暂无用药计划',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < today.items.length; i++)
            _buildMedicationItem(context, today.items[i], i),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(BuildContext context, MedicationLogItem item, int index) {
    final isPending = item.status == MedicationLogStatus.pending ||
        item.status == MedicationLogStatus.missed;
    final isTaken = item.status == MedicationLogStatus.taken;
    final isSkipped = item.status == MedicationLogStatus.skipped;

    Color statusColor;
    IconData statusIcon;

    if (isTaken) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
    } else if (isSkipped) {
      statusColor = AppColors.warning;
      statusIcon = Icons.remove_circle;
    } else if (isPending) {
      final now = TimeOfDay.now();
      final scheduled = TimeOfDay(
        hour: int.parse(item.scheduledTime.split(':')[0]),
        minute: int.parse(item.scheduledTime.split(':')[1]),
      );
      final isOverdue = _isOverdue(now, scheduled);
      statusColor = isOverdue ? AppColors.error : AppColors.textSecondary;
      statusIcon = isOverdue ? Icons.warning : Icons.schedule;
    } else {
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.schedule;
    }

    return InkWell(
      onTap: item.canCheckIn ? () => _showCheckInSheet(context, item) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: index != today.items.length - 1 ? 1 : 0,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                item.scheduledTime,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.medicationName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration:
                              isSkipped ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  Text(
                    item.dosage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isTaken || isSkipped)
              Icon(statusIcon, color: statusColor, size: 20)
            else if (item.canCheckIn)
              Container(
                width: 72,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '打卡',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Icon(Icons.schedule, color: statusColor, size: 20),
          ],
        ),
      ),
    );
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
                      '已服用',
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
              child: const Text('稍后提醒'),
            ),
          ],
        ),
      ),
    );
  }
}
