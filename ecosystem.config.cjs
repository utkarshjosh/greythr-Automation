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
      env: {
        NODE_ENV: "production",
      },
      
      // ============================================
      // ENVIRONMENT VARIABLES - IMPORTANT!
      // ============================================
      // Environment variables are loaded from .env file via dotenv in server.js
      // Make sure .env file exists and contains all required variables:
      //   - PORT (optional, defaults to 8000)
      //   - TRIGGER_TOKEN (required for API authentication)
      //   - EMP_ID (required for GreytHR login)
      //   - PASSWORD (required for GreytHR login)
      //   - GREYTHR_URL (required for GreytHR base URL)
      //   - HEADLESS (optional, for Puppeteer)
      //
      // Note: PM2 doesn't support env_file property. Use dotenv in code instead.
      // To load .env file, ensure dotenv.config() is called at the start of server.js
      
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
      min_uptime: 10000,
      
      // Number of consecutive unstable restarts before stopping
      max_restarts: 10,
      
      // Restart delay (in milliseconds)
      restart_delay: 4000,
      
      // Kill timeout (in milliseconds) - time to wait before force killing
      kill_timeout: 5000,
      
      // Wait for graceful shutdown
      wait_ready: true,
      
      // Listen for ready event
      listen_timeout: 10000,
      
      // Shutdown with message
      shutdown_with_message: true,
    },
  ],
};
