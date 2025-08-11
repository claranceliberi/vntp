import { PickType } from '@nestjs/swagger';
import { EmployerData } from './employer.data';

export class EmployerInput extends PickType(EmployerData, ['name', 'matricule'] as const) {}