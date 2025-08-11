import { PickType } from '@nestjs/swagger';
import { EmployeeData } from './employee.data';

export class EmployeeInput extends PickType(EmployeeData, ['firstname', 'lastname', 'rssbNumber', 'dob'] as const) {}