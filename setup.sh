#!/bin/bash

echo "🚀 Setting up GreytHR Automation Tool..."
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed!"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo ""
    echo "📝 Creating .env file..."
    cat > .env << EOF
# GreytHR Login Credentials
EMP_ID=your_employee_id
PASSWORD=your_password
EOF
    echo "✅ .env file created"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file and add your credentials:"
    echo "   EMP_ID=your_employee_id"
    echo "   PASSWORD=your_password"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📖 Next steps:"
echo "   1. Edit .env file with your credentials"
echo "   2. Run: npm run record"
echo "   3. Manually login and perform swipe-in in the browser"
echo "   4. Press Ctrl+C when done"
echo "   5. Run: npm run analyze"
echo "   6. Run: npm run automate"
echo ""


