import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UploadController } from './upload.controller';
import { CareLogAttachment } from '../../care-log/entities/care-log-attachment.entity';

@Module({
  imports: [TypeOrmModule.forFeature([CareLogAttachment])],
  controllers: [UploadController],
})
export class UploadModule {}
