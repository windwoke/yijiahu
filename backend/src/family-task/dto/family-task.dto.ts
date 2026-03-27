import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsUUID, IsEnum, IsArray } from 'class-validator';
import { Type } from 'class-transformer';
import { TaskFrequency } from '../entities/family-task.entity';

export class CreateFamilyTaskDto {
  @ApiProperty({ description: '家庭ID' })
  @IsNotEmpty()
  @IsUUID()
  familyId: string;

  @ApiPropertyOptional({ description: '照护对象ID' })
  @IsOptional()
  @IsUUID()
  recipientId?: string;

  @ApiProperty({ description: '任务标题' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiPropertyOptional({ description: '任务描述' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ description: '频率', enum: TaskFrequency })
  @IsNotEmpty()
  @IsEnum(TaskFrequency)
  frequency: TaskFrequency;

  @ApiPropertyOptional({ description: '定时时间 HH:mm' })
  @IsOptional()
  @IsString()
  scheduledTime?: string;

  @ApiPropertyOptional({ description: '到期日期 YYYY-MM-DD（单次任务必填）' })
  @IsOptional()
  @IsString()
  scheduledDate?: string;

  @ApiPropertyOptional({ description: '周期日（周几1-7 或 日期1-31）' })
  @IsOptional()
  @IsArray()
  @Type(() => Number)
  scheduledDay?: number[];

  @ApiProperty({ description: '负责人ID' })
  @IsNotEmpty()
  @IsUUID()
  assigneeId: string;

  @ApiPropertyOptional({ description: '备注' })
  @IsOptional()
  @IsString()
  note?: string;
}

export class UpdateFamilyTaskDto extends PartialType(CreateFamilyTaskDto) {
  @ApiPropertyOptional({ description: '任务状态', enum: ['pending', 'completed', 'cancelled'] })
  @IsOptional()
  @IsString()
  status?: string;
}

export class CompleteTaskDto {
  @ApiPropertyOptional({ description: '完成的日期实例 YYYY-MM-DD' })
  @IsOptional()
  @IsString()
  scheduledDate?: string;

  @ApiPropertyOptional({ description: '完成备注' })
  @IsOptional()
  @IsString()
  note?: string;
}
