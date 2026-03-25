import {
  Controller,
  Post,
  Get,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
  BadRequestException,
  Req,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { Repository } from 'typeorm';
import { CareLogAttachment, AttachmentType } from '../../care-log/entities/care-log-attachment.entity';
import { Request } from 'express';
import * as path from 'path';
import * as fs from 'fs';

@ApiTags('上传')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  private readonly avatarDir = path.join(process.cwd(), 'uploads', 'avatars');
  private readonly attachmentDir = path.join(process.cwd(), 'uploads', 'attachments');

  constructor(
    @InjectRepository(CareLogAttachment)
    private readonly attachmentRepo: Repository<CareLogAttachment>,
  ) {
    if (!fs.existsSync(this.avatarDir)) {
      fs.mkdirSync(this.avatarDir, { recursive: true });
    }
    if (!fs.existsSync(this.attachmentDir)) {
      fs.mkdirSync(this.attachmentDir, { recursive: true });
    }
  }

  @Post('avatar')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (req, file, callback) => {
        const allowed = /jpeg|jpg|png|gif|webp/;
        if (allowed.test(file.mimetype)) {
          callback(null, true);
        } else {
          callback(new BadRequestException('只支持 jpeg/jpg/png/gif/webp 格式'), false);
        }
      },
    }),
  )
  @ApiOperation({ summary: '上传头像' })
  uploadAvatar(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!file) {
      throw new BadRequestException('请选择要上传的头像');
    }

    const ext = path.extname(file.originalname);
    const filename = `${req.user.id}_${Date.now()}${ext}`;
    const filePath = path.join(this.avatarDir, filename);

    fs.writeFileSync(filePath, file.buffer);

    const avatarUrl = `uploads/avatars/${filename}`;
    return { avatarUrl };
  }

  @Post('attachments')
  @UseInterceptors(
    FilesInterceptor('files', 9, {
      limits: { fileSize: 100 * 1024 * 1024 }, // 单个最大 100MB，最多 9 个
      fileFilter: (req, file, callback) => {
        const allowedImages = /jpeg|jpg|png|gif|webp/;
        const allowedVideos = /mp4|quicktime|x-msvideo/;
        const mime = file.mimetype;
        if (allowedImages.test(mime) || allowedVideos.test(mime)) {
          callback(null, true);
        } else {
          callback(new BadRequestException('只支持图片（jpeg/png/gif/webp）和视频（mp4/mov/avi）格式'), false);
        }
      },
    }),
  )
  @ApiOperation({ summary: '批量上传日志附件（图片/视频）' })
  async uploadAttachments(@UploadedFiles() files: Express.Multer.File[]) {
    if (!files || files.length === 0) {
      throw new BadRequestException('请选择要上传的文件');
    }

    // 保存文件到磁盘
    const savedFiles = files.map(file => {
      const subdir = file.mimetype.startsWith('video/') ? 'videos' : 'images';
      const ext = path.extname(file.originalname);
      const filename = `${Date.now()}_${Math.random().toString(36).slice(2)}${ext}`;
      const filePath = path.join(this.attachmentDir, subdir, filename);

      const subdirPath = path.join(this.attachmentDir, subdir);
      if (!fs.existsSync(subdirPath)) {
        fs.mkdirSync(subdirPath, { recursive: true });
      }

      fs.writeFileSync(filePath, file.buffer);

      const url = `uploads/attachments/${subdir}/${filename}`;
      return {
        type: file.mimetype.startsWith('video/') ? AttachmentType.VIDEO : AttachmentType.IMAGE,
        url,
        filename: file.originalname,
        size: file.size,
      };
    });

    // 在数据库中创建附件记录（careLogId 稍后在日志创建时绑定）
    const attachmentEntities = await this.attachmentRepo.save(
      savedFiles.map(f => this.attachmentRepo.create({
        type: f.type,
        url: f.url,
        filename: f.filename,
        size: f.size,
        // careLogId 为 null，后续在 care-log.service.ts 中绑定
      })),
    );

    // 返回完整记录（含 UUID）
    const results = attachmentEntities.map((a, i) => ({
      id: a.id,
      filename: savedFiles[i].filename,
      url: savedFiles[i].url,
      mimeType: savedFiles[i].type === AttachmentType.VIDEO ? 'video/mp4' : 'image/jpeg',
      size: savedFiles[i].size,
      type: savedFiles[i].type === AttachmentType.VIDEO ? 'video' : 'image',
    }));

    return { attachments: results };
  }
}
