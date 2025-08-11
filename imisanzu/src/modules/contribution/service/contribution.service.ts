import { Injectable, Inject } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import Redis from 'ioredis';

import { LoggerService } from '../../common';
import { Service } from '../../tokens';
import { ContributionData } from '../model';

interface Config {
    ORACLE_SERVICE_URL: string;
    REDIS_HOST: string;
    REDIS_PORT: string;
}

@Injectable()
export class ContributionService {

    private redis: Redis;
    private readonly CACHE_TTL = 60; // 1 minute in seconds

    public constructor(
        private readonly logger: LoggerService,
        private readonly httpService: HttpService,
        @Inject(Service.CONFIG) private readonly config: Config
    ) {
        this.redis = new Redis({
            host: this.config.REDIS_HOST,
            port: parseInt(this.config.REDIS_PORT),
            maxRetriesPerRequest: 3,
        });
    }

    /**
     * Get contributions for an employee by RSSB number
     * Uses Redis cache with 1-minute TTL
     *
     * @param rssbNumber The employee RSSB number
     * @returns Contributions for the employee
     */
    public async getContributionsByRssbNumber(rssbNumber: string): Promise<ContributionData[]> {

        const cacheKey = `contributions:${rssbNumber}`;
        
        try {
            // Try to get from cache first
            const cached = await this.redis.get(cacheKey);
            if (cached) {
                this.logger.info(`Cache hit for contributions of employee ${rssbNumber}`);
                const contributionsData = JSON.parse(cached);
                return contributionsData.map((c: any) => new ContributionData(c));
            }

            this.logger.info(`Cache miss for contributions of employee ${rssbNumber}, fetching from Oracle service`);

            // Fetch from Oracle service
            const response = await firstValueFrom(
                this.httpService.get(`${this.config.ORACLE_SERVICE_URL}/api/v1/contributions?rssbNumber=${rssbNumber}`)
            );

            const contributions = response.data.map((c: any) => new ContributionData(c));

            // Cache the result for 1 minute
            await this.redis.setex(cacheKey, this.CACHE_TTL, JSON.stringify(contributions));
            this.logger.info(`Cached contributions for employee ${rssbNumber} with TTL ${this.CACHE_TTL}s`);

            return contributions;

        } catch (error) {
            this.logger.error(`Failed to get contributions for employee ${rssbNumber}: ${error.message}`);
            throw error;
        }
    }

    /**
     * Get cache statistics (for monitoring)
     */
    public async getCacheStats(): Promise<{ hit: number; miss: number; keys: number }> {
        try {
            // Count keys matching our pattern
            const keys = await this.redis.keys('contributions:*');
            const stats = { hit: 0, miss: 0, keys: keys.length };

            return stats;
        } catch (error) {
            this.logger.error(`Failed to get cache stats: ${error.message}`);
            return { hit: 0, miss: 0, keys: 0 };
        }
    }

}