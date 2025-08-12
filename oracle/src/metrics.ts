import { metrics } from '@opentelemetry/api';

// Create a meter for business metrics
const meter = metrics.getMeter('vntp-oracle-service', '1.0.0');

// Business Metrics
export const employeeCounter = meter.createCounter('employees_total', {
  description: 'Total number of employees managed',
});

export const employeeCrudOperations = meter.createCounter('employee_operations_total', {
  description: 'Total number of employee CRUD operations',
});

export const databaseConnectionsGauge = meter.createUpDownCounter('database_connections_active', {
  description: 'Number of active database connections',
});

export const requestDurationHistogram = meter.createHistogram('request_duration_ms', {
  description: 'Duration of HTTP requests in milliseconds',
  boundaries: [0.1, 5, 15, 50, 100, 500, 1000, 5000],
});

export const redisOperationsCounter = meter.createCounter('redis_operations_total', {
  description: 'Total number of Redis cache operations',
});

// Helper functions
export function incrementEmployeeOperation(operation: string, status: string) {
  employeeCrudOperations.add(1, { operation, status });
}

export function recordRequestDuration(duration: number, method: string, route: string, status: number) {
  requestDurationHistogram.record(duration, { 
    method, 
    route, 
    status: status.toString() 
  });
}

export function incrementRedisOperation(operation: string, status: string) {
  redisOperationsCounter.add(1, { operation, status });
}
