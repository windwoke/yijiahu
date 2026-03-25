/// 照护日志页 - 温暖日记风时间线
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart' as models;
import '../../providers/family_provider.dart';

/// 日志类型
enum LogType { medication, health, emotion, activity, meal, other }

extension LogTypeExt on LogType {
  String get label {
    switch (this) {
      case LogType.medication: return '服药';
      case LogType.health: return '健康';
      case LogType.emotion: return '情绪';
      case LogType.activity: return '活动';
      case LogType.meal: return '饮食';
      case LogType.other: return '其他';
    }
  }

  String get emoji {
    switch (this) {
      case LogType.medication: return '💊';
      case LogType.health: return '🩺';
      case LogType.emotion: return '😊';
      case LogType.activity: return '🚶';
      case LogType.meal: return '🍽️';
      case LogType.other: return '📝';
    }
  }

  Color get color {
    switch (this) {
      case LogType.medication: return AppColors.blue;
      case LogType.health: return AppColors.coral;
      case LogType.emotion: return AppColors.warning;
      case LogType.activity: return AppColors.primary;
      case LogType.meal: return const Color(0xFFFF9F0A);
      case LogType.other: return AppColors.textSecondary;
    }
  }

  static LogType fromString(String? s) {
    switch (s) {
      case 'medication': return LogType.medication;
      case 'health': return LogType.health;
      case 'emotion': return LogType.emotion;
      case 'activity': return LogType.activity;
      case 'meal': return LogType.meal;
      default: return LogType.other;
    }
  }
}

/// 照护日志数据
class CareLogEntry {
  final String id;
  final DateTime time;
  final LogType type;
  final String content;
  final String author;
  final String? authorAvatar;
  final String? recipientId;

  CareLogEntry({
    required this.id,
    required this.time,
    required this.type,
    required this.content,
    required this.author,
    this.authorAvatar,
    this.recipientId,
  });
}

/// 照护日志页
class CareLogPage extends ConsumerStatefulWidget {
  const CareLogPage({super.key});

  @override
  ConsumerState<CareLogPage> createState() => _CareLogPageState();
}

class _CareLogPageState extends ConsumerState<CareLogPage> {
  String? _selectedRecipientId;
  LogType? _filterType;

  @override
  Widget build(BuildContext context) {
    final recipientsAsync = ref.watch(careRecipientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 顶部安全区
          SizedBox(height: MediaQuery.of(context).padding.top),
          // 照护对象切换器
          recipientsAsync.when(
            data: (recipients) => _buildRecipientSwitcher(recipients),
            loading: () => const SizedBox(height: 56),
            error: (_, __) => const SizedBox(height: 56),
          ),
          // 页面标题行
          _buildHeader(),
          // 日志类型筛选
          _buildTypeFilter(),
          // 日志时间线
          Expanded(
            child: _buildTimeline(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLogSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('记一笔', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// 照护对象切换器 — pill chips
  Widget _buildRecipientSwitcher(List<models.CareRecipient> recipients) {
    if (recipients.isEmpty) return const SizedBox.shrink();

    // 默认选中第一个
    _selectedRecipientId ??= recipients.first.id;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipients.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final r = recipients[index];
          final isSelected = r.id == _selectedRecipientId;
          return GestureDetector(
            onTap: () => setState(() => _selectedRecipientId = r.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.grey200,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.displayAvatar, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    r.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 页面标题
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const Text(
            '照护日志',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timeline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '时间线',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 日志类型筛选
  Widget _buildTypeFilter() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: LogType.values.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // 全部
            final isSelected = _filterType == null;
            return _buildTypeChip(null, '全部', isSelected);
          }
          final type = LogType.values[index - 1];
          final isSelected = _filterType == type;
          return _buildTypeChip(type, '${type.emoji} ${type.label}', isSelected);
        },
      ),
    );
  }

  Widget _buildTypeChip(LogType? type, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey200,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 时间线主体
  Widget _buildTimeline() {
    final logs = _getMockLogs();

    if (logs.isEmpty) {
      return _buildEmptyState();
    }

    // 按日期分组
    final grouped = _groupByDate(logs);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped[index];
        final showDateHeader = index == 0 ||
            !_isSameDay(
              grouped[index - 1].time,
              entry.time,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期分隔头
            if (showDateHeader) _buildDateHeader(entry.time),
            _buildLogCard(entry),
          ],
        );
      },
    );
  }

  /// 日期头部标签
  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    String label;
    Color bgColor;
    Color textColor;

    if (dateDay == today) {
      label = '今天';
      bgColor = AppColors.primary.withValues(alpha: 0.1);
      textColor = AppColors.primary;
    } else if (dateDay == yesterday) {
      label = '昨天';
      bgColor = AppColors.coral.withValues(alpha: 0.1);
      textColor = AppColors.coral;
    } else {
      label = '${date.month}月${date.day}日 ${_weekdayLabel(date.weekday)}';
      bgColor = AppColors.surfaceContainerLow;
      textColor = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.borderLight,
            ),
          ),
        ],
      ),
    );
  }

  /// 单条日志卡片
  Widget _buildLogCard(CareLogEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间轴
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 类型色圆点
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: entry.type.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: entry.type.color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(entry.type.emoji, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          // 卡片
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶栏：时间 + 类型标签 + 作者
                  Row(
                    children: [
                      Text(
                        _formatTime(entry.time),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.type.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.type.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: entry.type.color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 作者头像
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            entry.author.isNotEmpty ? entry.author[0] : '?',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.author,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 内容
                  Text(
                    entry.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  // 底部装饰线
                  const SizedBox(height: 10),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: entry.type.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📖', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '还没有日志',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '记录每一天的照护点滴',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '点击下方「记一笔」开始记录',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 添加日志底部弹窗
  void _showAddLogSheet(BuildContext context) {
    LogType selectedType = LogType.activity;
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部拖拽条
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
              // 标题
              Row(
                children: [
                  const Text(
                    '记一笔',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // 关闭
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 类型选择
              const Text(
                '日志类型',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LogType.values.map((type) {
                  final isSelected = type == selectedType;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? type.color.withValues(alpha: 0.12)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? type.color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(type.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? type.color : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // 文本输入
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: TextField(
                  controller: contentController,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                  decoration: const InputDecoration.collapsed(
                    hintText: '今天发生了什么...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 提交按钮
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (contentController.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('日志已保存'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    '保存日志',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 工具方法 ───

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _weekdayLabel(int w) {
    const labels = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[w];
  }

  List<CareLogEntry> _getMockLogs() {
    final now = DateTime.now();
    final all = [
      CareLogEntry(
        id: '1',
        time: now.subtract(const Duration(hours: 1)),
        type: LogType.activity,
        content: '上午下楼散步 30 分钟，走了一公里。天气不错，精神状态良好。',
        author: '大女儿',
        recipientId: null,
      ),
      CareLogEntry(
        id: '2',
        time: now.subtract(const Duration(hours: 3)),
        type: LogType.medication,
        content: '血压药已服用，剂量正常。',
        author: '保姆',
        recipientId: null,
      ),
      CareLogEntry(
        id: '3',
        time: now.subtract(const Duration(hours: 5)),
        type: LogType.meal,
        content: '中午吃了半碗粥和蒸蛋，胃口比昨天好一些。',
        author: '保姆',
        recipientId: null,
      ),
      CareLogEntry(
        id: '4',
        time: now.subtract(const Duration(days: 1, hours: 2)),
        type: LogType.emotion,
        content: '今天心情不错，跟邻居聊了很久。晚上看了一会儿电视。',
        author: '二儿子',
        recipientId: null,
      ),
      CareLogEntry(
        id: '5',
        time: now.subtract(const Duration(days: 1, hours: 6)),
        type: LogType.health,
        content: '测量血压 128/82，略有偏高，密切观察中。',
        author: '大女儿',
        recipientId: null,
      ),
      CareLogEntry(
        id: '6',
        time: now.subtract(const Duration(days: 2)),
        type: LogType.activity,
        content: '在阳台晒太阳约1小时，给花浇了水。',
        author: '保姆',
        recipientId: null,
      ),
      CareLogEntry(
        id: '7',
        time: now.subtract(const Duration(days: 2, hours: 4)),
        type: LogType.medication,
        content: '降糖药按时服用，无异常反应。',
        author: '保姆',
        recipientId: null,
      ),
      CareLogEntry(
        id: '8',
        time: now.subtract(const Duration(days: 3)),
        type: LogType.other,
        content: '社区医生上门随访，血压血糖指标稳定，建议继续保持。',
        author: '大女儿',
        recipientId: null,
      ),
    ];

    // 按筛选条件过滤
    var filtered = all;
    if (_selectedRecipientId != null) {
      filtered = filtered.where((l) => l.recipientId == null || l.recipientId == _selectedRecipientId).toList();
    }
    if (_filterType != null) {
      filtered = filtered.where((l) => l.type == _filterType).toList();
    }

    // 排序：最新的在前
    filtered.sort((a, b) => b.time.compareTo(a.time));
    return filtered;
  }

  List<CareLogEntry> _groupByDate(List<CareLogEntry> logs) => logs;
}
