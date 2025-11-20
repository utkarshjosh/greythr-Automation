#!/bin/bash

# View the latest forensic recording logs

LOGS_DIR="./logs"

echo "📂 Available Logs:"
echo ""

# Find all forensic recording files
FORENSIC_FILES=$(find "$LOGS_DIR" -name "forensic-recording-*.json" 2>/dev/null | sort -r)

if [ -z "$FORENSIC_FILES" ]; then
    echo "❌ No recording files found."
    echo "💡 Run: npm run record"
    exit 1
fi

echo "Forensic Recordings:"
echo "$FORENSIC_FILES" | nl -w2 -s'. '
echo ""

# Find all summary files
SUMMARY_FILES=$(find "$LOGS_DIR" -name "summary-*.txt" 2>/dev/null | sort -r)

if [ -n "$SUMMARY_FILES" ]; then
    echo "Summaries:"
    echo "$SUMMARY_FILES" | nl -w2 -s'. '
    echo ""
fi

# Show latest summary
LATEST_SUMMARY=$(echo "$SUMMARY_FILES" | head -1)
if [ -n "$LATEST_SUMMARY" ]; then
    echo "📄 Latest Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$LATEST_SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "Commands:"
echo "  View full recording: cat logs/forensic-recording-*.json | jq ."
echo "  Analyze data: npm run analyze"
echo "  Run automation: npm run automate"


