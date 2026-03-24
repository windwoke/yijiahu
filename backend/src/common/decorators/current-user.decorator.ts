import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (data: string | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest() as Record<string, any>;
    const user = request.user as Record<string, unknown> | undefined;
    return data ? user?.[data] : user;
  },
);
