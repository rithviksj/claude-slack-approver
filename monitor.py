#!/usr/bin/env python3
"""
Claude session monitor - only notifies about sessions ACTUALLY at Bash approval prompts
Pre-filters sessions before sending Slack notifications.
Race condition fix: re-checks sessions before sending notification.
Duplicate notification fix: checks if ANY session already being monitored.
"""
import os
import sys
import time
import subprocess
import threading
from slack_sdk import WebClient

# Force unbuffered output
sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)
sys.stderr = os.fdopen(sys.stderr.fileno(), 'w', buffering=1)

# Load Slack token
def load_slack_token():
    with open(os.path.expanduser('~/.mcp/slack-credentials.env')) as f:
        for line in f:
            if 'SLACK_GLOBAL_TOKEN=' in line:
                return line.split('=', 1)[1].strip().strip('"')
            if 'SLACK_USER_ID=' in line:
                user_id = line.split('=', 1)[1].strip().strip('"')
    return None

SLACK_TOKEN = load_slack_token()
client = WebClient(token=SLACK_TOKEN)

# Track active notifications - now maps individual PIDs to notification info
active_notifications = {}  # {pid: {'channel': ..., 'ts': ..., 'pids_tuple': ...}}
notification_lock = threading.Lock()

def get_waiting_sessions():
    """Find Claude sessions waiting for input (S+ state)"""
    result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
    waiting = []
    for line in result.stdout.split('\n'):
        if 'claude' in line and 'S+' in line and 'grep' not in line:
            parts = line.split()
            pid = parts[1]
            tty = parts[6]
            waiting.append({'pid': pid, 'tty': tty})
    return waiting

def check_bash_prompt(tty):
    """Check if TTY is actually at a Bash approval prompt"""
    script = os.path.expanduser('~/.mcp/async-approval/check-bash-prompt.sh')
    result = subprocess.run([script, tty], capture_output=True, text=True)
    is_prompt = result.returncode == 0
    if is_prompt:
        print(f"    ✓ {tty} at Bash approval prompt", flush=True)
    return is_prompt

def filter_bash_prompts(sessions):
    """Filter sessions to only those at Bash approval prompts"""
    bash_sessions = []
    for session in sessions:
        if check_bash_prompt(session['tty']):
            bash_sessions.append(session)
    return bash_sessions

def sessions_still_waiting(sessions):
    """Verify sessions are STILL in S+ state (not resolved)"""
    current = get_waiting_sessions()
    current_pids = {s['pid'] for s in current}
    return [s for s in sessions if s['pid'] in current_pids]

def get_new_sessions(sessions):
    """Filter out sessions already being monitored, return only new ones"""
    new_sessions = []
    with notification_lock:
        for session in sessions:
            if session['pid'] not in active_notifications:
                new_sessions.append(session)
    return new_sessions

def send_notification(sessions):
    """Send Slack notification"""
    count = len(sessions)
    message = f"⚠️ {count} Claude session(s) waiting for approval.\n\n"
    for s in sessions:
        message += f"• PID {s['pid']} | TTY {s['tty']}\n"
    message += "\nReply 'A' to approve all, 'Z' to deny."

    response = client.chat_postMessage(
        channel='@rjavgal',
        text=message
    )
    return response['ts'], response['channel']

def poll_for_reply_thread(channel, ts, pids_tuple, sessions):
    """Poll for user's reply in background thread"""
    timeout = 1800
    start = time.time()

    print(f"  [POLL] Thread started - channel={channel}, ts={ts}, PIDs={pids_tuple}", flush=True)

    try:
        poll_count = 0
        while (time.time() - start) < timeout:
            poll_count += 1

            # Check if sessions still waiting
            current_waiting = get_waiting_sessions()
            current_pids = {s['pid'] for s in current_waiting}

            still_waiting = [pid for pid in pids_tuple if pid in current_pids]

            if poll_count % 10 == 1:
                print(f"  [POLL #{poll_count}] {len(still_waiting)}/{len(pids_tuple)} sessions still waiting", flush=True)

            if not still_waiting:
                print(f"  → All sessions resolved in terminal - cleaning up", flush=True)
                cleanup_notification(channel, ts)

                # Remove from tracking
                with notification_lock:
                    for pid in pids_tuple:
                        if pid in active_notifications:
                            del active_notifications[pid]
                return

            # Poll for Slack reply
            oldest_ts = ts
            response = client.conversations_history(
                channel=channel,
                oldest=oldest_ts,
                limit=10
            )

            messages = response.get('messages', [])
            if poll_count % 10 == 1:
                print(f"  [POLL #{poll_count}] Found {len(messages)} messages after ts={ts}", flush=True)
                if messages:
                    for msg in messages[:2]:
                        print(f"    - Message: {msg.get('text', '')[:30]}", flush=True)

            for msg in messages:
                text = msg.get('text', '').upper().strip()
                if text in ['A', 'YES']:
                    print(f"  → User approved via Slack (msg ts={msg.get('ts')})", flush=True)

                    # Send keystrokes to all sessions (already pre-filtered)
                    for session in sessions:
                        success = send_keystroke(session['tty'], '1')
                        print(f"  → Sent to {session['tty']}: {'✅' if success else '❌'}", flush=True)

                    # Cleanup both messages
                    cleanup_notification(channel, ts)
                    cleanup_user_reply(channel, msg.get('ts'))

                    # Remove from tracking
                    with notification_lock:
                        for pid in pids_tuple:
                            if pid in active_notifications:
                                del active_notifications[pid]
                    return

                elif text in ['Z', 'NO']:
                    print(f"  → User denied via Slack (msg ts={msg.get('ts')})", flush=True)
                    cleanup_notification(channel, ts)
                    cleanup_user_reply(channel, msg.get('ts'))

                    # Remove from tracking
                    with notification_lock:
                        for pid in pids_tuple:
                            if pid in active_notifications:
                                del active_notifications[pid]
                    return

            time.sleep(2)

        # Timeout
        print(f"  → Timeout waiting for reply - cleaning up", flush=True)
        cleanup_notification(channel, ts)
        with notification_lock:
            for pid in pids_tuple:
                if pid in active_notifications:
                    del active_notifications[pid]

    except Exception as e:
        print(f"[ERROR] Polling thread crashed: {e}", flush=True)
        import traceback
        traceback.print_exc()

def send_keystroke(tty, keystroke):
    """Send keystroke using iterm-key-sender"""
    script = os.path.expanduser('~/.mcp/async-approval/send-keystroke-iks.sh')
    result = subprocess.run([script, tty, keystroke], capture_output=True, text=True)
    return result.returncode == 0

def cleanup_notification(channel, ts):
    """Delete notification message"""
    try:
        client.chat_delete(channel=channel, ts=ts)
        print(f"  → Deleted notification", flush=True)
    except Exception as e:
        print(f"  → Cleanup failed: {e}", flush=True)

def cleanup_user_reply(channel, reply_ts):
    """Delete user's reply message"""
    if not reply_ts:
        return
    try:
        client.chat_delete(channel=channel, ts=reply_ts)
        print(f"  → Deleted reply", flush=True)
    except Exception as e:
        print(f"  → Reply cleanup failed: {e}", flush=True)

def main():
    print("[Monitor V7] Debug logging enabled", flush=True)

    last_notify_time = {}
    cooldown = 10

    while True:
        try:
            # Get all waiting sessions
            all_sessions = get_waiting_sessions()

            if all_sessions:
                # PRE-FILTER: Only keep sessions at Bash approval prompts
                bash_sessions = filter_bash_prompts(all_sessions)

                if not bash_sessions:
                    # No sessions at Bash prompts - skip notification
                    time.sleep(10)
                    continue

                print(f"[{time.strftime('%H:%M:%S')}] Found {len(bash_sessions)}/{len(all_sessions)} at Bash prompts", flush=True)

                # DUPLICATE FIX: Filter out already-monitored sessions, notify only NEW ones
                new_sessions = get_new_sessions(bash_sessions)
                if not new_sessions:
                    # All sessions already being monitored - skip
                    time.sleep(10)
                    continue
                
                # Use new_sessions for notification (not bash_sessions)
                bash_sessions = new_sessions

                pids_tuple = tuple(sorted(s['pid'] for s in bash_sessions))

                # Check cooldown
                if pids_tuple in last_notify_time:
                    elapsed = time.time() - last_notify_time[pids_tuple]
                    if elapsed < cooldown:
                        time.sleep(10)
                        continue

                # RACE CONDITION FIX: Re-check sessions are STILL waiting
                still_waiting = sessions_still_waiting(bash_sessions)

                if not still_waiting:
                    print(f"  → Sessions resolved before notification sent (race avoided)", flush=True)
                    time.sleep(10)
                    continue

                if len(still_waiting) < len(bash_sessions):
                    print(f"  → {len(bash_sessions) - len(still_waiting)} session(s) resolved before notification", flush=True)
                    bash_sessions = still_waiting
                    pids_tuple = tuple(sorted(s['pid'] for s in bash_sessions))

                # Send notification ONLY for sessions still waiting
                ts, channel = send_notification(bash_sessions)
                print(f"  → Sent Slack notification (ts={ts})", flush=True)

                last_notify_time[pids_tuple] = time.time()

                # Track each PID individually
                with notification_lock:
                    for session in bash_sessions:
                        active_notifications[session['pid']] = {
                            'channel': channel,
                            'ts': ts,
                            'pids_tuple': pids_tuple
                        }

                # Start polling thread
                poll_thread = threading.Thread(
                    target=poll_for_reply_thread,
                    args=(channel, ts, pids_tuple, bash_sessions),
                    daemon=True
                )

                poll_thread.start()
                print(f"  → Polling thread started", flush=True)

        except Exception as e:
            print(f"[ERROR] Main loop failed: {e}", flush=True)
            import traceback
            traceback.print_exc()

        time.sleep(10)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"[FATAL] Monitor crashed: {e}", flush=True)
        import traceback
        traceback.print_exc()
        sys.exit(1)
