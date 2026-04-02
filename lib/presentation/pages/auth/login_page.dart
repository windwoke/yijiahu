/// 登录页
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/env/env_config.dart';
import '../../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';

class _PhoneField extends StatefulWidget {
  const _PhoneField({super.key});

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextEditingController get controller => _controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      key: const ValueKey('phone_field'),
      keyboardType: TextInputType.phone,
      maxLength: 11,
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: '手机号',
        hintText: '请输入手机号',
        hintStyle: const TextStyle(color: AppColors.grey400),
        prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.grey500, size: 20),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _CodeField extends StatefulWidget {
  const _CodeField({super.key});

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextEditingController get controller => _controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      key: const ValueKey('code_field'),
      keyboardType: TextInputType.number,
      maxLength: 6,
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: '验证码',
        hintText: '请输入验证码',
        hintStyle: const TextStyle(color: AppColors.grey400),
        prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.grey500, size: 20),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({super.key});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextEditingController get controller => _controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      key: const ValueKey('password_field'),
      obscureText: true,
      maxLength: 20,
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        hintStyle: const TextStyle(color: AppColors.grey400),
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.grey500, size: 20),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _CountdownButton extends StatefulWidget {
  final VoidCallback onSendCode;

  const _CountdownButton({required this.onSendCode});

  @override
  State<_CountdownButton> createState() => _CountdownButtonState();
}

class _CountdownButtonState extends State<_CountdownButton> {
  int _countdown = 0;
  Timer? _timer;

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
        setState(() => _countdown = 0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _countdown > 0 ? null : _handleSendCode,
      style: FilledButton.styleFrom(
        backgroundColor: _countdown > 0 ? AppColors.grey200 : AppColors.primary,
        foregroundColor: _countdown > 0 ? AppColors.grey500 : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        _countdown > 0 ? '${_countdown}s' : '获取验证码',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _handleSendCode() {
    _startCountdown();
    widget.onSendCode();
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneFieldKey = GlobalKey<_PhoneFieldState>();
  final _codeFieldKey = GlobalKey<_CodeFieldState>();
  final _passwordFieldKey = GlobalKey<_PasswordFieldState>();

  /// false = 验证码登录，true = 密码登录
  bool _usePassword = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 10)),
    );
  }

  void _sendCode() {
    final phone = _phoneFieldKey.currentState!.controller.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showError('请输入正确的手机号');
      return;
    }
    ref.read(authStateProvider.notifier).sendCode(phone).then((_) {
      if (!mounted) return;
      // 开发模式：显示 mock 验证码
      if (AppEnv.isDebug) {
        final mockCode = ref.read(authStateProvider.notifier).lastMockCode;
        if (mockCode != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('开发模式 · 验证码：$mockCode'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }).catchError((e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    });
  }

  Future<void> _login() async {
    final phone = _phoneFieldKey.currentState!.controller.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showError('请输入正确的手机号');
      return;
    }

    if (_usePassword) {
      final password = _passwordFieldKey.currentState!.controller.text.trim();
      if (password.isEmpty) {
        _showError('请输入密码');
        return;
      }
      await ref.read(authStateProvider.notifier).loginWithPassword(
            phone: phone,
            password: password,
          );
    } else {
      final code = _codeFieldKey.currentState!.controller.text.trim();
      if (code.length != 6) {
        _showError('请输入6位验证码');
        return;
      }
      await ref.read(authStateProvider.notifier).login(
            phone: phone,
            code: code,
          );
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState.error != null) {
      _showError(authState.error!);
    } else if (authState.isLoggedIn) {
      context.go(AppRoutes.home);
    } else {
      _showError('登录失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 品牌渐变背景
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF0F7F4), // 淡绿背景（AppColors 暂无对应值）
                    AppColors.background,      // 米白背景
                  ],
                ),
              ),
            ),
          ),
          // 右上角装饰圆
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          // 左下角装饰圆
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppTexts.appName,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppTexts.appSlogan,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.grey500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  _PhoneField(key: _phoneFieldKey),
                  const SizedBox(height: 16),
                  if (_usePassword)
                    _PasswordField(key: _passwordFieldKey)
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _CodeField(key: _codeFieldKey),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: _CountdownButton(
                            onSendCode: _sendCode,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        key: ValueKey(_usePassword),
                        onPressed: () {
                          setState(() => _usePassword = !_usePassword);
                        },
                        child: Text(
                          _usePassword ? '验证码登录' : '密码登录',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    AppTexts.disclaimer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.grey400,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
