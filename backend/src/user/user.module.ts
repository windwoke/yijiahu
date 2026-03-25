import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UserService } from './user.service';
import { UserController } from './user.controller';
import { FamilyMember } from '../family/entities/family-member.entity';
import { Family } from '../family/entities/family.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';

@Module({
  imports: [TypeOrmModule.forFeature([User, FamilyMember, Family, CareRecipient])],
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
