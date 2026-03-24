import {
  Controller,
  Post,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  Req,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { Request } from 'express';
import * as path from 'path';
import * as fs from 'fs';

@ApiTags('上传')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  private readonly uploadDir = path.join(process.cwd(), 'uploads', 'avatars');

  constructor() {
    // 确保上传目录存在
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  @Post('avatar')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
      fileFilter: (req, file, callback) => {
        const allowed = /jpeg|jpg|png|gif|webp/;
        const ext = allowed.test(file.mimetype);
        if (ext) {
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
    const filePath = path.join(this.uploadDir, filename);

    fs.writeFileSync(filePath, file.buffer);

    const avatarUrl = `uploads/avatars/${filename}`;
    return { avatarUrl };
  }
}
