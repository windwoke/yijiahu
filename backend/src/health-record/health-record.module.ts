import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthRecord } from './entities/health-record.entity';
import { User } from '../user/entities/user.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CaregiverRecord } from '../caregiver-record/entities/caregiver-record.entity';
import { HealthRecordService } from './health-record.service';
import { HealthRecordController } from './health-record.controller';
import { CommonModule } from '../common/services/common.module';
import { NotificationModule } from '../notification/notification.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([HealthRecord, User, CareRecipient, FamilyMember, CaregiverRecord]),
    CommonModule,
    NotificationModule,
  ],
  providers: [HealthRecordService],
  controllers: [HealthRecordController],
  exports: [HealthRecordService],
})
export class HealthRecordModule {}
