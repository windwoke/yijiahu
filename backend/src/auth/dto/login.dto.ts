import { Matches, IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({ example: '13800138000' })
  @Matches(/^1[3-9]\d{9}$/, { message: 'phone must be a valid phone number' })
  phone: string;

  @ApiProperty({ example: '123456', description: '6位验证码' })
  @IsString()
  @Length(6, 6)
  code: string;
}
