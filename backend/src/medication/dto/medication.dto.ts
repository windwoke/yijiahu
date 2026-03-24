import { IsString, IsArray, IsOptional, MaxLength, ArrayMaxSize } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateMedicationDto {
  @ApiProperty({ example: '血压药' })
  @IsString()
  @MaxLength(100)
  name: string;

  @ApiProperty({ example: '1颗' })
  @IsString()
  @MaxLength(50)
  dosage: string;

  @ApiProperty({ example: ['08:00', '20:00'], description: '服药时间列表' })
  @IsArray()
  @ArrayMaxSize(6)
  times: string[];

  @ApiPropertyOptional({ example: '饭后服用' })
  @IsString()
  @IsOptional()
  instructions?: string;
}

export class UpdateMedicationDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  dosage?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsArray()
  @IsOptional()
  times?: string[];

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  instructions?: string;

  @ApiPropertyOptional()
  @IsOptional()
  isActive?: boolean;
}
