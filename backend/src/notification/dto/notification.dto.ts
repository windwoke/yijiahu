import { IsOptional, IsEnum, IsInt, Min, IsIn } from 'class-validator';
import { Type } from 'class-transformer';
import {
  NotificationType,
  NotificationLevel,
  NotificationChannel,
} from '../entities/notification.entity';

export class NotificationQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  pageSize?: number = 20;

  @IsOptional()
  @IsEnum(NotificationType)
  type?: NotificationType;

  @IsOptional()
  @IsIn(['true', 'false'])
  isRead?: string;

  @IsOptional()
  familyId?: string;
}

export class CreateNotificationDto {
  userId: string;
  familyId?: string;
  type: NotificationType;
  title: string;
  body: string;
  level?: NotificationLevel;
  sourceType?: string;
  sourceId?: string;
  sourceUserId?: string;
  channel?: NotificationChannel;
  dataJson?: Record<string, any>;
}

export class BroadcastNotificationDto {
  familyId: string;
  excludeUserId?: string;
  type: NotificationType;
  title: string;
  body: string;
  level?: NotificationLevel;
  sourceType?: string;
  sourceId?: string;
  sourceUserId?: string;
  dataJson?: Record<string, any>;
}

export class MarkReadDto {
  @IsOptional()
  @IsIn(['true', 'false'])
  all?: string;
}
