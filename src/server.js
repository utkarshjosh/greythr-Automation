// src/server.js
// Load environment variables FIRST before any other imports
import dotenv from "dotenv";
dotenv.config();

import express from "express";
import cron from "node-cron";
import cors from "cors";
import { initFirebase } from "./firebase-config.js";
import { runAutomation } from "./run-automation.js";
import { sendNotification } from "./notify.js";

// Validate required environment variables
function validateEnv() {
  const required = ["TRIGGER_TOKEN", "EMP_ID", "PASSWORD", "GREYTHR_URL"];
  const missing = required.filter((key) => !process.env[key]);
  
  if (missing.length > 0) {
    console.error("❌ Missing required environment variables:");
    missing.forEach((key) => console.error(`   - ${key}`));
    console.error("\n💡 Make sure .env file exists and contains all required variables.");
    console.error("   See .env.example for reference.\n");
    process.exit(1);
  }
  
  console.log("✅ All required environment variables are present");
}

// Validate environment before starting server
validateEnv();

const app = express();
const PORT = process.env.PORT || 8000;

// Initial date - logs before this date should be marked as PENDING
const INITIAL_DATE = "2025-11-20"; // November 20, 2025

// Helper function to check if a date string (YYYY-MM-DD) is before the initial date
function isBeforeInitialDate(dateString) {
  return dateString < INITIAL_DATE;
}

// Enable CORS for all origins with explicit configuration
// app.use(
//   cors({
//     origin: "*",
//     methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
//     allowedHeaders: [
//       "Content-Type",
//       "Authorization",
//       "X-Trigger-Token",
//       "X-Force",
//     ],
//     credentials: false,
//   })
// );

// Handle preflight requests explicitly
app.options("*", cors());

// Middleware for JSON body parsing
app.use(express.json());

// Initialize Firebase once
const db = initFirebase();

// Helper to fetch today's config (e.g., skip flag, status)
async function fetchTodayConfig() {
  const today = new Date().toISOString().split("T")[0];

  // Check if date is before initial date
  if (isBeforeInitialDate(today)) {
    return {
      status: "PENDING",
      message:
        "Data not available - date is before initial day (November 20, 2025)",
      date: today,
    };
  }

  const doc = await db.collection("daily_logs").doc(today).get();
  if (doc.exists) {
    const data = doc.data();
    // If the stored data is PENDING and before initial date, return it
    if (
      data.status === "PENDING" &&
      data.message &&
      data.message.includes("before initial day")
    ) {
      return data;
    }
    return data;
  }
  return {};
}

// Seed function to create default config if database is empty
async function seedDefaultConfig() {
  try {
    console.log("🌱 Checking for default config...");

    // Check if schedule config exists
    const scheduleDoc = await db.collection("config").doc("schedule").get();

    if (!scheduleDoc.exists) {
      console.log("📝 Creating default schedule config...");
      const defaultSchedule = {
        cron: "0 9 * * *", // 9:00 AM daily
        description: "Daily automation at 9:00 AM",
        enabled: true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      await db.collection("config").doc("schedule").set(defaultSchedule);
      console.log(
        "✅ Default schedule config created:",
        defaultSchedule.description
      );
    } else {
      console.log("✅ Schedule config already exists");
    }

    // Check if general config exists
    const generalDoc = await db.collection("config").doc("general").get();

    if (!generalDoc.exists) {
      console.log("📝 Creating default general config...");
      const defaultGeneral = {
        headless: true,
        timeout: 60000,
        retryAttempts: 3,
        notifications: {
          enabled: true,
          onSuccess: true,
          onFailure: true,
        },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      await db.collection("config").doc("general").set(defaultGeneral);
      console.log("✅ Default general config created");
    } else {
      console.log("✅ General config already exists");
    }

    // Check if location/GPS config exists
    const locationDoc = await db.collection("config").doc("location").get();

    if (!locationDoc.exists) {
      console.log("📝 Creating default location config...");
      const defaultLocation = {
        latitude: 28.5355,
        longitude: 77.391,
        accuracy: 100, // meters
        enabled: true,
        description: "Default location: Delhi, India (28.5355° N, 77.3910° E)",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      await db.collection("config").doc("location").set(defaultLocation);
      console.log(
        "✅ Default location config created:",
        defaultLocation.description
      );
    } else {
      console.log("✅ Location config already exists");
    }

    // Check if work_location config exists
    const workLocationDoc = await db.collection("config").doc("work_location").get();

    if (!workLocationDoc.exists) {
      console.log("📝 Creating default work location config...");
      const defaultWorkLocation = {
        workLocation: "Office", // Options: "Office" or "Work From Home"
        remarks: "", // Optional remarks for sign-in
        description: "Work location for sign-in (Office or Work From Home)",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      await db.collection("config").doc("work_location").set(defaultWorkLocation);
      console.log(
        "✅ Default work location config created:",
        `${defaultWorkLocation.workLocation}`
      );
    } else {
      console.log("✅ Work location config already exists");
    }

    console.log("🌱 Database seeding complete\n");
  } catch (e) {
    console.error("❌ Error seeding default config:", e.message);
    // Don't throw - allow server to start even if seeding fails
  }
}

// Helper to fetch schedule cron expression from config collection
async function fetchScheduleCron() {
  try {
    const cfgDoc = await db.collection("config").doc("schedule").get();
    if (cfgDoc.exists) {
      const data = cfgDoc.data();
      if (data && data.cron) return data.cron;
    }
  } catch (e) {
    console.warn("⚠️ Could not fetch schedule config:", e.message);
  }
  // Default to 09:00 daily
  return "0 9 * * *";
}

// Helper to fetch GPS/location config from config collection
async function fetchLocationConfig() {
  try {
    const locationDoc = await db.collection("config").doc("location").get();
    if (locationDoc.exists) {
      const data = locationDoc.data();
      if (data && data.enabled !== false) {
        return {
          latitude: data.latitude || 28.5355,
          longitude: data.longitude || 77.391,
          accuracy: data.accuracy || 100,
          enabled: true,
        };
      }
    }
  } catch (e) {
    console.warn("⚠️ Could not fetch location config:", e.message);
  }
  // Default to Delhi, India coordinates
  return {
    latitude: 28.5355,
    longitude: 77.391,
    accuracy: 100,
    enabled: true,
  };
}

// Main task executed by cron or manual trigger
// Returns: { success: boolean, message: string, alreadyDone: boolean, status: string }
async function dailyTask(force = false) {
  try {
    const config = await fetchTodayConfig();

    // Skip check only if not in force mode
    if (!force && config.status === "SKIP") {
      console.log("⏭️  Today is marked as SKIP. No swipe performed.");
      await sendNotification(
        "GreytHR Automation",
        "Today is skipped as per config."
      );
      return {
        success: true,
        message: "Skipped as per config",
        alreadyDone: false,
        status: "SKIP",
      };
    }

    // Check if already done before running automation
    const alreadyDone = config.status === "DONE";

    // If already done and not forced, return early without running automation
    if (alreadyDone && !force) {
      const message = "Swipe was already completed today. No action needed.";
      console.log(`✅ ${message}`);
      await sendNotification("GreytHR Automation", message);
      return {
        success: true,
        message,
        alreadyDone: true,
        status: config.status || "DONE",
      };
    }

    if (force && alreadyDone) {
      console.log(
        "⚡ Force mode: Running automation even though status is DONE"
      );
    }

    // Run the existing automation (force parameter bypasses internal DONE check)
    await runAutomation(force);

    // Check status after automation
    const afterConfig = await fetchTodayConfig();
    const finalStatus = afterConfig.status || "UNKNOWN";

    const message =
      force && alreadyDone
        ? "Automation forced to run (bypassed DONE status)."
        : "Swipe-in completed successfully.";
    console.log(`✅ ${message}`);
    await sendNotification("GreytHR Automation", message);
    return {
      success: true,
      message,
      alreadyDone: false,
      status: finalStatus,
      forced: force,
    };
  } catch (e) {
    console.error("❌ Daily task failed:", e);
    await sendNotification(
      "GreytHR Automation",
      `Automation failed: ${e.message}`
    );
    return {
      success: false,
      message: `Automation failed: ${e.message}`,
      alreadyDone: false,
      status: "ERROR",
    };
  }
}

// Health endpoint
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Config endpoint (provides schedule, location, and today config)
app.get("/config", async (req, res) => {
  try {
    const cfgDoc = await db.collection("config").doc("schedule").get();
    const schedule = cfgDoc.exists ? cfgDoc.data().cron : null;
    const locationConfig = await fetchLocationConfig();
    const todayConfig = await fetchTodayConfig();
    res.json({ schedule, location: locationConfig, today: todayConfig });
  } catch (e) {
    console.warn("⚠️ Config fetch error:", e.message);
    res.status(500).json({ error: e.message });
  }
});

// Seed endpoint - manually trigger database seeding (protected by token)
app.post("/seed", async (req, res) => {
  const token =
    req.body?.token ||
    req.headers["x-trigger-token"] ||
    req.query.token ||
    process.env.TRIGGER_TOKEN;
  if (!token || token !== process.env.TRIGGER_TOKEN) {
    return res
      .status(403)
      .json({ error: "Forbidden", message: "Invalid or missing token" });
  }

  try {
    await seedDefaultConfig();
    res.json({
      success: true,
      message: "Database seeding completed",
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    res.status(500).json({
      success: false,
      error: e.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Status endpoint (today's swipe status)
app.get("/status", async (req, res) => {
  try {
    const today = new Date().toISOString().split("T")[0];

    // Check if date is before initial date
    if (isBeforeInitialDate(today)) {
      return res.json({
        date: today,
        data: {
          status: "PENDING",
          message:
            "Data not available - date is before initial day (November 20, 2025)",
        },
        alreadySwiped: false,
        status: "PENDING",
      });
    }

    const doc = await db.collection("daily_logs").doc(today).get();
    if (doc.exists) {
      const data = doc.data();
      res.json({
        date: today,
        data: data,
        alreadySwiped: data.status === "DONE",
        status: data.status || "PENDING",
      });
    } else {
      res.json({
        date: today,
        data: null,
        alreadySwiped: false,
        status: "PENDING",
      });
    }
  } catch (e) {
    console.warn("⚠️ Status fetch error:", e.message);
    res.status(500).json({ error: e.message });
  }
});

// Manual trigger endpoint (protected by token)
// Supports ?force=true to bypass "already done" check
// GET /trigger?token=YOUR_TOKEN&force=true
// POST /trigger with body: { "token": "YOUR_TOKEN", "force": true }
app.get("/trigger", async (req, res) => {
  const token =
    req.query.token ||
    req.headers["x-trigger-token"] ||
    process.env.TRIGGER_TOKEN;
  if (!token || token !== process.env.TRIGGER_TOKEN) {
    return res
      .status(403)
      .json({ error: "Forbidden", message: "Invalid or missing token" });
  }

  // Check for force parameter
  const force =
    req.query.force === "true" ||
    req.query.force === "1" ||
    req.headers["x-force"] === "true";

  try {
    const result = await dailyTask(force);
    res.json({
      success: result.success,
      message: result.message,
      alreadyDone: result.alreadyDone,
      status: result.status,
      forced: result.forced || false,
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    res.status(500).json({
      success: false,
      error: e.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// POST endpoint for trigger (same functionality, different method)
app.post("/trigger", async (req, res) => {
  const token =
    req.body?.token ||
    req.headers["x-trigger-token"] ||
    process.env.TRIGGER_TOKEN;
  if (!token || token !== process.env.TRIGGER_TOKEN) {
    return res
      .status(403)
      .json({ error: "Forbidden", message: "Invalid or missing token" });
  }

  // Check for force parameter from body or header
  const force =
    req.body?.force === true ||
    req.body?.force === "true" ||
    req.headers["x-force"] === "true";

  try {
    const result = await dailyTask(force);
    res.json({
      success: result.success,
      message: result.message,
      alreadyDone: result.alreadyDone,
      status: result.status,
      forced: result.forced || false,
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    res.status(500).json({
      success: false,
      error: e.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Global variables for dynamic scheduling
let currentCronTask = null;
let currentCronExpression = null;

// Setup listener for schedule changes
function setupCronListener() {
  console.log("🎧 Setting up config listener for dynamic scheduling...");

  db.collection("config")
    .doc("schedule")
    .onSnapshot(
      (doc) => {
        if (!doc.exists) {
          console.warn("⚠️ Schedule config document does not exist.");
          return;
        }

        const data = doc.data();
        const newCronExpr = data.cron || "0 9 * * *"; // Default

        if (newCronExpr !== currentCronExpression) {
          if (currentCronTask) {
            console.log("🛑 Stopping previous cron task...");
            currentCronTask.stop();
          }

          const timezone = "Asia/Kolkata";
          console.log(
            `🔄 Updating cron schedule to: ${newCronExpr} (Timezone: ${timezone})`
          );

          currentCronTask = cron.schedule(newCronExpr, dailyTask, {
            timezone: timezone,
          });

          currentCronExpression = newCronExpr;
        }
      },
      (error) => {
        console.error("❌ Error listening to schedule config:", error);
      }
    );
}

// Start server and schedule cron
app.listen(PORT, async () => {
  console.log(`🚀 Server listening on port ${PORT}\n`);

  // Seed default config if database is empty
  await seedDefaultConfig();

  // Start dynamic cron listener
  setupCronListener();

  console.log("✅ Server ready!\n");
});
