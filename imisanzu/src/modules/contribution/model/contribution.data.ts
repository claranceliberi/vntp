import { ApiProperty } from '@nestjs/swagger';

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

    public constructor(data: any) {
        this.id = data.id;
        this.period = data.period;
        this.rssbNumber = data.rssbNumber;
        this.matricule = data.matricule;
        this.amount = typeof data.amount === 'number' ? data.amount : Number(data.amount);
        this.createdAt = new Date(data.createdAt);
        this.updatedAt = new Date(data.updatedAt);
    }

}