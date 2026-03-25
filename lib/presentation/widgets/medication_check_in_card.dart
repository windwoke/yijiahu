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
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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
    final isTaken =
        item.status == MedicationLogStatus.taken || item.status == MedicationLogStatus.skipped;
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
            padding: const EdgeInsets.all(14),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          decoration: item.status == MedicationLogStatus.skipped
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isTaken)
                      Icon(Icons.check_circle, color: statusColor, size: 18)
                    else
                      Icon(Icons.schedule, color: statusColor, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.dosage,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.scheduledTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (canCheckIn) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showCheckInSheet(context, item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        AppTexts.checkIn,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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
