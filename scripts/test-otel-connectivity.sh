#!/bin/bash

echo "🔍 Testing OTEL Collector connectivity..."
echo "=================================="

# Test if port 4318 is open
echo "1. Testing port 4318 connectivity:"
if curl -s --connect-timeout 3 http://localhost:4318/v1/traces > /dev/null 2>&1; then
    echo "   ✅ Port 4318 is accessible"
else
    echo "   ❌ Port 4318 is NOT accessible"
fi

# Test if SigNoz OTEL Collector is running
echo ""
echo "2. Checking for SigNoz OTEL Collector container:"
if docker ps | grep -q "signoz-otel-collector"; then
    echo "   ✅ SigNoz OTEL Collector container is running"
else
    echo "   ❌ SigNoz OTEL Collector container is NOT running"
fi

# Test service connectivity
echo ""
echo "3. Testing service endpoints:"
if curl -s http://localhost:3001/api/v1/health > /dev/null 2>&1; then
    echo "   ✅ Imisanzu service is accessible"
else
    echo "   ❌ Imisanzu service is NOT accessible"
fi

if curl -s http://localhost:3002/api/v1/health > /dev/null 2>&1; then
    echo "   ✅ Oracle service is accessible"
else
    echo "   ❌ Oracle service is NOT accessible"
fi

echo ""
echo "4. Checking service logs for OTEL errors:"
echo "   Oracle service logs (last 10 lines):"
docker logs vntp-oracle-service-1 --tail=10 2>/dev/null | grep -E "(OTEL|error|Error|fail|Fail)" || echo "   No OTEL errors found in recent logs"

echo ""
echo "   Imisanzu service logs (last 10 lines):"
docker logs vntp-imisanzu-service-1 --tail=10 2>/dev/null | grep -E "(OTEL|error|Error|fail|Fail)" || echo "   No OTEL errors found in recent logs"

echo ""
echo "=================================="
echo "Test completed."
