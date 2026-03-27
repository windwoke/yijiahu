import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Appointment } from './entities/appointment.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { AppointmentService } from './appointment.service';
import { AppointmentController } from './appointment.controller';
import { CommonModule } from '../common/services/common.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Appointment, CareRecipient, FamilyMember]),
    CommonModule,
  ],
  controllers: [AppointmentController],
  providers: [AppointmentService],
  exports: [AppointmentService],
})
export class AppointmentModule {}
