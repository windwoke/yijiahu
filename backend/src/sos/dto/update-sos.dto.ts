import { ApiProperty } from '@nestjs/swagger';
import { IsEnum } from 'class-validator';
import { SosStatus } from '../entities/sos-record.entity';

export class UpdateSosDto {
  @ApiProperty({ description: '状态', enum: SosStatus })
  @IsEnum(SosStatus)
  status: SosStatus;
}
