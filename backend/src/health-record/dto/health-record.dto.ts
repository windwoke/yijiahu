import { IsString, IsOptional, IsNumber, IsDateString, IsObject, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateHealthRecordDto {
  @ApiProperty({ example: 'recipient-uuid' })
  @IsString()
  recipientId: string;

  @ApiProperty({ example: 'blood_pressure' })
  @IsString()
  recordType: string;

  @ApiPropertyOptional({ example: { systolic: 120, diastolic: 80 } })
  @IsObject()
  value: object;

  @ApiPropertyOptional({ example: '2026-03-25T08:30:00Z' })
  @IsDateString()
  @IsOptional()
  recordedAt?: string;

  @ApiPropertyOptional({ example: '测量时心情平静' })
  @IsString()
  @IsOptional()
  note?: string;
}
