#!/bin/bash
# health-check.sh - Quick health check for Claude Slack Approver monitor
# Exit code: 0 = healthy, 1 = unhealthy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/logs"
LOG_FILE="$LOG_DIR/monitor.log"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏥 CLAUDE SLACK APPROVER HEALTH CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

HEALTHY=true

# Check 1: Is process running?
if pgrep -f "monitor.py" > /dev/null; then
    PID=$(pgrep -f "monitor.py")
    echo "✅ Process running (PID: $PID)"
else
    echo "❌ Process NOT running"
    HEALTHY=false
fi

# Check 2: Is log file growing? (updated in last 5 minutes)
if [ -f "$LOG_FILE" ]; then
    LAST_MODIFIED=$(stat -f %m "$LOG_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    AGE=$((NOW - LAST_MODIFIED))

    if [ $AGE -lt 300 ]; then
        echo "✅ Log file active (updated ${AGE}s ago)"
    else
        echo "⚠️  Log file stale (updated ${AGE}s ago)"
        HEALTHY=false
    fi
else
    echo "❌ Log file missing: $LOG_FILE"
    HEALTHY=false
fi

# Check 3: Are there recent errors in logs?
if [ -f "$LOG_FILE" ]; then
    ERROR_COUNT=$(tail -100 "$LOG_FILE" | grep -c "ERROR\|FATAL" || echo "0")
    if [ $ERROR_COUNT -eq 0 ]; then
        echo "✅ No recent errors in logs"
    else
        echo "⚠️  Found $ERROR_COUNT errors in last 100 lines"
        tail -5 "$LOG_FILE" | grep "ERROR\|FATAL" || true
    fi
fi

# Check 4: Slack credentials present?
if [ -f "$HOME/.mcp/slack-credentials.env" ]; then
    echo "✅ Slack credentials found"
else
    echo "❌ Slack credentials missing"
    HEALTHY=false
fi

# Check 5: iterm-key-sender available?
if [ -x "/tmp/iterm-key-sender/iks" ]; then
    echo "✅ iterm-key-sender available"
else
    echo "⚠️  iterm-key-sender not found (keystrokes won't work)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$HEALTHY" = true ]; then
    echo "✅ OVERALL STATUS: HEALTHY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "❌ OVERALL STATUS: UNHEALTHY"
    echo ""
    echo "💡 Fix: ./start.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
