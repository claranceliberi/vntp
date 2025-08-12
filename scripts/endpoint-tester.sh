#!/bin/bash

# Endpoint Testing Script for VNTP Demo
# Tests all service endpoints periodically with intentional failures to simulate real-world scenarios

set -e

# Configuration
ORACLE_URL="http://localhost:3002"
IMISANZU_URL="http://localhost:3001"
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"
SIGNOZ_QUERY_URL="http://localhost:8080"
SIGNOZ_FRONTEND_URL="http://localhost:8080"

# Test interval in seconds
INTERVAL=30

# Log file
LOG_FILE="endpoint-tests.log"
ERROR_LOG="endpoint-errors.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$ERROR_LOG"
}

# Function to test endpoint with intentional failures
test_endpoint() {
    local name="$1"
    local url="$2"
    local endpoint="$3"
    local expected_status="$4"
    local should_fail="$5"

    local full_url="${url}${endpoint}"
    
    if [[ "$should_fail" == "true" ]]; then
        # Simulate network failure
        log "🔥 CHAOS: Simulating failure for ${name} ${endpoint}"
        echo -e "${RED}❌ ${name} ${endpoint} - SIMULATED FAILURE${NC}"
        error_log "Simulated failure for ${name} ${endpoint}"
        return 1
    fi

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$full_url" 2>/dev/null || echo "000")
    
    if [[ "$status_code" == "$expected_status" ]]; then
        echo -e "${GREEN}✅ ${name} ${endpoint} - Status: ${status_code}${NC}"
        log "SUCCESS: ${name} ${endpoint} returned ${status_code}"
        return 0
    else
        echo -e "${RED}❌ ${name} ${endpoint} - Expected: ${expected_status}, Got: ${status_code}${NC}"
        error_log "${name} ${endpoint} - Expected: ${expected_status}, Got: ${status_code}"
        return 1
    fi
}

# Function to create test data (using correct API schema)
create_test_data() {
    local should_fail="$1"
    
    if [[ "$should_fail" == "true" ]]; then
        log "🔥 CHAOS: Skipping test data creation due to simulated failure"
        return 1
    fi

    # Create employee in Oracle service (using correct schema)
    local employee_data='{"firstname":"John","lastname":"Doe","rssbNumber":"TEST'$(date +%s)'","dob":"1990-01-01"}'
    local employee_response
    employee_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$employee_data" \
        "$ORACLE_URL/api/v1/employees" 2>/dev/null || echo "")
    
    if [[ -n "$employee_response" ]]; then
        log "Created test employee: $employee_response"
        
        # Extract employee ID for contribution test (handle both jq and manual parsing)
        local employee_id
        if command -v jq >/dev/null 2>&1; then
            employee_id=$(echo "$employee_response" | jq -r '.id' 2>/dev/null || echo "")
        else
            # Manual parsing if jq is not available
            employee_id=$(echo "$employee_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || echo "")
        fi
        
        if [[ -n "$employee_id" && "$employee_id" != "null" ]]; then
            # Create contribution in Oracle service (contributions are managed by Oracle)
            local contribution_data='{"employeeId":"'$employee_id'","employerId":"EMP'$(date +%s)'","amount":1000,"contributionDate":"2025-01-01"}'
            local contribution_response
            contribution_response=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "$contribution_data" \
                "$ORACLE_URL/api/v1/contributions" 2>/dev/null || echo "")
            
            if [[ -n "$contribution_response" ]]; then
                log "Created test contribution: $contribution_response"
            fi
        fi
    fi
}

# Function to determine if this iteration should fail
should_fail_now() {
    local iteration="$1"
    # Fail approximately every 7th iteration (simulate ~15% failure rate)
    if (( iteration % 7 == 0 )); then
        echo "true"
    else
        echo "false"
    fi
}

# Main testing loop
main() {
    echo "🚀 Starting VNTP Endpoint Testing with Chaos Engineering"
    echo "📝 Logs will be written to: $LOG_FILE and $ERROR_LOG"
    echo "⏱️  Test interval: ${INTERVAL} seconds"
    echo "🔥 Simulating failures every ~7 iterations"
    echo ""

    # Clear previous logs
    > "$LOG_FILE"
    > "$ERROR_LOG"

    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        local should_fail
        should_fail=$(should_fail_now $iteration)
        
        echo "🔄 Test iteration #${iteration} ($(date '+%H:%M:%S'))"
        
        if [[ "$should_fail" == "true" ]]; then
            echo -e "${YELLOW}⚠️  CHAOS MODE: This iteration will simulate failures${NC}"
        fi
        
        local total_tests=0
        local passed_tests=0
        
        # Test Oracle service endpoints
        echo "🏛️  Testing Oracle Service..."
        test_endpoint "Oracle" "$ORACLE_URL" "/api/v1/employees" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        test_endpoint "Oracle" "$ORACLE_URL" "/api/v1/employees" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        # Test Imisanzu service endpoints
        echo "🏢 Testing Imisanzu Service..."
        test_endpoint "Imisanzu" "$IMISANZU_URL" "/api/v1/employees" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        test_endpoint "Imisanzu" "$IMISANZU_URL" "/api/v1/employees" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        test_endpoint "Imisanzu" "$IMISANZU_URL" "/api/v1/contributions/cache/stats" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        # Test observability stack
        echo "📊 Testing Observability Stack..."
        test_endpoint "Prometheus" "$PROMETHEUS_URL" "/-/ready" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        test_endpoint "Grafana" "$GRAFANA_URL" "/api/health" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        test_endpoint "SigNoz Query" "$SIGNOZ_QUERY_URL" "/api/v1/health" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        test_endpoint "SigNoz Frontend" "$SIGNOZ_FRONTEND_URL" "/" "200" "$should_fail" && ((passed_tests++))
        ((total_tests++))
        
        # Create test data (with potential failure)
        echo "📝 Creating test data..."
        if create_test_data "$should_fail"; then
            echo -e "${GREEN}✅ Test data created successfully${NC}"
            log "Test data created successfully"
            ((passed_tests++))
        else
            echo -e "${RED}❌ Failed to create test data${NC}"
        fi
        ((total_tests++))
        
        # Summary for this iteration
        local success_rate=$((passed_tests * 100 / total_tests))
        echo ""
        echo "📈 Iteration #${iteration} Summary:"
        echo "   Tests passed: ${passed_tests}/${total_tests} (${success_rate}%)"
        
        if [[ "$should_fail" == "true" ]]; then
            echo -e "   ${YELLOW}Mode: CHAOS (intentional failures)${NC}"
        else
            echo "   Mode: Normal"
        fi
        
        log "Iteration #${iteration} completed: ${passed_tests}/${total_tests} tests passed (${success_rate}%)"
        
        echo ""
        echo "⏳ Waiting ${INTERVAL} seconds until next iteration..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        sleep "$INTERVAL"
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n👋 Endpoint testing stopped by user"; exit 0' INT

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo "❌ curl is required but not installed."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "⚠️  jq is not installed. JSON parsing for test data creation will be limited."
fi

# Start the main function
main