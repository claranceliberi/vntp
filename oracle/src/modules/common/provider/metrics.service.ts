import { Injectable } from '@nestjs/common';
import { metrics } from '@opentelemetry/api';

@Injectable()
export class MetricsService {
    private meter = metrics.getMeter('oracle-service');

    // Counters
    private employeeCreatedCounter = this.meter.createCounter('employees_created_total', {
        description: 'Total number of employees created',
    });

    private employerCreatedCounter = this.meter.createCounter('employers_created_total', {
        description: 'Total number of employers created',
    });

    private contributionCreatedCounter = this.meter.createCounter('contributions_created_total', {
        description: 'Total number of contributions created',
    });

    private databaseQueryCounter = this.meter.createCounter('database_queries_total', {
        description: 'Total number of database queries',
    });

    // Histograms
    private databaseQueryDuration = this.meter.createHistogram('database_query_duration_seconds', {
        description: 'Duration of database queries',
    });

    public recordEmployeeCreated(): void {
        this.employeeCreatedCounter.add(1);
    }

    public recordEmployerCreated(): void {
        this.employerCreatedCounter.add(1);
    }

    public recordContributionCreated(rssbNumber: string): void {
        this.contributionCreatedCounter.add(1, { rssb_number: rssbNumber });
    }

    public recordDatabaseQuery(operation: string, table: string): void {
        this.databaseQueryCounter.add(1, { operation, table });
    }

    public recordDatabaseQueryDuration(duration: number, operation: string, table: string): void {
        this.databaseQueryDuration.record(duration, { operation, table });
    }
}