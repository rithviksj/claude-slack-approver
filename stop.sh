#!/bin/bash
# stop.sh - Stop Claude Slack Approver monitor

set -euo pipefail

if pgrep -f "monitor.py" > /dev/null; then
    echo "🛑 Stopping monitor..."
    pkill -f "monitor.py"
    sleep 1

    if pgrep -f "monitor.py" > /dev/null; then
        echo "⚠️  Monitor still running, forcing kill..."
        pkill -9 -f "monitor.py"
    fi

    echo "✅ Monitor stopped"
else
    echo "ℹ️  Monitor not running"
fi
