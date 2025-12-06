# Environment Variables Setup

This app uses environment variables stored in a `.env` file for API configuration.

## Setup Instructions

1. **Create a `.env` file** in the `mobile_app/` directory:

```bash
cd mobile_app
touch .env
```

2. **Add the following content to `.env`**:

```env
# API Configuration
API_BASE_URL=https://utkarshjoshi.com/.hidden-api

# API Key for authentication (http_x_api_key header)
HTTP_X_API_KEY=your_actual_api_key_here

# Trigger Token for automation endpoints (x-trigger-token header)
X_TRIGGER_TOKEN=your_actual_trigger_token_here
```

3. **Replace the placeholder values** with your actual API credentials:

   - `HTTP_X_API_KEY`: Your API key for authentication
   - `X_TRIGGER_TOKEN`: Your trigger token for automation endpoints

4. **Important**: The `.env` file is already in `.gitignore` and should NOT be committed to version control.

## Example `.env` file

```env
API_BASE_URL=https://utkarshjoshi.com/.hidden-api
HTTP_X_API_KEY=abc123xyz789
X_TRIGGER_TOKEN=my_secure_trigger_token_here
```

## Verification

After setting up the `.env` file, run:

```bash
flutter pub get
flutter run
```

The app will automatically load these environment variables on startup.


