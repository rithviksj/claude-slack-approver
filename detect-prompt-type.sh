#!/bin/bash
# detect-prompt-type.sh - Detect prompt format and return correct keystroke
# Usage: detect-prompt-type.sh <tty>
# Output: "1" for simple Yes/No, "2" for Yes/Always/No prompts

set -euo pipefail

TTY="$1"

# Get terminal output
TERMINAL_OUTPUT=$(osascript <<EOF
tell application "iTerm"
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                if ((tty of s) ends with "$TTY") then
                    return text of s
                end if
            end repeat
        end repeat
    end repeat
end tell
return ""
EOF
)

# Check prompt format
if echo "$TERMINAL_OUTPUT" | grep -qE "> 1\. Yes|1\. Yes"; then
    # Has "1. Yes" option

    # Check if it also has "2. Always" or "2. Yes (always)"
    if echo "$TERMINAL_OUTPUT" | grep -qE "2\. (Always|Yes \(always\))"; then
        # Three-option prompt: 1. Yes, 2. Always, 3. No
        echo "2"  # Send 2 for "Always Yes"
    else
        # Two-option prompt: 1. Yes, 2. No
        echo "1"  # Send 1 for "Yes"
    fi
else
    # Unknown format, default to 1
    echo "1"
fi
