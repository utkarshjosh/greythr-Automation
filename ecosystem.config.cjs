/**
 * PM2 Ecosystem Configuration File
 * 
 * This file configures PM2 to run the GreytHR Automation server in production mode.
 * 
 * Usage:
 *   - Start: pm2 start ecosystem.config.cjs
 *   - Stop: pm2 stop ecosystem.config.cjs
 *   - Restart: pm2 restart ecosystem.config.cjs
 *   - Delete: pm2 delete ecosystem.config.cjs
 *   - View logs: pm2 logs greythr-automation
 *   - Monitor: pm2 monit
 * 
 * Note: This file uses .cjs extension because the project uses ES modules ("type": "module")
 * in package.json. PM2 ecosystem files need to be CommonJS format.
 */

const fs = require("fs");
const path = require("path");

/**
 * Load environment variables from .env file
 * This ensures PM2 has access to all required environment variables
 */
function loadEnvFile() {
  const envPath = path.join(__dirname, ".env");
  const env = {
    NODE_ENV: "production",
  };

  // Try to load .env file if it exists
  if (fs.existsSync(envPath)) {
    const envFile = fs.readFileSync(envPath, "utf8");
    const lines = envFile.split("\n");

    for (const line of lines) {
      // Skip empty lines and comments
      const trimmedLine = line.trim();
      if (!trimmedLine || trimmedLine.startsWith("#")) {
        continue;
      }

      // Parse KEY=VALUE format
      const equalIndex = trimmedLine.indexOf("=");
      if (equalIndex > 0) {
        const key = trimmedLine.substring(0, equalIndex).trim();
        let value = trimmedLine.substring(equalIndex + 1).trim();

        // Remove quotes if present
        if (
          (value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))
        ) {
          value = value.slice(1, -1);
        }

        // Skip empty values (they might be placeholders)
        if (value && value !== "your_value_here") {
          env[key] = value;
        }
      }
    }
  } else {
    console.warn(
      "⚠️  Warning: .env file not found at",
      envPath,
      "- Make sure .env file exists with all required variables"
    );
  }

  return env;
}

module.exports = {
  apps: [
    {
      // Application name
      name: "greythr-automation",
      
      // Script to run (server entry point)
      script: "src/server.js",
      
      // Node.js interpreter
      interpreter: "node",
      
      // Production mode - explicitly set NODE_ENV to production
      // Environment variables are loaded from .env file
      env: loadEnvFile(),
      
      // ============================================
      // ENVIRONMENT VARIABLES - IMPORTANT!
      // ============================================
      // Environment variables are automatically loaded from .env file above
      // Make sure .env file exists and contains all required variables:
      //   - PORT (optional, defaults to 8000)
      //   - TRIGGER_TOKEN (required for API authentication)
      //   - EMP_ID (required for GreytHR login)
      //   - PASSWORD (required for GreytHR login)
      //   - GREYTHR_URL (required for GreytHR base URL)
      //   - HEADLESS (optional, for Puppeteer)
      //
      // The loadEnvFile() function reads the .env file and loads all variables
      // into PM2's environment, ensuring they are available to the application.
      
      // Number of instances to run (use "max" for all CPU cores, or specify a number)
      instances: 1,
      
      // Execution mode: "cluster" for load balancing or "fork" for single instance
      exec_mode: "fork",
      
      // Auto restart on crash
      autorestart: true,
      
      // Watch for file changes (set to false in production)
      watch: false,
      
      // Maximum memory before restart (optional, in MB)
      max_memory_restart: "500M",
      
      // Log file paths
      error_file: "./logs/pm2-error.log",
      out_file: "./logs/pm2-out.log",
      log_file: "./logs/pm2-combined.log",
      
      // Log date format
      time: true,
      
      // Merge logs from all instances
      merge_logs: true,
      
      // Log rotation
      log_date_format: "YYYY-MM-DD HH:mm:ss Z",
      
      // Minimum uptime to consider app stable (in milliseconds)
      // Reduced for small app - faster startup detection
      min_uptime: 2000,
      
      // Number of consecutive unstable restarts before stopping
      max_restarts: 10,
      
      // Restart delay (in milliseconds)
      // Reduced for small app - faster restarts
      restart_delay: 1000,
      
      // Kill timeout (in milliseconds) - time to wait before force killing
      // Reduced for small app - faster shutdown
      kill_timeout: 2000,
      
      // Wait for graceful shutdown
      wait_ready: true,
      
      // Listen for ready event
      // Reduced for small app - faster startup
      listen_timeout: 3000,
      
      // Shutdown with message
      shutdown_with_message: true,
    },
  ],
};
