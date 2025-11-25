# GreytHR Automation

A headless automation system for GreytHR portal attendance marking with REST API support and Firebase integration.

## 🚀 Features

- **Automated Attendance**: Automated login and swipe-in/out for GreytHR portal
- **REST API**: Trigger automation on-demand via HTTP endpoints
- **Scheduled Automation**: Daily cron job support with configurable schedules
- **Firebase Integration**: Status tracking and configuration via Firestore
- **Work Location Support**: Configure Office or Work From Home sign-in via Firebase
- **Force Mode**: Bypass "already done" checks for testing and manual overrides
- **Smart Detection**: Automatically detects if swipe was already completed
- **Modal Handling**: Automatically handles sign-in location modals
- **Headless Mode**: Run automation in headless mode for server environments
- **Shadow DOM Support**: Handles modern web components with shadow DOM

## 📋 Prerequisites

- Node.js (v16 or higher)
- npm
- Firebase project with Firestore enabled
- GreytHR portal credentials

## 🔧 Installation

1. **Clone the repository**
   ```bash
   git clone git@github.com-personal:utkarshjosh/greythr-Automation.git
   cd greythr-Automation
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

4. **Setup Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Firestore Database
   - Download service account key and save as `serviceAccountKey.json` in the root directory

5. **Configure credentials**
   Edit `.env` file:
   ```bash
   EMP_ID=your_employee_id
   PASSWORD=your_password
   GREYTHR_URL=https://your-company.greythr.com/
   TRIGGER_TOKEN=your-secure-token
   PORT=8000
   HEADLESS=true  # Optional: defaults to headless in production
   ```

   **Note:** When `NODE_ENV=production`, the automation automatically runs in headless mode unless `HEADLESS=false` is explicitly set.

## 🚀 Usage

### Start the Server

```bash
npm start
```

The server will:
- Start on port 8000 (or PORT from .env)
- Seed default configuration in Firebase
- Schedule daily automation based on config

### Run Automation Manually

```bash
npm run automate
```

### API Endpoints

See [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) for complete API documentation.

**Quick Examples:**

```bash
# Check status
curl http://localhost:8000/status

# Trigger automation (normal)
curl "http://localhost:8000/trigger?token=YOUR_TOKEN"

# Trigger automation (force mode)
curl "http://localhost:8000/trigger?token=YOUR_TOKEN&force=true"

# Health check
curl http://localhost:8000/health
```

## 📚 Documentation

- [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) - Complete API reference
- [QUICK_START.md](./QUICK_START.md) - Quick start guide
- [SCHEDULING.md](./SCHEDULING.md) - Cron scheduling guide
- [FIREBASE_CONFIG.md](./FIREBASE_CONFIG.md) - Firebase configuration guide

## 🧪 Testing

Run the API test suite:

```bash
./test-api.sh
```

Make sure the server is running before executing tests.

## 🔒 Security

- Never commit `.env` or `serviceAccountKey.json` to git
- Use strong `TRIGGER_TOKEN` values
- Use HTTPS in production
- Consider IP whitelisting for production deployments

## 📁 Project Structure

```
greythr-Automation/
├── src/                    # Source code
│   ├── server.js          # Express API server
│   ├── automate-login.js  # Automation logic
│   ├── firebase-config.js  # Firebase setup
│   └── ...
├── logs/                   # Automation logs
├── screenshots/            # Screenshots (if headless=false)
├── README.md              # This file
├── API_DOCUMENTATION.md   # API docs
├── package.json           # Dependencies
└── .env                   # Environment variables (not in git)
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

ISC

## 🔗 Links

- [Firebase Console](https://console.firebase.google.com/)
- [GreytHR Portal](https://www.greythr.com/)

## ⚠️ Disclaimer

This automation tool is for personal use only. Ensure compliance with your organization's policies regarding automated access to company systems.
