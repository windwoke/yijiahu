import {
  IsOptional,
  IsInt,
  Min,
  Max,
  IsBoolean,
  IsString,
} from 'class-validator';

export class UpdatePreferenceDto {
  // 开关
  @IsOptional()
  @IsBoolean()
  medicationReminder?: boolean;

  @IsOptional()
  @IsBoolean()
  missedDose?: boolean;

  @IsOptional()
  @IsBoolean()
  appointmentReminder?: boolean;

  @IsOptional()
  @IsBoolean()
  taskReminder?: boolean;

  @IsOptional()
  @IsBoolean()
  taskAssigned?: boolean;

  @IsOptional()
  @IsBoolean()
  dailyCheckin?: boolean;

  @IsOptional()
  @IsBoolean()
  dailyCheckinCompleted?: boolean;

  @IsOptional()
  @IsBoolean()
  healthAlert?: boolean;

  @IsOptional()
  @IsBoolean()
  sosEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  memberJoined?: boolean;

  @IsOptional()
  @IsBoolean()
  careLog?: boolean;

  // 提前时间
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(60)
  medicationLeadMinutes?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(72)
  appointmentLeadHours?: number;

  // 免打扰
  @IsOptional()
  @IsBoolean()
  dndEnabled?: boolean;

  @IsOptional()
  @IsString()
  dndStart?: string; // HH:mm

  @IsOptional()
  @IsString()
  dndEnd?: string; // HH:mm

  // 推送偏好
  @IsOptional()
  @IsBoolean()
  soundEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  vibrationEnabled?: boolean;

  // 微信小程序订阅通知开关
  @IsOptional()
  @IsBoolean()
  wechatEnabled?: boolean;
}
