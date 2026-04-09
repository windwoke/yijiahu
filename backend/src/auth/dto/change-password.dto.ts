import { IsString, IsOptional, MinLength } from 'class-validator';

export class ChangePasswordDto {
  /** 旧密码，首次设置密码时可不传 */
  @IsOptional()
  @IsString()
  oldPassword?: string;

  @IsString()
  @MinLength(6)
  newPassword: string;
}
