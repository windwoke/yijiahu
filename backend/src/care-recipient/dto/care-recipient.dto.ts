import {
  IsString,
  IsOptional,
  IsDateString,
  MaxLength,
  IsNumber,
  IsArray,
  ArrayMaxSize,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCareRecipientDto {
  @ApiProperty({ example: '爷爷' })
  @IsString()
  @MaxLength(20)
  name: string;

  @ApiPropertyOptional({ example: '👴' })
  @IsString()
  @IsOptional()
  avatarEmoji?: string;

  @ApiPropertyOptional({ example: 'https://...' })
  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @ApiPropertyOptional({ example: '13800138000' })
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiPropertyOptional({ example: 'male' })
  @IsString()
  @IsOptional()
  gender?: 'male' | 'female';

  @ApiPropertyOptional({ example: '1948-05-01' })
  @IsDateString()
  @IsOptional()
  birthDate?: string;

  @ApiPropertyOptional({ example: 'A' })
  @IsString()
  @IsOptional()
  bloodType?: string;

  @ApiPropertyOptional({ example: ['青霉素', '磺胺类'] })
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @IsOptional()
  allergies?: string[];

  @ApiPropertyOptional({ example: ['高血压', '糖尿病'] })
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @IsOptional()
  chronicConditions?: string[];

  @ApiPropertyOptional({ example: '2020年做过阑尾手术' })
  @IsString()
  @IsOptional()
  medicalHistory?: string;

  @ApiPropertyOptional({ example: '市立医院' })
  @IsString()
  @IsOptional()
  hospital?: string;

  @ApiPropertyOptional({ example: '心内科' })
  @IsString()
  @IsOptional()
  department?: string;

  @ApiPropertyOptional({ example: '王建国' })
  @IsString()
  @IsOptional()
  doctorName?: string;

  @ApiPropertyOptional({ example: '13800139000' })
  @IsString()
  @IsOptional()
  doctorPhone?: string;

  @ApiPropertyOptional({ example: '儿子张三' })
  @IsString()
  @IsOptional()
  emergencyContact?: string;

  @ApiPropertyOptional({ example: '13800138000' })
  @IsString()
  @IsOptional()
  emergencyPhone?: string;

  @ApiPropertyOptional({ example: '朝阳区XX路XX号' })
  @IsString()
  @IsOptional()
  currentAddress?: string;

  @ApiPropertyOptional({ example: 39.9042 })
  @IsNumber()
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional({ example: 116.4074 })
  @IsNumber()
  @IsOptional()
  longitude?: number;
}

export class UpdateCareRecipientDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  avatarEmoji?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  gender?: 'male' | 'female';

  @ApiPropertyOptional()
  @IsDateString()
  @IsOptional()
  birthDate?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  bloodType?: string;

  @ApiPropertyOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @IsOptional()
  allergies?: string[];

  @ApiPropertyOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @IsOptional()
  chronicConditions?: string[];

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  medicalHistory?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  hospital?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  department?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  doctorName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  doctorPhone?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  emergencyContact?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  emergencyPhone?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  currentAddress?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  longitude?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  isActive?: boolean;
}
