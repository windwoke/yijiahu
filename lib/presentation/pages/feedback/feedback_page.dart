/// 问题反馈页
/// 表单提交到后端 → 飞书 webhook 即时通知
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';

const _categories = [
  _CatItem(key: 'bug', icon: Icons.bug_report_outlined, label: '问题反馈', desc: '功能异常、闪退、数据错误'),
  _CatItem(key: 'feature', icon: Icons.lightbulb_outline, label: '功能建议', desc: '希望增加的新功能'),
  _CatItem(key: 'other', icon: Icons.edit_note_outlined, label: '其他', desc: '使用咨询、合作等'),
];

class _CatItem {
  final String key;
  final IconData icon;
  final String label;
  final String desc;
  const _CatItem({required this.key, required this.icon, required this.label, required this.desc});
}

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  String _category = 'bug';
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showToast('请输入反馈内容');
      return;
    }
    if (content.length < 5) {
      _showToast('反馈内容至少5个字');
      return;
    }

    setState(() => _submitting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/feedback', data: {
        'category': _category,
        'content': content,
        if (_contactController.text.trim().isNotEmpty)
          'contact': _contactController.text.trim(),
      });
      if (!mounted) return;
      _showToast('感谢反馈，我们会尽快处理！');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showToast('提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentController.text;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('问题反馈'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 反馈类型
            _buildSectionTitle('反馈类型'),
            ..._categories.map((cat) => _buildCategoryCard(cat)),

            const SizedBox(height: 20),

            // 详细描述
            _buildSectionTitle('详细描述'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: '请描述您遇到的问题或建议，越详细越好...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.6),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 联系方式
            _buildSectionTitle('联系方式（选填）'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _contactController,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: '手机号 / 微信号 / 邮箱（选填）',
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  border: InputBorder.none,
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(height: 28),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_submitting || content.trim().isEmpty) ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  _submitting ? '提交中...' : '提交反馈',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildCategoryCard(_CatItem cat) {
    final selected = _category == cat.key;
    return GestureDetector(
      onTap: () => setState(() => _category = cat.key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(cat.icon, size: 20, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat.desc,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
