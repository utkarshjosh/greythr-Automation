# Quick Start Guide

## Overview

This tool helps you:

1. **Record** all API calls during login and swipe-in
2. **Analyze** the recorded data to understand the flow
3. **Automate** the entire process

## Step-by-Step Guide

### 1️⃣ Setup (First Time Only)

```bash
# Run the setup script
./setup.sh

# OR manually:
npm install
cp .env.example .env
# Edit .env with your credentials
```

Edit `.env` file:

```
EMP_ID=your_employee_id
PASSWORD=your_password
```

### 2️⃣ Record the Login Flow

```bash
npm run record
```

**What happens:**

- A Chrome browser window opens
- You see the GreytHR login page
- **YOU** need to:
  1. Enter your credentials manually
  2. Complete the login
  3. Navigate to attendance/swipe-in
  4. Perform the swipe-in action
  5. Press `Ctrl+C` when done

**What's being recorded:**

- ✅ All HTTP/HTTPS requests
- ✅ Request headers and payloads
- ✅ Response data
- ✅ Cookies and tokens
- ✅ JWKS keys
- ✅ V3 API calls
- ✅ Authentication flow
- ✅ Attendance/swipe APIs

**Output:**

- `logs/forensic-recording-[timestamp].json` - Full detailed log
- `logs/summary-[timestamp].txt` - Human-readable summary
- `screenshots/` - Screenshots at key moments

### 3️⃣ Analyze the Recording

```bash
npm run analyze
```

**What you'll see:**

- 🔐 Authentication flow breakdown
- 🔑 JWKS and token analysis
- 🌐 V3 API endpoints used
- ⏰ Attendance/swipe-in flow
- 🎫 Tokens and authorization headers
- 🍪 Cookies
- 🤖 Automation plan

**Output:**

- `logs/automation-config.json` - Configuration for automation

### 4️⃣ Run the Automation

```bash
npm run automate
```

**What happens:**

- Browser opens automatically
- Navigates to GreytHR portal
- Fills in credentials from `.env`
- Submits login form
- Attempts to find and click swipe-in button
- Takes screenshots
- Closes after completion

**Note:** If the swipe-in button can't be found automatically, you'll have 30 seconds to click it manually.

## Folder Structure

```
greytAuto/
├── src/
│   ├── forensic-recorder.js   # Records all network activity
│   ├── analyze-logs.js         # Analyzes recorded data
│   ├── automate-login.js       # Automated login + swipe-in
│   └── helpers.js              # Utility functions
├── logs/                       # All recordings and analysis
├── screenshots/                # Screenshots taken during process
├── .env                        # Your credentials (DON'T COMMIT!)
├── package.json               # Dependencies
├── README.md                  # Full documentation
└── QUICK_START.md            # This file

```

## Troubleshooting

### Recording Issues

**Problem:** Browser closes immediately

- **Solution:** Check if Puppeteer is installed: `npm install`

**Problem:** Can't see what's being recorded

- **Solution:** Check the terminal output - all API calls are logged in real-time

**Problem:** Recording file is empty

- **Solution:** Make sure you complete the login and swipe-in before pressing Ctrl+C

### Analysis Issues

**Problem:** "No recording files found"

- **Solution:** Run `npm run record` first

**Problem:** No authentication endpoints detected

- **Solution:** Make sure you completed the login during recording

**Problem:** No attendance endpoints detected

- **Solution:** Make sure you performed swipe-in during recording

### Automation Issues

**Problem:** "Automation config not found"

- **Solution:** Run `npm run record` and then `npm run analyze`

**Problem:** "Missing credentials"

- **Solution:** Edit `.env` file with your EMP_ID and PASSWORD

**Problem:** Login fails during automation

- **Solution:**
  1. Verify credentials in `.env`
  2. Re-record the login flow (website might have changed)
  3. Check screenshots in `screenshots/` folder to see where it failed

**Problem:** Swipe-in button not found

- **Solution:** The script will wait 30 seconds for manual action

## Security Notes

⚠️ **IMPORTANT:**

- Never commit `.env` file to git
- Keep your `logs/` folder private (contains tokens and session data)
- This tool is for personal automation only
- Respect your organization's automation policies

## Advanced Usage

### Headless Mode

Edit `src/automate-login.js` and change:

```javascript
headless: false; // Change to true
```

### Custom Wait Times

Edit the `wait()` calls in `automate-login.js`:

```javascript
await this.wait(5000); // Adjust milliseconds as needed
```

### Debug Mode

Check the screenshots in `screenshots/` folder to see exactly what the browser sees at each step.

### Re-recording

If the website structure changes, just run `npm run record` again and the new data will be used for automation.

## Tips

1. **First Run:** Always do a manual recording first to understand the flow
2. **Test Automation:** Run automation during work hours to verify it works
3. **Check Logs:** Always review the forensic recording to understand what's happening
4. **Screenshots:** Use screenshots to debug when automation fails
5. **Keep Updated:** Re-record periodically if the website changes

## Support

If you encounter issues:

1. Check the terminal output for error messages
2. Review screenshots in `screenshots/` folder
3. Check the full recording in `logs/` folder
4. Verify your credentials in `.env`
5. Try re-recording the flow

## What's Next?

After successful automation, you can:

- Schedule the script to run daily (using cron)
- Add notifications (email/slack) on success/failure
- Extend it to handle other GreytHR tasks
- Customize the selectors for your specific portal version



