import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Family } from './entities/family.entity';
import { FamilyMember } from './entities/family-member.entity';
import { User } from '../user/entities/user.entity';
import { FamilyService } from './family.service';
import { FamilyController } from './family.controller';
import { SubscriptionModule } from '../subscription/subscription.module';
import { NotificationModule } from '../notification/notification.module';

@Module({
  imports: [TypeOrmModule.forFeature([Family, FamilyMember, User]), SubscriptionModule, NotificationModule],
  controllers: [FamilyController],
  providers: [FamilyService],
  exports: [FamilyService, TypeOrmModule],
})
export class FamilyModule {}
