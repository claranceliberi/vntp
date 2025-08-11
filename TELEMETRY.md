# VNTP - Complete SigNoz Integration

## Overview

This VNTP (Vendor-Neutral Telemetry Proof) system demonstrates comprehensive observability using OpenTelemetry with **full SigNoz integration**. All telemetry data (traces, metrics, logs) from applications and infrastructure is collected and visualized in SigNoz, with Prometheus/Grafana providing complementary infrastructure monitoring.

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

## Complete SigNoz Telemetry Configuration

### OpenTelemetry Setup
Both services are fully integrated with SigNoz:
- **Trace Export**: OTLP HTTP to signoz-otel-collector:4318
- **Metrics Export**: OTLP HTTP to signoz-otel-collector:4318  
- **Logs Export**: OTLP HTTP to signoz-otel-collector:4318
- **Auto-Instrumentations**: HTTP, Express, PostgreSQL, Redis
- **Resource Attributes**: service.name, service.version, deployment.environment
- **Network Integration**: Connected to SigNoz network for seamless communication

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

## Complete Observability Architecture with SigNoz Integration

### SigNoz as Primary Observability Platform
- **All Telemetry to SigNoz**: Traces, metrics, and logs flow directly to SigNoz OTEL collector
- **Multi-Network Setup**: Services connect to both default network and SigNoz network
- **Comprehensive Log Aggregation**: Fluent Bit collects logs from all containers
- **Database Integration**: PostgreSQL and Redis metrics/logs also sent to SigNoz

### Enhanced Data Flow:
```
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                         │
├─────────────────────────────────────────────────────────────┤
│ Oracle Service + Imisanzu Service (OTEL Instrumented)      │
│         ↓ (OTLP HTTP traces/metrics/logs)                  │
├─────────────────────────────────────────────────────────────┤
│                Infrastructure Layer                         │
├─────────────────────────────────────────────────────────────┤
│ PostgreSQL + Redis + Container Logs                        │
│         ↓ (Fluent Bit Log Aggregation)                     │
├─────────────────────────────────────────────────────────────┤
│                  SigNoz OTEL Collector                     │
│                   (Port 4317/4318)                         │
│         ↓ (All telemetry data)                             │
├─────────────────────────────────────────────────────────────┤
│  SigNoz Backend → SigNoz Frontend (localhost:3301)         │
│            (Complete Observability Platform)               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Complementary Infrastructure                   │
├─────────────────────────────────────────────────────────────┤
│ Prometheus Exporters → Prometheus → Grafana                │
│        (Infrastructure metrics backup)                     │
└─────────────────────────────────────────────────────────────┘
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

## Complete Integration Testing

### Quick Start
1. **Start SigNoz** (separate monitoring/signoz folder):
   ```bash
   cd monitoring/signoz/deploy/docker
   docker-compose up -d
   ```

2. **Start VNTP Services** (fully integrated with SigNoz):
   ```bash
   docker-compose up -d
   ```

3. **Run Integration Test**:
   ```bash
   ./scripts/signoz-integration-test.sh
   ```

### Manual Testing
1. **Generate Application Traces**:
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

2. **Verify Complete SigNoz Integration**:
   - **Services**: http://localhost:3301 → Services tab
     - ✅ oracle-service should appear
     - ✅ imisanzu-service should appear
     - ✅ postgres-oracle, postgres-imisanzu, redis (via logs)
   
   - **Traces**: View detailed request flows between services
   - **Logs**: All application and database logs aggregated
   - **Metrics**: Business metrics + infrastructure metrics
   - **Dashboards**: Pre-built and custom dashboards

## Key Benefits of Complete SigNoz Integration

### SigNoz as Single Source of Truth:
- **Unified Observability**: All telemetry data (traces, metrics, logs) in one platform
- **Real-time Visibility**: Live service health, performance, and error tracking
- **Complete Service Map**: Full dependency visualization including databases
- **Advanced APM**: Detailed application performance monitoring with business context
- **Log Correlation**: Correlated logs with traces for faster debugging

### Enhanced Monitoring Capabilities:
- **Multi-Layer Observability**: Application + Infrastructure + Database logs/metrics
- **Business Intelligence**: Custom business metrics alongside technical metrics  
- **Proactive Alerting**: Early detection of issues across all system components
- **Performance Optimization**: Identify bottlenecks in the entire request flow
- **Compliance & Audit**: Complete audit trail of all system interactions

### Operational Excellence:
- **Faster MTTR**: Quick root cause analysis with correlated telemetry
- **Predictive Insights**: Trend analysis for capacity planning
- **Zero Blind Spots**: Complete visibility into microservices interactions
- **Developer Experience**: Rich debugging context for faster development
- **Production Readiness**: Enterprise-grade observability for production workloads

### Architecture Benefits:
- **Cloud-Native Design**: Scalable, container-based observability stack
- **Vendor-Neutral**: OpenTelemetry standard ensures no vendor lock-in
- **Cost-Effective**: Open-source solution with enterprise features
- **Easy Deployment**: Docker-based setup with minimal configuration