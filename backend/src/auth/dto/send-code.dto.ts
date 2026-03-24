import { IsPhoneNumber } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendCodeDto {
  @ApiProperty({ example: '13800138000', description: '手机号' })
  @IsPhoneNumber('CN')
  phone: string;
}
