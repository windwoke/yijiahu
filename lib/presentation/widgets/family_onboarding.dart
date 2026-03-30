import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';
import '../../core/network/api_client.dart';
import '../providers/providers.dart';

/// 家庭引导遮罩（全屏覆盖，禁用底部 Tab 切换）
class FamilyOnboardingOverlay extends StatelessWidget {
  final VoidCallback onComplete;

  const FamilyOnboardingOverlay({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: SafeArea(
        child: Center(
          child: FamilyOnboardingCard(onComplete: onComplete),
        ),
      ),
    );
  }
}

/// 家庭引导卡片（弹窗风格）
class FamilyOnboardingCard extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const FamilyOnboardingCard({super.key, required this.onComplete});

  @override
  ConsumerState<FamilyOnboardingCard> createState() => _FamilyOnboardingCardState();
}

class _FamilyOnboardingCardState extends ConsumerState<FamilyOnboardingCard> {
  bool _joining = false;
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateFamilyMiniSheet(),
    );
    if (name == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/families', data: {'name': name.trim()});
      final family = Family.fromJson(response.data as Map<String, dynamic>);
      ref.read(currentFamilyProvider.notifier).state = family;
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinFamily() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入邀请码'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/families/join', data: {'inviteCode': code});
      ref.invalidate(myFamiliesProvider);
      await ref.read(myFamiliesProvider.future);
      final families = ref.read(myFamiliesProvider).valueOrNull ?? [];
      if (families.isNotEmpty) {
        ref.read(currentFamilyProvider.notifier).state = families.last;
      }
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '欢迎使用一家护',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '创建或加入一个家庭，开始使用',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (!_joining) ...[
              Row(
                children: [
                  Expanded(
                    child: _OnboardBtn(
                      emoji: '🏠', label: '创建新家庭',
                      color: AppColors.primary,
                      onTap: _createFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OnboardBtn(
                      emoji: '🔗', label: '输入邀请码加入',
                      color: AppColors.blue,
                      onTap: () => setState(() => _joining = true),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                '输入家庭邀请码',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inviteCodeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 16, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: '请输入 8 位邀请码',
                  hintStyle: const TextStyle(color: AppColors.grey400, letterSpacing: 0),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _joining = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('返回'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _joinFamily,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('确认加入', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 引导页操作按钮
class _OnboardBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OnboardBtn({
    required this.emoji, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// 创建家庭迷你弹层
class _CreateFamilyMiniSheet extends StatefulWidget {
  @override
  State<_CreateFamilyMiniSheet> createState() => _CreateFamilyMiniSheetState();
}

class _CreateFamilyMiniSheetState extends State<_CreateFamilyMiniSheet> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '创建新家庭',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '为你的家庭起个名字',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 50,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '例如：老张家、老王家',
              hintStyle: const TextStyle(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('家庭名称至少需要 2 个字'), duration: Duration(seconds: 2)),
                  );
                  return;
                }
                Navigator.pop(context, name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('创建', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.grey500)),
          ),
        ],
      ),
    );
  }
}
