/// 用药打卡底部弹窗（核心交互页）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../core/services/jpush_service.dart';
import '../../data/models/models.dart';
import '../providers/family_provider.dart';

/// 跳过原因选项
const _skipReasons = [
  '忘记了',
  '身体不适',
  '医生建议停药',
  '已自行服药',
  '其他',
];

/// 底部打卡弹窗
class MedicationCheckInSheet extends ConsumerStatefulWidget {
  final MedicationLogItem item;
  final Future<void> Function() onCheckIn;
  final Future<void> Function(String reason) onSkip;

  const MedicationCheckInSheet({
    super.key,
    required this.item,
    required this.onCheckIn,
    required this.onSkip,
  });

  @override
  ConsumerState<MedicationCheckInSheet> createState() => _MedicationCheckInSheetState();
}

class _MedicationCheckInSheetState extends ConsumerState<MedicationCheckInSheet> {
  bool _loading = false;
  bool _loadingHistory = true;
  List<MedicationLog> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ref.read(medicationHistoryProvider(widget.item.medicationId).future);
      if (mounted) setState(() { _history = history; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  bool get _isDone =>
      widget.item.status == MedicationLogStatus.taken ||
      widget.item.status == MedicationLogStatus.skipped;

  String _formatTimeStr(String? time) {
    if (time == null || time.isEmpty) return '';
    // "YYYY-MM-DD HH:mm:ss" → "MM/DD HH:mm"
    final parts = time.split(' ');
    if (parts.length < 2) return time;
    final date = parts[0].split('-'); // [year, month, day]
    if (date.length < 3) return time;
    return '${date[1]}/${date[2]} ${parts[1].substring(0, 5)}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动条
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // 药品信息头部
              Text(
                widget.item.medicationName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.item.dosage} · ${widget.item.scheduledTime}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // 大圆打卡按钮
              _buildCheckInButton(),
              const SizedBox(height: 16),

              // 稍后提醒 + 跳过 按钮行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDelayButton(),
                  const SizedBox(width: 16),
                  _buildSkipButton(),
                ],
              ),
              const SizedBox(height: 24),

              // 分割线
              Container(height: 1, color: AppColors.grey100),
              const SizedBox(height: 20),

              // 历史记录
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInButton() {
    return GestureDetector(
      onTap: _isDone || _loading ? null : () => _handleCheckIn(),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: _isDone ? AppColors.grey200 : AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: _isDone
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading && !_isDone)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            else
              Icon(
                _isDone ? Icons.check : Icons.check,
                size: 40,
                color: _isDone ? AppColors.textSecondary : Colors.white,
              ),
            const SizedBox(height: 2),
            Text(
              _isDone ? '已完成' : '已服用',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _isDone ? AppColors.textSecondary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayButton() {
    final disabled = _isDone;
    return GestureDetector(
      onTap: disabled ? null : () => _handleDelay(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: disabled ? AppColors.grey200 : AppColors.primary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 16, color: disabled ? AppColors.grey300 : AppColors.primary),
            const SizedBox(width: 6),
            Text(
              '稍后 15 分钟',
              style: TextStyle(
                fontSize: 13,
                color: disabled ? AppColors.grey300 : AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    final disabled = _isDone;
    return GestureDetector(
      onTap: disabled ? null : () => _showSkipReasonSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: disabled ? AppColors.grey200 : AppColors.grey300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, size: 16, color: disabled ? AppColors.grey300 : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '跳过',
              style: TextStyle(
                fontSize: 13,
                color: disabled ? AppColors.grey300 : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '用药记录',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '近7天',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_history.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Icon(Icons.history, size: 36, color: AppColors.textTertiary),
                const SizedBox(height: 4),
                Text(
                  '暂无用药记录',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
            ),
          )
        else
          Column(
            children: _history.take(7).map(_buildHistoryItem).toList(),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(MedicationLog log) {
    final isTaken = log.status == MedicationLogStatus.taken;
    final statusColor = isTaken ? AppColors.success : AppColors.textTertiary;
    final statusText = isTaken ? '已服用' : '已跳过';

    final timeStr = _formatTimeStr(log.time);
    final authorName = log.authorName ?? '家庭成员';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              timeStr,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          // 操作人
          if (authorName.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    authorName.isNotEmpty ? authorName[0] : '?',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  authorName.length > 4
                      ? '${authorName.substring(0, 4)}…'
                      : authorName,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _handleCheckIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onCheckIn();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        Navigator.pop(context);
      }
    }
  }

  void _handleDelay() {
    JPushService().scheduleReminder(
      minutes: 15,
      medicationName: widget.item.medicationName,
      dosage: widget.item.dosage,
    );
    Navigator.pop(context);
  }

  void _showSkipReasonSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (subCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(subCtx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择跳过原因',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._skipReasons.map((reason) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    reason,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(subCtx); // 关闭原因选择
                    Navigator.pop(ctx); // 关闭打卡弹窗
                    await widget.onSkip(reason);
                  },
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(subCtx),
                child: const Text(AppTexts.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
