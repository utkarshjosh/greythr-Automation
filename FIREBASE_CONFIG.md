# Firebase Configuration Guide

This document describes all Firebase Firestore collections and documents used by the GreytHR Automation system.

## 📦 Collections Overview

The system uses two main collections:
- `config` - Configuration settings
- `daily_logs` - Daily automation logs and status

---

## 🔧 Config Collection

### Document: `config/schedule`

Controls the automation schedule using cron expressions.

**Fields:**
```javascript
{
  cron: "0 9 * * *",                    // Cron expression (default: 9:00 AM daily)
  description: "Daily automation at 9:00 AM",
  enabled: true,                         // Enable/disable scheduled automation
  createdAt: "2025-11-24T10:00:00.000Z",
  updatedAt: "2025-11-24T10:00:00.000Z"
}
```

**Example Cron Expressions:**
- `0 9 * * *` - Daily at 9:00 AM
- `0 9 * * 1-5` - Weekdays at 9:00 AM
- `30 8,17 * * 1-5` - Weekdays at 8:30 AM and 5:30 PM

**Update via Firebase Console or API:**
```bash
# Update schedule via API (if implemented)
# Or manually in Firebase Console: Firestore > config > schedule
```

---

### Document: `config/general`

General automation settings.

**Fields:**
```javascript
{
  headless: true,                        // Run browser in headless mode
  timeout: 60000,                        // Timeout in milliseconds
  retryAttempts: 3,                      // Number of retry attempts on failure
  notifications: {
    enabled: true,                       // Enable notifications
    onSuccess: true,                     // Notify on success
    onFailure: true                      // Notify on failure
  },
  createdAt: "2025-11-24T10:00:00.000Z",
  updatedAt: "2025-11-24T10:00:00.000Z"
}
```

---

### Document: `config/location`

GPS/Location spoofing configuration for attendance marking.

**Fields:**
```javascript
{
  latitude: 28.5355,                     // Latitude coordinate
  longitude: 77.391,                     // Longitude coordinate
  accuracy: 100,                         // GPS accuracy in meters
  enabled: true,                         // Enable location spoofing
  description: "Default location: Delhi, India (28.5355° N, 77.3910° E)",
  createdAt: "2025-11-24T10:00:00.000Z",
  updatedAt: "2025-11-24T10:00:00.000Z"
}
```

**How to Update:**
1. Go to Firebase Console → Firestore Database
2. Navigate to: `config` → `location`
3. Edit the fields:
   - `latitude`: Your office latitude
   - `longitude`: Your office longitude
   - `accuracy`: GPS accuracy (100 meters is typical)
   - `enabled`: Set to `false` to disable location spoofing

**Finding Coordinates:**
1. Open Google Maps
2. Right-click on your office location
3. Click the coordinates to copy them
4. First number is latitude, second is longitude

---

### Document: `config/work_location` ⭐ NEW

Work location preference for sign-in (Office or Work From Home).

**Fields:**
```javascript
{
  workLocation: "Office",                // Options: "Office" or "Work From Home"
  remarks: "",                           // Optional remarks for sign-in (max 50 chars)
  description: "Work location for sign-in (Office or Work From Home)",
  createdAt: "2025-11-24T10:00:00.000Z",
  updatedAt: "2025-11-24T10:00:00.000Z"
}
```

**Valid Values for `workLocation`:**
- `"Office"` - Sign in from office
- `"Work From Home"` - Sign in from home (WFH)

**How to Update:**
1. Go to Firebase Console → Firestore Database
2. Navigate to: `config` → `work_location`
3. Edit the `workLocation` field:
   - Set to `"Office"` for office work
   - Set to `"Work From Home"` for remote work
4. Optionally add `remarks` if your organization requires it

**Example: Work From Home Setup:**
```javascript
{
  workLocation: "Work From Home",
  remarks: "Remote work approved",
  description: "Work location for sign-in (Office or Work From Home)",
  createdAt: "2025-11-24T10:00:00.000Z",
  updatedAt: "2025-11-24T10:00:00.000Z"
}
```

**When This is Used:**
When you click the "Sign In" button on GreytHR, a modal may appear asking for your work location. The automation will:
1. Detect the modal automatically
2. Select the location from the dropdown based on this config
3. Fill in remarks if provided
4. Click the "Sign In" button in the modal

---

## 📊 Daily Logs Collection

### Document: `daily_logs/{YYYY-MM-DD}`

Tracks daily automation status and results.

**Fields:**
```javascript
{
  status: "DONE",                        // Status: DONE, FAILED, SKIP, PENDING
  timestamp: "2025-11-24T09:00:15.000Z", // Last update time
  empId: "EMP12345",                     // Employee ID
  swipeTime: "09:00:15",                 // Time of successful swipe (HH:MM:SS)
  failureReason: null                    // Error message if status is FAILED
}
```

**Status Values:**
- `DONE` - Swipe completed successfully
- `FAILED` - Automation failed (check `failureReason`)
- `SKIP` - Day was skipped (holiday, leave, etc.)
- `PENDING` - Before initial date or not yet attempted

**Example Documents:**

**Success:**
```javascript
{
  status: "DONE",
  timestamp: "2025-11-24T09:00:15.000Z",
  empId: "EMP12345",
  swipeTime: "09:00:15"
}
```

**Failure:**
```javascript
{
  status: "FAILED",
  timestamp: "2025-11-24T09:00:30.000Z",
  empId: "EMP12345",
  failureReason: "Sign In button not found or not accessible"
}
```

---

## 🚀 Quick Setup Guide

### 1. Enable Firestore

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database**
4. Click **Create database**
5. Choose **Production mode**
6. Select a location close to you
7. Click **Enable**

### 2. Set Up Service Account

1. In Firebase Console, go to **Project Settings** (⚙️ icon)
2. Go to **Service accounts** tab
3. Click **Generate new private key**
4. Save the JSON file as `serviceAccountKey.json` in your project root

### 3. Start the Server

The server will automatically create default configurations on first start:

```bash
npm start
```

Expected output:
```
🌱 Checking for default config...
📝 Creating default schedule config...
✅ Default schedule config created: Daily automation at 9:00 AM
📝 Creating default general config...
✅ Default general config created
📝 Creating default location config...
✅ Default location config created: Default location: Delhi, India (28.5355° N, 77.3910° E)
📝 Creating default work location config...
✅ Default work location config created: Office
🌱 Database seeding complete
```

### 4. Customize Configurations

After the server starts, go to Firebase Console → Firestore Database and update:
- `config/location` - Your office coordinates
- `config/work_location` - Your work location preference
- `config/schedule` - Your preferred automation time

---

## 🔍 Monitoring

### View Logs in Firebase Console

1. Go to Firestore Database
2. Navigate to `daily_logs` collection
3. Each document is named by date (YYYY-MM-DD)
4. Check `status` field:
   - ✅ `DONE` - Success
   - ❌ `FAILED` - Failed (check `failureReason`)
   - ⏭️ `SKIP` - Skipped
   - ⏸️ `PENDING` - Not yet attempted

### Example Query (Firebase Console)

**Find all failures this month:**
```
Collection: daily_logs
Filter: status == FAILED
Order by: timestamp desc
```

**Check today's status:**
```
Document ID: 2025-11-24
```

---

## 🔐 Security Rules

Recommended Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Config collection - read/write via service account only
    match /config/{document=**} {
      allow read, write: if false; // Service account bypasses this
    }
    
    // Daily logs - read/write via service account only
    match /daily_logs/{document=**} {
      allow read, write: if false; // Service account bypasses this
    }
  }
}
```

**Note:** Service accounts bypass security rules, so your automation will work regardless of these rules.

---

## 🆘 Troubleshooting

### Config not being created?

**Error:** `Permission denied` or `NOT_FOUND`

**Solution:**
1. Check that Firestore is enabled in Firebase Console
2. Verify `serviceAccountKey.json` is valid
3. Ensure service account has Firestore permissions

### Work location not being detected?

**Check:**
1. Verify `config/work_location` exists in Firestore
2. Ensure `workLocation` field is exactly `"Office"` or `"Work From Home"` (case-sensitive)
3. Check automation logs for modal detection messages

### Want to switch between Office and WFH daily?

You can manually update the `workLocation` field in Firebase Console before the scheduled automation runs, or create an API endpoint to update it programmatically.

---

## 📝 Notes

- All timestamps are in ISO 8601 format (UTC)
- Document IDs for `daily_logs` are in `YYYY-MM-DD` format
- The system automatically prevents duplicate swipes on the same day (unless force mode is used)
- Configuration changes take effect on the next automation run

---

## 🔗 Related Documentation

- [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) - REST API reference
- [SCHEDULING.md](./SCHEDULING.md) - Cron scheduling guide
- [README.md](./README.md) - Main documentation


