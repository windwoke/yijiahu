import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthRecord } from './entities/health-record.entity';
import { User } from '../user/entities/user.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { HealthRecordService } from './health-record.service';
import { HealthRecordController } from './health-record.controller';
import { CommonModule } from '../common/services/common.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([HealthRecord, User, CareRecipient, FamilyMember]),
    CommonModule,
  ],
  providers: [HealthRecordService],
  controllers: [HealthRecordController],
  exports: [HealthRecordService],
})
export class HealthRecordModule {}
