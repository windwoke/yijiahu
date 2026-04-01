import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UploadController } from './upload.controller';
import { CareLogAttachment } from '../../care-log/entities/care-log-attachment.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';
import { CommonModule } from '../services/common.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([CareLogAttachment, CareRecipient]),
    CommonModule,
  ],
  controllers: [UploadController],
})
export class UploadModule {}
