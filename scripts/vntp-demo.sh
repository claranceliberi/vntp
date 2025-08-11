#!/bin/bash

# VNTP (Vendor-Neutral Telemetry Proof) Master Demo Script
# Orchestrates the complete demonstration of multi-platform telemetry

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="vntp-demo.log"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to print banner
print_banner() {
    echo -e "${BLUE}"
    echo "██╗   ██╗███╗   ██╗████████╗██████╗ "
    echo "██║   ██║████╗  ██║╚══██╔══╝██╔══██╗"
    echo "██║   ██║██╔██╗ ██║   ██║   ██████╔╝"
    echo "╚██╗ ██╔╝██║╚██╗██║   ██║   ██╔═══╝ "
    echo " ╚████╔╝ ██║ ╚████║   ██║   ██║     "
    echo "  ╚═══╝  ╚═╝  ╚═══╝   ╚═╝   ╚═╝     "
    echo -e "${NC}"
    echo -e "${CYAN}Vendor-Neutral Telemetry Proof${NC}"
    echo -e "${YELLOW}Demonstrating OpenTelemetry multi-platform integration${NC}"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        missing_tools+=("docker-compose")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites satisfied${NC}"
    log "Prerequisites check passed"
}

# Function to show system status
show_status() {
    echo -e "${CYAN}📊 VNTP System Status${NC}"
    echo "════════════════════════════════════════════════════════════════"
    
    # Check container status
    echo -e "${BLUE}🐳 Container Status:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -1
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(vntp-|signoz-|query-service|alertmanager)" || echo "No VNTP containers found"
    
    echo ""
    echo -e "${BLUE}🌐 Service Endpoints:${NC}"
    local endpoints=(
        "Oracle Service API:http://localhost:3002/api/v1"
        "Imisanzu Service API:http://localhost:3001/api/v1"
        "Prometheus:http://localhost:9090"
        "Grafana:http://localhost:3000"
        "SigNoz Frontend:http://localhost:3301"
        "SigNoz Query Service:http://localhost:8080"
    )
    
    for endpoint_info in "${endpoints[@]}"; do
        local name=$(echo "$endpoint_info" | cut -d: -f1)
        local url=$(echo "$endpoint_info" | cut -d: -f2-)
        
        local status
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
        
        if [[ "$status" =~ ^[2-3][0-9][0-9]$ ]]; then
            echo -e "  ${GREEN}✅ $name${NC} - $url"
        else
            echo -e "  ${RED}❌ $name${NC} - $url (HTTP $status)"
        fi
    done
    
    echo ""
}

# Function to start all services
start_services() {
    echo -e "${YELLOW}🚀 Starting VNTP services...${NC}"
    log "Starting VNTP services"
    
    cd "$PROJECT_ROOT"
    
    echo "Starting infrastructure services..."
    docker-compose up -d postgres-oracle postgres-imisanzu redis
    
    echo "Waiting for databases to be healthy..."
    sleep 10
    
    echo "Starting application services..."
    docker-compose up -d oracle-service imisanzu-service
    
    echo "Starting observability stack..."
    docker-compose up -d prometheus grafana otel-collector
    
    echo "Starting SigNoz services..."
    docker-compose up -d clickhouse query-service frontend
    
    echo "Waiting for services to start..."
    sleep 20
    
    log "VNTP services startup completed"
    echo -e "${GREEN}✅ All services started${NC}"
}

# Function to stop all services
stop_services() {
    echo -e "${YELLOW}⏹️  Stopping VNTP services...${NC}"
    log "Stopping VNTP services"
    
    cd "$PROJECT_ROOT"
    docker-compose down
    
    echo -e "${GREEN}✅ All services stopped${NC}"
    log "VNTP services stopped"
}

# Function to run quick validation
run_validation() {
    echo -e "${YELLOW}🔍 Running VNTP system validation...${NC}"
    log "Running system validation"
    
    # Use the telemetry monitor for health check
    if [[ -x "$SCRIPT_DIR/telemetry-monitor.sh" ]]; then
        "$SCRIPT_DIR/telemetry-monitor.sh" --health
    else
        echo -e "${YELLOW}⚠️  Telemetry monitor script not found, running basic validation${NC}"
        
        # Basic validation
        local services=(
            "Oracle:http://localhost:3002/api/v1/health"
            "Imisanzu:http://localhost:3001/api/v1/health"
            "Prometheus:http://localhost:9090/-/ready"
            "Grafana:http://localhost:3000/api/health"
            "SigNoz:http://localhost:8080/api/v1/version"
        )
        
        local passed=0
        local total=${#services[@]}
        
        for service_info in "${services[@]}"; do
            local name=$(echo "$service_info" | cut -d: -f1)
            local url=$(echo "$service_info" | cut -d: -f2-)
            
            local status
            status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
            
            if [[ "$status" =~ ^[2-3][0-9][0-9]$ ]]; then
                echo -e "${GREEN}✅ $name service is healthy${NC}"
                ((passed++))
            else
                echo -e "${RED}❌ $name service is not responding (HTTP $status)${NC}"
            fi
        done
        
        echo ""
        echo "Validation Summary: $passed/$total services healthy"
        
        if [[ $passed -eq $total ]]; then
            echo -e "${GREEN}🎉 All services are healthy!${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Some services are not healthy${NC}"
            return 1
        fi
    fi
}

# Function to run demo scenarios
run_demo() {
    echo -e "${MAGENTA}🎭 Running VNTP Demo Scenarios${NC}"
    echo "This will demonstrate the complete telemetry pipeline"
    echo ""
    
    # Start monitoring in background
    if [[ -x "$SCRIPT_DIR/telemetry-monitor.sh" ]]; then
        echo "Starting telemetry monitoring..."
        "$SCRIPT_DIR/telemetry-monitor.sh" --monitor 5 > telemetry-monitor-output.log 2>&1 &
        local monitor_pid=$!
        echo "Telemetry monitor started (PID: $monitor_pid)"
        sleep 5
    fi
    
    # Run endpoint testing
    if [[ -x "$SCRIPT_DIR/endpoint-tester.sh" ]]; then
        echo -e "${BLUE}📡 Starting endpoint testing (2 minutes)...${NC}"
        timeout 120 "$SCRIPT_DIR/endpoint-tester.sh" > endpoint-test-output.log 2>&1 &
        local endpoint_pid=$!
        sleep 10
    fi
    
    # Run light load test
    if [[ -x "$SCRIPT_DIR/load-generator.sh" ]]; then
        echo -e "${BLUE}🎯 Running light load test (1 minute)...${NC}"
        timeout 60 "$SCRIPT_DIR/load-generator.sh" --quick > load-test-output.log 2>&1 &
        local load_pid=$!
        sleep 30
    fi
    
    # Run chaos scenario
    if [[ -x "$SCRIPT_DIR/chaos-engineering.sh" ]]; then
        echo -e "${BLUE}🔥 Running chaos engineering scenario...${NC}"
        echo "Simulating a service restart scenario..."
        timeout 60 "$SCRIPT_DIR/chaos-engineering.sh" --demo > chaos-test-output.log 2>&1 &
        local chaos_pid=$!
    fi
    
    echo ""
    echo -e "${YELLOW}⏳ Demo scenarios running... This will take about 2 minutes${NC}"
    echo "You can observe the effects in:"
    echo "  • Prometheus: http://localhost:9090"
    echo "  • Grafana: http://localhost:3000 (admin/admin)"
    echo "  • SigNoz: http://localhost:3301"
    echo ""
    
    # Wait for scenarios to complete
    sleep 120
    
    # Stop background processes
    if [[ -n "$monitor_pid" ]]; then
        kill $monitor_pid 2>/dev/null || true
    fi
    
    if [[ -n "$endpoint_pid" ]]; then
        kill $endpoint_pid 2>/dev/null || true
    fi
    
    if [[ -n "$load_pid" ]]; then
        kill $load_pid 2>/dev/null || true
    fi
    
    if [[ -n "$chaos_pid" ]]; then
        kill $chaos_pid 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Demo scenarios completed!${NC}"
    echo ""
    echo -e "${CYAN}📋 Demo Results:${NC}"
    echo "  • Endpoint test log: endpoint-test-output.log"
    echo "  • Load test log: load-test-output.log"
    echo "  • Chaos test log: chaos-test-output.log"
    echo "  • Telemetry monitor log: telemetry-monitor-output.log"
    
    log "Demo scenarios completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start all VNTP services"
    echo "  stop        Stop all VNTP services"
    echo "  restart     Restart all VNTP services"
    echo "  status      Show current system status"
    echo "  validate    Run system validation"
    echo "  demo        Run complete demo scenarios"
    echo "  scripts     Show available utility scripts"
    echo "  logs        Show recent logs"
    echo "  clean       Clean up all data and logs"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start              # Start all services"
    echo "  $0 demo               # Run complete demo"
    echo "  $0 status             # Check system status"
    echo ""
}

# Function to show available scripts
show_scripts() {
    echo -e "${CYAN}📝 Available VNTP Utility Scripts${NC}"
    echo "════════════════════════════════════════════════════════════════"
    
    local scripts=(
        "endpoint-tester.sh:Periodic API endpoint testing with chaos simulation"
        "chaos-engineering.sh:Controlled failure injection for resilience testing"
        "load-generator.sh:High-volume traffic generation for performance testing"
        "telemetry-monitor.sh:Real-time monitoring of telemetry data across platforms"
    )
    
    for script_info in "${scripts[@]}"; do
        local script=$(echo "$script_info" | cut -d: -f1)
        local description=$(echo "$script_info" | cut -d: -f2-)
        
        if [[ -x "$SCRIPT_DIR/$script" ]]; then
            echo -e "  ${GREEN}✅ $script${NC} - $description"
            echo "     Usage: $SCRIPT_DIR/$script"
        else
            echo -e "  ${RED}❌ $script${NC} - Not found or not executable"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}💡 Tip: Run scripts individually for more control over testing scenarios${NC}"
}

# Function to show logs
show_logs() {
    echo -e "${CYAN}📖 Recent VNTP Logs${NC}"
    echo "════════════════════════════════════════════════════════════════"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${BLUE}Master Demo Log (last 20 entries):${NC}"
        tail -20 "$LOG_FILE"
        echo ""
    fi
    
    # Show Docker compose logs
    echo -e "${BLUE}Recent Service Logs:${NC}"
    cd "$PROJECT_ROOT"
    docker-compose logs --tail=5 oracle-service imisanzu-service 2>/dev/null || echo "No service logs available"
}

# Function to clean up
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up VNTP data and logs...${NC}"
    
    # Remove log files
    rm -f "$LOG_FILE"
    rm -f endpoint-test*.log
    rm -f load-test*.log
    rm -f chaos-test*.log
    rm -f telemetry-monitor*.log
    rm -f telemetry-*.csv
    rm -f telemetry-report-*.txt
    
    # Remove script-generated files
    rm -f "$SCRIPT_DIR"/../endpoint-tests.log
    rm -f "$SCRIPT_DIR"/../endpoint-errors.log
    rm -f "$SCRIPT_DIR"/../load-test.log
    rm -f "$SCRIPT_DIR"/../load-test-results.csv
    rm -f "$SCRIPT_DIR"/../load-test-errors.log
    rm -f "$SCRIPT_DIR"/../chaos-engineering.log
    rm -f "$SCRIPT_DIR"/../telemetry-monitor.log
    rm -f "$SCRIPT_DIR"/../telemetry-metrics.csv
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
    log "Cleanup completed"
}

# Main function
main() {
    # Initialize log file
    > "$LOG_FILE"
    log "VNTP demo session started"
    
    print_banner
    
    # Handle command line arguments
    case "${1:-help}" in
        start)
            check_prerequisites
            start_services
            show_status
            ;;
        stop)
            stop_services
            ;;
        restart)
            stop_services
            sleep 5
            check_prerequisites
            start_services
            show_status
            ;;
        status)
            show_status
            ;;
        validate)
            run_validation
            ;;
        demo)
            check_prerequisites
            echo -e "${MAGENTA}🎉 Starting Complete VNTP Demo${NC}"
            echo "This will:"
            echo "  1. Start all services"
            echo "  2. Validate system health"
            echo "  3. Run demonstration scenarios"
            echo "  4. Show results"
            echo ""
            echo -n "Continue? (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                start_services
                echo ""
                if run_validation; then
                    echo ""
                    run_demo
                    echo ""
                    show_status
                else
                    echo -e "${YELLOW}⚠️  System validation failed. Demo may not work correctly.${NC}"
                    echo -n "Continue anyway? (y/N): "
                    read -r continue_confirm
                    if [[ "$continue_confirm" =~ ^[Yy]$ ]]; then
                        run_demo
                    fi
                fi
            fi
            ;;
        scripts)
            show_scripts
            ;;
        logs)
            show_logs
            ;;
        clean)
            echo -n "This will remove all logs and data files. Continue? (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                cleanup
            fi
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
    
    log "VNTP demo session ended"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n👋 Demo stopped by user"; log "Demo session interrupted by user"; exit 0' INT

# Change to project root directory
cd "$PROJECT_ROOT"

# Start the main function
main "$@"