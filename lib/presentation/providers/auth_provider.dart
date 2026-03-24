/// 认证状态 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user.dart';

/// 认证状态
class AuthState {
  final User? user;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  bool get isLoggedIn => accessToken != null && user != null;

  AuthState copyWith({
    User? user,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 认证 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _loadFromStorage();
  }

  static const _tokenKey = 'access_token';
  static const _userKey = 'user_data';

  SharedPreferences? _prefs;

  Future<void> _loadFromStorage() async {
    _prefs = await SharedPreferences.getInstance();
    final token = _prefs?.getString(_tokenKey);
    if (token != null) {
      // TODO: 从存储恢复用户信息
      state = state.copyWith(accessToken: token);
    }
  }

  Future<void> login({
    required String phone,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: 调用 API
      // final response = await dio.post('/auth/login', data: {
      //   'phone': phone,
      //   'code': code,
      // });

      // 模拟登录成功
      await Future.delayed(const Duration(seconds: 1));

      final user = User(
        id: 'test_user_id',
        phone: phone,
        name: '测试用户',
        createdAt: DateTime.now(),
      );
      const token = 'mock_token';

      await _prefs?.setString(_tokenKey, token);

      state = AuthState(
        user: user,
        accessToken: token,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_userKey);
    state = const AuthState();
  }
}

/// 认证状态 Provider
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
