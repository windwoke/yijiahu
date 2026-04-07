import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';

/** 请求平台类型 */
export enum Platform {
  APP = 'app',
  WECHAT = 'wechat',
  WEB = 'web',
}

export const PLATFORM_KEY = 'platform';

/**
 * X-Platform 拦截器
 * 读取请求头 X-Platform，附加到 request 对象上，供后续逻辑区分平台
 */
@Injectable()
export class PlatformInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    const platform = (request.headers['x-platform'] || Platform.APP).toLowerCase();

    // 附加到 request 对象，供 @CurrentUser 或其他 service 使用
    request[PLATFORM_KEY] =
      platform === Platform.WECHAT ? Platform.WECHAT : Platform.APP;

    return next.handle();
  }
}
