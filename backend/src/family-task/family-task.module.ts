import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FamilyTask } from './entities/family-task.entity';
import { TaskCompletion } from './entities/task-completion.entity';
import { FamilyTaskService } from './family-task.service';
import { FamilyTaskController } from './family-task.controller';

@Module({
  imports: [TypeOrmModule.forFeature([FamilyTask, TaskCompletion])],
  controllers: [FamilyTaskController],
  providers: [FamilyTaskService],
  exports: [FamilyTaskService],
})
export class FamilyTaskModule {}
