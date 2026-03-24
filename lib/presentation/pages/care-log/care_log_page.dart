/// 照护日志页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/date_utils.dart' as app_date;

class CareLogPage extends ConsumerStatefulWidget {
  const CareLogPage({super.key});

  @override
  ConsumerState<CareLogPage> createState() => _CareLogPageState();
}

class _CareLogPageState extends ConsumerState<CareLogPage> {
  String? _selectedLogType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppTexts.careLogs),
      ),
      body: _buildTimeline(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLogDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    // TODO: 从 Provider 获取真实数据
    final logs = [
      _MockLog(
        time: DateTime.now().subtract(const Duration(hours: 2)),
        type: 'health',
        content: '爸爸今天精神不错，下午下楼散步30分钟，走了800米。血压稳定。',
        emoji: '😊',
        author: '大女儿',
      ),
      _MockLog(
        time: DateTime.now().subtract(const Duration(hours: 5)),
        type: 'medication',
        content: '血压药已服用',
        author: '保姆',
      ),
      _MockLog(
        time: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        type: 'emotion',
        content: '奶奶今天情绪很好，跟邻居打了招呼。吃了半碗粥。',
        emoji: '😊',
        author: '保姆',
      ),
    ];

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('还没有照护日志'),
            const SizedBox(height: 8),
            Text(
              '记录每一天的照护情况',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(context, log);
      },
    );
  }

  Widget _buildLogItem(BuildContext context, _MockLog log) {
    final isToday = app_date.DateUtils.isToday(log.time);
    final isYesterday = app_date.DateUtils.isYesterday(log.time);
    final dateLabel = isToday
        ? '今天'
        : isYesterday
            ? '昨天'
            : app_date.DateUtils.formatMonthDay(log.time);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  app_date.DateUtils.formatTime(log.time),
                  style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
          // 连接线
          Container(
            width: 2,
            height: 60,
            color: AppColors.border,
          ),
          const SizedBox(width: 12),
          // 内容卡片
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_getTypeIcon(log.type)),
                      const SizedBox(width: 8),
                      Text(
                        log.author,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (log.emoji != null) ...[
                        const Spacer(),
                        Text(log.emoji!, style: const TextStyle(fontSize: 20)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    log.content,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case 'medication':
        return '💊';
      case 'health':
        return '🩺';
      case 'emotion':
        return '😊';
      case 'activity':
        return '🚶';
      default:
        return '📝';
    }
  }

  void _showAddLogDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部标题栏
            Row(
              children: [
                const Text(
                  '添加日志',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 日志类型选择
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip('💊 服药记录', 'medication', () {}),
                _buildTypeChip('🩺 健康数据', 'health', () {}),
                _buildTypeChip('😊 情绪状态', 'emotion', () {}),
                _buildTypeChip('🚶 活动情况', 'activity', () {}),
                _buildTypeChip('📝 其他', 'other', () {}),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '今天发生了什么？',
                hintStyle: const TextStyle(fontSize: 15, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String type, VoidCallback onTap) {
    final isSelected = _selectedLogType == type;
    return GestureDetector(
      onTap: () {
        // TODO: 选中类型
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MockLog {
  final DateTime time;
  final String type;
  final String content;
  final String? emoji;
  final String author;

  _MockLog({
    required this.time,
    required this.type,
    required this.content,
    this.emoji,
    required this.author,
  });
}
