import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThanOrEqual, LessThan } from 'typeorm';
import { Appointment, AppointmentStatus } from './entities/appointment.entity';
import { CreateAppointmentDto, UpdateAppointmentDto } from './dto/appointment.dto';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';

@Injectable()
export class AppointmentService {
  constructor(
    @InjectRepository(Appointment) private repo: Repository<Appointment>,
    @InjectRepository(FamilyMember) private memberRepo: Repository<FamilyMember>,
    @InjectRepository(CareRecipient) private recipientRepo: Repository<CareRecipient>,
  ) {}

  /** 按照护对象查询列表 */
  async findByRecipient(recipientId: string, familyId: string, status?: AppointmentStatus) {
    const recipient = await this.recipientRepo.findOne({ where: { id: recipientId } });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) {
      throw new ForbiddenException('该照护对象不属于您的家庭');
    }
    const where: any = { recipientId };
    if (status) where.status = status;

    return this.repo.find({
      where,
      relations: ['recipient', 'assignedDriver', 'createdBy'],
      order: { appointmentTime: 'ASC' },
    });
  }

  /** 按家庭查询，按月视图 */
  async findByFamily(familyId: string, year: number, month: number) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59);

    const recipients = await this.recipientRepo.find({ where: { familyId } });
    const recipientIds = recipients.map(r => r.id);

    if (recipientIds.length === 0) return [];

    return this.repo
      .createQueryBuilder('apt')
      .leftJoinAndSelect('apt.recipient', 'recipient')
      .leftJoinAndSelect('apt.assignedDriver', 'assignedDriver')
      .leftJoinAndSelect('apt.createdBy', 'createdBy')
      .where('apt.recipientId IN (:...recipientIds)', { recipientIds })
      .andWhere('apt.appointmentTime BETWEEN :start AND :end', {
        start: startDate,
        end: endDate,
      })
      .orderBy('apt.appointmentTime', 'ASC')
      .getMany();
  }

  /** 创建 */
  async create(familyId: string, dto: CreateAppointmentDto, userId: string) {
    const recipient = await this.recipientRepo.findOne({
      where: { id: dto.recipientId },
    });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) throw new ForbiddenException('无权为此照护对象添加复诊');

    const apt = this.repo.create({
      ...dto,
      appointmentTime: new Date(dto.appointmentTime),
      familyId,
      createdById: userId,
      status: AppointmentStatus.UPCOMING,
    });

    return this.repo.save(apt);
  }

  /** 更新 */
  async update(id: string, familyId: string, dto: UpdateAppointmentDto) {
    const apt = await this.repo.findOne({ where: { id } });
    if (!apt) throw new NotFoundException('复诊记录不存在');
    if (apt.familyId !== familyId) throw new ForbiddenException('无权修改此记录');

    if (dto.appointmentTime) {
      (dto as any).appointmentTime = new Date(dto.appointmentTime);
    }

    Object.assign(apt, dto);
    return this.repo.save(apt);
  }

  /** 删除（软删除） */
  async delete(id: string, familyId: string) {
    const apt = await this.repo.findOne({ where: { id } });
    if (!apt) throw new NotFoundException('复诊记录不存在');
    if (apt.familyId !== familyId) throw new ForbiddenException('无权删除此记录');

    return this.repo.softRemove(apt);
  }

  /** 更新状态 */
  async updateStatus(id: string, familyId: string, status: AppointmentStatus) {
    const apt = await this.repo.findOne({ where: { id } });
    if (!apt) throw new NotFoundException('复诊记录不存在');
    if (apt.familyId !== familyId) throw new ForbiddenException('无权修改此记录');

    apt.status = status;
    return this.repo.save(apt);
  }
}
