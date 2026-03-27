import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Medication } from './entities/medication.entity';
import { MedicationService } from './medication.service';
import { MedicationController } from './medication.controller';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Medication, CareRecipient])],
  controllers: [MedicationController],
  providers: [MedicationService],
  exports: [MedicationService],
})
export class MedicationModule {}
