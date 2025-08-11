import { ApiProperty } from '@nestjs/swagger';
import { Contribution } from '../../../entities';

export class ContributionData {

    @ApiProperty({ description: 'Contribution unique ID', example: 'f47ac10b-58cc-4372-a567-0e02b2c3d479' })
    public readonly id: string;

    @ApiProperty({ description: 'Period (YYYY-MM)', example: '2025-01' })
    public readonly period: string;

    @ApiProperty({ description: 'Employee RSSB Number', example: '1023829A' })
    public readonly rssbNumber: string;

    @ApiProperty({ description: 'Employer matricule', example: '3100000000A' })
    public readonly matricule: string;

    @ApiProperty({ description: 'Contribution amount', example: 4000000 })
    public readonly amount: number;

    @ApiProperty({ description: 'Created at', example: '2025-01-01T10:00:00Z' })
    public readonly createdAt: Date;

    @ApiProperty({ description: 'Updated at', example: '2025-01-01T10:00:00Z' })
    public readonly updatedAt: Date;

    public constructor(entity: Contribution) {
        this.id = entity.id;
        this.period = entity.period;
        this.rssbNumber = entity.rssbNumber;
        this.matricule = entity.matricule;
        this.amount = parseFloat(entity.amount);
        this.createdAt = entity.createdAt;
        this.updatedAt = entity.updatedAt;
    }

}