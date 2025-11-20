#!/bin/bash

# Test script for GreytHR Automation API
# Usage: ./test-api.sh [PORT] [TOKEN]

PORT=${1:-8000}
TOKEN=${2:-${TRIGGER_TOKEN:-"andi-mandi-shandi"}}

BASE_URL="http://localhost:${PORT}"

echo "🧪 Testing GreytHR Automation API"
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if server is running
echo -e "${BLUE}🔍 Checking if server is running on port ${PORT}...${NC}"
if ! curl -s --connect-timeout 2 "${BASE_URL}/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Server is not running on port ${PORT}${NC}"
    echo -e "${YELLOW}💡 Please start the server first:${NC}"
    echo "   cd server && npm start"
    echo ""
    echo "   Or in another terminal:"
    echo "   cd server && node src/server.js"
    echo ""
    exit 1
fi
echo -e "${GREEN}✅ Server is running${NC}"
echo ""

# Test 1: Health Check
echo "1️⃣  Testing Health Endpoint..."
response=$(curl -s "${BASE_URL}/health")
if echo "$response" | grep -q "ok"; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    echo "   Response: $response"
else
    echo -e "${RED}❌ Health check failed${NC}"
    echo "   Response: $response"
fi
echo ""

# Test 2: Status Check
echo "2️⃣  Testing Status Endpoint..."
response=$(curl -s "${BASE_URL}/status")
if echo "$response" | grep -q "date"; then
    echo -e "${GREEN}✅ Status check passed${NC}"
    echo "   Response: $response" | jq '.' 2>/dev/null || echo "   Response: $response"
else
    echo -e "${RED}❌ Status check failed${NC}"
    echo "   Response: $response"
fi
echo ""

# Test 3: Config Check
echo "3️⃣  Testing Config Endpoint..."
response=$(curl -s "${BASE_URL}/config")
if echo "$response" | grep -q "schedule\|today"; then
    echo -e "${GREEN}✅ Config check passed${NC}"
    echo "   Response: $response" | jq '.' 2>/dev/null || echo "   Response: $response"
else
    echo -e "${RED}❌ Config check failed${NC}"
    echo "   Response: $response"
fi
echo ""

# Test 4: Trigger (Normal)
echo "4️⃣  Testing Trigger Endpoint (Normal Mode)..."
echo -e "${YELLOW}⚠️  This will actually run the automation!${NC}"
read -p "   Continue? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/trigger?token=${TOKEN}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] && echo "$body" | grep -q "success"; then
        echo -e "${GREEN}✅ Trigger (normal) passed${NC}"
        echo "   Response: $body" | jq '.' 2>/dev/null || echo "   Response: $body"
    else
        echo -e "${RED}❌ Trigger (normal) failed${NC}"
        echo "   HTTP Code: $http_code"
        echo "   Response: $body"
        if [ -z "$body" ]; then
            echo -e "${YELLOW}   💡 Empty response - check server logs${NC}"
        fi
    fi
else
    echo "   Skipped"
fi
echo ""

# Test 5: Trigger (Force Mode)
echo "5️⃣  Testing Trigger Endpoint (Force Mode)..."
echo -e "${YELLOW}⚠️  This will force run the automation even if already done!${NC}"
read -p "   Continue? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/trigger?token=${TOKEN}&force=true")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] && echo "$body" | grep -q "success"; then
        echo -e "${GREEN}✅ Trigger (force) passed${NC}"
        echo "   Response: $body" | jq '.' 2>/dev/null || echo "   Response: $body"
    else
        echo -e "${RED}❌ Trigger (force) failed${NC}"
        echo "   HTTP Code: $http_code"
        echo "   Response: $body"
        if [ -z "$body" ]; then
            echo -e "${YELLOW}   💡 Empty response - check server logs${NC}"
        fi
    fi
else
    echo "   Skipped"
fi
echo ""

# Test 6: POST Trigger (Force Mode)
echo "6️⃣  Testing POST Trigger Endpoint (Force Mode)..."
echo -e "${YELLOW}⚠️  This will force run the automation via POST!${NC}"
read -p "   Continue? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/trigger" \
        -H "Content-Type: application/json" \
        -d "{\"token\": \"${TOKEN}\", \"force\": true}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] && echo "$body" | grep -q "success"; then
        echo -e "${GREEN}✅ POST Trigger (force) passed${NC}"
        echo "   Response: $body" | jq '.' 2>/dev/null || echo "   Response: $body"
    else
        echo -e "${RED}❌ POST Trigger (force) failed${NC}"
        echo "   HTTP Code: $http_code"
        echo "   Response: $body"
        if [ -z "$body" ]; then
            echo -e "${YELLOW}   💡 Empty response - check server logs${NC}"
        fi
    fi
else
    echo "   Skipped"
fi
echo ""

# Test 7: Invalid Token
echo "7️⃣  Testing Invalid Token..."
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/trigger?token=invalid-token")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "403" ] || echo "$body" | grep -qi "forbidden"; then
    echo -e "${GREEN}✅ Invalid token correctly rejected${NC}"
    echo "   HTTP Code: $http_code"
    echo "   Response: $body"
else
    echo -e "${RED}❌ Security check failed${NC}"
    echo "   HTTP Code: $http_code (expected: 403)"
    echo "   Response: $body"
fi
echo ""

echo "=================================="
echo "✅ API Testing Complete!"
echo ""
echo "📝 Quick Reference:"
echo "   Health:  curl ${BASE_URL}/health"
echo "   Status:  curl ${BASE_URL}/status"
echo "   Config:  curl ${BASE_URL}/config"
echo "   Trigger: curl ${BASE_URL}/trigger?token=${TOKEN}&force=true"
echo "   POST:    curl -X POST ${BASE_URL}/trigger -H 'Content-Type: application/json' -d '{\"token\":\"${TOKEN}\",\"force\":true}'"
echo ""

