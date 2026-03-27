import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CareLog } from './entities/care-log.entity';
import { CareLogAttachment } from './entities/care-log-attachment.entity';
import { User } from '../user/entities/user.entity';
import { CareLogService } from './care-log.service';
import { CareLogController } from './care-log.controller';
import { CareLogAttachmentService } from './care-log-attachment.service';
import { CareLogAttachmentController } from './care-log-attachment.controller';
import { CommonModule } from '../common/services/common.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([CareLog, CareLogAttachment, User]),
    CommonModule,
  ],
  controllers: [CareLogController, CareLogAttachmentController],
  providers: [CareLogService, CareLogAttachmentService],
  exports: [CareLogService, CareLogAttachmentService],
})
export class CareLogModule {}
