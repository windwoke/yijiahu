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
}
