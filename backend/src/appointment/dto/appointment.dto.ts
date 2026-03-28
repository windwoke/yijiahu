import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsUUID, IsBoolean, IsInt, Min } from 'class-validator';
import { Transform } from 'class-transformer';
import { AppointmentStatus } from '../entities/appointment.entity';

export class CreateAppointmentDto {
  @ApiProperty({ description: '照护对象ID' })
  @IsNotEmpty()
  @IsUUID()
  recipientId: string;

  @ApiPropertyOptional({ description: '医院名称' })
  @IsOptional()
  @IsString()
  familyId?: string;

  @ApiProperty({ description: '医院名称' })
  @IsNotEmpty()
  @IsString()
  hospital: string;

  @ApiPropertyOptional({ description: '科室' })
  @IsOptional()
  @IsString()
  department?: string;

  @ApiPropertyOptional({ description: '医生姓名' })
  @IsOptional()
  @IsString()
  doctorName?: string;

  @ApiPropertyOptional({ description: '医生电话' })
  @IsOptional()
  @IsString()
  doctorPhone?: string;

  @ApiProperty({ description: '复诊时间' })
  @IsNotEmpty()
  appointmentTime: string;

  @ApiPropertyOptional({ description: '挂号序号' })
  @IsOptional()
  @IsString()
  appointmentNo?: string;

  @ApiPropertyOptional({ description: '地址' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ description: '纬度' })
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional({ description: '经度' })
  @IsOptional()
  longitude?: number;

  @ApiPropertyOptional({ description: '挂号费' })
  @IsOptional()
  fee?: number;

  @ApiPropertyOptional({ description: '就诊目的' })
  @IsOptional()
  @IsString()
  purpose?: string;

  @ApiPropertyOptional({ description: '接送人ID' })
  @IsOptional()
  @IsUUID()
  assignedDriverId?: string;

  @ApiPropertyOptional({ description: '48小时前提醒', default: true })
  @IsOptional()
  @IsBoolean()
  reminder48h?: boolean;

  @ApiPropertyOptional({ description: '24小时前提醒', default: true })
  @IsOptional()
  @IsBoolean()
  reminder24h?: boolean;

  @ApiPropertyOptional({ description: '备注' })
  @IsOptional()
  @IsString()
  note?: string;
}

export class UpdateAppointmentDto extends PartialType(CreateAppointmentDto) {}

export class UpdateAppointmentStatusDto {
  @ApiProperty({ description: '状态', enum: AppointmentStatus })
  @IsNotEmpty()
  status: AppointmentStatus;
}
