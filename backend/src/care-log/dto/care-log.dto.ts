import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString, IsArray } from 'class-validator';
import { CareLogType } from '../entities/care-log.entity';

export class CreateCareLogDto {
  @ApiProperty({ description: '照护对象ID' })
  @IsString()
  @IsNotEmpty()
  recipientId: string;

  @ApiProperty({ enum: CareLogType, description: '日志类型' })
  @IsEnum(CareLogType)
  type: CareLogType;

  @ApiProperty({ description: '日志内容' })
  @IsString()
  @IsNotEmpty()
  content: string;

  @ApiPropertyOptional({ description: '附件ID列表', type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  attachmentIds?: string[];
}
