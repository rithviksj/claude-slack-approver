#!/bin/bash
# test-notification.sh - Send a test Slack notification to verify monitor is working
# This simulates what the monitor does when it detects a waiting session

set -euo pipefail

source "$HOME/.mcp/slack-credentials.env"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 TESTING SLACK NOTIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Send test message
echo "📤 Sending test message to Slack..."
RESPONSE=$(curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_GLOBAL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "@rjavgal",
    "text": "🧪 **Test Notification**\n\nThis is a test from Claude Slack Approver monitor.\n\nIf you see this, the monitor can send notifications!\n\nReply \"OK\" to confirm you received it (message will auto-delete)."
  }')

# Check if successful
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Test message sent successfully!"

    # Extract timestamp and channel for cleanup
    TS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('ts', ''))" 2>/dev/null)
    CHANNEL=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('channel', ''))" 2>/dev/null)

    echo ""
    echo "Waiting 10 seconds for you to check Slack..."
    sleep 10

    # Clean up test message
    if [[ -n "$TS" && -n "$CHANNEL" ]]; then
        echo "🧹 Cleaning up test message..."
        curl -s -X POST https://slack.com/api/chat.delete \
          -H "Authorization: Bearer $SLACK_GLOBAL_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"channel\":\"$CHANNEL\",\"ts\":\"$TS\"}" > /dev/null
        echo "✅ Test message deleted"
    fi
else
    echo "❌ Failed to send test message"
    echo ""
    echo "Response:"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Slack notifications working correctly!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
