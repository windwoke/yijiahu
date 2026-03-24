import { IsString, IsOptional, IsDateString, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCareRecipientDto {
  @ApiProperty({ example: '爷爷' })
  @IsString()
  @MaxLength(20)
  name: string;

  @ApiPropertyOptional({ example: '男' })
  @IsString()
  @IsOptional()
  gender?: 'male' | 'female';

  @ApiPropertyOptional({ example: '1940-01-01' })
  @IsDateString()
  @IsOptional()
  birthDate?: string;

  @ApiPropertyOptional({ example: '爷爷' })
  @IsString()
  @IsOptional()
  relation?: string;

  @ApiPropertyOptional({ example: '青霉素' })
  @IsString()
  @IsOptional()
  allergies?: string;

  @ApiPropertyOptional({ example: '高血压、糖尿病' })
  @IsString()
  @IsOptional()
  chronicDiseases?: string;

  @ApiPropertyOptional({ example: '张三 13800138000' })
  @IsString()
  @IsOptional()
  emergencyContact?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  emergencyPhone?: string;
}

export class UpdateCareRecipientDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  avatar?: string;

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
  relation?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  allergies?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  chronicDiseases?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  emergencyContact?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  emergencyPhone?: string;
}
