import { Body, Controller, Get, HttpStatus, Param, Post, NotFoundException } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags, ApiParam } from '@nestjs/swagger';
import { trace, SpanStatusCode } from '@opentelemetry/api';

import { LoggerService } from '../../common';

import { EmployeeData, EmployeeInput } from '../model';
import { EmployeeService } from '../service';

const tracer = trace.getTracer('oracle-employee-controller');

@Controller('employees')
@ApiTags('employee')
export class EmployeeController {

    public constructor(
        private readonly logger: LoggerService,
        private readonly employeeService: EmployeeService
    ) { }

    @Get()
    @ApiOperation({ summary: 'Find all employees' })
    @ApiResponse({ status: HttpStatus.OK, isArray: true, type: EmployeeData })
    public async find(): Promise<EmployeeData[]> {

        return tracer.startActiveSpan('employee.find_all', async (span) => {
            try {
                const employees = await this.employeeService.find();
                span.setAttributes({
                    'employees.count': employees.length,
                    'operation.type': 'read_all',
                    'service.component': 'oracle-employee',
                });
                span.setStatus({ code: SpanStatusCode.OK });
                return employees;
            } catch (error) {
                span.recordException(error);
                span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
                throw error;
            } finally {
                span.end();
            }
        });
    }

    @Get(':rssbNumber')
    @ApiOperation({ summary: 'Find employee by RSSB number' })
    @ApiParam({ name: 'rssbNumber', description: 'RSSB Number', example: '1023829A' })
    @ApiResponse({ status: HttpStatus.OK, type: EmployeeData })
    @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Employee not found' })
    public async findByRssbNumber(@Param('rssbNumber') rssbNumber: string): Promise<EmployeeData> {

        return tracer.startActiveSpan('employee.find_by_rssb', async (span) => {
            span.setAttributes({
                'employee.rssb_number': rssbNumber,
                'operation.type': 'read_single',
                'service.component': 'oracle-employee',
            });

            try {
                const employee = await this.employeeService.findByRssbNumber(rssbNumber);
                
                if (!employee) {
                    span.setAttributes({
                        'employee.found': false,
                        'error.type': 'not_found',
                    });
                    span.setStatus({ code: SpanStatusCode.ERROR, message: 'Employee not found' });
                    throw new NotFoundException(`Employee with RSSB number ${rssbNumber} not found`);
                }

                span.setAttributes({
                    'employee.found': true,
                    'employee.id': employee.id,
                });
                span.setStatus({ code: SpanStatusCode.OK });
                return employee;
            } catch (error) {
                span.recordException(error);
                if (!(error instanceof NotFoundException)) {
                    span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
                }
                throw error;
            } finally {
                span.end();
            }
        });
    }

    @Post()
    @ApiOperation({ summary: 'Create employee' })
    @ApiResponse({ status: HttpStatus.CREATED, type: EmployeeData })
    public async create(@Body() input: EmployeeInput): Promise<EmployeeData> {

        return tracer.startActiveSpan('employee.create', async (span) => {
            span.setAttributes({
                'employee.rssb_number': input.rssbNumber,
                'employee.firstname': input.firstname,
                'employee.lastname': input.lastname,
                'operation.type': 'create',
                'service.component': 'oracle-employee',
            });

            try {
                const employee = await this.employeeService.create(input);
                
                span.setAttributes({
                    'employee.id': employee.id,
                    'employee.created': true,
                });
                
                this.logger.info(`Created new employee with ID ${employee.id} and RSSB ${employee.rssbNumber}`);
                span.setStatus({ code: SpanStatusCode.OK });
                return employee;
            } catch (error) {
                span.recordException(error);
                span.setAttributes({
                    'employee.created': false,
                    'error.type': 'creation_failed',
                });
                span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
                throw error;
            } finally {
                span.end();
            }
        });
    }

}