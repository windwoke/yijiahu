import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  IsDateString,
} from 'class-validator';

export class CreateCaregiverRecordDto {
  @ApiProperty({ description: '照护对象ID' })
  @IsNotEmpty()
  @IsUUID()
  careRecipientId: string;

  @ApiProperty({ description: '照护人ID' })
  @IsNotEmpty()
  @IsUUID()
  caregiverId: string;

  @ApiProperty({ description: '照护开始日期 YYYY-MM-DD' })
  @IsNotEmpty()
  @IsDateString()
  periodStart: string;

  @ApiPropertyOptional({ description: '备注' })
  @IsOptional()
  @IsString()
  note?: string;
}
