#!/bin/bash

# Chaos Engineering Script for VNTP Demo
# Introduces controlled failures to test system resilience and observability

set -e

# Configuration
ORACLE_CONTAINER="vntp-oracle-service-1"
IMISANZU_CONTAINER="vntp-imisanzu-service-1"
REDIS_CONTAINER="vntp-redis-1"
POSTGRES_ORACLE_CONTAINER="vntp-postgres-oracle-1"
POSTGRES_IMISANZU_CONTAINER="vntp-postgres-imisanzu-1"

# Chaos scenarios duration (in seconds)
SHORT_OUTAGE=30
MEDIUM_OUTAGE=60
LONG_OUTAGE=120

# Log file
LOG_FILE="chaos-engineering.log"

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

# Function to check if container is running
is_container_running() {
    local container="$1"
    docker ps --format "table {{.Names}}" | grep -q "^${container}$"
}

# Function to wait for container to be healthy
wait_for_healthy() {
    local container="$1"
    local max_wait="$2"
    local waited=0
    
    echo "⏳ Waiting for $container to become healthy (max ${max_wait}s)..."
    
    while [ $waited -lt $max_wait ]; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container" | grep -q "healthy"; then
            echo -e "${GREEN}✅ $container is healthy${NC}"
            return 0
        fi
        
        if is_container_running "$container"; then
            echo -n "."
            sleep 5
            waited=$((waited + 5))
        else
            echo -e "${RED}❌ $container is not running${NC}"
            return 1
        fi
    done
    
    echo -e "${YELLOW}⚠️  $container did not become healthy within ${max_wait}s${NC}"
    return 1
}

# Function to pause container (simulate service failure)
pause_container() {
    local container="$1"
    local duration="$2"
    local reason="$3"
    
    if ! is_container_running "$container"; then
        echo -e "${YELLOW}⚠️  Container $container is not running, skipping pause${NC}"
        return 1
    fi
    
    echo -e "${RED}🔥 CHAOS: Pausing $container for ${duration}s ($reason)${NC}"
    log "CHAOS: Pausing $container for ${duration}s - $reason"
    
    docker pause "$container"
    sleep "$duration"
    
    echo -e "${GREEN}🔄 RECOVERY: Unpausing $container${NC}"
    log "RECOVERY: Unpausing $container"
    docker unpause "$container"
    
    wait_for_healthy "$container" 60
}

# Function to restart container (simulate service restart)
restart_container() {
    local container="$1"
    local reason="$2"
    
    if ! is_container_running "$container"; then
        echo -e "${YELLOW}⚠️  Container $container is not running, skipping restart${NC}"
        return 1
    fi
    
    echo -e "${RED}🔥 CHAOS: Restarting $container ($reason)${NC}"
    log "CHAOS: Restarting $container - $reason"
    
    docker restart "$container"
    wait_for_healthy "$container" 120
}

# Function to kill and restart container (simulate crash)
kill_container() {
    local container="$1"
    local duration="$2"
    local reason="$3"
    
    if ! is_container_running "$container"; then
        echo -e "${YELLOW}⚠️  Container $container is not running, skipping kill${NC}"
        return 1
    fi
    
    echo -e "${RED}💥 CHAOS: Killing $container for ${duration}s ($reason)${NC}"
    log "CHAOS: Killing $container for ${duration}s - $reason"
    
    docker kill "$container"
    sleep "$duration"
    
    echo -e "${GREEN}🔄 RECOVERY: Starting $container${NC}"
    log "RECOVERY: Starting $container"
    docker start "$container"
    
    wait_for_healthy "$container" 180
}

# Function to simulate high CPU load
simulate_high_cpu() {
    local container="$1"
    local duration="$2"
    local reason="$3"
    
    if ! is_container_running "$container"; then
        echo -e "${YELLOW}⚠️  Container $container is not running, skipping CPU stress${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔥 CHAOS: High CPU stress on $container for ${duration}s ($reason)${NC}"
    log "CHAOS: High CPU stress on $container for ${duration}s - $reason"
    
    # Create CPU stress in background
    docker exec -d "$container" sh -c "
        for i in \$(seq 1 4); do
            dd if=/dev/zero of=/dev/null bs=1M &
        done
        sleep $duration
        killall dd
    " 2>/dev/null || echo "Failed to create CPU stress"
    
    sleep "$duration"
    echo -e "${GREEN}🔄 RECOVERY: CPU stress ended for $container${NC}"
    log "RECOVERY: CPU stress ended for $container"
}

# Function to run a chaos scenario
run_scenario() {
    local scenario_name="$1"
    shift
    
    echo ""
    echo -e "${BLUE}🎭 Starting Chaos Scenario: $scenario_name${NC}"
    echo "════════════════════════════════════════════════════════"
    log "Starting chaos scenario: $scenario_name"
    
    "$@"
    
    echo -e "${BLUE}✅ Completed Chaos Scenario: $scenario_name${NC}"
    log "Completed chaos scenario: $scenario_name"
    echo ""
}

# Chaos scenarios
scenario_database_outage() {
    echo "Simulating database connectivity issues..."
    pause_container "$POSTGRES_ORACLE_CONTAINER" "$MEDIUM_OUTAGE" "Database maintenance simulation"
    sleep 10
    pause_container "$POSTGRES_IMISANZU_CONTAINER" "$SHORT_OUTAGE" "Secondary database issue"
}

scenario_cache_failure() {
    echo "Simulating cache layer failure..."
    kill_container "$REDIS_CONTAINER" "$SHORT_OUTAGE" "Redis cache crash simulation"
}

scenario_service_restart() {
    echo "Simulating rolling service restarts..."
    restart_container "$ORACLE_CONTAINER" "Scheduled maintenance restart"
    sleep 15
    restart_container "$IMISANZU_CONTAINER" "Application deployment"
}

scenario_high_load() {
    echo "Simulating high CPU load across services..."
    simulate_high_cpu "$ORACLE_CONTAINER" "$SHORT_OUTAGE" "High traffic load" &
    sleep 5
    simulate_high_cpu "$IMISANZU_CONTAINER" "$SHORT_OUTAGE" "Processing heavy workload" &
    wait
}

scenario_cascade_failure() {
    echo "Simulating cascade failure scenario..."
    echo "1. Cache goes down first..."
    pause_container "$REDIS_CONTAINER" "$SHORT_OUTAGE" "Initial cache failure"
    
    sleep 10
    echo "2. Primary service struggles without cache..."
    simulate_high_cpu "$ORACLE_CONTAINER" 20 "Overload due to cache miss"
    
    sleep 5
    echo "3. Secondary service affected by primary service issues..."
    pause_container "$IMISANZU_CONTAINER" 15 "Downstream effect of primary service issues"
}

scenario_network_partition() {
    echo "Simulating network partition (service isolation)..."
    # This simulates services being temporarily unreachable
    pause_container "$ORACLE_CONTAINER" 20 "Network partition - primary service"
    sleep 10
    pause_container "$IMISANZU_CONTAINER" 15 "Network partition - secondary service"
}

# Interactive menu
show_menu() {
    echo ""
    echo -e "${BLUE}🎭 VNTP Chaos Engineering Menu${NC}"
    echo "════════════════════════════════════════"
    echo "1. Database Outage Scenario"
    echo "2. Cache Failure Scenario"
    echo "3. Service Restart Scenario"
    echo "4. High Load Scenario"
    echo "5. Cascade Failure Scenario"
    echo "6. Network Partition Scenario"
    echo "7. Run All Scenarios (Demo Mode)"
    echo "8. Show Container Status"
    echo "9. View Chaos Log"
    echo "0. Exit"
    echo ""
}

show_status() {
    echo ""
    echo -e "${BLUE}📊 Current Container Status${NC}"
    echo "════════════════════════════════════════"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(vntp-|signoz-|query-service|alertmanager)" || echo "No VNTP containers found"
    echo ""
}

view_log() {
    if [[ -f "$LOG_FILE" ]]; then
        echo ""
        echo -e "${BLUE}📖 Recent Chaos Engineering Log (last 20 lines)${NC}"
        echo "════════════════════════════════════════"
        tail -20 "$LOG_FILE"
        echo ""
    else
        echo "No log file found."
    fi
}

run_all_scenarios() {
    echo -e "${YELLOW}🚀 Running All Chaos Scenarios (Demo Mode)${NC}"
    echo "This will run all scenarios with 30-second delays between them."
    echo "Press Ctrl+C to stop at any time."
    echo ""
    
    local scenarios=(
        "Database Outage" scenario_database_outage
        "Cache Failure" scenario_cache_failure
        "Service Restart" scenario_service_restart
        "High Load" scenario_high_load
        "Network Partition" scenario_network_partition
        "Cascade Failure" scenario_cascade_failure
    )
    
    for ((i=0; i<${#scenarios[@]}; i+=2)); do
        run_scenario "${scenarios[i]}" "${scenarios[i+1]}"
        
        if [[ $((i+2)) -lt ${#scenarios[@]} ]]; then
            echo "⏳ Waiting 30 seconds before next scenario..."
            sleep 30
        fi
    done
    
    echo -e "${GREEN}🎉 All chaos scenarios completed!${NC}"
}

# Main function
main() {
    echo -e "${BLUE}🎭 VNTP Chaos Engineering Tool${NC}"
    echo "Testing system resilience through controlled failures"
    echo "📝 Logs will be written to: $LOG_FILE"
    echo ""
    
    # Initialize log file
    > "$LOG_FILE"
    log "Chaos Engineering session started"
    
    if [[ "$1" == "--demo" ]]; then
        run_all_scenarios
        return 0
    fi
    
    while true; do
        show_menu
        echo -n "Select an option (0-9): "
        read -r choice
        
        case $choice in
            1) run_scenario "Database Outage" scenario_database_outage ;;
            2) run_scenario "Cache Failure" scenario_cache_failure ;;
            3) run_scenario "Service Restart" scenario_service_restart ;;
            4) run_scenario "High Load" scenario_high_load ;;
            5) run_scenario "Cascade Failure" scenario_cascade_failure ;;
            6) run_scenario "Network Partition" scenario_network_partition ;;
            7) run_all_scenarios ;;
            8) show_status ;;
            9) view_log ;;
            0) 
                echo -e "${GREEN}👋 Exiting Chaos Engineering Tool${NC}"
                log "Chaos Engineering session ended"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-9.${NC}"
                ;;
        esac
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n👋 Chaos Engineering stopped by user"; log "Chaos Engineering session interrupted by user"; exit 0' INT

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed."
    exit 1
fi

# Start the main function
main "$@"