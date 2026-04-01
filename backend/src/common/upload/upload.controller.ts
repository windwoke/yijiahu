import {
  Controller,
  Post,
  Delete,
  Query,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
  BadRequestException,
  Req,
} from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { Repository, DataSource } from 'typeorm';
import { CareLogAttachment, AttachmentType } from '../../care-log/entities/care-log-attachment.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';
import { FamilyMemberRole } from '../../family/entities/family-member.entity';
import { PermissionService } from '../services/permission.service';
import { Request } from 'express';
import * as path from 'path';
import * as fs from 'fs';

@ApiTags('上传')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  private readonly avatarDir = path.join(process.cwd(), 'uploads', 'avatars');
  private readonly familiesDir = path.join(process.cwd(), 'uploads', 'families');

  constructor(
    @InjectRepository(CareLogAttachment)
    private readonly attachmentRepo: Repository<CareLogAttachment>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly permission: PermissionService,
  ) {
    if (!fs.existsSync(this.avatarDir)) {
      fs.mkdirSync(this.avatarDir, { recursive: true });
    }
    if (!fs.existsSync(this.familiesDir)) {
      fs.mkdirSync(this.familiesDir, { recursive: true });
    }
  }

  private getFamilyDir(familyId: string): string {
    const dir = path.join(this.familiesDir, familyId);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    return dir;
  }

  private getAttachmentDir(familyId: string, subdir: 'images' | 'videos'): string {
    const dir = path.join(this.familiesDir, familyId, 'attachments', subdir);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    return dir;
  }

  @Post('avatar')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (req, file, callback) => {
        if (/jpeg|jpg|png|gif|webp/.test(file.mimetype)) {
          callback(null, true);
        } else {
          callback(new BadRequestException('只支持 jpeg/jpg/png/gif/webp 格式'), false);
        }
      },
    }),
  )
  @ApiOperation({ summary: '上传用户头像' })
  uploadAvatar(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!file) throw new BadRequestException('请选择要上传的头像');

    const userDir = path.join(this.avatarDir, req.user.id);
    if (!fs.existsSync(userDir)) fs.mkdirSync(userDir, { recursive: true });

    // 删除旧头像
    try {
      const oldFiles = fs.readdirSync(userDir).filter(f => f.startsWith('avatar.'));
      for (const oldFile of oldFiles) {
        fs.unlinkSync(path.join(userDir, oldFile));
      }
    } catch (_) {}

    const ext = path.extname(file.originalname).toLowerCase();
    const filePath = path.join(userDir, `avatar${ext}`);
    fs.writeFileSync(filePath, file.buffer);

    return { avatarUrl: `uploads/avatars/${req.user.id}/avatar${ext}` };
  }

  @Post('family-avatar')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (req, file, callback) => {
        if (/jpeg|jpg|png|gif|webp/.test(file.mimetype)) {
          callback(null, true);
        } else {
          callback(new BadRequestException('只支持 jpeg/jpg/png/gif/webp 格式'), false);
        }
      },
    }),
  )
  @ApiOperation({ summary: '上传家庭头像' })
  async uploadFamilyAvatar(
    @UploadedFile() file: Express.Multer.File,
    @Query('familyId') familyId: string,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!file) throw new BadRequestException('请选择要上传的头像');
    if (!familyId) throw new BadRequestException('familyId 不能为空');

    await this.permission.requireRole(req.user.id, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);

    const ext = path.extname(file.originalname).toLowerCase();
    const filePath = path.join(this.getFamilyDir(familyId), `avatar${ext}`);
    fs.writeFileSync(filePath, file.buffer);

    return { avatarUrl: `uploads/families/${familyId}/avatar${ext}` };
  }

  @Post('recipient-avatar')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (req, file, callback) => {
        if (/jpeg|jpg|png|gif|webp/.test(file.mimetype)) {
          callback(null, true);
        } else {
          callback(new BadRequestException('只支持 jpeg/jpg/png/gif/webp 格式'), false);
        }
      },
    }),
  )
  @ApiOperation({ summary: '上传照护对象头像' })
  async uploadRecipientAvatar(
    @UploadedFile() file: Express.Multer.File,
    @Query('familyId') familyId: string,
    @Query('recipientId') recipientId: string,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!file) throw new BadRequestException('请选择要上传的头像');
    if (!familyId) throw new BadRequestException('familyId 不能为空');
    if (!recipientId) throw new BadRequestException('recipientId 不能为空');

    await this.permission.requireRole(req.user.id, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);

    // 校验 recipient 属于该家庭
    const recipientRepo = this.dataSource.getRepository(CareRecipient);
    const r = await recipientRepo.findOne({ where: { id: recipientId, familyId } });
    if (!r) throw new BadRequestException('照护对象不存在或不属于该家庭');

    const recipientDir = path.join(this.getFamilyDir(familyId), 'recipients', recipientId);
    if (!fs.existsSync(recipientDir)) fs.mkdirSync(recipientDir, { recursive: true });

    const ext = path.extname(file.originalname).toLowerCase();
    const filePath = path.join(recipientDir, `avatar${ext}`);
    fs.writeFileSync(filePath, file.buffer);

    return { avatarUrl: `uploads/families/${familyId}/recipients/${recipientId}/avatar${ext}` };
  }

  @Post('attachments')
  @UseInterceptors(
    FilesInterceptor('files', 9, {
      limits: { fileSize: 100 * 1024 * 1024 },
      fileFilter: (req, file, callback) => {
        const mime = file.mimetype;
        if (/jpeg|jpg|png|gif|webp/.test(mime) || /mp4|quicktime|x-msvideo/.test(mime)) {
          callback(null, true);
        } else {
          callback(new BadRequestException('只支持图片（jpeg/png/gif/webp）和视频（mp4/mov/avi）格式'), false);
        }
      },
    }),
  )
  @ApiOperation({ summary: '批量上传日志附件（图片/视频）' })
  async uploadAttachments(
    @UploadedFiles() files: Express.Multer.File[],
    @Query('familyId') familyId: string,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!files || files.length === 0) throw new BadRequestException('请选择要上传的文件');
    if (!familyId) throw new BadRequestException('familyId 不能为空');

    await this.permission.requireRole(req.user.id, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
      FamilyMemberRole.CAREGIVER,
      FamilyMemberRole.GUEST,
    ]);

    const savedFiles = files.map(file => {
      const isVideo = file.mimetype.startsWith('video/');
      const ext = path.extname(file.originalname);
      const filename = `${Date.now()}_${Math.random().toString(36).slice(2)}${ext}`;
      const subdir = isVideo ? 'videos' : 'images';
      const fileDir = this.getAttachmentDir(familyId, subdir);
      const filePath = path.join(fileDir, filename);
      fs.writeFileSync(filePath, file.buffer);
      return {
        type: isVideo ? AttachmentType.VIDEO : AttachmentType.IMAGE,
        url: `uploads/families/${familyId}/attachments/${subdir}/${filename}`,
        filename: file.originalname,
        size: file.size,
        familyId,
      };
    });

    const attachmentEntities = await this.attachmentRepo.save(
      savedFiles.map(f => this.attachmentRepo.create({
        type: f.type,
        url: f.url,
        filename: f.filename,
        size: f.size,
        familyId: f.familyId,
      })),
    );

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

  @Delete('attachments')
  @ApiOperation({ summary: '删除附件（取消日记时清理）' })
  async deleteAttachments(
    @Body() body: { ids: string[] },
    @Query('familyId') familyId: string,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!familyId) throw new BadRequestException('familyId 不能为空');
    if (!body.ids || body.ids.length === 0) return;

    await this.permission.requireRole(req.user.id, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
      FamilyMemberRole.CAREGIVER,
      FamilyMemberRole.GUEST,
    ]);

    // 只删除未绑定 careLogId 的附件
    const attachments = await this.attachmentRepo.findByIds(body.ids);
    const deletable = attachments.filter(a => !a.careLogId);

    for (const a of deletable) {
      const filePath = path.join(process.cwd(), a.url);
      try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); } catch (_) {}
    }

    await this.attachmentRepo.delete(deletable.map(a => a.id));
    return { deleted: deletable.length };
  }
}
