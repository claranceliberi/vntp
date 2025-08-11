# VNTP - Enhanced OpenTelemetry Integration

## Overview

This VNTP (Vendor-Neutral Telemetry Proof) system demonstrates comprehensive observability using OpenTelemetry with SigNoz, Prometheus, and Grafana.

## Services Architecture

### Oracle Service (Port 3002)
- **Role**: Master data API for employees, employers, and contributions
- **Service Name**: `oracle-service`
- **Component**: `oracle`
- **Type**: `master-data-api`

### Imisanzu Service (Port 3001)  
- **Role**: Employee management and contribution aggregation with Redis caching
- **Service Name**: `imisanzu-service`
- **Component**: `imisanzu`
- **Type**: `aggregation-api`

## Telemetry Configuration

### OpenTelemetry Setup
Both services are configured with:
- **Trace Export**: OTLP HTTP to localhost:4318 (SigNoz)
- **Metrics Export**: OTLP HTTP to localhost:4318 (SigNoz)
- **Auto-Instrumentations**: HTTP, Express, PostgreSQL, Redis
- **Custom Resource Attributes**: Service name, version, namespace, environment

### Custom Spans and Attributes

#### Oracle Service - Employee Operations
- `employee.find_all`: List all employees with count metrics
- `employee.find_by_rssb`: Find employee by RSSB number with success/failure tracking
- `employee.create`: Create new employee with validation and error tracking

**Key Attributes**:
- `employee.rssb_number`: RSSB identification number
- `employee.id`: Generated UUID
- `employee.found`: Boolean success indicator
- `operation.type`: read_all, read_single, create
- `service.component`: oracle-employee

#### Imisanzu Service - Contribution Operations
- `contribution.get_by_employee`: Fetch cached contributions with business metrics
- `contribution.get_cache_stats`: Monitor cache performance

**Key Attributes**:
- `contributions.count`: Number of contributions found
- `contributions.total_amount`: Sum of contribution amounts
- `cache.hit_rate`: Redis cache performance metric
- `data.source`: cached_from_oracle
- `service.component`: imisanzu-contribution

## Unified Observability Architecture

### SigNoz OTEL Collector (Unified - Port 4317/4318)
- **Single Point of Entry**: All telemetry data flows through SigNoz OTEL collector
- **Dual Export Strategy**: 
  - Exports metrics to Prometheus (port 8889) for Grafana dashboards
  - Sends traces/metrics/logs to SigNoz backend for detailed analysis
- **No Port Conflicts**: Eliminates duplicate OTEL collectors

### Data Flow:
```
NestJS Services (Oracle & Imisanzu) 
    ↓ (OTLP HTTP/gRPC)
SigNoz OTEL Collector (4317/4318)
    ├── Prometheus Metrics (8889) → Prometheus → Grafana
    └── Traces/Metrics/Logs → SigNoz Backend → SigNoz Frontend
```

### SigNoz (localhost:3301) 
- **Traces**: Detailed request flow analysis with custom spans
- **Metrics**: Business metrics and system performance
- **Service Map**: Inter-service dependency visualization  
- **Error Tracking**: Exception monitoring and alerts
- **APM**: Application Performance Monitoring

### Prometheus (localhost:9090)
- **Infrastructure Metrics**: Database, Redis, system metrics via exporters
- **OTEL Metrics**: Application metrics from unified OTEL collector
- **Scrape Targets**: postgres_exporter, redis_exporter, signoz-otel-collector

### Grafana (localhost:3000) 
- **Dashboards**: Visual monitoring combining infrastructure + application metrics
- **Login**: admin/admin
- **Data Sources**: Prometheus (infrastructure + OTEL metrics)

## Testing Telemetry

1. **Start SigNoz** (separate monitoring/signoz folder):
   ```bash
   cd monitoring/signoz
   docker-compose up -d
   ```

2. **Start VNTP Services** (now uses unified OTEL collector):
   ```bash
   docker-compose up -d
   ```
   
   **Note**: The main docker-compose no longer includes a separate otel-collector service. All telemetry flows through SigNoz's OTEL collector.

3. **Generate Traces**:
   ```bash
   # Create employee in Oracle service
   curl -X POST http://localhost:3002/api/v1/employees -H "Content-Type: application/json" -d '{
     "firstname": "John",
     "lastname": "Doe", 
     "rssbNumber": "TEST123",
     "dob": "1990-01-01"
   }'

   # Fetch contributions in Imisanzu service (triggers Oracle service call)
   curl http://localhost:3001/api/v1/contributions/employee/TEST123
   ```

4. **View in SigNoz**:
   - Open http://localhost:3301
   - Check Services tab for service health
   - View Traces for request flow analysis
   - Monitor custom spans and business metrics

## Key Benefits

### Unified Architecture Benefits:
- **No Port Conflicts**: Single OTEL collector eliminates duplicate services
- **Resource Efficiency**: Reduced memory and CPU usage with unified collector
- **Simplified Deployment**: Fewer services to manage and monitor
- **Consistent Data**: All telemetry flows through same pipeline ensuring data consistency

### Observability Benefits:
- **Service Performance**: Track response times, error rates, throughput across both platforms
- **Business Metrics**: Monitor contribution amounts, employee operations, cache efficiency  
- **Error Tracking**: Detailed exception monitoring with stack traces in SigNoz
- **Dependencies**: Visualize PostgreSQL and Redis interactions via both SigNoz and Grafana
- **Cross-Service Tracing**: Follow requests from Imisanzu to Oracle service in SigNoz
- **Infrastructure Monitoring**: Database connections, memory usage, cache performance in Grafana
- **Dual Visualization**: Rich APM in SigNoz + Traditional dashboards in Grafana