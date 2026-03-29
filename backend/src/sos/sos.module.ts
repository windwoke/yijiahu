import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SosController } from './sos.controller';
import { SosService } from './sos.service';
import { SosRecord } from './entities/sos-record.entity';

@Module({
  imports: [TypeOrmModule.forFeature([SosRecord])],
  controllers: [SosController],
  providers: [SosService],
  exports: [SosService],
})
export class SosModule {}
