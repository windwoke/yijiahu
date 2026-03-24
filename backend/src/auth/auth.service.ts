import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../user/entities/user.entity';
import { SendCodeDto } from './dto/send-code.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private userRepo: Repository<User>,
    private jwtService: JwtService,
  ) {}

  async sendCode(dto: SendCodeDto) {
    // TODO: 集成阿里云短信服务
    // 暂时存储到 Redis（后续实现）
    const code = '123456'; // Mock: 固定验证码
    console.log(`[Mock SMS] 向 ${dto.phone} 发送验证码: ${code}`);
    return { message: '验证码已发送', expiresIn: 300 };
  }

  async login(dto: LoginDto) {
    // TODO: 从 Redis 验证验证码
    if (dto.code !== '123456') {
      throw new BadRequestException('验证码错误');
    }

    // 查找或创建用户
    let user = await this.userRepo.findOne({ where: { phone: dto.phone } });
    if (!user) {
      user = this.userRepo.create({
        phone: dto.phone,
        name: `用户${dto.phone.slice(-4)}`,
      });
      await this.userRepo.save(user);
    }

    // 更新登录时间
    user.lastLoginAt = new Date();
    await this.userRepo.save(user);

    // 生成 Token
    const payload = { sub: user.id, phone: user.phone };
    const token = this.jwtService.sign(payload);

    return {
      accessToken: token,
      tokenType: 'Bearer',
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        avatar: user.avatar,
      },
    };
  }

  async refreshToken(userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();

    const token = this.jwtService.sign({ sub: user.id, phone: user.phone });
    return { accessToken: token };
  }
}
