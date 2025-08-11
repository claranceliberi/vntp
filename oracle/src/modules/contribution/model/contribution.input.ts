import { PickType } from '@nestjs/swagger';
import { ContributionData } from './contribution.data';

export class ContributionInput extends PickType(ContributionData, ['period', 'rssbNumber', 'matricule', 'amount'] as const) {}