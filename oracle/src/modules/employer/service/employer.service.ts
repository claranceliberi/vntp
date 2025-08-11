import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Employer } from '../../../entities';
import { EmployerData, EmployerInput } from '../model';

@Injectable()
export class EmployerService {

    public constructor(
        @InjectRepository(Employer)
        private readonly employerRepository: Repository<Employer>
    ) { }

    /**
     * Find all employers in the database
     *
     * @returns An employer list
     */
    public async find(): Promise<EmployerData[]> {

        const employers = await this.employerRepository.find();

        return employers.map(employer => new EmployerData(employer));
    }

    /**
     * Find employer by matricule
     *
     * @param matricule The matricule to search for
     * @returns An employer or null if not found
     */
    public async findByMatricule(matricule: string): Promise<EmployerData | null> {

        const employer = await this.employerRepository.findOne({
            where: { matricule }
        });

        return employer ? new EmployerData(employer) : null;
    }

    /**
     * Create a new employer record
     *
     * @param data Employer details
     * @returns An employer created in the database
     */
    public async create(data: EmployerInput): Promise<EmployerData> {

        const employer = this.employerRepository.create(data);
        const savedEmployer = await this.employerRepository.save(employer);

        return new EmployerData(savedEmployer);
    }

}