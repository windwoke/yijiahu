import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CaregiverRecord } from './entities/caregiver-record.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CaregiverRecordService } from './caregiver-record.service';
import { CaregiverRecordController } from './caregiver-record.controller';
import { NotificationModule } from '../notification/notification.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([CaregiverRecord, CareRecipient, FamilyMember]),
    NotificationModule,
  ],
  controllers: [CaregiverRecordController],
  providers: [CaregiverRecordService],
  exports: [CaregiverRecordService],
})
export class CaregiverRecordModule {}
