import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';

import { HealthController } from './controller';
import { LogInterceptor } from './flow';
import { configProvider, LoggerService, MetricsService } from './provider';

@Module({
    imports: [
        TerminusModule
    ],
    providers: [
        configProvider,
        LoggerService,
        LogInterceptor,
        MetricsService
    ],
    exports: [
        configProvider,
        LoggerService,
        LogInterceptor,
        MetricsService
    ],
    controllers: [
        HealthController
    ],
})
export class CommonModule {}
