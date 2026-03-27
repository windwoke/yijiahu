import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsUUID, IsInt, Min } from 'class-validator';
import { CheckinStatus } from '../entities/daily-care-checkin.entity';

export class CreateDailyCareCheckinDto {
  @ApiProperty({ description: '家庭ID（必填，用于多家庭隔离）' })
  @IsNotEmpty()
  @IsUUID()
  familyId: string;

  @ApiProperty({ description: '照护对象ID' })
  @IsNotEmpty()
  @IsUUID()
  careRecipientId: string;

  @ApiProperty({ description: '打卡日期 YYYY-MM-DD' })
  @IsNotEmpty()
  @IsString()
  checkinDate: string;

  @ApiProperty({ description: '状态', enum: CheckinStatus })
  @IsNotEmpty()
  @IsString()
  status: CheckinStatus;

  @ApiPropertyOptional({ description: '已完成药品数' })
  @IsOptional()
  @IsInt()
  @Min(0)
  medicationCompleted?: number;

  @ApiPropertyOptional({ description: '应服药总数' })
  @IsOptional()
  @IsInt()
  @Min(0)
  medicationTotal?: number;

  @ApiPropertyOptional({ description: '特殊情况备注' })
  @IsOptional()
  @IsString()
  specialNote?: string;
}

export class UpdateDailyCareCheckinDto {
  @ApiPropertyOptional({ description: '状态', enum: CheckinStatus })
  @IsOptional()
  @IsString()
  status?: CheckinStatus;

  @ApiPropertyOptional({ description: '已完成药品数' })
  @IsOptional()
  @IsInt()
  @Min(0)
  medicationCompleted?: number;

  @ApiPropertyOptional({ description: '应服药总数' })
  @IsOptional()
  @IsInt()
  @Min(0)
  medicationTotal?: number;

  @ApiPropertyOptional({ description: '特殊情况备注' })
  @IsOptional()
  @IsString()
  specialNote?: string;
}
