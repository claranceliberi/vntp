#!/bin/bash

# Telemetry Monitoring Script for VNTP Demo
# Monitors telemetry data across all observability platforms (Prometheus, Grafana, SigNoz)

set -e

# Configuration
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"
SIGNOZ_QUERY_URL="http://localhost:8080"
SIGNOZ_FRONTEND_URL="http://localhost:3301"

# Service endpoints
ORACLE_URL="http://localhost:3002/api/v1"
IMISANZU_URL="http://localhost:3001/api/v1"

# Monitoring interval
MONITOR_INTERVAL=${MONITOR_INTERVAL:-10}  # seconds

# Log files
LOG_FILE="telemetry-monitor.log"
METRICS_FILE="telemetry-metrics.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to make HTTP request with timeout
make_request() {
    local url="$1"
    local timeout="${2:-5}"
    curl -s --max-time "$timeout" "$url" 2>/dev/null || echo ""
}

# Function to query Prometheus metrics
query_prometheus() {
    local query="$1"
    local url="${PROMETHEUS_URL}/api/v1/query?query=${query}"
    make_request "$url" 10
}

# Function to get SigNoz service list
query_signoz_services() {
    local url="${SIGNOZ_QUERY_URL}/api/v1/services"
    make_request "$url" 10
}

# Function to get container stats
get_container_stats() {
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "Docker stats unavailable"
}

# Function to check service health
check_service_health() {
    local service_name="$1"
    local health_url="$2"
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$health_url" 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^[2-3][0-9][0-9]$ ]]; then
        echo -e "${GREEN}✅ $service_name${NC}"
        return 0
    else
        echo -e "${RED}❌ $service_name (HTTP $response)${NC}"
        return 1
    fi
}

# Function to display real-time telemetry dashboard
show_dashboard() {
    local iteration="$1"
    
    clear
    echo -e "${BLUE}🔍 VNTP Telemetry Monitoring Dashboard${NC}"
    echo "════════════════════════════════════════════════════════════════"
    echo "Iteration: #$iteration | $(date '+%Y-%m-%d %H:%M:%S') | Refresh: ${MONITOR_INTERVAL}s"
    echo ""
    
    # Service Health Status
    echo -e "${CYAN}🏥 Service Health Status${NC}"
    echo "────────────────────────────"
    check_service_health "Oracle Service    " "$ORACLE_URL/health"
    check_service_health "Imisanzu Service " "$IMISANZU_URL/health"
    check_service_health "Prometheus       " "$PROMETHEUS_URL/-/ready"
    check_service_health "Grafana          " "$GRAFANA_URL/api/health"
    check_service_health "SigNoz Query     " "$SIGNOZ_QUERY_URL/api/v1/version"
    check_service_health "SigNoz Frontend  " "$SIGNOZ_FRONTEND_URL/"
    echo ""
    
    # Prometheus Metrics
    echo -e "${CYAN}📊 Prometheus Metrics${NC}"
    echo "────────────────────────────"
    
    # Get HTTP request metrics
    local http_requests
    http_requests=$(query_prometheus 'sum(rate(http_requests_total[1m]))')
    if [[ -n "$http_requests" ]] && [[ "$http_requests" != *"error"* ]]; then
        local req_rate
        req_rate=$(echo "$http_requests" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | head -c 10)
        echo "HTTP Requests/sec: ${req_rate}"
    else
        echo "HTTP Requests/sec: No data"
    fi
    
    # Get error rate
    local error_rate
    error_rate=$(query_prometheus 'sum(rate(http_requests_total{status=~"5.."}[1m])) / sum(rate(http_requests_total[1m]))')
    if [[ -n "$error_rate" ]] && [[ "$error_rate" != *"error"* ]]; then
        local err_pct
        err_pct=$(echo "$error_rate" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | head -c 8)
        echo "Error Rate: ${err_pct}%"
    else
        echo "Error Rate: No data"
    fi
    
    # Get response time
    local response_time
    response_time=$(query_prometheus 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))')
    if [[ -n "$response_time" ]] && [[ "$response_time" != *"error"* ]]; then
        local p95_time
        p95_time=$(echo "$response_time" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | head -c 8)
        echo "95th percentile response time: ${p95_time}s"
    else
        echo "95th percentile response time: No data"
    fi
    echo ""
    
    # SigNoz Services
    echo -e "${CYAN}🔍 SigNoz Discovered Services${NC}"
    echo "────────────────────────────────────"
    local services
    services=$(query_signoz_services)
    if [[ -n "$services" ]] && [[ "$services" != *"error"* ]]; then
        echo "$services" | jq -r '.data[] | "Service: \(.serviceName) | Calls: \(.numCalls // 0) | Errors: \(.numErrors // 0)"' 2>/dev/null || echo "No services data available"
    else
        echo "No SigNoz services data available"
    fi
    echo ""
    
    # Container Resource Usage
    echo -e "${CYAN}🐳 Container Resource Usage${NC}"
    echo "───────────────────────────────────────────────────────────"
    get_container_stats | grep -E "(vntp-|signoz-|query-service|alertmanager)" | head -8
    echo ""
    
    # System Resource Summary
    echo -e "${CYAN}💻 System Resources${NC}"
    echo "─────────────────────"
    local cpu_usage
    cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' 2>/dev/null || echo "N/A")
    echo "CPU Usage: $cpu_usage"
    
    local memory_pressure
    memory_pressure=$(vm_stat | head -7 | tail -1 | awk '{print $3}' 2>/dev/null || echo "N/A")
    echo "Memory Pressure: $memory_pressure"
    
    local disk_usage
    disk_usage=$(df -h / | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
    echo "Disk Usage: $disk_usage"
    echo ""
    
    # Recent Log Activity
    echo -e "${CYAN}📋 Recent Activity (Last 3 Log Entries)${NC}"
    echo "─────────────────────────────────────────"
    if [[ -f "$LOG_FILE" ]]; then
        tail -3 "$LOG_FILE" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  No log activity yet"
    fi
    echo ""
    
    # Instructions
    echo -e "${YELLOW}💡 Controls: Press Ctrl+C to stop monitoring${NC}"
    echo -e "${YELLOW}   Logs: $LOG_FILE | Metrics: $METRICS_FILE${NC}"
}

# Function to collect and save metrics to CSV
collect_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get basic metrics
    local oracle_health
    oracle_health=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ORACLE_URL/health" 2>/dev/null || echo "000")
    
    local imisanzu_health
    imisanzu_health=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$IMISANZU_URL/health" 2>/dev/null || echo "000")
    
    local prometheus_health
    prometheus_health=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$PROMETHEUS_URL/-/ready" 2>/dev/null || echo "000")
    
    local signoz_health
    signoz_health=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$SIGNOZ_QUERY_URL/api/v1/version" 2>/dev/null || echo "000")
    
    # Try to get HTTP request rate from Prometheus
    local http_req_rate="0"
    local http_requests
    http_requests=$(query_prometheus 'sum(rate(http_requests_total[1m]))')
    if [[ -n "$http_requests" ]] && [[ "$http_requests" != *"error"* ]]; then
        http_req_rate=$(echo "$http_requests" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")
    fi
    
    # Save to CSV: timestamp,oracle_health,imisanzu_health,prometheus_health,signoz_health,http_req_rate
    echo "$timestamp,$oracle_health,$imisanzu_health,$prometheus_health,$signoz_health,$http_req_rate" >> "$METRICS_FILE"
}

# Function to generate telemetry report
generate_report() {
    if [[ ! -f "$METRICS_FILE" ]]; then
        echo "No metrics data available for report generation."
        return 1
    fi
    
    local report_file="telemetry-report-$(date '+%Y%m%d-%H%M%S').txt"
    
    echo "VNTP Telemetry Monitoring Report" > "$report_file"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$report_file"
    echo "═══════════════════════════════════════════════════════════════" >> "$report_file"
    echo "" >> "$report_file"
    
    # Calculate uptime statistics
    local total_checks
    total_checks=$(tail -n +2 "$METRICS_FILE" | wc -l)
    
    local oracle_uptime
    oracle_uptime=$(tail -n +2 "$METRICS_FILE" | awk -F, '$2=="200"' | wc -l)
    
    local imisanzu_uptime
    imisanzu_uptime=$(tail -n +2 "$METRICS_FILE" | awk -F, '$3=="200"' | wc -l)
    
    local prometheus_uptime
    prometheus_uptime=$(tail -n +2 "$METRICS_FILE" | awk -F, '$4=="200"' | wc -l)
    
    local signoz_uptime
    signoz_uptime=$(tail -n +2 "$METRICS_FILE" | awk -F, '$5=="200"' | wc -l)
    
    echo "SERVICE UPTIME STATISTICS" >> "$report_file"
    echo "─────────────────────────" >> "$report_file"
    echo "Total Monitoring Periods: $total_checks" >> "$report_file"
    
    if [[ $total_checks -gt 0 ]]; then
        echo "Oracle Service Uptime: $oracle_uptime/$total_checks ($(echo "scale=2; $oracle_uptime * 100 / $total_checks" | bc -l 2>/dev/null || echo "N/A")%)" >> "$report_file"
        echo "Imisanzu Service Uptime: $imisanzu_uptime/$total_checks ($(echo "scale=2; $imisanzu_uptime * 100 / $total_checks" | bc -l 2>/dev/null || echo "N/A")%)" >> "$report_file"
        echo "Prometheus Uptime: $prometheus_uptime/$total_checks ($(echo "scale=2; $prometheus_uptime * 100 / $total_checks" | bc -l 2>/dev/null || echo "N/A")%)" >> "$report_file"
        echo "SigNoz Uptime: $signoz_uptime/$total_checks ($(echo "scale=2; $signoz_uptime * 100 / $total_checks" | bc -l 2>/dev/null || echo "N/A")%)" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "HTTP REQUEST RATE STATISTICS" >> "$report_file"
    echo "────────────────────────────" >> "$report_file"
    
    local avg_req_rate
    avg_req_rate=$(tail -n +2 "$METRICS_FILE" | awk -F, '{sum+=$6; count++} END {print sum/count}' 2>/dev/null || echo "0")
    
    local max_req_rate
    max_req_rate=$(tail -n +2 "$METRICS_FILE" | awk -F, '{print $6}' | sort -n | tail -1 2>/dev/null || echo "0")
    
    echo "Average Request Rate: ${avg_req_rate} req/sec" >> "$report_file"
    echo "Peak Request Rate: ${max_req_rate} req/sec" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "RECENT ACTIVITY (Last 10 entries)" >> "$report_file"
    echo "──────────────────────────────────" >> "$report_file"
    tail -10 "$LOG_FILE" >> "$report_file" 2>/dev/null || echo "No recent activity logged" >> "$report_file"
    
    echo -e "${GREEN}📄 Report generated: $report_file${NC}"
}

# Interactive menu
show_menu() {
    echo ""
    echo -e "${BLUE}📊 VNTP Telemetry Monitor Menu${NC}"
    echo "════════════════════════════════════════"
    echo "1. Start Real-time Monitoring Dashboard"
    echo "2. Run One-time Health Check"
    echo "3. Test Individual Service Endpoints"
    echo "4. Generate Telemetry Report"
    echo "5. View Recent Metrics (CSV)"
    echo "6. View Monitor Log"
    echo "7. Clear All Data"
    echo "0. Exit"
    echo ""
}

run_health_check() {
    echo ""
    echo -e "${BLUE}🏥 One-time Health Check${NC}"
    echo "════════════════════════════════════════"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "Timestamp: $timestamp"
    echo ""
    
    echo "Application Services:"
    check_service_health "  Oracle Service    " "$ORACLE_URL/health"
    check_service_health "  Imisanzu Service " "$IMISANZU_URL/health"
    
    echo ""
    echo "Observability Stack:"
    check_service_health "  Prometheus       " "$PROMETHEUS_URL/-/ready"
    check_service_health "  Grafana          " "$GRAFANA_URL/api/health"
    check_service_health "  SigNoz Query     " "$SIGNOZ_QUERY_URL/api/v1/version"
    check_service_health "  SigNoz Frontend  " "$SIGNOZ_FRONTEND_URL/"
    
    echo ""
    echo "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(vntp-|signoz-|query-service|alertmanager)" || echo "No VNTP containers found"
    
    log "One-time health check completed"
    collect_metrics
}

test_individual_services() {
    echo ""
    echo -e "${BLUE}🔍 Individual Service Testing${NC}"
    echo "════════════════════════════════════════"
    
    local services=(
        "Oracle Health:$ORACLE_URL/health"
        "Oracle Employees:$ORACLE_URL/employees"
        "Imisanzu Health:$IMISANZU_URL/health"
        "Imisanzu Contributions:$IMISANZU_URL/contributions"
        "Prometheus Ready:$PROMETHEUS_URL/-/ready"
        "Prometheus Metrics:$PROMETHEUS_URL/api/v1/label/__name__/values"
        "Grafana Health:$GRAFANA_URL/api/health"
        "SigNoz Version:$SIGNOZ_QUERY_URL/api/v1/version"
        "SigNoz Services:$SIGNOZ_QUERY_URL/api/v1/services"
    )
    
    for service_info in "${services[@]}"; do
        local service_name=$(echo "$service_info" | cut -d: -f1)
        local service_url=$(echo "$service_info" | cut -d: -f2-)
        
        echo -n "Testing $service_name... "
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$service_url" 2>/dev/null || echo "000")
        
        if [[ "$response" =~ ^[2-3][0-9][0-9]$ ]]; then
            echo -e "${GREEN}✅ $response${NC}"
        else
            echo -e "${RED}❌ $response${NC}"
        fi
    done
    
    echo ""
}

# Main monitoring loop
start_monitoring() {
    echo -e "${GREEN}🚀 Starting Real-time Telemetry Monitoring${NC}"
    echo "Monitor interval: ${MONITOR_INTERVAL} seconds"
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Initialize files
    > "$LOG_FILE"
    echo "timestamp,oracle_health,imisanzu_health,prometheus_health,signoz_health,http_req_rate" > "$METRICS_FILE"
    
    log "Telemetry monitoring started"
    
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        show_dashboard "$iteration"
        collect_metrics
        log "Monitoring iteration #$iteration completed"
        sleep "$MONITOR_INTERVAL"
    done
}

# Main function
main() {
    echo -e "${BLUE}📊 VNTP Telemetry Monitor${NC}"
    echo "Real-time monitoring for Vendor-Neutral Telemetry Proof system"
    echo ""
    
    if [[ "$1" == "--monitor" ]]; then
        MONITOR_INTERVAL=${2:-10}
        start_monitoring
        return 0
    elif [[ "$1" == "--health" ]]; then
        run_health_check
        return 0
    elif [[ "$1" == "--report" ]]; then
        generate_report
        return 0
    fi
    
    while true; do
        show_menu
        echo -n "Select an option (0-7): "
        read -r choice
        
        case $choice in
            1) start_monitoring ;;
            2) run_health_check ;;
            3) test_individual_services ;;
            4) generate_report ;;
            5) 
                if [[ -f "$METRICS_FILE" ]]; then
                    echo ""
                    echo -e "${BLUE}📈 Recent Metrics (last 10 entries)${NC}"
                    echo "════════════════════════════════════════"
                    head -1 "$METRICS_FILE"
                    tail -10 "$METRICS_FILE"
                    echo ""
                else
                    echo "No metrics file found."
                fi
                ;;
            6)
                if [[ -f "$LOG_FILE" ]]; then
                    echo ""
                    echo -e "${BLUE}📖 Monitor Log (last 20 entries)${NC}"
                    echo "════════════════════════════════════════"
                    tail -20 "$LOG_FILE"
                    echo ""
                else
                    echo "No log file found."
                fi
                ;;
            7)
                echo -n "Are you sure you want to clear all monitoring data? (y/N): "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    rm -f "$LOG_FILE" "$METRICS_FILE" telemetry-report-*.txt
                    echo -e "${GREEN}✅ All monitoring data cleared${NC}"
                fi
                ;;
            0)
                echo -e "${GREEN}👋 Exiting Telemetry Monitor${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-7.${NC}"
                ;;
        esac
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n👋 Monitoring stopped by user"; log "Monitoring session ended by user"; exit 0' INT

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo "❌ curl is required but not installed."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq is not installed. JSON parsing will be limited.${NC}"
fi

if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}⚠️  bc is not installed. Some calculations may not work.${NC}"
fi

# Start the main function
main "$@"