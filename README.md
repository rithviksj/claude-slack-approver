# Claude Slack Approver

**Never miss a Claude approval prompt again!** 🚀

Async approval system for Claude Code Bash prompts via Slack DMs - battle-tested on **34 concurrent iTerm2 Claude sessions**.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Python](https://img.shields.io/badge/python-3.9+-green)
![License](https://img.shields.io/badge/license-MIT-yellow)
![Battle Tested](https://img.shields.io/badge/battle--tested-34%20sessions-brightgreen)

---

## 🎯 The Problem

Claude Code sometimes waits for Bash approval prompts:

```bash
Do you want to proceed?
  1. Yes
  2. No
```

**If you're away from your laptop, these sessions freeze indefinitely.**

---

## ✨ The Solution

This monitor:
1. ✅ **Detects** Claude sessions at Bash approval prompts (not just any paused process)
2. ✅ **Notifies** you via Slack DM with session details
3. ✅ **Polls** for your reply ("A" to approve, "Z" to deny)
4. ✅ **Sends** the keystroke to the correct iTerm2 terminal
5. ✅ **Cleans up** both request and reply messages (no Slack clutter!)
6. ✅ **Handles** multiple concurrent sessions without conflicts

**All automatically. All in the background. Zero clutter.**

---

## 🏆 Battle-Tested Features

### **Smart Pre-Filtering**
- ❌ No notifications for vim, editors, or "thinking..." states
- ❌ No false positives from file listings or numbered output
- ✅ Only notifies for **actual Bash approval prompts**

### **Zero Slack Clutter**
- 🧹 Auto-deletes both request AND reply messages
- 🧹 Cleans up stale notifications if you answer in terminal directly
- 🧹 Your DMs stay pristine

### **Non-Blocking Architecture**
- 🔄 Detects new prompts while polling for replies (fully threaded)
- 🔄 Handles 34+ concurrent sessions without blocking
- 🔄 New prompts get immediate notifications even while processing others

### **Race Condition Protection**
- 🛡️ Re-checks sessions before sending notifications
- 🛡️ Prevents duplicate notifications for same prompt
- 🛡️ Handles rapid prompt sequences gracefully

### **Actual Keyboard Simulation**
- ⌨️ Uses `iterm-key-sender` for real key events (not just buffer writes)
- ⌨️ Keystrokes actually reach Bash prompts reliably
- ⌨️ Detects 2-option vs 3-option prompts automatically

---

## 📋 Requirements

### Platform
- **macOS only** (tested on macOS Sonoma 14.x+)
- iTerm2 (build 3.x+)
- Python 3.9+

### Dependencies
- `slack-sdk` (Python library for Slack API)
- `iterm-key-sender` (keyboard event simulation for iTerm2)

### Slack Workspace
- Slack workspace with **user token** (xoxp-...)
- **Required scopes** (minimum for core functionality):
  - `chat:write` - Send messages to channels/DMs
  - `im:read` - View DM channels list
  - `im:history` - Read DM message history

**Optional but recommended scopes:**
  - `users:read` - View user information
  - `channels:read` - View public channels
  - `groups:read` - View private channels

**How to get your token:**
1. Go to https://api.slack.com/apps
2. Create a new app or select existing app
3. Navigate to **OAuth & Permissions**
4. Add the scopes listed above under **User Token Scopes**
5. Install/Reinstall app to workspace
6. Copy the **User OAuth Token** (starts with `xoxp-`)

---

## 📦 Installation

### 1. Clone the repository
```bash
git clone https://github.com/rithviksj/claude-slack-approver.git
cd claude-slack-approver
```

### 2. Install Python dependencies
```bash
pip3 install slack-sdk
```

### 3. Install iterm-key-sender
```bash
git clone https://github.com/t-daisuke/iterm-key-sender.git /tmp/iterm-key-sender
chmod +x /tmp/iterm-key-sender/iks
```

### 4. Configure Slack credentials
Create `~/.mcp/slack-credentials.env`:
```bash
mkdir -p ~/.mcp
cat > ~/.mcp/slack-credentials.env << 'EOF'
SLACK_GLOBAL_TOKEN="xoxp-your-slack-token-here"
SLACK_USER_ID="YOUR_USER_ID"
EOF
```

Get your Slack token from: https://api.slack.com/apps

### 5. Make scripts executable
```bash
chmod +x *.sh *.py
```

---

## 🏃 Usage

### Start the monitor
```bash
./start.sh
```

Or manually:
```bash
nohup python3 -u monitor.py > ~/logs/monitor.log 2>&1 &
```

### Stop the monitor
```bash
./stop.sh
```

Or manually:
```bash
pkill -f monitor.py
```

### Check logs
```bash
tail -f ~/logs/monitor.log
```

### Approve prompts
When you get a Slack DM:
- Reply **"A"** or **"YES"** to approve
- Reply **"Z"** or **"NO"** to deny
- Ignore it to timeout after 30 minutes

Both messages (request + reply) are auto-deleted after handling.

---

## 🎮 How It Works

### Architecture

```
┌─────────────────┐
│  Claude Session │ (at Bash prompt)
│   PID 12345     │
└────────┬────────┘
         │ S+ state detected
         │
         ▼
┌─────────────────────────────────┐
│  Monitor (monitor.py)           │
│  - Checks ps aux every 10s      │
│  - Filters for S+ Claude procs  │
│  - Runs check-bash-prompt.sh    │
│  - Filters out already-monitored│
└────────┬────────────────────────┘
         │ Bash prompt confirmed (new session)
         │
         ▼
┌─────────────────────────────────┐
│  Slack API                      │
│  - Sends DM to user             │
│  - Polls for reply (threaded)   │
└────────┬────────────────────────┘
         │ User replies "A"
         │
         ▼
┌─────────────────────────────────┐
│  iterm-key-sender               │
│  - Finds iTerm2 pane by TTY     │
│  - Simulates "1" + Enter        │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Bash Prompt    │ → Approved! ✅
│  (continues)    │
└─────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Cleanup                        │
│  - Deletes request message      │
│  - Deletes reply message        │
│  - Clears tracking data         │
└─────────────────────────────────┘
```

### Detection Logic

**Pre-filter checks (in order):**
1. ✅ Is process in S+ state? (sleeping with terminal in foreground)
2. ✅ Is it a `claude` process? (not grep, not other tools)
3. ✅ Is the TTY at a Bash approval prompt? (runs `check-bash-prompt.sh`)
   - Must see "Do you want to proceed?" in last 10 lines
   - Must also see "1. Yes" or "> 1. Yes"
4. ✅ Is the session still waiting? (race condition check)
5. ✅ Is it already being monitored? (duplicate prevention)

Only if **ALL checks pass** → Send Slack notification

---

## 🧪 Battle-Testing

**Stress-tested with:**
- ✅ 34 concurrent iTerm2 Claude sessions
- ✅ Multiple Bash prompts appearing simultaneously
- ✅ Race conditions (user answering before notification sent)
- ✅ False positives (vim, file listings, "thinking..." states)
- ✅ Manual resolution (answering in terminal directly)
- ✅ Rapid prompt sequences (same session, multiple prompts)
- ✅ Long-running sessions (30+ minute timeouts)

**Test scenarios:**
- ✅ Single session approval
- ✅ Multi-session approval (2+ prompts at once)
- ✅ False positive filtering (no notifications for non-Bash prompts)
- ✅ Manual resolution cleanup (auto-deletes stale notifications)
- ✅ Concurrent prompt handling (non-blocking polling)
- ✅ Race condition avoidance (re-checks before sending)
- ✅ Duplicate prevention (tracks individual PIDs)
- ✅ New session detection (doesn't block new prompts on already-monitored sessions)

---

## 🔧 Configuration

### Cooldown period
Minimum time between notifications for **same session**:

```python
# In monitor.py, line ~198
cooldown = 10  # seconds
```

### Polling timeout
Maximum time waiting for Slack reply:

```python
# In monitor.py, line ~74
timeout = 1800  # seconds (30 minutes)
```

### Check interval
Time between session scans:

```python
# In monitor.py, line ~238
time.sleep(10)  # 10 seconds
```

---

## 📁 File Structure

```
claude-slack-approver/
├── monitor.py                  # Main monitor script
├── check-bash-prompt.sh        # Bash prompt detection
├── send-keystroke-iks.sh       # Keystroke relay via iterm-key-sender
├── detect-prompt-type.sh       # Prompt format detection (2 vs 3 options)
├── start.sh                    # Start monitor
├── stop.sh                     # Stop monitor
├── health-check.sh             # Quick health check
├── test-notification.sh        # Test Slack notifications
├── watchdog.sh                 # Auto-restart on crash
├── daily-check.sh              # Paranoid-level daily check
├── com.user.claude-slack-approver.plist  # LaunchAgent for auto-start
├── README.md                   # This file
├── MONITORING.md               # Monitoring & guardrails guide
├── LICENSE                     # MIT License
└── .gitignore                  # Git ignore rules
```

---

## 🛡️ Monitoring & Guardrails

**Critical:** The monitor must be running 24/7 to catch approval prompts. See [MONITORING.md](MONITORING.md) for comprehensive monitoring setup.

### Quick Daily Check
```bash
./health-check.sh
```

### Guardrails (4 Layers)
1. **LaunchAgent** - Auto-restart on crash, runs at login
2. **Watchdog Cron** - Checks every 5 minutes, restarts if down
3. **Daily Health Check** - Comprehensive system report
4. **Test Notification** - Weekly Slack verification

### Paranoid-Level Setup
```bash
# 1. Install LaunchAgent (edit paths first)
cp com.user.claude-slack-approver.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-slack-approver.plist

# 2. Add watchdog cron (every 5 minutes)
crontab -e
# Add: */5 * * * * /path/to/watchdog.sh

# 3. Add daily check (every morning at 9 AM)
# Add: 0 9 * * * /path/to/daily-check.sh
```

**See [MONITORING.md](MONITORING.md) for full documentation.**

---

## 🐛 Troubleshooting

### Monitor not detecting prompts
```bash
# Check if monitor is running
ps aux | grep monitor.py

# Check logs for errors
tail -50 ~/logs/monitor.log

# Verify Slack credentials
source ~/.mcp/slack-credentials.env
echo $SLACK_GLOBAL_TOKEN
```

### Keystrokes not reaching terminal
```bash
# Test iterm-key-sender directly
/tmp/iterm-key-sender/iks -t 1 "test"

# Verify pane number detection works
osascript -e 'tell application "iTerm" to get tty of current session of current tab of current window'
```

### Slack notifications not sending
```bash
# Verify token authentication
source ~/.mcp/slack-credentials.env
curl -X POST https://slack.com/api/auth.test \
  -H "Authorization: Bearer $SLACK_GLOBAL_TOKEN" | python3 -m json.tool

# Test sending a message
curl -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_GLOBAL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"channel":"@your-username","text":"Test"}'
```

**Common issues:**
- **Wrong token type**: Must be a **user token** (xoxp-...), not a bot token (xoxb-...)
- **Missing scopes**: Verify you have `chat:write`, `im:read`, and `im:history` scopes
- **Token expired**: Regenerate token from https://api.slack.com/apps

### Finding 0 messages when polling
- Check `oldest` parameter in `conversations.history` API call
- Monitor logs show: `[POLL #X] Found 0 messages after ts=...`
- **Fixed in v1.0.0** - removed `+ 0.001` offset that was excluding replies

---

## 🙏 Credits

Built with:
- [slack-sdk](https://github.com/slackapi/python-slack-sdk) by Slack
- [iterm-key-sender](https://github.com/t-daisuke/iterm-key-sender) by @t-daisuke

Inspired by the need to approve Claude Bash prompts while away from laptop during long-running automation tasks.

**Battle-tested through:**
- 5+ hours of debugging
- 8+ iterations
- 10+ bug fixes
- 34 concurrent Claude sessions
- Infinite patience and **NEVER GIVING UP** 💪

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repo
2. Create a feature branch
3. Test thoroughly (especially edge cases and race conditions)
4. Submit a PR with clear description

**Testing checklist:**
- [ ] Single session approval works
- [ ] Multiple concurrent sessions work
- [ ] False positive filtering works (no notifications for vim/editors)
- [ ] Manual resolution cleanup works (auto-deletes stale notifications)
- [ ] New sessions detected even while others are being monitored
- [ ] Race conditions handled (user answers before notification sent)

---

## ⚠️ Limitations

- **macOS only** - Uses iTerm2 AppleScript integration
- **iTerm2 required** - Won't work with Terminal.app or other terminal emulators
- **Slack workspace required** - Needs valid bot token with proper scopes
- **Single user** - Designed for personal use, not multi-user environments
- **Tested up to 34 concurrent sessions** - May have performance issues beyond this

---

## 📝 Changelog

### v1.0.0 (2026-03-08)
- ✅ Initial release
- ✅ Non-blocking threaded polling
- ✅ Pre-filtered Bash prompt detection
- ✅ Race condition protection
- ✅ Duplicate notification prevention
- ✅ Auto-cleanup for stale notifications
- ✅ Clean Slack DMs (deletes both request and reply)
- ✅ Support for up to 34 concurrent Claude sessions
- ✅ Fixed `oldest` parameter bug (was excluding replies with `+ 0.001` offset)
- ✅ Fixed cooldown blocking new prompts on same session (reduced to 10s)
- ✅ Fixed duplicate logic blocking new sessions when others monitored
- ✅ Fixed false positives from file listings (stricter prompt detection)

---

**Never miss a Claude approval again!** ⚡
