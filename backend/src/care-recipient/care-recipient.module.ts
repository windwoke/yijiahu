import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CareRecipient } from './entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CareRecipientService } from './care-recipient.service';
import { CareRecipientController } from './care-recipient.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CareRecipient, FamilyMember])],
  controllers: [CareRecipientController],
  providers: [CareRecipientService],
  exports: [CareRecipientService],
})
export class CareRecipientModule {}
