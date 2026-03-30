import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Notification } from './entities/notification.entity';
import { NotificationService } from './notification.service';
import { NotificationController } from './notification.controller';
import { NotificationScheduler } from './notification.scheduler';
import { MedicationLog } from '../medication-log/entities/medication-log.entity';
import { Medication } from '../medication/entities/medication.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { CaregiverRecord } from '../caregiver-record/entities/caregiver-record.entity';
import { Appointment } from '../appointment/entities/appointment.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { User } from '../user/entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Notification,
      MedicationLog,
      Medication,
      CareRecipient,
      CaregiverRecord,
      Appointment,
      FamilyMember,
      User,
    ]),
  ],
  controllers: [NotificationController],
  providers: [NotificationService, NotificationScheduler],
  exports: [NotificationService],
})
export class NotificationModule {}
