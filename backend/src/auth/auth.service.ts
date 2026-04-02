import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { User } from '../user/entities/user.entity';
import { SendCodeDto } from './dto/send-code.dto';
import { LoginDto } from './dto/login.dto';
import { RedisService } from '../common/redis/redis.service';

const CODE_KEY = (phone: string) => `verify:code:${phone}`;
const RATE_KEY = (phone: string) => `verify:rate:${phone}`;
const CODE_TTL = 300; // 5分钟
const RATE_TTL = 3600; // 1小时
const MAX_RATE = 10; // 1小时内最多发10次

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private userRepo: Repository<User>,
    private jwtService: JwtService,
    private config: ConfigService,
    private redis: RedisService,
  ) {}

  private get smsMode() {
    return this.config.get<string>('sms.mode') || 'mock';
  }

  private get codeOverride() {
    return this.config.get<string>('sms.codeOverride') || '';
  }

  private generateCode(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  async sendCode(dto: SendCodeDto) {
    // 频率限制：1小时内最多10次
    const rateKey = RATE_KEY(dto.phone);
    const count = await this.redis.incr(rateKey);
    if (count === 1) {
      await this.redis.expire(rateKey, RATE_TTL);
    }
    if (count > MAX_RATE) {
      throw new BadRequestException('发送太频繁，请稍后再试');
    }

    let code: string;
    if (this.smsMode === 'mock') {
      code = this.codeOverride || this.generateCode();
      console.log(`[Mock SMS] 向 ${dto.phone} 发送验证码: ${code}`);
    } else {
      code = this.generateCode();
      await this.sendAliSms(dto.phone, code);
    }

    // 存 Redis，5分钟有效期
    const codeKey = CODE_KEY(dto.phone);
    await this.redis.set(codeKey, code, CODE_TTL);

    return {
      message: '验证码已发送',
      expiresIn: CODE_TTL,
      ...(this.smsMode === 'mock' ? { mockCode: code } : {}),
    };
  }

  private async sendAliSms(phone: string, code: string): Promise<void> {
    // TODO: 集成阿里云短信 API
    // 可复用 aliyun SDK @fastr/sms 或 HTTP API
    throw new BadRequestException('短信服务暂未配置');
  }

  async login(dto: LoginDto) {
    const codeKey = CODE_KEY(dto.phone);
    const storedCode = await this.redis.get(codeKey);

    if (!storedCode || storedCode !== dto.code) {
      throw new BadRequestException('验证码错误或已过期');
    }

    // 一次性验证码，使用后删除
    await this.redis.del(codeKey);

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
        hasPassword: !!user.hashedPassword,
      },
    };
  }

  async refreshToken(userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();

    const token = this.jwtService.sign({ sub: user.id, phone: user.phone });
    return { accessToken: token };
  }

  async changePassword(
    userId: string,
    oldPassword: string,
    newPassword: string,
  ) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');

    if (user.hashedPassword) {
      const isValid = await bcrypt.compare(oldPassword, user.hashedPassword);
      if (!isValid) {
        throw new BadRequestException('旧密码错误');
      }
    }

    user.hashedPassword = await bcrypt.hash(newPassword, 10);
    await this.userRepo.save(user);
    return { success: true };
  }

  async loginWithPassword(phone: string, password: string) {
    const user = await this.userRepo.findOne({ where: { phone } });
    if (!user) throw new BadRequestException('手机号或密码错误');

    if (!user.hashedPassword) {
      throw new BadRequestException('该账号未设置密码，请使用验证码登录');
    }

    const isValid = await bcrypt.compare(password, user.hashedPassword);
    if (!isValid) {
      throw new BadRequestException('手机号或密码错误');
    }

    user.lastLoginAt = new Date();
    await this.userRepo.save(user);

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
        hasPassword: true,
      },
    };
  }
}
