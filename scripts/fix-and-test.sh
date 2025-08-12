#!/bin/bash

# Fix and Test Script for VNTP Server
# This script installs missing dependencies and tests the fixed scripts

set -e

echo "🔧 VNTP Script Fix and Test Utility"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check and install dependencies
install_dependencies() {
    echo -e "${BLUE}📦 Checking and installing dependencies...${NC}"
    
    # Check for bc (calculator for load testing)
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}Installing bc (calculator)...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y bc
        elif command -v yum &> /dev/null; then
            sudo yum install -y bc
        else
            echo -e "${RED}❌ Cannot install bc automatically. Please install manually.${NC}"
        fi
    else
        echo -e "${GREEN}✅ bc is already installed${NC}"
    fi
    
    # Check for jq (JSON processor)
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Installing jq (JSON processor)...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            echo -e "${RED}❌ Cannot install jq automatically. Please install manually.${NC}"
        fi
    else
        echo -e "${GREEN}✅ jq is already installed${NC}"
    fi
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl is required but not installed. Please install curl.${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ curl is already installed${NC}"
    fi
}

# Function to test service connectivity
test_services() {
    echo ""
    echo -e "${BLUE}🔗 Testing service connectivity...${NC}"
    echo "================================="
    
    local services=(
        "Oracle:http://localhost:3002/api/v1/employees"
        "Imisanzu:http://localhost:3001/api/v1/employees"
        "Prometheus:http://localhost:9090/-/ready"
        "Grafana:http://localhost:3000/api/health"
        "SigNoz:http://localhost:8080/api/v1/health"
    )
    
    local failed_services=0
    
    for service_info in "${services[@]}"; do
        local name=$(echo "$service_info" | cut -d: -f1)
        local url=$(echo "$service_info" | cut -d: -f2-)
        
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
        
        if [[ "$response" =~ ^[2-3][0-9][0-9]$ ]]; then
            echo -e "${GREEN}✅ $name - Status: $response${NC}"
        else
            echo -e "${RED}❌ $name - Status: $response${NC}"
            ((failed_services++))
        fi
    done
    
    echo ""
    if [[ $failed_services -eq 0 ]]; then
        echo -e "${GREEN}🎉 All services are accessible!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  $failed_services service(s) are not accessible${NC}"
        return 1
    fi
}

# Function to test API endpoints with correct data
test_api_endpoints() {
    echo ""
    echo -e "${BLUE}🧪 Testing API endpoints with correct schema...${NC}"
    echo "=============================================="
    
    # Test Oracle service - Create employee
    echo "Testing Oracle Employee Creation..."
    local employee_data='{"firstname":"TestUser","lastname":"FixScript","rssbNumber":"TEST'$(date +%s)'","dob":"1990-01-01"}'
    local employee_response
    employee_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$employee_data" \
        "http://localhost:3002/api/v1/employees" 2>/dev/null || echo "ERROR")
    
    if [[ "$employee_response" == "ERROR" ]] || [[ -z "$employee_response" ]]; then
        echo -e "${RED}❌ Failed to create employee${NC}"
    else
        echo -e "${GREEN}✅ Employee created successfully${NC}"
        echo "Response: $employee_response"
        
        # Extract employee ID for contribution test
        local employee_id
        if command -v jq >/dev/null 2>&1; then
            employee_id=$(echo "$employee_response" | jq -r '.id' 2>/dev/null || echo "")
        else
            employee_id=$(echo "$employee_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || echo "")
        fi
        
        if [[ -n "$employee_id" && "$employee_id" != "null" ]]; then
            echo "Employee ID: $employee_id"
            
            # Test Oracle service - Create contribution
            echo "Testing Oracle Contribution Creation..."
            local contribution_data='{"employeeId":"'$employee_id'","employerId":"EMP'$(date +%s)'","amount":1500,"contributionDate":"2025-01-15"}'
            local contribution_response
            contribution_response=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "$contribution_data" \
                "http://localhost:3002/api/v1/contributions" 2>/dev/null || echo "ERROR")
            
            if [[ "$contribution_response" == "ERROR" ]] || [[ -z "$contribution_response" ]]; then
                echo -e "${RED}❌ Failed to create contribution${NC}"
            else
                echo -e "${GREEN}✅ Contribution created successfully${NC}"
                echo "Response: $contribution_response"
            fi
        fi
    fi
    
    # Test Imisanzu service endpoints
    echo ""
    echo "Testing Imisanzu Cache Stats..."
    local cache_stats
    cache_stats=$(curl -s "http://localhost:3001/api/v1/contributions/cache/stats" 2>/dev/null || echo "ERROR")
    
    if [[ "$cache_stats" == "ERROR" ]] || [[ -z "$cache_stats" ]]; then
        echo -e "${RED}❌ Failed to get cache stats${NC}"
    else
        echo -e "${GREEN}✅ Cache stats retrieved successfully${NC}"
        echo "Response: $cache_stats"
    fi
}

# Function to run a quick load test
run_quick_test() {
    echo ""
    echo -e "${BLUE}🚀 Running quick load test (30 seconds)...${NC}"
    echo "==========================================="
    
    # Make the scripts executable
    chmod +x ./load-generator.sh
    chmod +x ./endpoint-tester.sh
    
    # Run a very quick load test
    timeout 30s ./load-generator.sh --quick || true
    
    echo ""
    echo -e "${GREEN}Quick test completed!${NC}"
}

# Main function
main() {
    echo "This script will:"
    echo "1. Install missing dependencies (bc, jq)"
    echo "2. Test service connectivity" 
    echo "3. Test API endpoints with correct schema"
    echo "4. Run a quick load test"
    echo ""
    
    # Install dependencies
    install_dependencies
    
    # Test services
    if test_services; then
        # Test API endpoints
        test_api_endpoints
        
        # Ask if user wants to run quick test
        echo ""
        echo -n "Run a quick 30-second load test? (y/N): "
        read -r run_test
        
        if [[ "$run_test" =~ ^[Yy]$ ]]; then
            run_quick_test
        fi
    else
        echo -e "${YELLOW}⚠️  Some services are not accessible. Please start all services first:${NC}"
        echo "   1. Start SigNoz: cd monitoring/signoz/deploy/docker && docker-compose up -d"
        echo "   2. Start VNTP: docker-compose up -d"
    fi
    
    echo ""
    echo -e "${GREEN}🎯 Script fixes completed!${NC}"
    echo ""
    echo "You can now run:"
    echo "  • ./load-generator.sh --quick    (Quick load test)"
    echo "  • ./endpoint-tester.sh           (Continuous endpoint testing)"
    echo "  • ./signoz-integration-test.sh   (SigNoz integration test)"
}

# Check if we're in the scripts directory
if [[ ! -f "load-generator.sh" ]] || [[ ! -f "endpoint-tester.sh" ]]; then
    echo -e "${RED}❌ Please run this script from the scripts directory${NC}"
    echo "Usage: cd /app/vntp/scripts && ./fix-and-test.sh"
    exit 1
fi

# Handle Ctrl+C gracefully
trap 'echo -e "\n👋 Fix script interrupted by user"; exit 0' INT

# Start the main function
main "$@"