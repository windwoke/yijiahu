import { IsString, IsArray, IsOptional, MaxLength, ArrayMaxSize, IsDateString, IsIn, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateMedicationDto {
  @ApiProperty({ example: '550e8400-e29b-41d4-a716-446655440020' })
  @IsUUID()
  recipientId: string;

  @ApiProperty({ example: '血压药' })
  @IsString()
  @MaxLength(100)
  name: string;

  @ApiPropertyOptional({ example: '苯磺酸氨氯地平片' })
  @IsString()
  @IsOptional()
  realName?: string;

  @ApiProperty({ example: '1颗' })
  @IsString()
  @MaxLength(50)
  dosage: string;

  @ApiPropertyOptional({ example: '片' })
  @IsString()
  @IsOptional()
  unit?: string;

  @ApiProperty({ example: 'daily', description: 'daily/weekly/as_needed' })
  @IsString()
  @IsIn(['daily', 'weekly', 'as_needed'])
  frequency: string;

  @ApiProperty({ example: ['08:00', '20:00'], description: '服药时间列表' })
  @IsArray()
  @ArrayMaxSize(6)
  times: string[];

  @ApiPropertyOptional({ example: '饭后服用' })
  @IsString()
  @IsOptional()
  instructions?: string;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsDateString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsDateString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional({ example: '王建国医生' })
  @IsString()
  @IsOptional()
  prescribedBy?: string;
}

export class UpdateMedicationDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  realName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  dosage?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  unit?: string;

  @ApiPropertyOptional({ description: 'daily/weekly/as_needed' })
  @IsString()
  @IsIn(['daily', 'weekly', 'as_needed'])
  @IsOptional()
  frequency?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsArray()
  @IsOptional()
  times?: string[];

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  instructions?: string;

  @ApiPropertyOptional()
  @IsDateString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional()
  @IsDateString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  prescribedBy?: string;

  @ApiPropertyOptional()
  @IsOptional()
  isActive?: boolean;
}
