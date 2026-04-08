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
import { WechatLoginDto } from './dto/wechat-login.dto';
import { BindPhoneDto } from './dto/bind-phone.dto';
import { RedisService } from '../common/redis/redis.service';
import { WechatService } from '../wechat/wechat.service';

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
    private wechatService: WechatService,
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

  /**
   * 微信小程序登录
   * 流程：code → openId → 创建/查找用户 → 返回 JWT
   */
  async wechatLogin(dto: WechatLoginDto): Promise<{
    accessToken: string;
    tokenType: string;
    isNewUser: boolean;
    user: {
      id: string;
      phone: string | null;
      name: string | null;
      avatar: string | null;
      hasPassword: boolean;
      isBound: boolean; // 是否已绑定手机号
    };
  }> {
    // 1. 用 code 换取 openId
    const { openId, unionId } = await this.wechatService.code2Session(dto.code);

    // 2. 用 openId 查找用户
    let user = await this.userRepo.findOne({ where: { openId } });

    const isNewUser = !user;

    if (isNewUser) {
      // 新用户：自动创建账户（手机号可为空）
      user = this.userRepo.create({
        openId,
        wechatUnionId: unionId,
        // name 和 avatar 后续通过 profile 更新
        name: `微信用户${openId.slice(-4)}`,
      });
      await this.userRepo.save(user!);
    } else {
      // 老用户：更新登录时间
      user!.lastLoginAt = new Date();
      await this.userRepo.save(user!);
    }

    // 确保 user 非 null（TypeScript 流分析需要）
    const currentUser = user!;

    // 3. 生成 JWT（payload 包含平台标识）
    const payload = {
      sub: currentUser.id,
      phone: currentUser.phone || '',
      platform: 'wechat',
    };
    const token = this.jwtService.sign(payload);

    return {
      accessToken: token,
      tokenType: 'Bearer',
      isNewUser,
      user: {
        id: currentUser.id,
        phone: currentUser.phone,
        name: currentUser.name,
        avatar: currentUser.avatar,
        hasPassword: !!currentUser.hashedPassword,
        isBound: !!currentUser.phone, // 是否已绑定手机号
      },
    };
  }

  /**
   * 更新微信用户的昵称和头像
   */
  async updateWechatProfile(
    userId: string,
    profile: { nickname?: string; avatarUrl?: string },
  ) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');

    if (profile.nickname) user.wechatNickname = profile.nickname;
    if (profile.avatarUrl) user.wechatAvatar = profile.avatarUrl;
    // 同步更新 name（如果用户没有设置过）
    if (!user.name || user.name.startsWith('微信用户')) {
      user.name = profile.nickname || user.name;
    }
    if (!user.avatar) {
      user.avatar = profile.avatarUrl || user.avatar;
    }

    await this.userRepo.save(user);
    return { success: true };
  }

  /**
   * 绑定手机号（微信小程序 getPhoneNumber 一键授权）
   * 流程：解密微信手机号 → 绑定到当前用户
   */
  async bindPhone(userId: string, dto: BindPhoneDto): Promise<{
    success: boolean;
    phone: string;
  }> {
    // 1. 解密微信手机号
    const phone = await this.wechatService.decryptPhoneNumber(
      dto.code,
      dto.encryptedData,
      dto.iv,
    );

    // 2. 查找用户
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');

    // 3. 检查手机号是否已被其他用户绑定
    const existing = await this.userRepo.findOne({ where: { phone } });
    if (existing && existing.id !== userId) {
      throw new BadRequestException('该手机号已被其他账号绑定');
    }

    // 4. 绑定手机号
    user.phone = phone;
    await this.userRepo.save(user);

    return { success: true, phone };
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
