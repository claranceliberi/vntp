import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Contribution } from '../../../entities';
import { ContributionData, ContributionInput } from '../model';

@Injectable()
export class ContributionService {

    public constructor(
        @InjectRepository(Contribution)
        private readonly contributionRepository: Repository<Contribution>
    ) { }

    /**
     * Find all contributions in the database
     *
     * @returns A contribution list
     */
    public async find(): Promise<ContributionData[]> {

        const contributions = await this.contributionRepository.find({
            order: {
                period: 'DESC',
                createdAt: 'DESC'
            }
        });

        return contributions.map(contribution => new ContributionData(contribution));
    }

    /**
     * Find contributions by employee RSSB number
     *
     * @param rssbNumber The employee RSSB number
     * @returns Contributions for the employee
     */
    public async findByRssbNumber(rssbNumber: string): Promise<ContributionData[]> {

        const contributions = await this.contributionRepository.find({
            where: { rssbNumber },
            order: {
                period: 'DESC'
            }
        });

        return contributions.map(contribution => new ContributionData(contribution));
    }

    /**
     * Find contributions by period
     *
     * @param period The period to search for (YYYY-MM format)
     * @returns Contributions for the period
     */
    public async findByPeriod(period: string): Promise<ContributionData[]> {

        const contributions = await this.contributionRepository.find({
            where: { period },
            order: {
                createdAt: 'DESC'
            }
        });

        return contributions.map(contribution => new ContributionData(contribution));
    }

    /**
     * Find contributions by employer matricule
     *
     * @param matricule The employer matricule
     * @returns Contributions for the employer
     */
    public async findByMatricule(matricule: string): Promise<ContributionData[]> {

        const contributions = await this.contributionRepository.find({
            where: { matricule },
            order: {
                period: 'DESC'
            }
        });

        return contributions.map(contribution => new ContributionData(contribution));
    }

    /**
     * Create a new contribution record
     *
     * @param data Contribution details
     * @returns A contribution created in the database
     */
    public async create(data: ContributionInput): Promise<ContributionData> {

        const contribution = this.contributionRepository.create({
            ...data,
            amount: data.amount.toString()
        });
        const savedContribution = await this.contributionRepository.save(contribution);

        return new ContributionData(savedContribution);
    }

}