#!/bin/bash

# Load Generator Script for VNTP Demo
# Generates realistic high-volume traffic to test system performance and telemetry

set -e

# Configuration
ORACLE_URL="http://localhost:3002/api/v1"
IMISANZU_URL="http://localhost:3001/api/v1"

# Load test parameters
CONCURRENT_USERS=${CONCURRENT_USERS:-10}
TEST_DURATION=${TEST_DURATION:-300}  # 5 minutes default
REQUESTS_PER_SECOND=${REQUESTS_PER_SECOND:-5}
RAMP_UP_TIME=${RAMP_UP_TIME:-30}     # 30 seconds ramp-up

# Log files
LOG_FILE="load-test.log"
RESULTS_FILE="load-test-results.csv"
ERROR_LOG="load-test-errors.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$ERROR_LOG"
}

# Function to generate random employee data (matching your API schema)
generate_employee_data() {
    local firstnames=("John" "Jane" "Bob" "Alice" "Charlie" "Eva" "Frank" "Grace" "Henry" "Ivy")
    local lastnames=("Doe" "Smith" "Johnson" "Brown" "Davis" "Wilson" "Miller" "Lee" "Taylor" "Chen")
    
    local firstname=${firstnames[$RANDOM % ${#firstnames[@]}]}
    local lastname=${lastnames[$RANDOM % ${#lastnames[@]}]}
    local rssbNumber="TEST$(date +%s)$RANDOM"
    local dob_year=$((1980 + RANDOM % 25))  # 1980-2004
    local dob_month=$(printf "%02d" $((1 + RANDOM % 12)))
    local dob_day=$(printf "%02d" $((1 + RANDOM % 28)))
    local dob="${dob_year}-${dob_month}-${dob_day}"
    
    echo "{\"firstname\":\"$firstname\",\"lastname\":\"$lastname\",\"rssbNumber\":\"$rssbNumber\",\"dob\":\"$dob\"}"
}

# Function to generate random contribution data (matching your API schema)
generate_contribution_data() {
    local period="2025-$(printf "%02d" $((1 + RANDOM % 12)))"
    local rssbNumber="TEST$(date +%s)$RANDOM"
    local matricule="EMP$(date +%s)$RANDOM"
    local amount=$((500 + RANDOM % 2000))
    
    echo "{\"period\":\"$period\",\"rssbNumber\":\"$rssbNumber\",\"matricule\":\"$matricule\",\"amount\":$amount}"
}

# Function to make HTTP request and measure response time
make_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local user_id="$4"
    local request_id="$5"
    
    local start_time=$(date +%s.%3N)
    local status_code
    local response
    
    if [[ "$method" == "POST" ]]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            --max-time 30 \
            "$url" 2>/dev/null || echo "000")
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 30 \
            "$url" 2>/dev/null || echo "000")
    fi
    
    local end_time=$(date +%s.%3N)
    local response_time=$(echo "$end_time - $start_time" | bc -l)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to CSV: timestamp,user_id,request_id,method,url,status_code,response_time
    echo "$timestamp,$user_id,$request_id,$method,$url,$response,$response_time" >> "$RESULTS_FILE"
    
    if [[ "$response" =~ ^[2-3][0-9][0-9]$ ]]; then
        return 0
    else
        error_log "User $user_id Request $request_id: $method $url returned $response (${response_time}s)"
        return 1
    fi
}

# Function to simulate realistic user behavior
simulate_user_session() {
    local user_id="$1"
    local session_duration="$2"
    local requests_per_second="$3"
    
    local request_interval=$(echo "1 / $requests_per_second" | bc -l)
    local session_start=$(date +%s)
    local request_count=0
    
    log "User $user_id: Starting session for ${session_duration}s (${requests_per_second} req/s)"
    
    while [[ $(($(date +%s) - session_start)) -lt $session_duration ]]; do
        request_count=$((request_count + 1))
        
        # Realistic user flow: 70% reads, 30% writes
        if [[ $((RANDOM % 10)) -lt 7 ]]; then
            # Read operations (using correct API endpoints)
            case $((RANDOM % 6)) in
                0) make_request "GET" "$ORACLE_URL/employees" "" "$user_id" "$request_count" ;;
                1) make_request "GET" "$ORACLE_URL/employees" "" "$user_id" "$request_count" ;;
                2) make_request "GET" "$IMISANZU_URL/employees" "" "$user_id" "$request_count" ;;
                3) make_request "GET" "$IMISANZU_URL/contributions/cache/stats" "" "$user_id" "$request_count" ;;
                4) make_request "GET" "$IMISANZU_URL/contributions/employee/TEST123" "" "$user_id" "$request_count" ;;
                5) make_request "GET" "$IMISANZU_URL/employees" "" "$user_id" "$request_count" ;;
            esac
        else
            # Write operations
            if [[ $((RANDOM % 2)) -eq 0 ]]; then
                # Create employee
                local employee_data
                employee_data=$(generate_employee_data)
                make_request "POST" "$ORACLE_URL/employees" "$employee_data" "$user_id" "$request_count"
                
                # Sometimes create a contribution for the employee (simulating realistic workflow)
                if [[ $((RANDOM % 3)) -eq 0 ]]; then
                    sleep 1  # Brief delay to simulate user thinking time
                    local contribution_data
                    contribution_data=$(generate_contribution_data)
                    request_count=$((request_count + 1))
                    make_request "POST" "$ORACLE_URL/contributions" "$contribution_data" "$user_id" "$request_count"
                fi
            else
                # Create contribution
                local contribution_data
                contribution_data=$(generate_contribution_data)
                make_request "POST" "$ORACLE_URL/contributions" "$contribution_data" "$user_id" "$request_count"
            fi
        fi
        
        # Wait between requests
        sleep "$request_interval"
    done
    
    log "User $user_id: Completed session with $request_count requests"
}

# Function to calculate statistics
calculate_stats() {
    if [[ ! -f "$RESULTS_FILE" ]]; then
        echo "No results file found."
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}📊 Load Test Results Summary${NC}"
    echo "════════════════════════════════════════════════════════"
    
    local total_requests
    total_requests=$(tail -n +2 "$RESULTS_FILE" | wc -l)
    
    local successful_requests
    successful_requests=$(tail -n +2 "$RESULTS_FILE" | awk -F, '$6 ~ /^[2-3][0-9][0-9]$/' | wc -l)
    
    local failed_requests=$((total_requests - successful_requests))
    local success_rate=$(echo "scale=2; $successful_requests * 100 / $total_requests" | bc -l)
    
    echo "Total Requests: $total_requests"
    echo "Successful Requests: $successful_requests"
    echo "Failed Requests: $failed_requests"
    echo "Success Rate: ${success_rate}%"
    
    # Response time statistics
    local avg_response_time
    avg_response_time=$(tail -n +2 "$RESULTS_FILE" | awk -F, '{sum+=$7; count++} END {print sum/count}')
    
    local min_response_time
    min_response_time=$(tail -n +2 "$RESULTS_FILE" | awk -F, '{print $7}' | sort -n | head -1)
    
    local max_response_time
    max_response_time=$(tail -n +2 "$RESULTS_FILE" | awk -F, '{print $7}' | sort -n | tail -1)
    
    echo "Average Response Time: ${avg_response_time}s"
    echo "Min Response Time: ${min_response_time}s"
    echo "Max Response Time: ${max_response_time}s"
    
    # Requests per endpoint
    echo ""
    echo "Requests by Endpoint:"
    tail -n +2 "$RESULTS_FILE" | awk -F, '{print $5}' | sort | uniq -c | sort -nr | head -10
    
    # Error analysis
    echo ""
    echo "Error Analysis:"
    tail -n +2 "$RESULTS_FILE" | awk -F, '$6 !~ /^[2-3][0-9][0-9]$/ {print $6}' | sort | uniq -c | sort -nr
    
    echo "════════════════════════════════════════════════════════"
}

# Function to show real-time statistics
show_realtime_stats() {
    local duration="$1"
    local start_time=$(date +%s)
    
    while [[ $(($(date +%s) - start_time)) -lt $duration ]]; do
        clear
        echo -e "${BLUE}📊 Real-time Load Test Statistics${NC}"
        echo "════════════════════════════════════════════════════════"
        echo "Test Duration: $(($(date +%s) - start_time))s / ${duration}s"
        echo "Concurrent Users: $CONCURRENT_USERS"
        echo "Target RPS: $REQUESTS_PER_SECOND"
        echo ""
        
        if [[ -f "$RESULTS_FILE" ]]; then
            local recent_requests
            recent_requests=$(tail -n +2 "$RESULTS_FILE" | wc -l)
            echo "Total Requests So Far: $recent_requests"
            
            local recent_successful
            recent_successful=$(tail -n +2 "$RESULTS_FILE" | awk -F, '$6 ~ /^[2-3][0-9][0-9]$/' | wc -l)
            
            if [[ $recent_requests -gt 0 ]]; then
                local recent_success_rate=$(echo "scale=2; $recent_successful * 100 / $recent_requests" | bc -l)
                echo "Current Success Rate: ${recent_success_rate}%"
            fi
            
            # Show last 5 requests
            echo ""
            echo "Recent Requests:"
            tail -5 "$RESULTS_FILE" | while IFS=, read -r timestamp user_id request_id method url status response_time; do
                if [[ "$status" =~ ^[2-3][0-9][0-9]$ ]]; then
                    echo -e "  ${GREEN}✅${NC} User$user_id: $method $(basename "$url") - ${status} (${response_time}s)"
                else
                    echo -e "  ${RED}❌${NC} User$user_id: $method $(basename "$url") - ${status} (${response_time}s)"
                fi
            done
        fi
        
        sleep 2
    done
}

# Main load test function
run_load_test() {
    echo -e "${GREEN}🚀 Starting Load Test${NC}"
    echo "Configuration:"
    echo "  Concurrent Users: $CONCURRENT_USERS"
    echo "  Test Duration: $TEST_DURATION seconds"
    echo "  Requests per Second (per user): $REQUESTS_PER_SECOND"
    echo "  Ramp-up Time: $RAMP_UP_TIME seconds"
    echo ""
    
    # Initialize result files
    > "$LOG_FILE"
    > "$ERROR_LOG"
    echo "timestamp,user_id,request_id,method,url,status_code,response_time" > "$RESULTS_FILE"
    
    log "Load test started - Duration: ${TEST_DURATION}s, Users: $CONCURRENT_USERS, RPS: $REQUESTS_PER_SECOND"
    
    # Start real-time monitoring in background
    show_realtime_stats "$TEST_DURATION" &
    local monitor_pid=$!
    
    # Start user sessions with ramp-up
    local ramp_up_delay=$(echo "$RAMP_UP_TIME / $CONCURRENT_USERS" | bc -l)
    
    for ((i=1; i<=CONCURRENT_USERS; i++)); do
        simulate_user_session "$i" "$TEST_DURATION" "$REQUESTS_PER_SECOND" &
        
        if [[ $i -lt $CONCURRENT_USERS ]]; then
            sleep "$ramp_up_delay"
        fi
    done
    
    # Wait for all user sessions to complete
    wait
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    
    clear
    echo -e "${GREEN}✅ Load Test Completed!${NC}"
    log "Load test completed"
    
    # Calculate and display final statistics
    calculate_stats
}

# Interactive menu
show_menu() {
    echo ""
    echo -e "${BLUE}🎯 VNTP Load Generator Menu${NC}"
    echo "════════════════════════════════════════"
    echo "1. Quick Test (5 users, 2 minutes)"
    echo "2. Medium Test (10 users, 5 minutes)"
    echo "3. Heavy Test (20 users, 10 minutes)"
    echo "4. Custom Test (specify parameters)"
    echo "5. View Last Test Results"
    echo "6. View Error Log"
    echo "7. Test Service Connectivity"
    echo "0. Exit"
    echo ""
}

test_connectivity() {
    echo ""
    echo -e "${BLUE}🔗 Testing Service Connectivity${NC}"
    echo "════════════════════════════════════════"
    
    local services=("$ORACLE_URL/employees" "$IMISANZU_URL/employees")
    
    for service in "${services[@]}"; do
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$service" 2>/dev/null || echo "000")
        
        if [[ "$response" == "200" ]]; then
            echo -e "${GREEN}✅ $service - Status: $response${NC}"
        else
            echo -e "${RED}❌ $service - Status: $response${NC}"
        fi
    done
    echo ""
}

# Main function
main() {
    echo -e "${BLUE}🎯 VNTP Load Generator${NC}"
    echo "High-volume traffic generator for performance testing"
    echo "📝 Results will be saved to: $RESULTS_FILE"
    echo ""
    
    # Check if bc is available for calculations
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}⚠️  'bc' command not found. Installing it is recommended for accurate calculations.${NC}"
    fi
    
    if [[ "$1" == "--quick" ]]; then
        CONCURRENT_USERS=5
        TEST_DURATION=120
        REQUESTS_PER_SECOND=2
        run_load_test
        return 0
    elif [[ "$1" == "--medium" ]]; then
        CONCURRENT_USERS=10
        TEST_DURATION=300
        REQUESTS_PER_SECOND=3
        run_load_test
        return 0
    elif [[ "$1" == "--heavy" ]]; then
        CONCURRENT_USERS=20
        TEST_DURATION=600
        REQUESTS_PER_SECOND=5
        run_load_test
        return 0
    fi
    
    while true; do
        show_menu
        echo -n "Select an option (0-7): "
        read -r choice
        
        case $choice in
            1)
                CONCURRENT_USERS=5
                TEST_DURATION=120
                REQUESTS_PER_SECOND=2
                run_load_test
                ;;
            2)
                CONCURRENT_USERS=10
                TEST_DURATION=300
                REQUESTS_PER_SECOND=3
                run_load_test
                ;;
            3)
                CONCURRENT_USERS=20
                TEST_DURATION=600
                REQUESTS_PER_SECOND=5
                run_load_test
                ;;
            4)
                echo -n "Enter concurrent users: "
                read -r CONCURRENT_USERS
                echo -n "Enter test duration (seconds): "
                read -r TEST_DURATION
                echo -n "Enter requests per second (per user): "
                read -r REQUESTS_PER_SECOND
                run_load_test
                ;;
            5)
                calculate_stats
                ;;
            6)
                if [[ -f "$ERROR_LOG" ]]; then
                    echo ""
                    echo -e "${BLUE}📖 Error Log (last 20 entries)${NC}"
                    echo "════════════════════════════════════════"
                    tail -20 "$ERROR_LOG"
                    echo ""
                else
                    echo "No error log found."
                fi
                ;;
            7)
                test_connectivity
                ;;
            0)
                echo -e "${GREEN}👋 Exiting Load Generator${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-7.${NC}"
                ;;
        esac
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n👋 Load test stopped by user"; killall sleep 2>/dev/null || true; exit 0' INT

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo "❌ curl is required but not installed."
    exit 1
fi

# Start the main function
main "$@"