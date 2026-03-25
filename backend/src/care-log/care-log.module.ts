import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CareLog } from './entities/care-log.entity';
import { User } from '../user/entities/user.entity';
import { CareLogService } from './care-log.service';
import { CareLogController } from './care-log.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CareLog, User])],
  controllers: [CareLogController],
  providers: [CareLogService],
  exports: [CareLogService],
})
export class CareLogModule {}
