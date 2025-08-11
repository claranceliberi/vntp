import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { Employee, Employer, Contribution } from '../entities';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        url: configService.get('DATABASE_URL'),
        entities: [Employee, Employer, Contribution],
        synchronize: true, // Only for development
        logging: true,
        ssl: false,
      }),
      inject: [ConfigService],
    }),
    TypeOrmModule.forFeature([Employee, Employer, Contribution]),
  ],
  exports: [TypeOrmModule],
})
export class DatabaseModule {}