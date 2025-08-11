import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { CommonModule } from '../common';
import { Contribution } from '../../entities';
import { ContributionController } from './controller';
import { ContributionService } from './service';

@Module({
    imports: [
        CommonModule,
        TypeOrmModule.forFeature([Contribution]),
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