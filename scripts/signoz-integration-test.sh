#!/bin/bash

echo "🔍 VNTP SigNoz Integration Test Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -n "Checking $service_name: "
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"; then
        echo -e "${GREEN}✓ HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}✗ UNHEALTHY${NC}"
        return 1
    fi
}

# Function to test telemetry endpoints
test_telemetry() {
    local service_name=$1
    local base_url=$2
    
    echo -e "${BLUE}Testing $service_name telemetry generation...${NC}"
    
    # Generate some test data to create traces/metrics/logs
    case $service_name in
        "Oracle")
            echo "Creating employee..."
            curl -X POST "$base_url/api/v1/employees" \
                -H "Content-Type: application/json" \
                -d '{
                    "firstname": "Test",
                    "lastname": "User",
                    "rssbNumber": "TEST'$(date +%s)'",
                    "dob": "1990-01-01"
                }' \
                -w "\nStatus: %{http_code}\n" \
                --silent --show-error || true
            
            echo "Fetching employees..."
            curl -s "$base_url/api/v1/employees" > /dev/null || true
            ;;
        "Imisanzu")
            echo "Testing contribution fetch..."
            curl -s "$base_url/api/v1/contributions/employee/TEST123" > /dev/null || true
            
            echo "Getting cache stats..."
            curl -s "$base_url/api/v1/contributions/cache/stats" > /dev/null || true
            ;;
    esac
}

# Function to generate load
generate_load() {
    echo -e "${YELLOW}Generating load to create telemetry data...${NC}"
    
    for i in {1..10}; do
        # Oracle Service Load
        curl -s "http://localhost:3002/api/v1/employees" > /dev/null &
        curl -X POST "http://localhost:3002/api/v1/employees" \
            -H "Content-Type: application/json" \
            -d '{
                "firstname": "Load'$i'",
                "lastname": "Test",
                "rssbNumber": "LOAD'$i'",
                "dob": "1990-01-01"
            }' > /dev/null &
        
        # Imisanzu Service Load
        curl -s "http://localhost:3001/api/v1/contributions/employee/TEST123" > /dev/null &
        curl -s "http://localhost:3001/api/v1/contributions/cache/stats" > /dev/null &
        
        sleep 0.5
    done
    
    wait
    echo -e "${GREEN}Load generation completed${NC}"
}

echo
echo "1. Checking service health..."
echo "============================="
check_service "Oracle Service" "http://localhost:3002/api/v1/employees"
check_service "Imisanzu Service" "http://localhost:3001/api/v1/employees" 
check_service "SigNoz Frontend" "http://localhost:3301"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"

echo
echo "2. Testing telemetry generation..."
echo "================================="
test_telemetry "Oracle" "http://localhost:3002"
test_telemetry "Imisanzu" "http://localhost:3001"

echo
echo "3. Generating load for better telemetry data..."
echo "=============================================="
generate_load

echo
echo "4. Verifying SigNoz integration..."
echo "================================="
echo -e "${BLUE}Checking SigNoz OTEL Collector...${NC}"
if curl -s "http://localhost:4318/v1/traces" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SigNoz OTEL Collector is accessible${NC}"
else
    echo -e "${RED}✗ SigNoz OTEL Collector not accessible${NC}"
fi

echo -e "${BLUE}Checking if services appear in SigNoz...${NC}"
echo "Please check SigNoz UI at http://localhost:3301"
echo "Go to Services page and verify:"
echo "  - oracle-service appears in the service list"
echo "  - imisanzu-service appears in the service list"
echo "  - Traces are being collected for both services"
echo "  - Logs are being ingested"
echo "  - Metrics are being collected"

echo
echo "5. Database metrics verification..."
echo "================================="
echo "Checking PostgreSQL exporters:"
curl -s "http://localhost:9187/metrics" | grep -c "pg_" || echo "PostgreSQL Imisanzu metrics: Not found"
curl -s "http://localhost:9188/metrics" | grep -c "pg_" || echo "PostgreSQL Oracle metrics: Not found"

echo "Checking Redis exporter:"
curl -s "http://localhost:9121/metrics" | grep -c "redis_" || echo "Redis metrics: Not found"

echo
echo "6. Log aggregation verification..."
echo "================================="
echo "Checking Fluent Bit status:"
if curl -s "http://localhost:2020" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Fluent Bit is running${NC}"
    curl -s "http://localhost:2020/api/v1/metrics" | head -5
else
    echo -e "${RED}✗ Fluent Bit not accessible${NC}"
fi

echo
echo "======================================"
echo -e "${GREEN}Integration test completed!${NC}"
echo
echo "Next steps:"
echo "1. Open SigNoz at http://localhost:3301"
echo "2. Check Services page for oracle-service and imisanzu-service"
echo "3. Verify traces are appearing in the Traces page"
echo "4. Check Logs page for application and database logs"
echo "5. Review Dashboards for comprehensive metrics"
echo
echo "If services don't appear, check:"
echo "- SigNoz is running: cd monitoring/signoz && docker-compose ps"
echo "- Networks are connected: docker network ls | grep signoz"
echo "- OTEL endpoints are correct in service configurations"