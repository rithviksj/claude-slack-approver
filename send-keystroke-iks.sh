#!/bin/bash
# send-keystroke-iks.sh - Send keystroke using iterm-key-sender
# Usage: send-keystroke-iks.sh <tty> <keystroke>

set -euo pipefail

TTY="$1"
KEYSTROKE="$2"

# Find pane number for this TTY using AppleScript
PANE_NUM=$(osascript <<EOF
tell application "iTerm"
    set paneCounter to 1
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                set sessionTTY to tty of s
                if sessionTTY ends with "$TTY" or sessionTTY ends with "/dev/tty$TTY" then
                    return paneCounter
                end if
                set paneCounter to paneCounter + 1
            end repeat
        end repeat
    end repeat
end tell
return "NOT_FOUND"
EOF
)

if [[ "$PANE_NUM" == "NOT_FOUND" ]]; then
    echo "ERROR: No pane found for TTY $TTY" >&2
    exit 1
fi

echo "Found pane $PANE_NUM for TTY $TTY" >&2

# Send keystroke using iks
/tmp/iterm-key-sender/iks -t "$PANE_NUM" "$KEYSTROKE"
sleep 0.1
/tmp/iterm-key-sender/iks -t "$PANE_NUM" Enter

echo "SUCCESS: Sent '$KEYSTROKE' + Enter to pane $PANE_NUM (TTY $TTY)" >&2
exit 0
