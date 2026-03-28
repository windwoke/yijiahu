import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CaregiverRecord } from './entities/caregiver-record.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CaregiverRecordService } from './caregiver-record.service';
import { CaregiverRecordController } from './caregiver-record.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CaregiverRecord, CareRecipient, FamilyMember])],
  controllers: [CaregiverRecordController],
  providers: [CaregiverRecordService],
  exports: [CaregiverRecordService],
})
export class CaregiverRecordModule {}
