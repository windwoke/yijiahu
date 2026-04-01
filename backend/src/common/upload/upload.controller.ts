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
import { extname } from 'path';
import * as fs from 'fs';
import {
  CareLogAttachment,
  AttachmentType,
} from '../../care-log/entities/care-log-attachment.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';
import { FamilyMemberRole } from '../../family/entities/family-member.entity';
import { PermissionService } from '../services/permission.service';
import { OssService } from '../services/oss.service';
import { Request } from 'express';

const TMP_DIR = `${process.cwd()}/uploads/tmp`;

@ApiTags('上传')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  constructor(
    @InjectRepository(CareLogAttachment)
    private readonly attachmentRepo: Repository<CareLogAttachment>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly permission: PermissionService,
    private readonly oss: OssService,
  ) {
    if (!fs.existsSync(TMP_DIR)) fs.mkdirSync(TMP_DIR, { recursive: true });
  }

  private ossPath(familyId: string, ...parts: string[]): string {
    return `families/${familyId}/${parts.join('/')}`;
  }

  /** 写 Buffer 到临时文件再读取回来，确保内存稳定 */
  private bufferToFile(buf: Buffer): string {
    const tmp = `${TMP_DIR}/upload_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    fs.writeFileSync(tmp, buf);
    return tmp;
  }

  @Post('avatar')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: '上传用户头像' })
  async uploadAvatar(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!file) throw new BadRequestException('请选择要上传的头像');
    const ossPath = `avatars/${req.user.id}/avatar${extname(file.originalname).toLowerCase()}`;
    // 保留 buffer 引用防止 GC，传入 Buffer 而非文件路径
    const buf = file.buffer;
    await this.oss.put(ossPath, buf);
    return { avatarUrl: ossPath };
  }

  @Post('family-avatar')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: '上传家庭头像' })
  async uploadFamilyAvatar(
    @UploadedFile() file: Express.Multer.File,
    @Query('familyId') familyId: string,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!file) throw new BadRequestException('请选择要上传的头像');
    if (!familyId) throw new BadRequestException('familyId 不能为空');
    await this.permission.requireRole(req.user.id, familyId, [FamilyMemberRole.OWNER, FamilyMemberRole.COORDINATOR]);
    const ext = extname(file.originalname).toLowerCase();
    const ossPath = this.ossPath(familyId, `avatar${ext}`);
    const tmp = this.bufferToFile(Buffer.from(file.buffer));
    await this.oss.put(ossPath, tmp);
    fs.unlinkSync(tmp);
    return { avatarUrl: ossPath };
  }

  @Post('recipient-avatar')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
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
    await this.permission.requireRole(req.user.id, familyId, [FamilyMemberRole.OWNER, FamilyMemberRole.COORDINATOR]);
    const recipientRepo = this.dataSource.getRepository(CareRecipient);
    const r = await recipientRepo.findOne({ where: { id: recipientId, familyId } });
    if (!r) throw new BadRequestException('照护对象不存在或不属于该家庭');
    const ext = extname(file.originalname).toLowerCase();
    const ossPath = this.ossPath(familyId, 'recipients', recipientId, `avatar${ext}`);
    const tmp = this.bufferToFile(Buffer.from(file.buffer));
    await this.oss.put(ossPath, tmp);
    fs.unlinkSync(tmp);
    return { avatarUrl: ossPath };
  }

  @Post('attachments')
  @UseInterceptors(FilesInterceptor('files', 9, { limits: { fileSize: 100 * 1024 * 1024 } }))
  @ApiOperation({ summary: '批量上传日志附件（图片/视频）' })
  async uploadAttachments(
    @UploadedFiles() files: Express.Multer.File[],
    @Query('familyId') familyId: string,
    @Req() req: Request & { user: { id: string } },
  ) {
    if (!files || files.length === 0) throw new BadRequestException('请选择要上传的文件');
    if (!familyId) throw new BadRequestException('familyId 不能为空');
    await this.permission.requireRole(req.user.id, familyId, [
      FamilyMemberRole.OWNER, FamilyMemberRole.COORDINATOR, FamilyMemberRole.CAREGIVER, FamilyMemberRole.GUEST,
    ]);
    const savedFiles = await Promise.all(files.map(async (file) => {
      const isVideo = file.mimetype.startsWith('video/');
      const ext = extname(file.originalname);
      const filename = `${Date.now()}_${Math.random().toString(36).slice(2)}${ext}`;
      const ossPath = this.ossPath(familyId, 'attachments', isVideo ? 'videos' : 'images', filename);
      const tmp = this.bufferToFile(Buffer.from(file.buffer));
      await this.oss.put(ossPath, tmp);
      fs.unlinkSync(tmp);
      return { type: isVideo ? AttachmentType.VIDEO : AttachmentType.IMAGE, url: ossPath, filename: file.originalname, size: file.size, familyId };
    }));
    const attachmentEntities = await this.attachmentRepo.save(savedFiles.map(f =>
      this.attachmentRepo.create({ type: f.type, url: f.url, filename: f.filename, size: f.size, familyId: f.familyId })
    ));
    return { attachments: attachmentEntities.map((a, i) => ({
      id: a.id, filename: savedFiles[i].filename, url: savedFiles[i].url,
      mimeType: savedFiles[i].type === AttachmentType.VIDEO ? 'video/mp4' : 'image/jpeg',
      size: savedFiles[i].size, type: savedFiles[i].type === AttachmentType.VIDEO ? 'video' : 'image',
    }))};
  }

  @Delete('attachments')
  @ApiOperation({ summary: '删除附件（取消日记时清理）' })
  async deleteAttachments(@Body() body: { ids: string[] }, @Query('familyId') familyId: string, @Req() req: Request & { user: { id: string } }) {
    if (!familyId) throw new BadRequestException('familyId 不能为空');
    if (!body.ids || body.ids.length === 0) return;
    await this.permission.requireRole(req.user.id, familyId, [FamilyMemberRole.OWNER, FamilyMemberRole.COORDINATOR, FamilyMemberRole.CAREGIVER, FamilyMemberRole.GUEST]);
    const attachments = await this.attachmentRepo.findByIds(body.ids);
    const deletable = attachments.filter((a) => !a.careLogId);
    await Promise.all(deletable.map((a) => this.oss.delete(a.url)));
    await this.attachmentRepo.delete(deletable.map((a) => a.id));
    return { deleted: deletable.length };
  }
}
