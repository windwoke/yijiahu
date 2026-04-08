import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class BindPhoneDto {
  @ApiProperty({
    description: '微信 login() 返回的 code（用于换取 sessionKey 解密手机号）',
    example: '081LyG1T1LyG1T1LyG1T1LyG1T1LyG1T1LyG1T1LyG1T',
  })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiProperty({
    description: 'getPhoneNumber 回调返回的加密数据（base64）',
    example: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  })
  @IsNotEmpty()
  @IsString()
  encryptedData: string;

  @ApiProperty({
    description: 'getPhoneNumber 回调返回的初始向量（base64）',
    example: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  })
  @IsNotEmpty()
  @IsString()
  iv: string;
}
