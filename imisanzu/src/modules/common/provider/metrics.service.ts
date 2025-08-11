import { Injectable } from '@nestjs/common';
import { metrics } from '@opentelemetry/api';

@Injectable()
export class MetricsService {
    private meter = metrics.getMeter('imisanzu-service');

    // Counters
    private cacheHitCounter = this.meter.createCounter('cache_hits_total', {
        description: 'Total number of cache hits',
    });

    private cacheMissCounter = this.meter.createCounter('cache_misses_total', {
        description: 'Total number of cache misses',
    });

    private employeeSyncCounter = this.meter.createCounter('employee_syncs_total', {
        description: 'Total number of employee sync operations from Oracle',
    });

    private oracleApiCallCounter = this.meter.createCounter('oracle_api_calls_total', {
        description: 'Total number of API calls to Oracle service',
    });

    // Histograms  
    private contributionFetchDuration = this.meter.createHistogram('contribution_fetch_duration_seconds', {
        description: 'Duration of contribution fetch operations',
    });

    public recordCacheHit(rssbNumber: string): void {
        this.cacheHitCounter.add(1, { rssb_number: rssbNumber });
    }

    public recordCacheMiss(rssbNumber: string): void {
        this.cacheMissCounter.add(1, { rssb_number: rssbNumber });
    }

    public recordEmployeeSync(rssbNumber: string, success: boolean): void {
        this.employeeSyncCounter.add(1, { 
            rssb_number: rssbNumber, 
            success: success.toString() 
        });
    }

    public recordOracleApiCall(endpoint: string, method: string, statusCode: number): void {
        this.oracleApiCallCounter.add(1, { 
            endpoint,
            method,
            status_code: statusCode.toString()
        });
    }

    public recordContributionFetchDuration(duration: number, rssbNumber: string): void {
        this.contributionFetchDuration.record(duration, { rssb_number: rssbNumber });
    }
}