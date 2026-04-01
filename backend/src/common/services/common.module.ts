import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FamilyMember } from '../../family/entities/family-member.entity';
import { CareLogAttachment } from '../../care-log/entities/care-log-attachment.entity';
import { PermissionService } from './permission.service';
import { CleanupService } from './cleanup.service';

@Module({
  imports: [TypeOrmModule.forFeature([FamilyMember, CareLogAttachment])],
  providers: [PermissionService, CleanupService],
  exports: [PermissionService],
})
export class CommonModule {}
