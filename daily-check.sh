#!/bin/bash
# daily-check.sh - Paranoid-level daily health check
# Run this manually or via cron once per day

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/logs"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 DAILY PARANOID HEALTH CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ISSUES_FOUND=0

# Check 1: Run standard health check
echo "1️⃣  Running standard health check..."
if "$SCRIPT_DIR/health-check.sh" > /dev/null 2>&1; then
    echo "   ✅ Standard health check passed"
else
    echo "   ❌ Standard health check FAILED"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check 2: Process uptime
echo "2️⃣  Checking process uptime..."
if pgrep -f "monitor.py" > /dev/null; then
    PID=$(pgrep -f "monitor.py")
    UPTIME_SECONDS=$(ps -p $PID -o etime= | awk -F- '{if (NF==2) print ($1*86400 + $2); else print $1}' | awk -F: '{if (NF==3) print ($1*3600 + $2*60 + $3); else print ($1*60 + $2)}')
    UPTIME_HOURS=$((UPTIME_SECONDS / 3600))

    if [ $UPTIME_HOURS -gt 24 ]; then
        echo "   ✅ Uptime: ${UPTIME_HOURS}h (healthy)"
    elif [ $UPTIME_HOURS -gt 1 ]; then
        echo "   ⚠️  Uptime: ${UPTIME_HOURS}h (recently restarted?)"
    else
        echo "   ❌ Uptime: ${UPTIME_HOURS}h (crashed recently!)"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo "   ❌ Process not running!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check 3: Log file size (shouldn't grow unbounded)
echo "3️⃣  Checking log file size..."
LOG_FILE="$LOG_DIR/monitor.log"
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(du -h "$LOG_FILE" | cut -f1)
    LOG_SIZE_BYTES=$(stat -f %z "$LOG_FILE")

    if [ $LOG_SIZE_BYTES -gt 104857600 ]; then  # > 100MB
        echo "   ⚠️  Log file large: $LOG_SIZE (consider rotating)"
    else
        echo "   ✅ Log file size: $LOG_SIZE"
    fi
else
    echo "   ❌ Log file missing!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check 4: Recent crashes in logs
echo "4️⃣  Scanning for crashes in last 24 hours..."
CRASH_COUNT=$(grep -c "FATAL\|crashed" "$LOG_FILE" 2>/dev/null | tail -1000 || echo "0")
if [ $CRASH_COUNT -eq 0 ]; then
    echo "   ✅ No crashes detected"
else
    echo "   ❌ Found $CRASH_COUNT crash events!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check 5: Slack token expiration (test API)
echo "5️⃣  Testing Slack token validity..."
source "$HOME/.mcp/slack-credentials.env"
AUTH_TEST=$(curl -s -X POST https://slack.com/api/auth.test \
  -H "Authorization: Bearer $SLACK_GLOBAL_TOKEN" 2>&1)

if echo "$AUTH_TEST" | grep -q '"ok":true'; then
    echo "   ✅ Slack token valid"
else
    echo "   ❌ Slack token INVALID or expired!"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check 6: Slack notification test (optional - uncomment to enable)
# echo "6️⃣  Testing Slack notifications..."
# if "$SCRIPT_DIR/test-notification.sh" > /dev/null 2>&1; then
#     echo "   ✅ Slack notifications working"
# else
#     echo "   ❌ Slack notifications FAILED"
#     ISSUES_FOUND=$((ISSUES_FOUND + 1))
# fi
# echo ""

# Check 7: Disk space
echo "6️⃣  Checking disk space..."
DISK_USAGE=$(df -h "$HOME" | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    echo "   ⚠️  Disk usage: ${DISK_USAGE}% (running low!)"
else
    echo "   ✅ Disk usage: ${DISK_USAGE}%"
fi
echo ""

# Check 8: Watchdog cron job installed
echo "7️⃣  Checking watchdog cron job..."
if crontab -l 2>/dev/null | grep -q "watchdog.sh"; then
    echo "   ✅ Watchdog cron job installed"
else
    echo "   ⚠️  Watchdog cron job NOT installed (auto-restart disabled)"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED - System healthy!"
else
    echo "❌ FOUND $ISSUES_FOUND ISSUES - Review above"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Quick fixes:"
echo "   - Restart monitor: ./start.sh"
echo "   - View logs: tail -f $LOG_DIR/monitor.log"
echo "   - Test Slack: ./test-notification.sh"
echo ""

exit $ISSUES_FOUND
