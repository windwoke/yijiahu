import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FamilyMember } from '../../family/entities/family-member.entity';
import { PermissionService } from './permission.service';

@Module({
  imports: [TypeOrmModule.forFeature([FamilyMember])],
  providers: [PermissionService],
  exports: [PermissionService],
})
export class CommonModule {}
