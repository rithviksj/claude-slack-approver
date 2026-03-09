# Monitoring & Guardrails

**Never let the monitor crash silently.** This guide provides paranoid-level monitoring to ensure Claude Slack Approver is always running.

---

## 🛡️ Guardrails (4 Layers)

### Layer 1: macOS LaunchAgent (Auto-Restart on Crash)

**What it does:** Automatically restarts the monitor if it crashes, runs at login.

**Setup:**
```bash
# 1. Edit the plist file
nano com.user.claude-slack-approver.plist

# Replace /path/to/claude-slack-approver with actual path
# Replace YOUR_USERNAME with your username

# 2. Install LaunchAgent
cp com.user.claude-slack-approver.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-slack-approver.plist

# 3. Verify it's running
launchctl list | grep claude-slack-approver
```

**Benefits:**
- ✅ Auto-starts on login
- ✅ Auto-restarts on crash (within 10 seconds)
- ✅ Survives system reboots
- ✅ Runs even if you're not in terminal

**Disable manually starting monitor** (LaunchAgent handles it):
```bash
# Stop manual process first
./stop.sh

# LaunchAgent will auto-start it
```

---

### Layer 2: Watchdog Cron Job (Every 5 Minutes)

**What it does:** Checks if monitor is running, restarts if not. Also detects hung processes (log not updating).

**Setup:**
```bash
# Add to crontab
crontab -e

# Add this line (replace path):
*/5 * * * * /path/to/claude-slack-approver/watchdog.sh
```

**Benefits:**
- ✅ Catches cases where LaunchAgent fails
- ✅ Detects hung processes (running but not working)
- ✅ Logs all restarts to ~/logs/watchdog.log
- ✅ Runs even if LaunchAgent is disabled

---

### Layer 3: Daily Health Check (Manual or Cron)

**What it does:** Comprehensive health report - process uptime, log analysis, Slack token validity, disk space.

**Run manually:**
```bash
./daily-check.sh
```

**Or automate** (daily at 9 AM):
```bash
crontab -e

# Add this line:
0 9 * * * /path/to/claude-slack-approver/daily-check.sh
```

**Benefits:**
- ✅ Detects issues before they cause failures
- ✅ Checks Slack token validity
- ✅ Monitors log file growth
- ✅ Scans for crashes in last 24h

---

### Layer 4: Test Notification (Weekly)

**What it does:** Sends a real Slack notification to verify end-to-end functionality.

**Run manually:**
```bash
./test-notification.sh
```

**Benefits:**
- ✅ Verifies Slack token works
- ✅ Tests message sending
- ✅ Tests message cleanup
- ✅ Catches permission issues

---

## 📊 Monitoring Scripts

### Quick Health Check
```bash
./health-check.sh
```

**Checks:**
1. ✅ Process running
2. ✅ Log file active (updated in last 5 min)
3. ✅ No recent errors
4. ✅ Slack credentials present
5. ✅ iterm-key-sender available

**Exit codes:**
- 0 = Healthy
- 1 = Unhealthy (needs restart)

---

### Test Slack Notifications
```bash
./test-notification.sh
```

**What it does:**
1. Sends test message to your Slack DM
2. Waits 10 seconds for you to verify
3. Auto-deletes the test message
4. Reports success/failure

**When to use:**
- After changing Slack token
- After updating scopes
- Weekly to verify everything works

---

### Daily Paranoid Check
```bash
./daily-check.sh
```

**Checks:**
1. ✅ Standard health check
2. ✅ Process uptime (warns if < 1 hour)
3. ✅ Log file size (warns if > 100MB)
4. ✅ Recent crashes in logs
5. ✅ Slack token validity
6. ✅ Disk space
7. ✅ Watchdog cron job installed

**Exit codes:**
- 0 = All checks passed
- >0 = Number of issues found

---

### Watchdog (Auto-Restart)
```bash
./watchdog.sh
```

**Checks:**
1. Is monitor running?
   - **No** → Restart immediately
2. Is monitor healthy? (log updated in last 5 min)
   - **No** → Kill and restart (might be hung)

**Logs to:** `~/logs/watchdog.log`

**Run via cron every 5 minutes** (see Layer 2 above)

---

## 🚨 Daily Routine (Paranoid Level)

### Option 1: Fully Automated

**Setup once:**
```bash
# 1. Install LaunchAgent
cp com.user.claude-slack-approver.plist ~/Library/LaunchAgents/
# (edit paths first!)
launchctl load ~/Library/LaunchAgents/com.user.claude-slack-approver.plist

# 2. Add watchdog cron
crontab -e
# Add: */5 * * * * /path/to/watchdog.sh

# 3. Add daily check cron
# Add: 0 9 * * * /path/to/daily-check.sh
```

**Daily action required:** None. Check Slack for daily report.

---

### Option 2: Manual Daily Check

**Every morning:**
```bash
# 1. Quick health check (5 seconds)
./health-check.sh

# 2. Full paranoid check (15 seconds)
./daily-check.sh

# 3. Test notification (optional, weekly)
./test-notification.sh
```

**What you're looking for:**
- ✅ All green checkmarks
- ✅ Uptime > 24 hours
- ✅ No crashes in logs
- ✅ Slack token valid

---

## 📈 What to Monitor

### Critical Metrics

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| **Process Running** | ✅ Yes | - | ❌ No |
| **Log Updated** | < 5 min ago | 5-10 min | > 10 min |
| **Uptime** | > 24 hours | 1-24 hours | < 1 hour |
| **Errors in Logs** | 0 | 1-5 | > 5 |
| **Slack Token** | ✅ Valid | - | ❌ Invalid |
| **Disk Space** | < 80% | 80-90% | > 90% |

---

## 🔧 Troubleshooting

### Monitor keeps crashing
```bash
# Check logs for errors
tail -50 ~/logs/monitor.log

# Common causes:
# - Slack token expired → Regenerate token
# - Python dependencies missing → pip3 install slack-sdk
# - Permissions issue → Check file ownership
```

### Watchdog not working
```bash
# Verify cron job is running
crontab -l | grep watchdog

# Check watchdog logs
tail -20 ~/logs/watchdog.log

# Test watchdog manually
./watchdog.sh
```

### LaunchAgent not starting
```bash
# Check status
launchctl list | grep claude-slack-approver

# View errors
launchctl error
tail ~/logs/monitor-error.log

# Reload
launchctl unload ~/Library/LaunchAgents/com.user.claude-slack-approver.plist
launchctl load ~/Library/LaunchAgents/com.user.claude-slack-approver.plist
```

---

## 📞 Notifications

### Get notified of issues

**Option 1: Daily summary via Slack**

Add to daily-check.sh cron:
```bash
# If daily check fails, send Slack alert
0 9 * * * /path/to/daily-check.sh || /path/to/send-alert-to-slack.sh
```

**Option 2: macOS notification**

Add to watchdog.sh:
```bash
# After restart, send macOS notification
osascript -e 'display notification "Monitor was restarted" with title "Claude Slack Approver"'
```

---

## ✅ Recommended Setup

**For paranoid-level reliability:**

1. ✅ Install LaunchAgent (auto-restart on crash)
2. ✅ Add watchdog cron every 5 minutes
3. ✅ Add daily check cron every morning
4. ✅ Run `./test-notification.sh` weekly
5. ✅ Check `~/logs/monitor.log` daily for errors

**This gives you:**
- Auto-restart within 5 minutes of crash
- Daily health reports
- Slack token validation
- Early warning of issues

---

## 📊 Logs

| Log File | Purpose | Location |
|----------|---------|----------|
| `monitor.log` | Main monitor output | `~/logs/monitor.log` |
| `monitor-error.log` | LaunchAgent errors | `~/logs/monitor-error.log` |
| `watchdog.log` | Watchdog restarts | `~/logs/watchdog.log` |

**Log rotation** (prevent unbounded growth):
```bash
# Add to weekly cron
0 0 * * 0 mv ~/logs/monitor.log ~/logs/monitor.log.old && touch ~/logs/monitor.log
```

---

## 🎯 Quick Reference

```bash
# Health check
./health-check.sh

# Test Slack notifications
./test-notification.sh

# Daily paranoid check
./daily-check.sh

# Manual restart
./stop.sh && ./start.sh

# View logs
tail -f ~/logs/monitor.log

# Check if running
pgrep -f monitor.py

# Check uptime
ps -p $(pgrep -f monitor.py) -o etime=
```
