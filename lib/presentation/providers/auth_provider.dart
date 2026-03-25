/// 认证状态 Provider
library;

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user.dart';
import '../../data/models/models.dart' as models;
import '../../core/network/api_client.dart';
import 'family_provider.dart';

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

/// 验证码倒计时（独立 provider，只影响按钮，不刷新整个页面）
final countdownProvider = StateProvider<int>((ref) => 0);

/// 认证 Notifier（使用 Notifier 以获得 ref 访问）
class AuthNotifier extends Notifier<AuthState> {
  Dio? _dio;
  Timer? _countdownTimer;
  TextEditingController? _phoneController;

  @override
  AuthState build() {
    _dio = ref.read(dioProvider);
    ref.onDispose(() => _countdownTimer?.cancel());
    // 异步加载，不阻塞初始化
    _loadFromStorage();
    return const AuthState();
  }

  static const _tokenKey = 'access_token';

  SharedPreferences? _prefs;

  Future<void> _loadFromStorage() async {
    _prefs = await SharedPreferences.getInstance();
    final token = _prefs?.getString(_tokenKey);
    if (token != null) {
      state = state.copyWith(accessToken: token);
      await _fetchCurrentUser();
      await _loadCurrentFamily();
    }
  }

  Future<void> _loadCurrentFamily() async {
    try {
      final res = await _dio!.get('/users/me/family');
      final data = res.data;
      if (data is Map && data['family'] != null) {
        ref.read(currentFamilyProvider.notifier).state =
            models.Family.fromJson(data['family'] as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final response = await _dio!.get('/users/me');
      // 后端直接返回用户对象，不是 {data: user}
      final rawData = response.data;
      if (rawData is! Map<String, dynamic>) return;
      final user = User.fromJson(rawData);
      state = state.copyWith(user: user);
    } catch (_) {
      // token 可能已失效，忽略
    }
  }

  void setPhoneController(TextEditingController controller) {
    _phoneController = controller;
  }

  /// 从已注入的 TextEditingController 读取手机号并发送验证码
  Future<void> sendCodeWithController() async {
    final phone = _phoneController?.text.trim() ?? '';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      throw Exception('请输入正确的手机号');
    }
    await sendCode(phone);
  }

  /// 发送验证码
  Future<void> sendCode(String phone) async {
    try {
      await _dio!.post('/auth/send-code', data: {'phone': phone});
      state = state.copyWith(error: null);
      _startCountdown();
    } on DioException catch (e) {
      try {
        throw Exception(handleDioError(e).message);
      } catch (_) {
        throw Exception('发送验证码失败，请重试');
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    ref.read(countdownProvider.notifier).state = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = ref.read(countdownProvider);
      if (current > 1) {
        ref.read(countdownProvider.notifier).state = current - 1;
      } else {
        _countdownTimer?.cancel();
        ref.read(countdownProvider.notifier).state = 0;
      }
    });
  }

  /// 登录
  Future<void> login({required String phone, required String code}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio!.post('/auth/login', data: {
        'phone': phone,
        'code': code,
      });

      // 响应可能是 {"accessToken":..., "user":...} 直接返回，或 {"data": {"accessToken":..., "user":...}}
      final rawData = response.data;
      Map<String, dynamic> data;
      if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
        data = rawData['data'] as Map<String, dynamic>;
      } else if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else {
        throw Exception('登录响应格式错误');
      }

      // accessToken 或 access_token
      final token = (data['accessToken'] ?? data['access_token']) as String?;
      if (token == null) throw Exception('登录响应格式错误');

      final userData = data['user'] as Map<String, dynamic>;

      await _prefs?.setString(_tokenKey, token);

      final user = User.fromJson(userData);

      _countdownTimer?.cancel();
      ref.read(countdownProvider.notifier).state = 0;
      state = AuthState(user: user, accessToken: token, isLoading: false);

      // 登录成功后加载当前用户家庭
      await _loadCurrentFamily();
    } on DioException catch (e) {
      try {
        state = state.copyWith(isLoading: false, error: handleDioError(e).message);
      } catch (_) {
        state = state.copyWith(isLoading: false, error: '请求失败，请重试');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    _countdownTimer?.cancel();
    await _prefs?.remove(_tokenKey);
    // 清除家庭数据，避免切换账号后残留旧数据
    ref.read(currentFamilyProvider.notifier).state = null;
    state = const AuthState();
  }

  /// 更新个人资料
  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (avatarUrl != null) body['avatar'] = avatarUrl;

    final response = await _dio!.patch('/users/me', data: body);
    // 后端直接返回用户对象，不包装在 data 里
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    if (state.user != null) {
      final updatedUser = state.user!.copyWith(
        name: data['name'] as String? ?? state.user!.name,
        avatarUrl: data['avatar'] as String? ?? state.user!.avatarUrl,
      );
      state = state.copyWith(user: updatedUser);
    }
  }

  /// 上传头像，返回新的 avatarUrl（相对路径）
  Future<String> uploadAvatar(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final response = await _dio!.post('/upload/avatar', data: formData);
    final avatarUrl = response.data['avatarUrl'] as String;
    // 存储相对路径，Flutter 显示时拼接完整 URL
    await updateProfile(avatarUrl: avatarUrl);
    return avatarUrl;
  }

  /// 密码登录
  Future<void> loginWithPassword({required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio!.post('/auth/login-password', data: {
        'phone': phone,
        'password': password,
      });
      final data = response.data;
      final token = (data['accessToken'] ?? data['access_token']) as String?;
      if (token == null) throw Exception('登录响应格式错误');
      final userData = data['user'] as Map<String, dynamic>;
      await _prefs?.setString(_tokenKey, token);
      final user = User.fromJson(userData);
      state = AuthState(user: user, accessToken: token, isLoading: false);
      // 登录成功后加载当前用户家庭
      await _loadCurrentFamily();
    } on DioException catch (e) {
      try {
        state = state.copyWith(isLoading: false, error: handleDioError(e).message);
      } catch (_) {
        state = state.copyWith(isLoading: false, error: '请求失败，请重试');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 修改密码
  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      await _dio!.post('/auth/change-password', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        throw Exception(msg is List ? msg.join('；') : (msg ?? '修改密码失败，请重试'));
      }
      throw Exception('修改密码失败，请重试');
    } catch (e) {
      if (e is! Exception) {
        throw Exception('修改密码失败，请重试');
      }
      rethrow;
    }
  }
}

/// 认证状态 Provider
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// 只暴露 isLoggedIn，用于 router select，避免无关状态变化触发重建
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider.select((s) => s.isLoggedIn));
});
