#!/bin/bash
# start.sh - Start Claude Slack Approver monitor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/logs"

# Create log directory
mkdir -p "$LOG_DIR"

# Check if already running
if pgrep -f "monitor.py" > /dev/null; then
    echo "⚠️  Monitor already running"
    echo "   PID: $(pgrep -f monitor.py)"
    echo "   Use './stop.sh' to stop it first"
    exit 1
fi

# Check dependencies
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found"
    exit 1
fi

if [ ! -f "$HOME/.mcp/slack-credentials.env" ]; then
    echo "❌ Slack credentials not found"
    echo "   Create ~/.mcp/slack-credentials.env with:"
    echo "   SLACK_GLOBAL_TOKEN=\"your-token\""
    echo "   SLACK_USER_ID=\"your-user-id\""
    exit 1
fi

if [ ! -x "/tmp/iterm-key-sender/iks" ]; then
    echo "⚠️  iterm-key-sender not found at /tmp/iterm-key-sender/iks"
    echo "   Clone it from: https://github.com/t-daisuke/iterm-key-sender"
fi

# Start monitor
cd "$SCRIPT_DIR"
nohup python3 -u monitor.py > "$LOG_DIR/monitor.log" 2>&1 &

PID=$!
sleep 1

# Verify it started
if ps -p $PID > /dev/null; then
    echo "✅ Monitor started successfully"
    echo "   PID: $PID"
    echo "   Logs: $LOG_DIR/monitor.log"
    echo ""
    echo "📊 View logs:"
    echo "   tail -f $LOG_DIR/monitor.log"
    echo ""
    echo "🛑 Stop monitor:"
    echo "   ./stop.sh"
else
    echo "❌ Monitor failed to start"
    echo "   Check logs: $LOG_DIR/monitor.log"
    exit 1
fi
