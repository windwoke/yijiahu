/// 用药打卡卡片组件
library;

import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';
import 'empty_state.dart';
import 'medication_check_in_sheet.dart';

/// 截断超长名称
String _truncate4(String s) => s.length > 4 ? '${s.substring(0, 4)}…' : s;

class MedicationCheckInCard extends StatelessWidget {
  final TodayMedicationSummary today;
  final Future<void> Function(MedicationLogItem item) onCheckIn;
  final Future<void> Function(MedicationLogItem item, String reason) onSkip;

  const MedicationCheckInCard({
    super.key,
    required this.today,
    required this.onCheckIn,
    required this.onSkip,
  });

  /// 将药品列表拆成多行，每行2个（奇数末尾留空位）
  List<Widget> _buildRows(BuildContext context, List<MedicationLogItem> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < items.length ? 10.0 : 0.0),
          child: Row(
            children: [
              Expanded(child: _buildMedicationItem(context, items[i])),
              if (i + 1 < items.length)
                Expanded(child: _buildMedicationItem(context, items[i + 1])),
              if (i + 1 >= items.length) const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (today.items.isEmpty) {
      return const EmptyState(
        emoji: '💊',
        title: '今日暂无用药计划',
        subtitle: '记得按时服药，保持健康',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppColors.shadowSoft2,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildRows(context, today.items),
        ),
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
    final isMissed = item.status == MedicationLogStatus.missed;
    final isDone = isTaken || isSkipped;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: AppColors.shadowSoft2,
            blurRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCheckInSheet(context, item),
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
                // 底部：统一最小高度，打卡/已打卡高度一致
                SizedBox(
                  height: 32,
                  child: isDone && item.takenBy != null
                      ? Align(alignment: Alignment.centerLeft, child: _buildDoneInfo(item, statusColor, isTaken, isMissed))
                      : isMissed
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.coral.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '已漏服',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : item.canCheckIn
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton(
                                    onPressed: () => _showCheckInSheet(context, item),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      minimumSize: const Size(0, 32),
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
                                )
                              : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneInfo(MedicationLogItem item, Color statusColor, bool isTaken, bool isMissed) {
    final timeStr = _formatTimeStr(item.actualTime);
    final action = isTaken ? '已服用' : isMissed ? '已漏服' : '已跳过';
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
          '由 ${_truncate4(item.takenBy!.name)} 记录',
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicationCheckInSheet(
        item: item,
        onCheckIn: () => onCheckIn(item),
        onSkip: (reason) => onSkip(item, reason),
      ),
    );
  }
}
