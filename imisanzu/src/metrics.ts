import { metrics } from '@opentelemetry/api';

// Create a meter for business metrics
const meter = metrics.getMeter('vntp-imisanzu-service', '1.0.0');

// Business Metrics
export const contributionCounter = meter.createCounter('contributions_total', {
  description: 'Total number of contributions processed',
});

export const aggregationOperations = meter.createCounter('aggregation_operations_total', {
  description: 'Total number of contribution aggregation operations',
});

export const cacheHitRatio = meter.createUpDownCounter('cache_hit_ratio', {
  description: 'Cache hit ratio for contribution data',
});

export const requestDurationHistogram = meter.createHistogram('request_duration_ms', {
  description: 'Duration of HTTP requests in milliseconds',
});

export const externalApiCalls = meter.createCounter('external_api_calls_total', {
  description: 'Total number of external API calls to Oracle service',
});

// Helper functions
export function incrementContributionOperation(operation: string, status: string) {
  contributionCounter.add(1, { operation, status });
}

export function incrementAggregationOperation(type: string, status: string) {
  aggregationOperations.add(1, { type, status });
}

export function recordCacheOperation(hit: boolean) {
  cacheHitRatio.add(hit ? 1 : -1, { type: hit ? 'hit' : 'miss' });
}

export function recordRequestDuration(duration: number, method: string, route: string, status: number) {
  requestDurationHistogram.record(duration, { 
    method, 
    route, 
    status: status.toString() 
  });
}

export function incrementExternalApiCall(service: string, status: string) {
  externalApiCalls.add(1, { service, status });
}
