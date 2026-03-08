#!/bin/bash
# check-bash-prompt.sh - Check if a TTY is at a Bash confirmation prompt
# Usage: check-bash-prompt.sh <tty>
# Exit code: 0 if at prompt, 1 if not

set -euo pipefail

TTY="$1"

# Get last 15 lines of terminal output using AppleScript
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

# Get last 10 lines only (more focused check)
LAST_LINES=$(echo "$TERMINAL_OUTPUT" | tail -10)

# STRICT PATTERNS: Only match actual Bash approval prompts
# Must have "Do you want to proceed?" followed by numbered options

if echo "$LAST_LINES" | grep -q "Do you want to proceed"; then
    # Verify it has Yes/No options
    if echo "$LAST_LINES" | grep -qE "(1\. Yes|> 1\. Yes)"; then
        exit 0  # At Bash approval prompt
    fi
fi

# Alternative pattern: numbered choice with explicit Yes/No/Always keywords
if echo "$LAST_LINES" | grep -qE "> 1\. Yes" && echo "$LAST_LINES" | grep -qE "2\. (No|Always)"; then
    exit 0  # At numbered Yes/No choice
fi

# Must have BOTH the question AND the numbered options in last 10 lines
exit 1  # Not at Bash approval prompt
