/// 照护日志页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/date_utils.dart' as app_date;

class CareLogPage extends ConsumerWidget {
  const CareLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppTexts.careLogs),
      ),
      body: _buildTimeline(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddLogDialog(context);
        },
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
              style: Theme.of(context).textTheme.bodySmall,
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  app_date.DateUtils.formatTime(log.time),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
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
                        style: Theme.of(context).textTheme.bodySmall,
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
                    style: Theme.of(context).textTheme.bodyMedium,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '添加日志',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // 日志类型选择
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip('💊 服药记录', () {}),
                _buildTypeChip('🩺 健康数据', () {}),
                _buildTypeChip('😊 情绪状态', () {}),
                _buildTypeChip('🚶 活动情况', () {}),
                _buildTypeChip('📝 其他', () {}),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '今天发生了什么？',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
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
