import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class WechatLoginDto {
  @ApiProperty({ description: '微信小程序 wx.login() 返回的 code' })
  @IsString()
  @IsNotEmpty()
  code: string;
}

export class WechatProfileDto {
  @ApiProperty({ description: '昵称', required: false })
  @IsString()
  nickname?: string;

  @ApiProperty({ description: '头像 URL', required: false })
  @IsString()
  avatarUrl?: string;
}
