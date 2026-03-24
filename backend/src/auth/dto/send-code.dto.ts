import { Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendCodeDto {
  @ApiProperty({ example: '13800138000', description: '手机号' })
  @Matches(/^1[3-9]\d{9}$/, { message: 'phone must be a valid phone number' })
  phone: string;
}
