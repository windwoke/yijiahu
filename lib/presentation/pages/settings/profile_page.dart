/// 个人中心 / 设置页
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/router/app_router.dart';
import '../../../core/env/env_config.dart';
import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart' as models;
import '../../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isUploading = false;

  String _maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(authStateProvider.notifier).uploadAvatar(File(image.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像更新成功'), duration: Duration(seconds: 10)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: $e'), duration: const Duration(seconds: 10)));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _editName() async {
    final user = ref.read(authStateProvider).user;
    final controller = TextEditingController(text: user?.name ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NameEditSheet(controller: controller),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ref.read(authStateProvider.notifier).updateProfile(name: result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('昵称已更新'), duration: Duration(seconds: 10)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('修改失败: $e'), duration: const Duration(seconds: 10)));
        }
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogoutConfirmSheet(),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  // ========== 家庭操作 ==========

  Future<void> _showSwitchFamilySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SwitchFamilySheet(),
    );
  }

  Future<void> _showJoinFamilySheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JoinFamilySheet(),
    );

    if (result == null) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/families/join', data: {'inviteCode': result.trim()});
      // 刷新家庭列表和当前家庭
      ref.invalidate(myFamiliesProvider);
      await ref.read(myFamiliesProvider.future);
      final families = ref.read(myFamiliesProvider).valueOrNull ?? [];
      if (families.isNotEmpty) {
        ref.read(currentFamilyProvider.notifier).state = families.last;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加入成功'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入失败: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _showCreateFamilySheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateFamilySheet(),
    );

    if (result == null) return;

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/families', data: {'name': result.trim()});
      final family = models.Family.fromJson(response.data as Map<String, dynamic>);
      // 切换到新家庭
      ref.read(currentFamilyProvider.notifier).state = family;
      ref.invalidate(myFamiliesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建成功：$result'), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  // ========== 页面结构 ==========

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final family = ref.watch(currentFamilyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: MediaQuery.of(context).padding.bottom + 32,
        ),
        children: [
          // 顶部用户信息卡片
          _buildUserCard(user),
          const SizedBox(height: 20),

          // 账号
          _buildSectionHeader('账号'),
          _buildCard([
            _buildSettingItem(
              icon: Icons.phone_iphone_rounded,
              title: '更换手机号',
              onTap: () => _showToast('更换手机号'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.notifications_rounded,
              title: '通知设置',
              onTap: () => _showToast('通知设置'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.lock_outline_rounded,
              title: '修改密码',
              onTap: () => context.push(AppRoutes.passwordChange),
            ),
          ]),

          const SizedBox(height: 16),

          // 家庭
          _buildSectionHeader('家庭'),
          _buildCard([
            _buildSettingItem(
              icon: Icons.swap_horiz_rounded,
              title: '切换家庭',
              subtitle: family?.name ?? '我的家庭',
              onTap: _showSwitchFamilySheet,
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.group_add_outlined,
              title: '加入新家庭',
              onTap: _showJoinFamilySheet,
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.add_home_outlined,
              title: '创建新家庭',
              onTap: _showCreateFamilySheet,
            ),
          ]),

          const SizedBox(height: 16),

          // 提醒
          _buildSectionHeader('提醒'),
          _buildCard([
            _buildSettingItem(
              icon: Icons.schedule_outlined,
              title: '用药提醒提前',
              subtitle: '15 分钟',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              onTap: () => _showToast('用药提醒提前'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.event_outlined,
              title: '复诊提醒提前',
              subtitle: '48 小时',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              onTap: () => _showToast('复诊提醒提前'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.volume_up_rounded,
              title: '推送声音',
              subtitle: '默认',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              onTap: () => _showToast('推送声音'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.do_not_disturb_on_outlined,
              title: '免打扰时段',
              subtitle: '22:00 - 07:00',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              onTap: () => _showToast('免打扰时段'),
            ),
          ]),

          const SizedBox(height: 16),

          // 微信生态
          _buildSectionHeader('微信生态'),
          _buildCard([
            _buildSettingItem(
              icon: Icons.chat_bubble_outline_rounded,
              title: '微信服务通知',
              trailing: _buildSwitch(true, (_) {}),
              onTap: null,
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.share_outlined,
              title: '微信分享',
              trailing: _buildSwitch(true, (_) {}),
              onTap: null,
            ),
          ]),

          const SizedBox(height: 16),

          // 关于
          _buildSectionHeader('关于'),
          _buildCard([
            _buildSettingItem(
              icon: Icons.info_outline_rounded,
              title: '关于我们',
              onTap: () => _showToast('关于我们'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.description_outlined,
              title: '隐私政策',
              onTap: () => _showToast('隐私政策'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.article_outlined,
              title: '用户协议',
              onTap: () => _showToast('用户协议'),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.info_outline_rounded,
              title: '版本',
              trailing: const Text('1.0.0',
                  style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
              onTap: null,
            ),
          ]),

          const SizedBox(height: 24),

          // 退出登录（自然流式）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Text('退出登录'),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ========== 组件 ==========

  Widget _buildUserCard(dynamic user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                      ),
                      child: user?.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                ApiConfig.avatarUrl(user!.avatarUrl) ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.person, color: Colors.white, size: 30),
                              ),
                            )
                          : const Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child:
                            const Icon(Icons.camera_alt, size: 12, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _editName,
                      child: Row(
                        children: [
                          Text(
                            user?.name?.isNotEmpty == true ? user!.name! : '未设置昵称',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _maskPhone(user?.phone ?? ''),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(color: AppColors.shadowSoft2, blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 56),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
            ),
            if (subtitle != null)
              Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textTertiary)),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(bool value, ValueChanged<bool> onChanged) {
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary,
      activeThumbColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showToast(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 功能即将上线'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ========== 切换家庭底部弹层 ==========

class _SwitchFamilySheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familiesAsync = ref.watch(myFamiliesProvider);
    final currentFamily = ref.watch(currentFamilyProvider);

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
            '切换家庭',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          familiesAsync.when(
            data: (families) {
              if (families.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('暂未加入任何家庭', style: TextStyle(color: AppColors.textTertiary)),
                );
              }
              return Column(
                children: families.map((f) {
                  final isSelected = f.id == currentFamily?.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        ref.read(currentFamilyProvider.notifier).state = f;
                        ref.invalidate(careRecipientsProvider);
                        ref.invalidate(familyMembersProvider(f.id));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 20)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (f.description != null && f.description!.isNotEmpty)
                                    Text(
                                      f.description!,
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.textTertiary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded,
                                  color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('加载失败: $e', style: const TextStyle(color: AppColors.error)),
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

// ========== 加入新家庭弹层 ==========

class _JoinFamilySheet extends StatefulWidget {
  @override
  State<_JoinFamilySheet> createState() => _JoinFamilySheetState();
}

class _JoinFamilySheetState extends State<_JoinFamilySheet> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
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
            '加入新家庭',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '请输入家庭邀请码',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'XXXXXXXX',
              hintStyle: const TextStyle(
                color: AppColors.grey300,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
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
              onPressed: _isLoading
                  ? null
                  : () {
                      final code = _codeController.text.trim();
                      if (code.isEmpty) return;
                      Navigator.pop(context, code);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('加入'),
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

// ========== 创建新家庭弹层 ==========

class _CreateFamilySheet extends StatefulWidget {
  @override
  State<_CreateFamilySheet> createState() => _CreateFamilySheetState();
}

class _CreateFamilySheetState extends State<_CreateFamilySheet> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

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
            maxLength: 20,
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
              onPressed: _isLoading
                  ? null
                  : () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(context, name);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('创建'),
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

// ========== 昵称修改底部弹层 ==========

class _NameEditSheet extends StatefulWidget {
  final TextEditingController controller;
  const _NameEditSheet({required this.controller});

  @override
  State<_NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends State<_NameEditSheet> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.text);
  }

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
            '修改昵称',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 20,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '请输入昵称',
              hintStyle: const TextStyle(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.grey100,
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Text('保存',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
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

// ========== 退出确认底部弹层 ==========

class _LogoutConfirmSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout, color: AppColors.coral, size: 26),
          ),
          const SizedBox(height: 16),
          const Text(
            '确定要退出登录吗？',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('退出登录'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppColors.grey500)),
          ),
        ],
      ),
    );
  }
}
