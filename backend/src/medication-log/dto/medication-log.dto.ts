import {
  IsString,
  IsEnum,
  IsOptional,
  IsUUID,
  IsNotEmpty,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MedicationLogStatus } from '../entities/medication-log.entity';

export class CheckInDto {
  @ApiProperty({ description: '家庭ID（必填，用于多家庭隔离）' })
  @IsNotEmpty()
  @IsUUID()
  familyId: string;

  @ApiProperty({ example: 'taken', enum: MedicationLogStatus })
  @IsEnum(MedicationLogStatus)
  status: MedicationLogStatus;

  @ApiPropertyOptional({ example: '吃完饭了' })
  @IsString()
  @IsOptional()
  note?: string;
}

export class CreateMedicationLogDto {
  @ApiProperty()
  @IsString()
  recipientId: string;

  @ApiProperty()
  @IsString()
  medicationId: string;

  @ApiProperty()
  @IsString()
  scheduledDate: string;

  @ApiProperty()
  @IsString()
  scheduledTime: string;
}
