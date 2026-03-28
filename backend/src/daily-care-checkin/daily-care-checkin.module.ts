import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DailyCareCheckin } from './entities/daily-care-checkin.entity';
import { MedicationLog } from '../medication-log/entities/medication-log.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { DailyCareCheckinService } from './daily-care-checkin.service';
import { DailyCareCheckinController } from './daily-care-checkin.controller';
import { CommonModule } from '../common/services/common.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([DailyCareCheckin, MedicationLog, CareRecipient, FamilyMember]),
    CommonModule,
  ],
  controllers: [DailyCareCheckinController],
  providers: [DailyCareCheckinService],
  exports: [DailyCareCheckinService],
})
export class DailyCareCheckinModule {}
