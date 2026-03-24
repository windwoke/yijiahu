import { IsPhoneNumber, IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({ example: '13800138000' })
  @IsPhoneNumber('CN')
  phone: string;

  @ApiProperty({ example: '123456', description: '6位验证码' })
  @IsString()
  @Length(6, 6)
  code: string;
}
