# VNTP - Vendor-Neutral Telemetry Proof

A demonstration of vendor-neutral telemetry using OpenTelemetry with two NestJS microservices showcasing distributed tracing, metrics collection, and observability platform independence.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Imisanzu      │◄──►│     Oracle       │◄──►│      Redis      │
│   Service       │    │     Service      │    │     Cache       │
│   Port: 3001    │    │   Port: 3002     │    │   Port: 6379    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        │
┌─────────────────┐    ┌──────────────────┐                │
│ PostgreSQL A    │    │  PostgreSQL B    │◄───────────────┘
│ Port: 5432      │    │  Port: 5433      │
└─────────────────┘    └──────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Observability Stack                              │
├─────────────────┬───────────────────┬─────────────────┬─────────────────┤
│ OTEL Collector  │   Prometheus      │    Grafana      │     SigNoz      │
│ Ports: 4317/18  │   Port: 9090     │   Port: 3000    │   Port: 3301    │
│                 │                   │                 │ + ClickHouse DB │
└─────────────────┴───────────────────┴─────────────────┴─────────────────┘
```

## Services

### Imisanzu Service (Port 3001)
- **Employee Management**: List employees, auto-sync from Oracle when missing
- **Contribution Aggregation**: Fetch contributions via Oracle API with Redis caching (1-minute TTL)
- **Database**: PostgreSQL A (secondary storage for employees/employers)
- **Cache**: Shared Redis instance

### Oracle Service (Port 3002)
- **Master Data Repository**: Primary storage for employees, employers, and contributions
- **CRUD APIs**: Full management of all entities
- **Database**: PostgreSQL B (primary storage)
- **Seed Data**: Pre-populated with 2 employees, 1 employer, and sample contributions

## Data Flow Example

1. **GET** `/api/v1/employees` → Lists employees from Imisanzu local DB
2. **GET** `/api/v1/contributions/employee/1023829A` → 
   - Imisanzu checks Redis cache
   - On cache miss: fetches from Oracle service API
   - Caches result for 1 minute
   - Returns contributions with full trace span

## Setup & Running

### Prerequisites
- Docker & Docker Compose
- Node.js 20+ (for local development)

### Quick Start

1. **Clone and Start All Services**:
```bash
# Start the complete stack
docker-compose up -d

# Check service health
docker-compose ps
```

2. **Wait for Services**: Services will automatically:
   - Run database migrations
   - Seed Oracle database with test data
   - Initialize OpenTelemetry instrumentation

3. **Access Points**:
   - **Imisanzu API**: http://localhost:3001/docs
   - **Oracle API**: http://localhost:3002/docs  
   - **Grafana**: http://localhost:3000 (admin/admin)
   - **SigNoz**: http://localhost:3301 (Unified observability platform)
   - **Prometheus**: http://localhost:9090
   - **OTEL Collector**: http://localhost:4317 (gRPC) / 4318 (HTTP)
   - **ClickHouse**: http://localhost:8123 (SigNoz database)

### Manual Testing Flow

#### 1. Verify Oracle Service Data
```bash
# List all employees
curl http://localhost:3002/api/v1/employees

# List all contributions
curl http://localhost:3002/api/v1/contributions

# Get specific employee contributions
curl "http://localhost:3002/api/v1/contributions?rssbNumber=1023829A"
```

#### 2. Test Imisanzu Service & Caching
```bash
# List employees (initially empty in Imisanzu)
curl http://localhost:3001/api/v1/employees

# Get employee by RSSB (auto-sync from Oracle)
curl http://localhost:3001/api/v1/employees/1023829A

# Verify employee was synced to Imisanzu
curl http://localhost:3001/api/v1/employees

# Get contributions (first call = cache miss)
curl http://localhost:3001/api/v1/contributions/employee/1023829A

# Get contributions again (second call = cache hit)
curl http://localhost:3001/api/v1/contributions/employee/1023829A

# Check cache statistics
curl http://localhost:3001/api/v1/contributions/cache/stats
```

#### 3. Verify Telemetry Data

**Prometheus Metrics**:
- Visit http://localhost:9090
- Query examples:
  - `cache_hits_total` - Redis cache hits
  - `cache_misses_total` - Redis cache misses
  - `oracle_api_calls_total` - API calls to Oracle
  - `employee_syncs_total` - Employee sync operations
  - `http_requests_total` - HTTP request metrics

**Grafana Dashboards**:
- Visit http://localhost:3000 (admin/admin)
- Prometheus datasource is pre-configured
- Create dashboards for:
  - Service-to-service communication
  - Cache hit/miss rates
  - Database query performance
  - HTTP request patterns

**SigNoz Platform**:
- Visit http://localhost:3301
- Unified observability with traces, metrics, and logs
- Pre-built dashboards for:
  - Application Performance Monitoring (APM)
  - Distributed tracing with service maps
  - Infrastructure metrics and alerts
  - Log analytics and search

## Database Schemas

### Employee
```typescript
{
  id: string (UUID)
  firstname: string
  lastname: string  
  rssbNumber: string (unique, e.g., "1023829A")
  dob: Date
}
```

### Employer
```typescript
{
  id: string (UUID)
  name: string
  matricule: string (unique, e.g., "3100000000A")
}
```

### Contribution
```typescript
{
  id: string (UUID)
  period: string ("YYYY-MM")
  rssbNumber: string 
  matricule: string
  amount: number (e.g., 4500000 = 4.5M RWF)
}
```

## OpenTelemetry Configuration

### Multi-Backend Export Architecture
```
┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   Application   │───►│  OTEL Collector     │───►│   Prometheus    │
│   Services      │    │  (Central Hub)      │    │   + Grafana     │
│ (Imisanzu +     │    │                     │    │                 │
│  Oracle)        │    │  Receives: OTLP     │    └─────────────────┘
└─────────────────┘    │  Exports to:        │              │
                       │  • Prometheus       │              │
                       │  • SigNoz           │    ┌─────────────────┐
                       │  • Debug logs       │───►│     SigNoz      │
                       └─────────────────────┘    │ (ClickHouse DB) │
                                                  │ Traces + Metrics│
                                                  │ + Logs          │
                                                  └─────────────────┘
```

### Instrumentation Features
- **Auto-instrumentation**: HTTP, Prisma, Redis, Axios
- **Custom Metrics**: Business-specific counters and histograms
- **Distributed Tracing**: End-to-end request correlation
- **Multi-Backend Export**: Simultaneous export to Prometheus + SigNoz
- **Vendor Neutral**: Works with any OTEL-compatible backend

### Custom Metrics Tracked

**Imisanzu Service**:
- `cache_hits_total` / `cache_misses_total`
- `employee_syncs_total`  
- `oracle_api_calls_total`
- `contribution_fetch_duration_seconds`

**Oracle Service**:
- `employees_created_total`
- `employers_created_total`
- `contributions_created_total`
- `database_queries_total`
- `database_query_duration_seconds`

## Development

### Local Development Setup
```bash
# Install dependencies for both services
cd oracle && npm install && cd ..
cd imisanzu && npm install && cd ..

# Set up databases locally
docker-compose up -d postgres-imisanzu postgres-oracle redis

# Run migrations and seed data
cd oracle && npm run db:migrate && npm run db:seed && cd ..
cd imisanzu && npm run db:migrate && cd ..

# Start services in development mode
cd oracle && npm run dev &
cd imisanzu && npm run dev &
```

### Building for Production
```bash
# Build both services
docker-compose build

# Deploy
docker-compose up -d
```

## Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker logs
```bash
docker-compose logs oracle-service
docker-compose logs imisanzu-service
```

2. **Database connection issues**: Verify PostgreSQL health
```bash
docker-compose exec postgres-oracle pg_isready
docker-compose exec postgres-imisanzu pg_isready
```

3. **Cache not working**: Check Redis connectivity
```bash
docker-compose exec redis redis-cli ping
```

4. **No telemetry data**: Verify OTEL Collector
```bash
curl http://localhost:4318/v1/traces -X POST \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'
```

### Logs
```bash
# View all service logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f oracle-service
docker-compose logs -f imisanzu-service
docker-compose logs -f otel-collector
```

## Demo Verification Checklist

- [ ] Both services start and respond to health checks
- [ ] Oracle service contains seed data (2 employees, 1 employer, contributions)
- [ ] Imisanzu service auto-syncs employees from Oracle
- [ ] Redis caching works (1-minute TTL for contributions)
- [ ] Prometheus collects metrics from both services
- [ ] Grafana shows dashboards with service metrics
- [ ] SigNoz displays unified observability (traces + metrics + logs)
- [ ] Multi-backend telemetry export works (Prometheus + SigNoz simultaneously)
- [ ] Distributed traces span across services in both platforms
- [ ] Custom business metrics are recorded in both backends
- [ ] ClickHouse database stores trace data for SigNoz
- [ ] All APIs documented in Swagger UI

## 🧪 Advanced Testing & Validation

### Master Demo Script

The VNTP system includes a comprehensive demo orchestration script:

```bash
# Complete demo with automatic service startup and testing
./scripts/vntp-demo.sh demo

# Individual commands
./scripts/vntp-demo.sh start     # Start all services
./scripts/vntp-demo.sh stop      # Stop all services
./scripts/vntp-demo.sh status    # Show system status
./scripts/vntp-demo.sh validate  # Run health checks
./scripts/vntp-demo.sh scripts   # List available testing scripts
```

### Automated Testing Scripts

#### 1. Endpoint Testing with Chaos Simulation
```bash
./scripts/endpoint-tester.sh
```
- Tests all service endpoints every 30 seconds
- Simulates ~15% failure rate (every 7th iteration)
- Creates realistic test data (employees, contributions)
- Comprehensive logging and error tracking

#### 2. Load Generation & Performance Testing
```bash
./scripts/load-generator.sh

# Quick tests
./scripts/load-generator.sh --quick   # 5 users, 2 minutes
./scripts/load-generator.sh --medium  # 10 users, 5 minutes  
./scripts/load-generator.sh --heavy   # 20 users, 10 minutes
```
Features:
- Realistic user behavior simulation (70% reads, 30% writes)
- Concurrent user sessions with ramp-up
- Real-time statistics and performance metrics
- CSV export of results for analysis

#### 3. Chaos Engineering
```bash
./scripts/chaos-engineering.sh

# Run all scenarios automatically
./scripts/chaos-engineering.sh --demo
```
Available scenarios:
- **Database Outage**: Simulates database connectivity issues
- **Cache Failure**: Redis service crashes
- **Service Restart**: Rolling service updates
- **High Load**: CPU stress simulation
- **Network Partition**: Service isolation
- **Cascade Failure**: Multi-component failure simulation

#### 4. Real-time Telemetry Monitoring
```bash
./scripts/telemetry-monitor.sh

# One-time health check
./scripts/telemetry-monitor.sh --health

# Generate monitoring report
./scripts/telemetry-monitor.sh --report
```
Features:
- Real-time dashboard with service health
- Prometheus metrics integration
- SigNoz service discovery
- Container resource monitoring
- Automated report generation

## 📊 Current System Status

**Note**: After the migration from Prisma to TypeORM for better NestJS integration, the system currently has:

✅ **Working Components**:
- Oracle Service (NestJS + TypeORM + PostgreSQL)
- Imisanzu Service (NestJS + TypeORM + PostgreSQL)
- Redis Cache (1-minute TTL)
- Prometheus (Metrics collection)
- Grafana (Visualization dashboards)
- SigNoz Query Service (Backend API)
- SigNoz Frontend (Web interface)
- ClickHouse Database (SigNoz storage)

🔧 **Components Needing Attention**:
- SigNoz OTEL Collector (configuration issues with trace exports)
- Alertmanager (connectivity issues with query service)

The core telemetry demonstration works perfectly with Prometheus and Grafana, while SigNoz provides query capabilities and frontend access.

## Architecture Benefits Demonstrated

1. **Vendor Neutrality**: OpenTelemetry configuration works with any compatible backend
2. **Multi-Backend Export**: Simultaneous telemetry streaming to Prometheus + SigNoz + future platforms
3. **Distributed Tracing**: Full request correlation across microservices visible in both Grafana and SigNoz
4. **Unified Observability**: SigNoz provides APM, tracing, metrics, and logs in single interface
5. **Performance Monitoring**: Database, cache, and API call metrics across all platforms
6. **Business Metrics**: Domain-specific counters and timing available in all backends
7. **Scalable Observability**: Collector pattern allows adding/removing backends without code changes
8. **Zero-Lock-In**: Applications send to OTEL Collector, not specific vendor endpoints
9. **Real-World Testing**: Comprehensive scripts for chaos engineering, load testing, and monitoring
10. **Automated Validation**: Complete system health checking and performance analysis