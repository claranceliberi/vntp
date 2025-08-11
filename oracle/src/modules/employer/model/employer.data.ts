import { ApiProperty } from '@nestjs/swagger';
import { Employer } from '../../../entities';

export class EmployerData {

    @ApiProperty({ description: 'Employer unique ID', example: 'f47ac10b-58cc-4372-a567-0e02b2c3d479' })
    public readonly id: string;

    @ApiProperty({ description: 'Company name', example: 'Tech Company Ltd' })
    public readonly name: string;

    @ApiProperty({ description: 'Employer matricule', example: '3100000000A' })
    public readonly matricule: string;

    @ApiProperty({ description: 'Created at', example: '2025-01-01T10:00:00Z' })
    public readonly createdAt: Date;

    @ApiProperty({ description: 'Updated at', example: '2025-01-01T10:00:00Z' })
    public readonly updatedAt: Date;

    public constructor(entity: Employer) {
        this.id = entity.id;
        this.name = entity.name;
        this.matricule = entity.matricule;
        this.createdAt = entity.createdAt;
        this.updatedAt = entity.updatedAt;
    }

}