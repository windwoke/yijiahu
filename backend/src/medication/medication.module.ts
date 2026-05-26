import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Medication } from './entities/medication.entity';
import { MedicationService } from './medication.service';
import { MedicationController } from './medication.controller';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { MedicationLog } from '../medication-log/entities/medication-log.entity';
import { MedicationLogStatus } from '../medication-log/entities/medication-log.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Medication, CareRecipient, MedicationLog])],
  controllers: [MedicationController],
  providers: [MedicationService],
  exports: [MedicationService],
})
export class MedicationModule {}
