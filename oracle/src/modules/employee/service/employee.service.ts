import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Employee } from '../../../entities';
import { EmployeeData, EmployeeInput } from '../model';

@Injectable()
export class EmployeeService {

    public constructor(
        @InjectRepository(Employee)
        private readonly employeeRepository: Repository<Employee>
    ) { }

    /**
     * Find all employees in the database
     *
     * @returns An employee list
     */
    public async find(): Promise<EmployeeData[]> {

        const employees = await this.employeeRepository.find();

        return employees.map(employee => new EmployeeData(employee));
    }

    /**
     * Find employee by RSSB number
     *
     * @param rssbNumber The RSSB number to search for
     * @returns An employee or null if not found
     */
    public async findByRssbNumber(rssbNumber: string): Promise<EmployeeData | null> {

        const employee = await this.employeeRepository.findOne({
            where: { rssbNumber }
        });

        return employee ? new EmployeeData(employee) : null;
    }

    /**
     * Create a new employee record
     *
     * @param data Employee details
     * @returns An employee created in the database
     */
    public async create(data: EmployeeInput): Promise<EmployeeData> {

        const employee = this.employeeRepository.create(data);
        const savedEmployee = await this.employeeRepository.save(employee);

        return new EmployeeData(savedEmployee);
    }

}