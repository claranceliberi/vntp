import { Injectable, Inject } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';

import { Employee } from '../../../entities';
import { LoggerService } from '../../common';
import { Service } from '../../tokens';
import { EmployeeData } from '../model';

interface OracleEmployee {
    id: string;
    firstname: string;
    lastname: string;
    rssbNumber: string;
    dob: string;
    createdAt: string;
    updatedAt: string;
}

interface Config {
    ORACLE_SERVICE_URL: string;
}

@Injectable()
export class EmployeeService {

    public constructor(
        @InjectRepository(Employee)
        private readonly employeeRepository: Repository<Employee>,
        private readonly logger: LoggerService,
        private readonly httpService: HttpService,
        @Inject(Service.CONFIG) private readonly config: Config
    ) { }

    /**
     * Find all employees in the local database
     *
     * @returns An employee list
     */
    public async find(): Promise<EmployeeData[]> {

        const employees = await this.employeeRepository.find({
            order: { createdAt: 'DESC' }
        });

        return employees.map(employee => new EmployeeData(employee));
    }

    /**
     * Find employee by RSSB number, auto-sync from Oracle if not found locally
     *
     * @param rssbNumber The RSSB number to search for
     * @returns An employee or null if not found anywhere
     */
    public async findByRssbNumber(rssbNumber: string): Promise<EmployeeData | null> {

        // First try to find locally
        let employee = await this.employeeRepository.findOne({
            where: { rssbNumber }
        });

        if (employee) {
            this.logger.info(`Found employee ${rssbNumber} in local database`);
            return new EmployeeData(employee);
        }

        // If not found locally, try to sync from Oracle service
        this.logger.info(`Employee ${rssbNumber} not found locally, syncing from Oracle service`);
        
        try {
            const response = await firstValueFrom(
                this.httpService.get<OracleEmployee>(`${this.config.ORACLE_SERVICE_URL}/api/v1/employees/${rssbNumber}`)
            );

            const oracleEmployee = response.data;
            
            // Save employee locally
            const newEmployee = this.employeeRepository.create({
                id: oracleEmployee.id,
                firstname: oracleEmployee.firstname,
                lastname: oracleEmployee.lastname,
                rssbNumber: oracleEmployee.rssbNumber,
                dob: new Date(oracleEmployee.dob)
            });
            
            employee = await this.employeeRepository.save(newEmployee);

            this.logger.info(`Synced employee ${rssbNumber} from Oracle service`);
            return new EmployeeData(employee);

        } catch (error) {
            this.logger.error(`Failed to sync employee ${rssbNumber} from Oracle service: ${error.message}`);
            return null;
        }
    }

}