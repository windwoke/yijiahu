import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FamilyTask } from './entities/family-task.entity';
import { TaskCompletion } from './entities/task-completion.entity';
import { FamilyTaskService } from './family-task.service';
import { FamilyTaskController } from './family-task.controller';
import { CommonModule } from '../common/services/common.module';
import { FamilyMember } from '../family/entities/family-member.entity';
import { NotificationModule } from '../notification/notification.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([FamilyTask, TaskCompletion, FamilyMember]),
    CommonModule,
    NotificationModule,
  ],
  controllers: [FamilyTaskController],
  providers: [FamilyTaskService],
  exports: [FamilyTaskService],
})
export class FamilyTaskModule {}
