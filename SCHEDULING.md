# Scheduling Automation

This guide shows you how to schedule the GreytHR automation to run automatically.

## Using Cron (Linux/Mac)

### 1. Make the script executable

```bash
chmod +x schedule-automation.sh
```

### 2. Edit crontab

```bash
crontab -e
```

### 3. Add schedule entry

**Run every weekday at 9:00 AM:**

```bash
0 9 * * 1-5 cd /greytAuto && /usr/bin/node src/automate-login.js >> logs/cron.log 2>&1
```

**Run every weekday at 9:00 AM and 6:00 PM:**

```bash
0 9,18 * * 1-5 cd /greytAuto && /usr/bin/node src/automate-login.js >> logs/cron.log 2>&1
```

**Run Monday to Friday at 9:15 AM:**

```bash
15 9 * * 1-5 cd /greytAuto && /usr/bin/node src/automate-login.js >> logs/cron.log 2>&1
```

### Cron Schedule Format

```
* * * * * command
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, 0 and 7 are Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

### Common Examples

- `0 9 * * *` - Every day at 9:00 AM
- `30 8 * * 1-5` - Weekdays at 8:30 AM
- `0 9,18 * * *` - Every day at 9:00 AM and 6:00 PM
- `*/30 * * * *` - Every 30 minutes
- `0 9-17 * * 1-5` - Weekdays, every hour from 9 AM to 5 PM

## Using systemd Timer (Linux)

### 1. Create service file

Create `/etc/systemd/system/greythr-automation.service`:

```ini
[Unit]
Description=GreytHR Attendance Automation
After=network.target

[Service]
Type=oneshot
User=user
WorkingDirectory=/greytAuto
ExecStart=/usr/bin/node /greytAuto/src/automate-login.js
StandardOutput=append:/greytAuto/logs/systemd.log
StandardError=append:/greytAuto/logs/systemd.log

[Install]
WantedBy=multi-user.target
```

### 2. Create timer file

Create `/etc/systemd/system/greythr-automation.timer`:

```ini
[Unit]
Description=GreytHR Automation Timer
Requires=greythr-automation.service

[Timer]
OnCalendar=Mon-Fri 09:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

### 3. Enable and start

```bash
sudo systemctl daemon-reload
sudo systemctl enable greythr-automation.timer
sudo systemctl start greythr-automation.timer
```

### 4. Check status

```bash
# Check timer status
sudo systemctl status greythr-automation.timer

# View logs
journalctl -u greythr-automation.service

# List all timers
systemctl list-timers
```

## Wrapper Script with Notifications

Create `schedule-automation.sh`:

```bash
#!/bin/bash

# Path to your project
PROJECT_DIR="/greytAuto"
LOG_FILE="$PROJECT_DIR/logs/automation-$(date +%Y%m%d).log"

cd "$PROJECT_DIR"

echo "==================================" >> "$LOG_FILE"
echo "Starting automation at $(date)" >> "$LOG_FILE"
echo "==================================" >> "$LOG_FILE"

# Run automation
node src/automate-login.js >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Automation successful at $(date)" >> "$LOG_FILE"

    # Optional: Send success notification
    # notify-send "GreytHR" "Attendance marked successfully"

else
    echo "❌ Automation failed at $(date) with code $EXIT_CODE" >> "$LOG_FILE"

    # Optional: Send failure notification
    # notify-send -u critical "GreytHR" "Automation failed!"
fi

echo "" >> "$LOG_FILE"
```

Make it executable:

```bash
chmod +x schedule-automation.sh
```

Then use this script in cron:

```bash
0 9 * * 1-5 /greytAuto/schedule-automation.sh
```

## Email Notifications

### Using mail command

Install mail utility:

```bash
sudo apt-get install mailutils  # Ubuntu/Debian
sudo yum install mailx          # CentOS/RHEL
```

Modify the wrapper script:

```bash
#!/bin/bash

PROJECT_DIR="/greytAuto"
EMAIL="your-email@example.com"
LOG_FILE="$PROJECT_DIR/logs/automation-$(date +%Y%m%d).log"

cd "$PROJECT_DIR"
node src/automate-login.js >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "Automation successful at $(date)" | mail -s "GreytHR: Success" "$EMAIL"
else
    echo "Automation failed at $(date). Check logs." | mail -s "GreytHR: FAILED" "$EMAIL"
fi
```

## Slack Notifications

Add to your automation script:

```javascript
async sendSlackNotification(success, message) {
  const webhookUrl = process.env.SLACK_WEBHOOK_URL;
  if (!webhookUrl) return;

  const payload = {
    text: success ? '✅ GreytHR Automation Success' : '❌ GreytHR Automation Failed',
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: message
        }
      }
    ]
  };

  try {
    await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
  } catch (e) {
    console.error('Slack notification failed:', e.message);
  }
}
```

Add to `.env`:

```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Desktop Notifications (Linux)

Install libnotify:

```bash
sudo apt-get install libnotify-bin
```

Add to wrapper script:

```bash
if [ $EXIT_CODE -eq 0 ]; then
    notify-send "GreytHR" "Attendance marked successfully" --icon=dialog-information
else
    notify-send "GreytHR" "Automation failed!" --urgency=critical --icon=dialog-error
fi
```

## Monitoring

### Check if automation is running

```bash
# View recent cron logs
grep CRON /var/log/syslog | tail -20

# View automation logs
tail -f logs/cron.log

# Check screenshots
ls -lht screenshots/ | head -10
```

### Create a status checker

Create `check-status.sh`:

```bash
#!/bin/bash

LOGS_DIR="./logs"
TODAY=$(date +%Y%m%d)
LATEST_LOG=$(find "$LOGS_DIR" -name "automation-$TODAY*.log" -o -name "cron.log" | xargs ls -t 2>/dev/null | head -1)

if [ -n "$LATEST_LOG" ]; then
    echo "📄 Latest Log: $LATEST_LOG"
    echo ""
    tail -20 "$LATEST_LOG"
else
    echo "❌ No logs found for today"
fi

echo ""
echo "📸 Recent Screenshots:"
ls -lht screenshots/ | head -5
```

## Troubleshooting Scheduled Jobs

### Cron not running?

1. **Check cron service:**

   ```bash
   sudo systemctl status cron
   ```

2. **Check cron logs:**

   ```bash
   grep CRON /var/log/syslog
   ```

3. **Test command manually:**
   ```bash
   cd /greytAuto && node src/automate-login.js
   ```

### Environment issues in cron

Cron has a minimal environment. Add to crontab:

```bash
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NODE_PATH=/usr/local/lib/node_modules

0 9 * * 1-5 cd /greytAuto && node src/automate-login.js >> logs/cron.log 2>&1
```

### Display issues (headless)

If running in headless mode, set:

```bash
export DISPLAY=:0
export XAUTHORITY=/home/user/.Xauthority
```

Add to crontab:

```bash
0 9 * * 1-5 export DISPLAY=:0 && cd /greytAuto && node src/automate-login.js >> logs/cron.log 2>&1
```

## Best Practices

1. **Test First:** Always test manually before scheduling
2. **Log Everything:** Keep detailed logs with timestamps
3. **Set Notifications:** Get alerted on failures
4. **Monitor Regularly:** Check logs weekly
5. **Handle Failures:** Have a backup manual process
6. **Update Credentials:** Keep .env file secure and updated
7. **Re-record Periodically:** If website changes, re-record the flow

## Security Considerations

⚠️ **Important:**

- Restrict log file permissions: `chmod 600 logs/*.log`
- Secure .env file: `chmod 600 .env`
- Don't log sensitive data
- Rotate logs regularly
- Use system keychain for credentials (advanced)

## Example: Complete Setup

```bash
# 1. Setup
cd /greytAuto
./setup.sh

# 2. Record flow
npm run record
# (Complete login and swipe-in manually)

# 3. Test automation
npm run automate

# 4. Create wrapper script
cat > schedule-automation.sh << 'EOF'
#!/bin/bash
cd /greytAuto
node src/automate-login.js >> logs/cron-$(date +%Y%m%d).log 2>&1
EOF

chmod +x schedule-automation.sh

# 5. Schedule with cron
crontab -e
# Add: 0 9 * * 1-5 /greytAuto/schedule-automation.sh

# 6. Monitor
tail -f logs/cron-*.log
```
