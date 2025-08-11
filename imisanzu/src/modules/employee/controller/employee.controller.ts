import { Controller, Get, HttpStatus, Param, NotFoundException } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags, ApiParam } from '@nestjs/swagger';

import { EmployeeData } from '../model';
import { EmployeeService } from '../service';

@Controller('employees')
@ApiTags('employee')
export class EmployeeController {

    public constructor(
        private readonly employeeService: EmployeeService
    ) { }

    @Get()
    @ApiOperation({ summary: 'List all employees from local database' })
    @ApiResponse({ status: HttpStatus.OK, isArray: true, type: EmployeeData })
    public async find(): Promise<EmployeeData[]> {

        return this.employeeService.find();
    }

    @Get(':rssbNumber')
    @ApiOperation({ summary: 'Find employee by RSSB number (auto-sync from Oracle if needed)' })
    @ApiParam({ name: 'rssbNumber', description: 'RSSB Number', example: '1023829A' })
    @ApiResponse({ status: HttpStatus.OK, type: EmployeeData })
    @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Employee not found' })
    public async findByRssbNumber(@Param('rssbNumber') rssbNumber: string): Promise<EmployeeData> {

        const employee = await this.employeeService.findByRssbNumber(rssbNumber);
        
        if (!employee) {
            throw new NotFoundException(`Employee with RSSB number ${rssbNumber} not found`);
        }

        return employee;
    }

}