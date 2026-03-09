#!/bin/bash
# watchdog.sh - Restart monitor if it crashes
# Run this via cron every 5 minutes: */5 * * * * /path/to/watchdog.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/logs"
WATCHDOG_LOG="$LOG_DIR/watchdog.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$WATCHDOG_LOG"
}

# Check if monitor is running
if pgrep -f "monitor.py" > /dev/null; then
    # Monitor is running - check if it's healthy (log updated in last 5 min)
    LOG_FILE="$LOG_DIR/monitor.log"
    if [ -f "$LOG_FILE" ]; then
        LAST_MODIFIED=$(stat -f %m "$LOG_FILE" 2>/dev/null || echo "0")
        NOW=$(date +%s)
        AGE=$((NOW - LAST_MODIFIED))

        if [ $AGE -gt 300 ]; then
            # Log stale - monitor might be hung
            log "WARNING: Monitor running but log stale (${AGE}s old) - restarting"
            "$SCRIPT_DIR/stop.sh" >> "$WATCHDOG_LOG" 2>&1
            sleep 2
            "$SCRIPT_DIR/start.sh" >> "$WATCHDOG_LOG" 2>&1
            log "Monitor restarted (log was stale)"
        fi
    fi
else
    # Monitor not running - restart it
    log "ERROR: Monitor not running - restarting"
    "$SCRIPT_DIR/start.sh" >> "$WATCHDOG_LOG" 2>&1
    log "Monitor restarted after crash"
fi
