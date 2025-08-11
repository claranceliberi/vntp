import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { CommonModule } from '../common';
import { Employer } from '../../entities';
import { EmployerController } from './controller';
import { EmployerService } from './service';

@Module({
    imports: [
        CommonModule,
        TypeOrmModule.forFeature([Employer]),
    ],
    providers: [
        EmployerService
    ],
    controllers: [
        EmployerController
    ],
    exports: [
        EmployerService
    ]
})
export class EmployerModule { }