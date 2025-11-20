# GreytHR Automation API Documentation

## Base URL
```
http://localhost:8000
```
(Or your configured PORT)

## Authentication
All trigger endpoints require a token. Set `TRIGGER_TOKEN` in your `.env` file or pass it as a parameter.

---

## Endpoints

### 1. Health Check
**GET** `/health`

Check if the API server is running.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-11-20T12:30:00.000Z"
}
```

**Example:**
```bash
curl http://localhost:8000/health
```

---

### 2. Get Status
**GET** `/status`

Get today's swipe status from Firebase.

**Response:**
```json
{
  "date": "2025-11-20",
  "data": {
    "status": "DONE",
    "timestamp": "2025-11-20T09:00:00.000Z",
    "swipeTime": "09:15:30",
    "empId": "EMP123"
  },
  "alreadySwiped": true,
  "status": "DONE"
}
```

**Example:**
```bash
curl http://localhost:8000/status
```

---

### 3. Get Config
**GET** `/config`

Get schedule configuration and today's config.

**Response:**
```json
{
  "schedule": "0 9 * * *",
  "today": {
    "status": "DONE",
    "timestamp": "2025-11-20T09:00:00.000Z"
  }
}
```

**Example:**
```bash
curl http://localhost:8000/config
```

---

### 4. Trigger Automation (GET)
**GET** `/trigger?token=YOUR_TOKEN&force=true`

Trigger the automation manually.

**Query Parameters:**
- `token` (required): Your trigger token
- `force` (optional): Set to `true` to bypass "already done" check

**Response:**
```json
{
  "success": true,
  "message": "Swipe-in completed successfully.",
  "alreadyDone": false,
  "status": "DONE",
  "forced": false,
  "timestamp": "2025-11-20T12:30:00.000Z"
}
```

**Examples:**

Normal trigger (respects "already done"):
```bash
curl "http://localhost:8000/trigger?token=YOUR_TOKEN"
```

Force trigger (bypasses "already done"):
```bash
curl "http://localhost:8000/trigger?token=YOUR_TOKEN&force=true"
```

Using header for token:
```bash
curl -H "x-trigger-token: YOUR_TOKEN" \
     -H "x-force: true" \
     "http://localhost:8000/trigger"
```

---

### 5. Trigger Automation (POST)
**POST** `/trigger`

Trigger the automation via POST request.

**Headers:**
- `Content-Type: application/json`
- `x-trigger-token` (optional): Token via header
- `x-force` (optional): Force mode via header

**Body:**
```json
{
  "token": "YOUR_TOKEN",
  "force": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Automation forced to run (bypassed DONE status).",
  "alreadyDone": false,
  "status": "DONE",
  "forced": true,
  "timestamp": "2025-11-20T12:30:00.000Z"
}
```

**Examples:**

Normal POST:
```bash
curl -X POST http://localhost:8000/trigger \
  -H "Content-Type: application/json" \
  -d '{"token": "YOUR_TOKEN"}'
```

Force POST:
```bash
curl -X POST http://localhost:8000/trigger \
  -H "Content-Type: application/json" \
  -d '{"token": "YOUR_TOKEN", "force": true}'
```

Using headers:
```bash
curl -X POST http://localhost:8000/trigger \
  -H "Content-Type: application/json" \
  -H "x-trigger-token: YOUR_TOKEN" \
  -H "x-force: true" \
  -d '{}'
```

---

## Force Mode

Force mode allows you to run the automation even if:
- Status is already `DONE` for today
- The automation has already completed

**When to use:**
- Testing the automation
- Re-running after manual changes
- Debugging issues
- Manual override scenarios

**How it works:**
1. Bypasses the Firebase status check in `checkStatus()`
2. Still verifies swipe status via modal (if already swiped, it will detect and exit)
3. Can perform a new swipe if needed

---

### 6. Seed Database
**POST** `/seed?token=YOUR_TOKEN`

Manually trigger database seeding to create default config if missing.

**Query Parameters:**
- `token` (required): Your trigger token

**Response:**
```json
{
  "success": true,
  "message": "Database seeding completed",
  "timestamp": "2025-11-20T12:30:00.000Z"
}
```

**Example:**
```bash
curl -X POST "http://localhost:8000/seed?token=YOUR_TOKEN"
```

**Note:** This endpoint automatically runs when the server starts, but you can manually trigger it if needed.

---

## Error Responses

### 403 Forbidden
```json
{
  "error": "Forbidden",
  "message": "Invalid or missing token"
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Error message here",
  "timestamp": "2025-11-20T12:30:00.000Z"
}
```

---

## Testing

Use the provided test script:

```bash
# Make sure server is running first
npm start

# In another terminal, run tests
./test-api.sh

# Or with custom port/token
./test-api.sh 8000 YOUR_TOKEN
```

---

## Environment Variables

Add to your `.env` file:

```bash
# API Configuration
PORT=8000
TRIGGER_TOKEN=your-secure-token-here

# Automation runs in headless mode when called via API
HEADLESS=true
```

---

## Security Notes

⚠️ **Important:**
- Never expose your `TRIGGER_TOKEN` publicly
- Use HTTPS in production
- Consider adding IP whitelisting for production
- Rotate tokens periodically
- Monitor API access logs

---

## Integration Examples

### Python
```python
import requests

url = "http://localhost:8000/trigger"
params = {
    "token": "YOUR_TOKEN",
    "force": "true"
}
response = requests.get(url, params=params)
print(response.json())
```

### JavaScript/Node.js
```javascript
const fetch = require('node-fetch');

const url = 'http://localhost:8000/trigger?token=YOUR_TOKEN&force=true';
fetch(url)
  .then(res => res.json())
  .then(data => console.log(data));
```

### cURL (one-liner)
```bash
curl -s "http://localhost:8000/trigger?token=YOUR_TOKEN&force=true" | jq
```

---

## Status Values

- `PENDING`: No automation run yet today
- `DONE`: Swipe completed successfully
- `SKIP`: Marked to skip today
- `ERROR`: Automation failed
- `UNKNOWN`: Status unclear

