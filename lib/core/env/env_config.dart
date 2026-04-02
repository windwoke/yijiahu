/// 应用环境枚举
enum AppEnv {
  dev,
  test,
  prod;

  static AppEnv get current {
    const env = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'dev');
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

  static bool get isDebug => AppEnv.current == AppEnv.dev;
}

/// API 配置
class ApiConfig {
  static String get baseUrl {
    const apiUrl =
        String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/v1');
    return apiUrl;
  }

  /// OSS 静态资源地址（不包含 /v1）
  static String get staticRoot {
    const oss = String.fromEnvironment('OSS_BASE_URL', defaultValue: '');
    return oss.isNotEmpty ? oss : baseUrl.replaceAll('/v1', '');
  }

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

  static Duration get connectTimeout => const Duration(seconds: 30);
  static Duration get receiveTimeout => const Duration(seconds: 30);
}

/// App 配置
class AppConfig {
  static String get version =>
      const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static String get buildNumber =>
      const String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');
}
