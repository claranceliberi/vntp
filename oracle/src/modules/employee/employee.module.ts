import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { CommonModule } from '../common';
import { Employee } from '../../entities';
import { EmployeeController } from './controller';
import { EmployeeService } from './service';

@Module({
    imports: [
        CommonModule,
        TypeOrmModule.forFeature([Employee]),
    ],
    providers: [
        EmployeeService
    ],
    controllers: [
        EmployeeController
    ],
    exports: [
        EmployeeService
    ]
})
export class EmployeeModule { }