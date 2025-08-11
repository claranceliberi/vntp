import { ApiProperty } from '@nestjs/swagger';
import { Employee } from '../../../entities';

export class EmployeeData {

    @ApiProperty({ description: 'Employee unique ID', example: 'f47ac10b-58cc-4372-a567-0e02b2c3d479' })
    public readonly id: string;

    @ApiProperty({ description: 'First name', example: 'John' })
    public readonly firstname: string;

    @ApiProperty({ description: 'Last name', example: 'Doe' })
    public readonly lastname: string;

    @ApiProperty({ description: 'RSSB Number', example: '1023829A' })
    public readonly rssbNumber: string;

    @ApiProperty({ description: 'Date of birth', example: '1990-01-15' })
    public readonly dob: Date;

    @ApiProperty({ description: 'Created at', example: '2025-01-01T10:00:00Z' })
    public readonly createdAt: Date;

    @ApiProperty({ description: 'Updated at', example: '2025-01-01T10:00:00Z' })
    public readonly updatedAt: Date;

    public constructor(entity: Employee) {
        this.id = entity.id;
        this.firstname = entity.firstname;
        this.lastname = entity.lastname;
        this.rssbNumber = entity.rssbNumber;
        this.dob = entity.dob;
        this.createdAt = entity.createdAt;
        this.updatedAt = entity.updatedAt;
    }

}