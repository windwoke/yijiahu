import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SubscriptionController } from './subscription.controller';
import { SubscriptionService } from './subscription.service';
import { Subscription } from './entities/subscription.entity';
import { Family } from '../family/entities/family.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Subscription,
      Family,
      FamilyMember,
      CareRecipient,
    ]),
  ],
  controllers: [SubscriptionController],
  providers: [SubscriptionService],
  exports: [SubscriptionService, TypeOrmModule],
})
export class SubscriptionModule {}
