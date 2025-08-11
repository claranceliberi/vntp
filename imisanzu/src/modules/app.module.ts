import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { DatabaseModule } from '../database/database.module';
import { CommonModule } from './common';
import { EmployeeModule } from './employee/employee.module';
import { ContributionModule } from './contribution/contribution.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
        }),
        DatabaseModule,
        CommonModule,
        EmployeeModule,
        ContributionModule
    ]
})
export class ApplicationModule {}
