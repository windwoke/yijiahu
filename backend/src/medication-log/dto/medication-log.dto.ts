import { IsString, IsEnum, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MedicationLogStatus } from '../entities/medication-log.entity';

export class CheckInDto {
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
