import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DailyCareCheckin } from './entities/daily-care-checkin.entity';
import { MedicationLog } from '../medication-log/entities/medication-log.entity';
import { DailyCareCheckinService } from './daily-care-checkin.service';
import { DailyCareCheckinController } from './daily-care-checkin.controller';

@Module({
  imports: [TypeOrmModule.forFeature([DailyCareCheckin, MedicationLog])],
  controllers: [DailyCareCheckinController],
  providers: [DailyCareCheckinService],
  exports: [DailyCareCheckinService],
})
export class DailyCareCheckinModule {}
