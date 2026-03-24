import { Controller, Get, Patch, Body, UseGuards, NotFoundException } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserService } from './user.service';
import { FamilyMember } from '../family/entities/family-member.entity';
import { Family } from '../family/entities/family.entity';

@ApiTags('用户')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UserController {
  constructor(
    private readonly userService: UserService,
    @InjectRepository(FamilyMember) private memberRepo: Repository<FamilyMember>,
    @InjectRepository(Family) private familyRepo: Repository<Family>,
  ) {}

  @Get('me')
  @ApiOperation({ summary: '获取当前用户信息' })
  getMe(@CurrentUser('id') userId: string) {
    return this.userService.findById(userId);
  }

  @Get('me/family')
  @ApiOperation({ summary: '获取当前用户所在家庭' })
  async getMyFamily(@CurrentUser('id') userId: string) {
    const member = await this.memberRepo.findOne({ where: { userId } });
    if (!member) return { family: null };
    const family = await this.familyRepo.findOne({ where: { id: member.familyId } });
    if (!family) return { family: null };
    return { family };
  }

  @Patch('me')
  @ApiOperation({ summary: '更新当前用户信息' })
  updateMe(@CurrentUser('id') userId: string, @Body() body: Record<string, unknown>) {
    return this.userService.update(userId, body);
  }
}
