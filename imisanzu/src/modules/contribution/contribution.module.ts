import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';

import { CommonModule } from '../common';
import { ContributionController } from './controller';
import { ContributionService } from './service';

@Module({
    imports: [
        CommonModule,
        HttpModule
    ],
    providers: [
        ContributionService
    ],
    controllers: [
        ContributionController
    ],
    exports: [
        ContributionService
    ]
})
export class ContributionModule { }