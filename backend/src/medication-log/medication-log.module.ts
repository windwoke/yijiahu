import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MedicationLog } from './entities/medication-log.entity';
import { Medication } from '../medication/entities/medication.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { User } from '../user/entities/user.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { MedicationLogService } from './medication-log.service';
import { MedicationLogController } from './medication-log.controller';

@Module({
  imports: [TypeOrmModule.forFeature([MedicationLog, Medication, FamilyMember, User, CareRecipient])],
  controllers: [MedicationLogController],
  providers: [MedicationLogService],
  exports: [MedicationLogService],
})
export class MedicationLogModule {}
