import { Body, Controller, Get, HttpStatus, Param, Post, NotFoundException } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags, ApiParam } from '@nestjs/swagger';

import { LoggerService } from '../../common';

import { EmployerData, EmployerInput } from '../model';
import { EmployerService } from '../service';

@Controller('employers')
@ApiTags('employer')
export class EmployerController {

    public constructor(
        private readonly logger: LoggerService,
        private readonly employerService: EmployerService
    ) { }

    @Get()
    @ApiOperation({ summary: 'Find all employers' })
    @ApiResponse({ status: HttpStatus.OK, isArray: true, type: EmployerData })
    public async find(): Promise<EmployerData[]> {

        return this.employerService.find();
    }

    @Get(':matricule')
    @ApiOperation({ summary: 'Find employer by matricule' })
    @ApiParam({ name: 'matricule', description: 'Employer matricule', example: '3100000000A' })
    @ApiResponse({ status: HttpStatus.OK, type: EmployerData })
    @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Employer not found' })
    public async findByMatricule(@Param('matricule') matricule: string): Promise<EmployerData> {

        const employer = await this.employerService.findByMatricule(matricule);
        
        if (!employer) {
            throw new NotFoundException(`Employer with matricule ${matricule} not found`);
        }

        return employer;
    }

    @Post()
    @ApiOperation({ summary: 'Create employer' })
    @ApiResponse({ status: HttpStatus.CREATED, type: EmployerData })
    public async create(@Body() input: EmployerInput): Promise<EmployerData> {

        const employer = await this.employerService.create(input);
        this.logger.info(`Created new employer with ID ${employer.id} and matricule ${employer.matricule}`);

        return employer;
    }

}