import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Notification } from './entities/notification.entity';
import { NotificationPreference } from './entities/notification-preference.entity';
import { NotificationService } from './notification.service';
import { NotificationPreferenceService } from './notification-preference.service';
import { NotificationController } from './notification.controller';
import { NotificationPreferenceController } from './notification-preference.controller';
import { NotificationScheduler } from './notification.scheduler';
import { MedicationLog } from '../medication-log/entities/medication-log.entity';
import { Medication } from '../medication/entities/medication.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { CaregiverRecord } from '../caregiver-record/entities/caregiver-record.entity';
import { Appointment } from '../appointment/entities/appointment.entity';
import { FamilyTask } from '../family-task/entities/family-task.entity';
import { DailyCareCheckin } from '../daily-care-checkin/entities/daily-care-checkin.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { User } from '../user/entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Notification,
      NotificationPreference,
      MedicationLog,
      Medication,
      CareRecipient,
      CaregiverRecord,
      Appointment,
      FamilyTask,
      DailyCareCheckin,
      FamilyMember,
      User,
    ]),
  ],
  controllers: [NotificationController, NotificationPreferenceController],
  providers: [NotificationService, NotificationPreferenceService, NotificationScheduler],
  exports: [NotificationService, NotificationPreferenceService],
})
export class NotificationModule {}
