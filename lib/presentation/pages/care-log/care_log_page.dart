/// 照护日志页 - 温暖日记风时间线
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/env/env_config.dart';
import '../../../data/models/models.dart';
import '../../../data/models/family.dart' as models;
import '../../providers/family_provider.dart';
import '../../widgets/empty_state.dart';

/// 照护日志页
class CareLogPage extends ConsumerStatefulWidget {
  const CareLogPage({super.key});

  @override
  ConsumerState<CareLogPage> createState() => _CareLogPageState();
}

class _CareLogPageState extends ConsumerState<CareLogPage> with WidgetsBindingObserver {
  /// null = 全部照护人
  String? _selectedRecipientId;
  CareLogType? _filterType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final family = ref.read(currentFamilyProvider);
      if (family != null) {
        final query = TimelineQuery(familyId: family.id, recipientId: _selectedRecipientId);
        ref.read(timelineProvider(query).notifier).refresh();
      }
    }
  }

  void _loadMore() {
    final family = ref.read(currentFamilyProvider);
    if (family == null) return;
    final query = TimelineQuery(familyId: family.id, recipientId: _selectedRecipientId);
    ref.read(timelineProvider(query).notifier).loadMore();
  }

  Future<void> _onRefresh() async {
    final family = ref.read(currentFamilyProvider);
    if (family == null) return;
    final query = TimelineQuery(familyId: family.id, recipientId: _selectedRecipientId);
    await ref.read(timelineProvider(query).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final recipientsAsync = ref.watch(careRecipientsProvider);
    final family = ref.watch(currentFamilyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          // 照护对象切换器（全部 + 各照护人）
          recipientsAsync.when(
            data: (recipients) => _buildRecipientSwitcher(recipients, family),
            loading: () => const SizedBox(height: 56),
            error: (_, __) => const SizedBox(height: 56),
          ),
          // 页面标题
          _buildHeader(),
          // 类型筛选
          _buildTypeFilter(),
          // 时间线
          Expanded(
            child: family != null
                ? _buildTimeline(family.id, _selectedRecipientId, _filterType)
                : _buildEmptyState(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onAddLog(family),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('记一笔', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// 全部 + 照护对象切换器
  Widget _buildRecipientSwitcher(List<CareRecipient> recipients, models.Family? family) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 1 + recipients.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // 全部 - 使用家庭头像
            final isSelected = _selectedRecipientId == null;
            return _buildRecipientChip(
              emoji: '👨‍👩‍👧‍👦',
              avatarUrl: family?.avatarUrl,
              name: '全部',
              isSelected: isSelected,
              onTap: () => setState(() => _selectedRecipientId = null),
            );
          }
          final r = recipients[index - 1];
          final isSelected = r.id == _selectedRecipientId;
          return _buildRecipientChip(
            emoji: r.displayAvatar,
            name: r.name,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedRecipientId = r.id),
          );
        },
      ),
    );
  }

  Widget _buildRecipientChip({
    required String emoji,
    String? avatarUrl,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey200,
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
            if (avatarUrl != null && avatarUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  ApiConfig.avatarUrl(avatarUrl) ?? '',
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              )
            else
              Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              name,
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
  }

  /// 页面标题
  Widget _buildHeader() {
    final recipientsAsync = ref.watch(careRecipientsProvider);
    final label = _selectedRecipientId == null
        ? '全部动态'
        : recipientsAsync.valueOrNull
                ?.where((r) => r.id == _selectedRecipientId)
                .firstOrNull
                ?.name ??
            '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Text(
            _selectedRecipientId == null ? '照护日志' : '$label 的日志',
            style: const TextStyle(
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

  /// 类型筛选
  Widget _buildTypeFilter() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CareLogType.values.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTypeChip(null, '全部', _filterType == null);
          }
          final type = CareLogType.values[index - 1];
          return _buildTypeChip(type, '${type.emoji} ${type.label}', _filterType == type);
        },
      ),
    );
  }

  Widget _buildTypeChip(CareLogType? type, String label, bool isSelected) {
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
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// 时间线
  Widget _buildTimeline(String familyId, String? recipientId, CareLogType? filterType) {
    final query = TimelineQuery(familyId: familyId, recipientId: recipientId);
    final timelineAsync = ref.watch(timelineProvider(query));

    return timelineAsync.when(
      data: (entries) {
        // 应用类型筛选
        final filtered = filterType != null
            ? entries.where((e) => e.type == filterType).toList()
            : entries;

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification) {
                final metrics = notification.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                  _loadMore();
                }
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: filtered.length + 1, // +1 for loading indicator
              itemBuilder: (context, index) {
                if (index == filtered.length) {
                  // 底部加载更多指示器
                  return _buildLoadMoreIndicator();
                }
                final entry = filtered[index];
                final showDateHeader = index == 0 ||
                    !_isSameDay(filtered[index - 1].time, entry.time);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) _buildDateHeader(entry.time),
                    _buildLogCard(entry),
                  ],
                );
              },
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('加载失败: $e'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _onRefresh,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: TextButton(
          onPressed: _loadMore,
          child: const Text('加载更多', style: TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  /// 日期分隔头
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
          Expanded(child: Container(height: 1, color: AppColors.borderLight)),
        ],
      ),
    );
  }

  /// 单条日志卡片
  Widget _buildLogCard(TimelineEntry entry) {
    // 健康记录超范围检测
    final isOutOfRange = entry.source == 'health_record' &&
        entry.healthMetricType != null &&
        entry.healthMetricType!.checkRange(entry.healthValue) == HealthRangeResult.high;
    final isLowRange = entry.source == 'health_record' &&
        entry.healthMetricType != null &&
        entry.healthMetricType!.checkRange(entry.healthValue) == HealthRangeResult.low;

    // 健康记录默认用主色蓝，超范围用警告橙
    final isHealthRecord = entry.source == 'health_record' && entry.healthMetricType != null;
    final baseColor = isHealthRecord ? AppColors.primary : entry.type.color;
    final alertColor = isOutOfRange
        ? AppColors.coral
        : (isLowRange ? AppColors.warning : null);

    // 健康记录时左侧显示子类型标签
    final metricType = entry.healthMetricType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (alertColor ?? baseColor).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (alertColor ?? baseColor).withValues(alpha: 0.3),
                      width: isOutOfRange || isLowRange ? 2.5 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isHealthRecord ? metricType!.emoji : entry.type.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: isOutOfRange || isLowRange
                    ? Border.all(color: alertColor!.withValues(alpha: 0.4), width: 1.5)
                    : null,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            if (isHealthRecord) ...[
                              // 健康子类型标签
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: baseColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  metricType!.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: baseColor,
                                  ),
                                ),
                              ),
                            ] else
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
                            // 超范围/偏低提示
                            if (isOutOfRange)
                              _buildRangeBadge('偏高', AppColors.coral)
                            else if (isLowRange)
                              _buildRangeBadge('偏低', AppColors.warning),
                            if (!isOutOfRange && !isLowRange)
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
                        // 内容：超范围时放大字体醒目
                        Text(
                          entry.content,
                          style: TextStyle(
                            fontSize: isOutOfRange || isLowRange ? 17 : 15,
                            fontWeight: isOutOfRange || isLowRange ? FontWeight.w700 : FontWeight.w500,
                            color: isOutOfRange
                                ? AppColors.coral
                                : (isLowRange ? AppColors.warning : AppColors.textPrimary),
                            height: 1.6,
                          ),
                        ),
                        // 超范围时显示正常范围提示
                        if (isOutOfRange || isLowRange) ...[
                          const SizedBox(height: 6),
                          Text(
                            '参考范围：${metricType!.normalRange}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                        // 附件网格
                        if (entry.attachments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildAttachmentGrid(entry.attachments),
                        ],
                      ],
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

  Widget _buildRangeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == '偏高' ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return const EmptyState(
      emoji: '📖',
      title: '还没有日志',
      subtitle: '记录每一天的照护点滴',
    );
  }

  /// 点击记一笔按钮
  void _onAddLog(Family? family) {
    if (family == null) return;

    // 如果没有选择照护人（全部模式），先选照护人
    if (_selectedRecipientId == null) {
      _showRecipientPicker(family.id);
    } else {
      _showAddLogSheet(family.id, _selectedRecipientId!);
    }
  }

  /// 选照护人弹窗（仅全部模式）
  void _showRecipientPicker(String familyId) {
    final recipients = ref.read(careRecipientsProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Text(
              '选择照护对象',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请选择要记录日志的照护对象',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ...recipients.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedRecipientId = r.id);
                  _showAddLogSheet(familyId, r.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(r.displayAvatar, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        r.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// 添加日志底部弹窗
  void _showAddLogSheet(String familyId, String recipientId) {
    CareLogType selectedType = CareLogType.activity;
    HealthMetricType? selectedMetric;
    final contentController = TextEditingController();
    // 血压
    final bpSysController = TextEditingController();
    final bpDiaController = TextEditingController();
    // 血糖
    final glucoseController = TextEditingController();
    String glucoseType = 'fasting';
    // 体重
    final weightController = TextEditingController();
    String weightUnit = 'kg';
    // 附件
    final selectedAttachments = <XFile>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isHealth = selectedType == CareLogType.health;

          return Container(
            padding: EdgeInsets.fromLTRB(
              24, 24, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  Row(
                    children: [
                      Text(
                        isHealth ? '记录健康数据' : '记一笔',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CareLogType.values.map((type) {
                      final isSelected = type == selectedType;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? type.color.withValues(alpha: 0.12) : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? type.color : Colors.transparent, width: 1.5),
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

                  // ── 健康类型时显示健康指标选择 ──
                  if (isHealth) ...[
                    const Text(
                      '选择指标',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: HealthMetricType.values.map((metric) {
                        final isSelected = metric == selectedMetric;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedMetric = metric),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(metric.emoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  metric.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 正常范围提示
                    if (selectedMetric != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '参考范围：${selectedMetric!.normalRange}',
                              style: TextStyle(fontSize: 12, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 健康指标输入区
                    if (selectedMetric != null) _buildHealthInput(
                      selectedMetric!,
                      bpSysController,
                      bpDiaController,
                      glucoseController,
                      glucoseType,
                      weightController,
                      weightUnit,
                      (type) => setSheetState(() => glucoseType = type),
                      (unit) => setSheetState(() => weightUnit = unit),
                      setSheetState,
                    ),
                  ],

                  // ── 非健康类型时显示文本输入 ──
                  if (!isHealth) ...[
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
                        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.6),
                        decoration: const InputDecoration.collapsed(
                          hintText: '今天发生了什么...',
                          hintStyle: TextStyle(fontSize: 15, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 附件选择区
                    _buildAttachmentPicker(selectedAttachments, setSheetState, () {
                      _pickAttachments(setSheetState, selectedAttachments);
                    }),
                    if (selectedAttachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAttachmentPreview(selectedAttachments, setSheetState),
                    ],
                  ],
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        // 健康类型验证
                        if (isHealth && selectedMetric != null) {
                          if (selectedMetric == HealthMetricType.bloodPressure) {
                            if (bpSysController.text.isEmpty || bpDiaController.text.isEmpty) return;
                          } else if (selectedMetric == HealthMetricType.bloodGlucose) {
                            if (glucoseController.text.isEmpty) return;
                          } else if (selectedMetric == HealthMetricType.weight) {
                            if (weightController.text.isEmpty) return;
                          }
                        } else if (!isHealth) {
                          if (contentController.text.trim().isEmpty && selectedAttachments.isEmpty) return;
                        }

                        Navigator.pop(ctx);

                        try {
                          final dio = ref.read(dioProvider);

                          // 先上传附件，获取附件ID列表
                          List<String> attachmentIds = [];
                          if (selectedAttachments.isNotEmpty) {
                            final filesFormData = FormData();
                            for (final file in selectedAttachments) {
                              final bytes = await file.readAsBytes();
                              filesFormData.files.add(MapEntry(
                                'files',
                                MultipartFile.fromBytes(bytes, filename: file.name),
                              ));
                            }
                            final uploadResp = await dio.post('/upload/attachments', data: filesFormData);
                            final attachments = uploadResp.data['attachments'] as List<dynamic>? ?? [];
                            attachmentIds = attachments.map<String>((a) => a['id'] as String).toList();
                          }

                          if (isHealth && selectedMetric != null) {
                            // 发健康记录
                            final value = <String, dynamic>{};
                            if (selectedMetric == HealthMetricType.bloodPressure) {
                              value['systolic'] = int.tryParse(bpSysController.text) ?? 0;
                              value['diastolic'] = int.tryParse(bpDiaController.text) ?? 0;
                            } else if (selectedMetric == HealthMetricType.bloodGlucose) {
                              value['value'] = double.tryParse(glucoseController.text) ?? 0.0;
                              value['type'] = glucoseType;
                            } else {
                              value['value'] = double.tryParse(weightController.text) ?? 0.0;
                              value['unit'] = weightUnit;
                            }
                            await dio.post('/health-records', data: {
                              'recipientId': recipientId,
                              'recordType': selectedMetric!.recordType,
                              'value': value,
                              'note': contentController.text.trim().isNotEmpty ? contentController.text.trim() : null,
                            });
                          } else {
                            // 发普通日志
                            await dio.post('/care-logs', queryParameters: {'familyId': familyId}, data: {
                              'recipientId': recipientId,
                              'type': selectedType.name,
                              'content': contentController.text.trim().isNotEmpty ? contentController.text.trim() : '（图片日志）',
                              'attachmentIds': attachmentIds,
                            });
                          }

                          final query = TimelineQuery(familyId: familyId, recipientId: _selectedRecipientId);
                          ref.read(timelineProvider(query).notifier).refresh();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('已记录'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('保存失败: $err'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      child: Text(
                        isHealth ? '记录健康数据' : '保存日志',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
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

  /// 健康数据输入表单
  Widget _buildHealthInput(
    HealthMetricType metric,
    TextEditingController bpSys,
    TextEditingController bpDia,
    TextEditingController glucose,
    String glucoseType,
    TextEditingController weight,
    String weightUnit,
    void Function(String) setGlucoseType,
    void Function(String) setWeightUnit,
    void Function(void Function()) setSheetState,
  ) {
    switch (metric) {
      case HealthMetricType.bloodPressure:
        return Row(
          children: [
            Expanded(
              child: _buildNumberField(
                controller: bpSys,
                label: '收缩压',
                hint: '120',
                unit: 'mmHg',
                color: AppColors.primary,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/', style: TextStyle(fontSize: 24, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: _buildNumberField(
                controller: bpDia,
                label: '舒张压',
                hint: '80',
                unit: 'mmHg',
                color: AppColors.primary,
              ),
            ),
          ],
        );

      case HealthMetricType.bloodGlucose:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: glucose,
                    label: '血糖值',
                    hint: '5.6',
                    unit: 'mmol/L',
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 空腹/餐后切换
            Row(
              children: [
                _buildSubTypeChip('空腹', glucoseType == 'fasting', () => setGlucoseType('fasting'), AppColors.primary),
                const SizedBox(width: 8),
                _buildSubTypeChip('餐后', glucoseType == 'postprandial', () => setGlucoseType('postprandial'), AppColors.primary),
              ],
            ),
          ],
        );

      case HealthMetricType.weight:
        return Row(
          children: [
            Expanded(
              child: _buildNumberField(
                controller: weight,
                label: '体重',
                hint: '60',
                unit: '',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: weightUnit,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: '斤', child: Text('斤', style: TextStyle(color: AppColors.textPrimary))),
                ],
                onChanged: (v) { if (v != null) setWeightUnit(v); },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Text(unit, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTypeChip(String label, bool isSelected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── 附件相关方法 ───

  Widget _buildAttachmentPicker(
    List<XFile> selectedAttachments,
    void Function(void Function()) setSheetState,
    VoidCallback onPick,
  ) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '添加图片/视频',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '最多 9 个文件，支持拍照和相册',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(
    List<XFile> selectedAttachments,
    void Function(void Function()) setSheetState,
  ) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selectedAttachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = selectedAttachments[index];
          final isVideo = file.mimeType?.startsWith('video/') ?? false;
          return SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: AppColors.surfaceContainerLow,
                      child: Icon(
                        isVideo ? Icons.videocam : Icons.image,
                        color: AppColors.textSecondary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                if (isVideo)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setSheetState(() {
                      // 用下标删除，避免列表在遍历中修改
                      if (index < selectedAttachments.length) {
                        selectedAttachments.removeAt(index);
                      }
                    }),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAttachments(
    void Function(void Function()) setSheetState,
    List<XFile> selectedAttachments,
  ) async {
    final picker = ImagePicker();

    // 显示图片来源选择（暂时只提供相册，相机/视频功能在真机上需单独配置权限）
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Text(
              '添加图片或视频',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _buildPickOption(ctx, Icons.photo_library_rounded, '从相册选择（图片和视频）', () => Navigator.pop(ctx, 'gallery')),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      // 统一使用相册选择，支持图片和视频
      final images = await picker.pickMultipleMedia();
      if (images.isNotEmpty) {
        final remaining = 9 - selectedAttachments.length;
        setSheetState(() {
          selectedAttachments.addAll(images.take(remaining > 0 ? remaining : 0));
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Widget _buildPickOption(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  /// 日志卡片内附件缩略图网格
  Widget _buildAttachmentGrid(List<CareLogAttachment> attachments) {
    final count = attachments.length;
    if (count == 0) return const SizedBox();

    final displayCount = count > 3 ? 3 : count;
    final extraCount = count > 3 ? count - 3 : 0;

    return SizedBox(
      height: 100,
      child: Row(
        children: List.generate(displayCount, (idx) {
          final att = attachments[idx];
          final url = ApiConfig.attachmentUrl(att.thumbnailUrl ?? att.url);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: idx > 0 ? 4 : 0),
              child: GestureDetector(
                onTap: () => _showAttachmentViewer(attachments, idx),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      SizedBox.expand(
                        child: att.isImage
                            ? Image.network(
                                url ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.surfaceContainerLow,
                                  child: const Icon(Icons.broken_image, color: AppColors.textTertiary),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceContainerLow,
                                child: const Icon(Icons.videocam, color: AppColors.textSecondary, size: 32),
                              ),
                      ),
                      if (att.isVideo)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                          ),
                        ),
                      if (extraCount > 0 && idx == 2)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: Center(
                              child: Text(
                                '+$extraCount',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
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
        }),
      ),
    );
  }

  /// 全屏查看附件（图片/视频）
  void _showAttachmentViewer(List<CareLogAttachment> attachments, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AttachmentViewerPage(
          attachments: attachments,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ─── 工具方法 ───

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(DateTime t) {
    final hour = t.hour;
    final minute = t.minute.toString().padLeft(2, '0');
    if (hour < 12) {
      return '上午 ${hour.toString().padLeft(2, '0')}:$minute';
    } else {
      return '下午 ${(hour - 12).toString().padLeft(2, '0')}:$minute';
    }
  }

  String _weekdayLabel(int w) {
    const labels = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[w];
  }
}

/// 全屏附件查看页面
class _AttachmentViewerPage extends StatefulWidget {
  final List<CareLogAttachment> attachments;
  final int initialIndex;

  const _AttachmentViewerPage({
    required this.attachments,
    required this.initialIndex,
  });

  @override
  State<_AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<_AttachmentViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1} / ${widget.attachments.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.attachments.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final att = widget.attachments[index];
          final url = ApiConfig.attachmentUrl(att.url);

          if (att.isImage) {
            return Center(
              child: Image.network(
                url ?? '',
                fit: BoxFit.contain,
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            );
          } else {
            // 视频占位，实际播放需要 video_player 包
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    '视频播放',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  if (url != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        url,
                        style: const TextStyle(color: Colors.white30, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
