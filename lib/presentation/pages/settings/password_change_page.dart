/// 修改密码页面（同时支持设置密码）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/constants.dart';
import '../../providers/auth_provider.dart';

class PasswordChangePage extends ConsumerStatefulWidget {
  const PasswordChangePage({super.key});

  @override
  ConsumerState<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends ConsumerState<PasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  /// 密码强度：0=无, 1=弱, 2=中, 3=强
  int _passwordStrength = 0;
  String _strengthLabel = '';

  @override
  void initState() {
    super.initState();
    _newPwdController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final pwd = _newPwdController.text;
    if (pwd.isEmpty) {
      setState(() { _passwordStrength = 0; _strengthLabel = ''; });
    } else if (pwd.length < 6) {
      setState(() { _passwordStrength = 1; _strengthLabel = '太短，至少6位'; });
    } else if (pwd.length < 10) {
      setState(() { _passwordStrength = 2; _strengthLabel = '中等强度'; });
    } else {
      final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
      final hasDigit = pwd.contains(RegExp(r'[0-9]'));
      final hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      if (hasUpper && hasDigit && hasSpecial) {
        setState(() { _passwordStrength = 3; _strengthLabel = '高强度'; });
      } else if ((hasUpper && hasDigit) || (hasUpper && hasSpecial) || (hasDigit && hasSpecial)) {
        setState(() { _passwordStrength = 3; _strengthLabel = '强'; });
      } else {
        setState(() { _passwordStrength = 2; _strengthLabel = '中等强度'; });
      }
    }
  }

  @override
  void dispose() {
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPwdController.text != _confirmPwdController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的新密码不一致'), duration: Duration(seconds: 10)),
      );
      return;
    }

    final hasPassword = ref.read(authStateProvider).user?.hasPassword ?? false;
    setState(() => _isLoading = true);
    try {
      await ref.read(authStateProvider.notifier).changePassword(
            hasPassword ? _oldPwdController.text : '',
            _newPwdController.text,
          );
      if (mounted) {
        // 设置密码成功后更新本地状态
        if (!hasPassword) {
          ref.read(authStateProvider.notifier).updateLocalHasPassword(true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码设置成功'), duration: Duration(seconds: 10)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), duration: const Duration(seconds: 10)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = ref.watch(authStateProvider).user?.hasPassword ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          hasPassword ? '修改密码' : '设置密码',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 说明
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasPassword
                              ? '为保障账户安全，请定期更换密码'
                              : '设置登录密码，方便换手机时使用',
                          style: const TextStyle(fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputCard(
                  children: [
                    if (hasPassword) ...[
                      _buildTextField(
                        controller: _oldPwdController,
                        label: '旧密码',
                        hint: '请输入旧密码',
                        obscure: _obscureOld,
                        onToggleObscure: () => setState(() => _obscureOld = !_obscureOld),
                        validator: (v) => v == null || v.isEmpty ? '请输入旧密码' : null,
                      ),
                      _buildDivider(),
                    ],
                    _buildTextField(
                      controller: _newPwdController,
                      label: hasPassword ? '新密码' : '密码',
                      hint: '6位以上',
                      obscure: _obscureNew,
                      onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请输入密码';
                        if (v.length < 6) return '密码至少6位';
                        return null;
                      },
                    ),
                    _buildDivider(),
                    _buildTextField(
                      controller: _confirmPwdController,
                      label: '确认密码',
                      hint: '再次输入密码',
                      obscure: _obscureConfirm,
                      onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) => v == null || v.isEmpty ? '请确认密码' : null,
                    ),
                  ],
                ),
                // 密码强度指示器
                if (_passwordStrength > 0) ...[
                  const SizedBox(height: 12),
                  _buildStrengthIndicator(),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthIndicator() {
    final color = _passwordStrength == 1
        ? AppColors.strengthWeak
        : _passwordStrength == 2
            ? AppColors.strengthMedium
            : AppColors.strengthStrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 4, decoration: BoxDecoration(
              color: _passwordStrength >= 1 ? color : AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ))),
            const SizedBox(width: 4),
            Expanded(child: Container(height: 4, decoration: BoxDecoration(
              color: _passwordStrength >= 2 ? color : AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ))),
            const SizedBox(width: 4),
            Expanded(child: Container(height: 4, decoration: BoxDecoration(
              color: _passwordStrength >= 3 ? color : AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ))),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '密码强度：$_strengthLabel',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14),
          labelStyle: const TextStyle(color: AppColors.primary, fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.grey400, size: 20),
            onPressed: onToggleObscure,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }
}
