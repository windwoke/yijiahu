import { IsString, IsOptional, MinLength, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateFamilyDto {
  @ApiProperty({ example: '张氏家庭' })
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  name: string;
}

export class UpdateFamilyDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @ApiPropertyOptional({ description: '家庭一句话简介' })
  @IsString()
  @IsOptional()
  @MaxLength(100)
  description?: string;
}

export class JoinFamilyDto {
  @ApiProperty({ example: 'ABC123' })
  @IsString()
  inviteCode: string;
}

export class UpdateMemberDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  nickname?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  avatarUrl?: string;

  /** 角色变更（owner/coordinator 可改，仅能改非 owner 的成员）*/
  @ApiPropertyOptional({ enum: ['owner', 'coordinator', 'caregiver', 'guest'] })
  @IsString()
  @IsOptional()
  role?: string;
}
