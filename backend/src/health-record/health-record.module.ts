import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthRecord } from './entities/health-record.entity';
import { User } from '../user/entities/user.entity';
import { HealthRecordService } from './health-record.service';
import { HealthRecordController } from './health-record.controller';

@Module({
  imports: [TypeOrmModule.forFeature([HealthRecord, User])],
  providers: [HealthRecordService],
  controllers: [HealthRecordController],
  exports: [HealthRecordService],
})
export class HealthRecordModule {}
