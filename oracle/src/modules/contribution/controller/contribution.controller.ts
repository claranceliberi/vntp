import { Body, Controller, Get, HttpStatus, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags, ApiQuery } from '@nestjs/swagger';

import { LoggerService } from '../../common';

import { ContributionData, ContributionInput } from '../model';
import { ContributionService } from '../service';

@Controller('contributions')
@ApiTags('contribution')
export class ContributionController {

    public constructor(
        private readonly logger: LoggerService,
        private readonly contributionService: ContributionService
    ) { }

    @Get()
    @ApiOperation({ summary: 'Find contributions with optional filters' })
    @ApiQuery({ name: 'rssbNumber', required: false, description: 'Filter by employee RSSB number', example: '1023829A' })
    @ApiQuery({ name: 'period', required: false, description: 'Filter by period (YYYY-MM)', example: '2025-01' })
    @ApiQuery({ name: 'matricule', required: false, description: 'Filter by employer matricule', example: '3100000000A' })
    @ApiResponse({ status: HttpStatus.OK, isArray: true, type: ContributionData })
    public async find(
        @Query('rssbNumber') rssbNumber?: string,
        @Query('period') period?: string,
        @Query('matricule') matricule?: string
    ): Promise<ContributionData[]> {

        if (rssbNumber) {
            return this.contributionService.findByRssbNumber(rssbNumber);
        }

        if (period) {
            return this.contributionService.findByPeriod(period);
        }

        if (matricule) {
            return this.contributionService.findByMatricule(matricule);
        }

        return this.contributionService.find();
    }

    @Post()
    @ApiOperation({ summary: 'Create contribution' })
    @ApiResponse({ status: HttpStatus.CREATED, type: ContributionData })
    public async create(@Body() input: ContributionInput): Promise<ContributionData> {

        const contribution = await this.contributionService.create(input);
        this.logger.info(`Created new contribution with ID ${contribution.id} for employee ${contribution.rssbNumber}`);

        return contribution;
    }

}