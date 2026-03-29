import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsString, IsUUID } from 'class-validator';

export class CreateSosDto {
  @ApiProperty({ description: '家庭ID' })
  @IsUUID()
  familyId: string;

  @ApiPropertyOptional({ description: '照护对象ID' })
  @IsUUID()
  @IsOptional()
  recipientId?: string;

  @ApiPropertyOptional({ description: '纬度' })
  @IsNumber()
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional({ description: '经度' })
  @IsNumber()
  @IsOptional()
  longitude?: number;

  @ApiPropertyOptional({ description: '地址描述' })
  @IsString()
  @IsOptional()
  address?: string;
}
