import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 应用环境枚举
enum AppEnv {
  dev,
  test,
  prod;

  static AppEnv get current {
    final env = dotenv.env['FLUTTER_ENV'] ?? 'dev';
    switch (env) {
      case 'test':
        return AppEnv.test;
      case 'prod':
        return AppEnv.prod;
      default:
        return AppEnv.dev;
    }
  }

  String get label {
    switch (this) {
      case AppEnv.dev:
        return '开发环境';
      case AppEnv.test:
        return '测试环境';
      case AppEnv.prod:
        return '生产环境';
    }
  }

  bool get isDebug => this == AppEnv.dev;
}

/// API 配置
class ApiConfig {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/v1';

  /// 静态资源根路径（去掉 /v1 前缀）
  static String get staticRoot => baseUrl.replaceAll('/v1', '');

  /// 根据相对路径构建完整头像 URL
  static String? avatarUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith('http')) return relativePath;
    return '$staticRoot/$relativePath';
  }

  /// 根据相对路径构建完整附件 URL
  static String? attachmentUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith('http')) return relativePath;
    return '$staticRoot/$relativePath';
  }

  static Duration get connectTimeout =>
      Duration(seconds: int.parse(dotenv.env['CONNECT_TIMEOUT'] ?? '30'));

  static Duration get receiveTimeout =>
      Duration(seconds: int.parse(dotenv.env['RECEIVE_TIMEOUT'] ?? '30'));
}

/// App 配置
class AppConfig {
  static String get version => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static String get buildNumber => dotenv.env['BUILD_NUMBER'] ?? '1';
}
