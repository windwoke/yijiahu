/// 登录页
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
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
      decoration: const InputDecoration(
        labelText: '手机号',
        hintText: '请输入手机号',
        prefixIcon: Icon(Icons.phone_outlined),
        counterText: '',
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
      obscureText: true,
      decoration: const InputDecoration(
        labelText: '验证码',
        hintText: '请输入验证码',
        prefixIcon: Icon(Icons.lock_outlined),
        counterText: '',
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
      decoration: const InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        prefixIcon: Icon(Icons.lock_outline),
        counterText: '',
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
    return OutlinedButton(
      onPressed: _countdown > 0 ? null : _handleSendCode,
      child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
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
    ref.read(authStateProvider.notifier).sendCode(phone).catchError((e) {
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppTexts.appName,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppTexts.appSlogan,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
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
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('登录'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => _usePassword = !_usePassword);
                  },
                  child: Text(
                    _usePassword ? '验证码登录' : '密码登录',
                    style: const TextStyle(color: Color(0xFF00BFA5)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppTexts.disclaimer,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
