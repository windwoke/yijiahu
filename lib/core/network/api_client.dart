/// API 客户端
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_exception.dart';

/// API 配置
class ApiConfig {
  static const String baseUrl = 'https://api.yijiahu.cn/v1';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

/// Dio 实例
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Platform': 'app',
        'X-Version': '1.0.0',
      },
    ),
  );

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
});

/// 认证拦截器
class AuthInterceptor extends Interceptor {
  // ignore: unused_field
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 从本地存储获取 token
    // final token = await ref.read(tokenStorageProvider).getAccessToken();
    // if (token != null) {
    //   options.headers['Authorization'] = 'Bearer $token';
    // }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token 过期，跳转登录
      // ref.read(authNotifierProvider.notifier).logout();
    }
    handler.next(err);
  }
}

/// API 响应封装
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
  final String? requestId;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.requestId,
  });

  bool get isSuccess => code == 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      requestId: json['request_id'] as String?,
    );
  }
}

/// API 异常处理
AppException handleDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkException('网络连接超时', 'NET_TIMEOUT');
    case DioExceptionType.connectionError:
      return const NetworkException('网络连接失败，请检查网络', 'NET_ERROR');
    case DioExceptionType.badResponse:
      return _handleBadResponse(error.response);
    case DioExceptionType.cancel:
      return const NetworkException('请求已取消', 'CANCEL');
    default:
      return const NetworkException('网络异常', 'UNKNOWN');
  }
}

AppException _handleBadResponse(Response? response) {
  if (response == null) {
    return const ServerException();
  }

  final data = response.data;
  if (data is! Map<String, dynamic>) {
    return ServerException('服务器响应格式错误');
  }

  final code = data['code'] as int? ?? 0;
  final message = data['message'] as String? ?? '未知错误';
  final errors = data['errors'] as Map<String, dynamic>?;

  switch (code) {
    case 10001:
      return ValidationException(message, code: '10001', fieldErrors: errors ?? {});
    case 20001:
      return const UnauthorizedException();
    case 20002:
      return const ForbiddenException();
    case 30001:
      return const NotFoundException();
    case 30003:
      return const QuotaExceededException();
    case 40001:
      return BusinessException(message, '40001');
    case 50001:
    case 50002:
      return ServerException(message);
    default:
      if (response.statusCode == 401) {
        return const UnauthorizedException();
      }
      if (response.statusCode == 403) {
        return const ForbiddenException();
      }
      if (response.statusCode == 404) {
        return const NotFoundException();
      }
      return ServerException(message);
  }
}
