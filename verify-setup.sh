#!/bin/bash

echo "🔍 Verifying GreytHR Automation Setup..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Node.js
if command -v node &> /dev/null; then
    echo -e "${GREEN}✓${NC} Node.js installed: $(node --version)"
else
    echo -e "${RED}✗${NC} Node.js not found"
    exit 1
fi

# Check npm
if command -v npm &> /dev/null; then
    echo -e "${GREEN}✓${NC} npm installed: $(npm --version)"
else
    echo -e "${RED}✗${NC} npm not found"
    exit 1
fi

# Check node_modules
if [ -d "node_modules" ]; then
    echo -e "${GREEN}✓${NC} Dependencies installed"
else
    echo -e "${RED}✗${NC} Dependencies not installed"
    echo "  Run: npm install"
    exit 1
fi

# Check puppeteer
if [ -d "node_modules/puppeteer" ]; then
    echo -e "${GREEN}✓${NC} Puppeteer installed"
else
    echo -e "${RED}✗${NC} Puppeteer not found"
    echo "  Run: npm install"
    exit 1
fi

# Check .env file
if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
    
    # Check if credentials are set
    if grep -q "your_employee_id" .env || grep -q "your_password" .env; then
        echo -e "${YELLOW}⚠${NC} .env contains default values"
        echo "  Please edit .env with your actual credentials"
    else
        echo -e "${GREEN}✓${NC} Credentials configured"
    fi
else
    echo -e "${RED}✗${NC} .env file not found"
    echo "  Run: cp .env.example .env"
    exit 1
fi

# Check directories
if [ -d "logs" ]; then
    echo -e "${GREEN}✓${NC} logs/ directory exists"
else
    echo -e "${YELLOW}⚠${NC} logs/ directory not found (will be created on first run)"
fi

if [ -d "screenshots" ]; then
    echo -e "${GREEN}✓${NC} screenshots/ directory exists"
else
    echo -e "${YELLOW}⚠${NC} screenshots/ directory not found (will be created on first run)"
fi

# Check source files
echo ""
echo "📂 Source Files:"
for file in src/forensic-recorder.js src/analyze-logs.js src/automate-login.js src/helpers.js; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file missing"
    fi
done

# Check scripts in package.json
echo ""
echo "📜 Available Commands:"
if grep -q '"record"' package.json; then
    echo -e "  ${GREEN}✓${NC} npm run record"
else
    echo -e "  ${RED}✗${NC} npm run record"
fi

if grep -q '"analyze"' package.json; then
    echo -e "  ${GREEN}✓${NC} npm run analyze"
else
    echo -e "  ${RED}✗${NC} npm run analyze"
fi

if grep -q '"automate"' package.json; then
    echo -e "  ${GREEN}✓${NC} npm run automate"
else
    echo -e "  ${RED}✗${NC} npm run automate"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Summary
if [ -f ".env" ] && [ -d "node_modules" ] && [ -f "src/forensic-recorder.js" ]; then
    echo -e "${GREEN}✅ Setup is complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Edit .env with your credentials (if not done)"
    echo "  2. Run: npm run record"
    echo "  3. Login and swipe-in manually in the browser"
    echo "  4. Press Ctrl+C when done"
    echo "  5. Run: npm run analyze"
    echo "  6. Run: npm run automate"
    echo ""
    echo "Documentation:"
    echo "  - QUICK_START.md - Beginner guide"
    echo "  - README.md - Full documentation"
    echo "  - SCHEDULING.md - Setup automation"
    echo "  - PROJECT_OVERVIEW.md - System overview"
else
    echo -e "${RED}❌ Setup incomplete${NC}"
    echo ""
    echo "Please run: ./setup.sh"
fi

echo ""


