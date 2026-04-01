/// 每日护理打卡页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/env/env_config.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class DailyCarePage extends ConsumerStatefulWidget {
  final String recipientId;
  final CareRecipient recipient;

  const DailyCarePage({
    super.key,
    required this.recipientId,
    required this.recipient,
  });

  @override
  ConsumerState<DailyCarePage> createState() => _DailyCarePageState();
}

class _DailyCarePageState extends ConsumerState<DailyCarePage> {
  CheckinStatus _selectedStatus = CheckinStatus.normal;
  final _noteController = TextEditingController();
  bool _isLoading = false;

  // 今日药品完成情况（从 provider 加载）
  int _medCompleted = 0;
  int _medTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayMedication();
  }

  Future<void> _loadTodayMedication() async {
    try {
      // 加载今日用药完成情况
      final todaySummary = await ref.read(todayMedicationProvider(widget.recipientId).future);
      if (!mounted) return;

      // 加载今日打卡已有的数据
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final dio = ref.read(dioProvider);
      final familyId = ref.read(currentFamilyProvider)?.id;
      final resp = await dio.get('/daily-care-checkins/today', queryParameters: {
        'recipientIds': widget.recipientId,
        'todayDate': todayStr,
        'familyId': familyId,
      });

      if (!mounted) return;

      if (resp.data is List && (resp.data as List).isNotEmpty) {
        final checkin = DailyCareCheckin.fromJson((resp.data as List)[0] as Map<String, dynamic>);
        setState(() {
          _medCompleted = checkin.medicationCompleted;
          _medTotal = checkin.medicationTotal > 0 ? checkin.medicationTotal : todaySummary.total;
          _selectedStatus = checkin.status;
          if (checkin.specialNote != null) {
            _noteController.text = checkin.specialNote!;
          }
        });
      } else {
        // 自动拉取今日打卡记录
        final checkins = await ref.read(checkinHistoryProvider(widget.recipientId).future);
        if (!mounted) return;
        final todayDate = DateTime(today.year, today.month, today.day);
        final todayCheckin = checkins.where((c) {
          return c.checkinDate.year == todayDate.year &&
              c.checkinDate.month == todayDate.month &&
              c.checkinDate.day == todayDate.day;
        }).toList();
        if (todayCheckin.isNotEmpty) {
          final c = todayCheckin.first;
          setState(() {
            _medCompleted = c.medicationCompleted;
            _medTotal = c.medicationTotal > 0 ? c.medicationTotal : todaySummary.total;
            _selectedStatus = c.status;
            if (c.specialNote != null) {
              _noteController.text = c.specialNote!;
            }
          });
        } else {
          // 无打卡记录，用今日药品打卡数填充
          setState(() {
            _medCompleted = todaySummary.completed;
            _medTotal = todaySummary.total > 0 ? todaySummary.total : _medTotal;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await submitCheckin(
        ref: ref,
        careRecipientId: widget.recipientId,
        status: _selectedStatus,
        medicationCompleted: _medCompleted,
        medicationTotal: _medTotal,
        specialNote: _noteController.text.isNotEmpty ? _noteController.text : null,
      );
      // 刷新今日打卡数据
      ref.invalidate(careRecipientsProvider);
      ref.invalidate(checkinHistoryProvider(widget.recipientId));
      final familyId = ref.read(currentFamilyProvider)?.id;
      if (familyId != null) ref.invalidate(todayCheckinsProvider(familyId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打卡成功'), duration: Duration(seconds: 2)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打卡失败: $e'), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '今日护理打卡',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 照护对象卡片
          _buildRecipientCard(),
          const SizedBox(height: 20),

          // 状态选择
          _buildSectionTitle('老人今日状态'),
          const SizedBox(height: 12),
          _buildStatusSelector(),
          const SizedBox(height: 24),

          // 用药完成情况
          _buildSectionTitle('用药情况'),
          const SizedBox(height: 12),
          _buildMedicationCard(),
          const SizedBox(height: 24),

          // 特殊情况备注
          _buildSectionTitle('特殊情况（选填）'),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '如：发热、腹泻、食欲不佳、跌倒等特殊情况',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),

          // 提交按钮
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    '确认打卡',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: AppColors.shadowSoft2, blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.coral.withValues(alpha: 0.1),
            child: (widget.recipient.avatarUrl != null && widget.recipient.avatarUrl!.isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      ApiConfig.avatarUrl(widget.recipient.avatarUrl!) ?? '',
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      errorBuilder: (_, __, ___) => Text(
                        widget.recipient.displayAvatar,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  )
                : widget.recipient.displayAvatar.isNotEmpty
                    ? Text(
                        widget.recipient.displayAvatar,
                        style: const TextStyle(fontSize: 24),
                      )
                    : const Icon(Icons.person_rounded, color: AppColors.coral, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipient.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(DateTime.now()),
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: CheckinStatus.values.map((s) {
        final isSelected = _selectedStatus == s;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? s.color.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? s.color : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: s.color.withValues(alpha: 0.2), blurRadius: 8)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? s.color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMedicationCard() {
    final progress = _medTotal > 0 ? (_medCompleted / _medTotal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.medication_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                '今日用药',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _medTotal > 0 ? '$_medCompleted / $_medTotal 项' : '暂无药品',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _medTotal > 0 ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (_medTotal > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.grey100,
                valueColor: AlwaysStoppedAnimation(
                  progress >= 0.8 ? AppColors.success : (_medTotal > 0 ? AppColors.primary : AppColors.grey200),
                ),
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}年${d.month}月${d.day}日 ${_weekday(d)}';

  String _weekday(DateTime d) {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[d.weekday - 1];
  }
}
