import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { FamilyService } from './family.service';
import {
  CreateFamilyDto,
  UpdateFamilyDto,
  JoinFamilyDto,
  UpdateMemberDto,
} from './dto/family.dto';

@ApiTags('家庭')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('families')
export class FamilyController {
  constructor(private readonly familyService: FamilyService) {}

  @Post()
  @ApiOperation({ summary: '创建家庭' })
  create(@CurrentUser('id') userId: string, @Body() dto: CreateFamilyDto) {
    return this.familyService.create(userId, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: '获取家庭详情' })
  findOne(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.familyService.findById(id, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新家庭' })
  update(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateFamilyDto,
  ) {
    return this.familyService.update(id, userId, dto);
  }

  @Post('join')
  @ApiOperation({ summary: '通过邀请码加入家庭' })
  join(@CurrentUser('id') userId: string, @Body() dto: JoinFamilyDto) {
    return this.familyService.join(userId, dto);
  }

  @Delete(':id/leave')
  @ApiOperation({ summary: '退出家庭' })
  leave(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.familyService.leave(id, userId);
  }

  @Delete(':familyId/members/:memberId')
  @ApiOperation({ summary: '移除家庭成员' })
  removeMember(
    @Param('familyId') familyId: string,
    @Param('memberId') memberId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.familyService.removeMember(familyId, memberId, userId);
  }

  @Get(':id/members')
  @ApiOperation({ summary: '获取家庭成员列表' })
  findMembers(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.familyService.findMembers(id, userId);
  }

  @Patch(':familyId/members/:memberId')
  @ApiOperation({ summary: '更新家庭成员' })
  updateMember(
    @Param('familyId') familyId: string,
    @Param('memberId') memberId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateMemberDto,
  ) {
    return this.familyService.updateMember(familyId, memberId, userId, dto);
  }
}
