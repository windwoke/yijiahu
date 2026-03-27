import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import configuration from './config/configuration';
import { AuthModule } from './auth/auth.module';
import { UserModule } from './user/user.module';
import { FamilyModule } from './family/family.module';
import { CareRecipientModule } from './care-recipient/care-recipient.module';
import { MedicationModule } from './medication/medication.module';
import { MedicationLogModule } from './medication-log/medication-log.module';
import { UploadModule } from './common/upload/upload.module';
import { HealthRecordModule } from './health-record/health-record.module';
import { CareLogModule } from './care-log/care-log.module';
import { SubscriptionModule } from './subscription/subscription.module';
import { AppointmentModule } from './appointment/appointment.module';
import { FamilyTaskModule } from './family-task/family-task.module';
import { CaregiverRecordModule } from './caregiver-record/caregiver-record.module';

@Module({
  imports: [
    // 配置模块
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),

    // 数据库
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get('database.host'),
        port: config.get('database.port'),
        username: config.get('database.username'),
        password: config.get('database.password'),
        database: config.get('database.name'),
        autoLoadEntities: true,
        synchronize: config.get('database.synchronize'),
        logging: config.get('database.logging'),
      }),
    }),

    // 业务模块
    AuthModule,
    UserModule,
    FamilyModule,
    CareRecipientModule,
    MedicationModule,
    MedicationLogModule,
    UploadModule,
    HealthRecordModule,
    CareLogModule,
    SubscriptionModule,
    AppointmentModule,
    FamilyTaskModule,
    CaregiverRecordModule,
  ],
})
export class AppModule {}
