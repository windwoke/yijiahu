/// 一家护 - 错误类型定义
library;

abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

/// 网络相关异常
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(super.message, [super.code, this.statusCode]);
}

/// API 业务错误
class ApiException extends AppException {
  final Map<String, dynamic>? errors;

  const ApiException(super.message, [super.code, this.errors]);
}

/// 未登录
class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = '请先登录']) : super(message, '20001');
}

/// 无权限
class ForbiddenException extends AppException {
  const ForbiddenException([String message = '无权限访问']) : super(message, '20002');
}

/// 资源不存在
class NotFoundException extends AppException {
  const NotFoundException([String message = '资源不存在']) : super(message, '30001');
}

/// 参数错误
class ValidationException extends AppException {
  final Map<String, dynamic> fieldErrors;

  const ValidationException(
    String message, {
    String code = '10001',
    this.fieldErrors = const {},
  }) : super(message, code);
}

/// 超出配额
class QuotaExceededException extends AppException {
  const QuotaExceededException([String message = '超出配额限制']) : super(message, '30003');
}

/// 业务逻辑错误
class BusinessException extends AppException {
  const BusinessException(super.message, [super.code = '40001']);
}

/// 服务器内部错误
class ServerException extends AppException {
  const ServerException([String message = '服务器错误']) : super(message, '50001');
}
