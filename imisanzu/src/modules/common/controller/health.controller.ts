import { Controller, Get, UseGuards } from '@nestjs/common';
import { HealthCheckService } from '@nestjs/terminus';

import { HealthGuard } from '../security/health.guard';

@Controller('health')
export class HealthController {

    public constructor(
        private readonly health: HealthCheckService
    ) {}

    @Get()
    @UseGuards(HealthGuard)
    public async healthCheck() {

        return this.health.check([
            () => ({
                database: {
                    status: 'up'
                }
            }),
            () => ({
                http: {
                    status: 'up',
                    uptime: process.uptime()
                }
            })
        ]);
    }

}
