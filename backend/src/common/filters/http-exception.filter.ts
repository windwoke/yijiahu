import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import * as Sentry from '@sentry/node';
import { Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = '服务器内部错误';
    let code = 50001;
    let errors: Record<string, string> | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
      } else if (typeof res === 'object') {
        const resObj = res as Record<string, unknown>;
        message = (resObj.message as string) || message;
        code = (resObj.code as number) || status;
        if (Array.isArray(resObj.message)) {
          errors = {};
          (resObj.message as string[]).forEach((m, i) => {
            errors![`field${i}`] = m;
          });
        }
      }
    } else if (exception instanceof Error) {
      message = exception.message;
    }

    // 上报 5xx 错误到 Sentry
    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const req = ctx.getRequest();
      Sentry.withScope((scope) => {
        scope.setTag('http_status', String(status));
        scope.setExtra('request_url', req.url);
        scope.setExtra('request_method', req.method);
        if (exception instanceof Error) {
          Sentry.captureException(exception);
        }
      });
    }

    const req = ctx.getRequest();
    response.status(status).json({
      code,
      message,
      errors,
      request_id:
        (req['headers'] as Record<string, unknown> | undefined)?.[
          'x-request-id'
        ] || '',
      timestamp: new Date().toISOString(),
    });
  }
}
