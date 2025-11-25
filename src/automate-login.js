import puppeteer from "puppeteer";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { initFirebase } from "./firebase-config.js";

// Load environment variables
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ============================================================================
// CONSTANTS AND SELECTORS
// ============================================================================

// Initial date - logs before this date should be marked as PENDING
const INITIAL_DATE = "2025-11-20"; // November 20, 2025

// Check if running standalone (not imported as a module)
const isStandaloneMode =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(__filename);

// ============================================================================
// SELECTORS AND IDENTIFIERS
// ============================================================================

// Widget and Container Selectors
const SELECTORS = {
  // Main attendance widget
  ATTENDANCE_WIDGET: "gt-attendance-info",
  WIDGET_DIV: ".widget-border.bg-primary-50",
  
  // Button Selectors
  BUTTON_SIGN_IN: "Sign In",
  BUTTON_SIGN_OUT: "Sign Out",
  BUTTON_VIEW_SWIPES: "View Swipes",
  BUTTON_SHADE_PRIMARY: "primary",
  BUTTON_NAME_PRIMARY: "primary",
  
  // Modal Selectors
  MODAL_BODY: '[slot="modal-body"]',
  MODAL_CONTAINER: ".gt-popup-modal, .modal-container, [role='modal']",
  SWIPES_MODAL: "attendance-swipes-modal",
  MODAL_CLOSE: "attendance-swipes-modal .close",
  
  // Dropdown Selectors
  DROPDOWN: "gt-dropdown",
  DROPDOWN_LABEL: ".dropdown-label label",
  DROPDOWN_BUTTON: "button.dropdown-button",
  DROPDOWN_CONTAINER: ".dropdown-container",
  DROPDOWN_BODY: ".dropdown-body",
  DROPDOWN_ITEM: ".dropdown-item",
  DROPDOWN_ITEM_LABEL: ".item-label",
  DROPDOWN_LABEL_TEXT: "Enter Sign-In Location",
  
  // Text Area Selectors
  TEXT_AREA: "gt-text-area",
  TEXT_AREA_INPUT: "textarea",
  
  // Table Selectors (for View Swipes)
  TABLE_ROW: "table tbody tr",
  TABLE_CELL: "td",
  
  // Location Options
  LOCATION_OPTIONS: {
    OFFICE: "Office",
    WORK_FROM_HOME: "Work from Home",
    CLIENT_LOCATION: "Client Location",
    ON_DUTY: "On-Duty"
  }
};

// Wait Times (in milliseconds)
const WAIT_TIMES = {
  SHADOW_DOM_INIT: 2000,
  MODAL_APPEAR: 1000,
  MODAL_CLOSE: 500,
  TABLE_RENDER: 1500,
  SWIPE_PROCESS: 3000,
  PAGE_LOAD: 2000,
  DROPDOWN_OPEN: 1000,
  BUTTON_CLICK: 500
};

// Column Indices for Swipe Table
const SWIPE_TABLE_COLUMNS = {
  TIME: 0,      // Swipe Time
  IN_OUT: 1     // In/Out status
};

export class GreytHRAutomation {
  constructor(force = false) {
    this.browser = null;
    this.page = null;
    this.empId = process.env.EMP_ID;
    this.password = process.env.PASSWORD;
    this.baseUrl = process.env.GREYTHR_URL;
    this.db = null;
    this.force = force; // Force mode: bypass "already done" check
  }

  async initFirebase() {
    try {
      this.db = initFirebase();
      console.log("🔥 Firebase initialized");

      // Test connection by trying to read a document
      try {
        const testDoc = await this.db
          .collection("daily_logs")
          .doc("_test")
          .get();
        console.log("✅ Firebase connection verified");
      } catch (testError) {
        console.warn("⚠️  Firebase connection test failed:", testError.message);
        if (testError.code === 5 || testError.message.includes("NOT_FOUND")) {
          console.warn(
            "   💡 This might indicate Firestore database needs to be created"
          );
          console.warn("   📖 Visit: https://console.firebase.google.com/");
          console.warn("   → Go to Firestore Database → Create database");
        }
      }
    } catch (error) {
      console.warn(
        "⚠️  Firebase initialization failed (continuing without it):",
        error.message
      );
    }
  }

  // Fetch GPS/location config from Firestore
  async fetchLocationConfig() {
    if (!this.db) {
      // Return default if Firebase not available
      return {
        latitude: 28.5355,
        longitude: 77.391,
        accuracy: 100,
        enabled: true,
      };
    }

    try {
      const locationDoc = await this.db
        .collection("config")
        .doc("location")
        .get();
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
    } catch (error) {
      console.warn("⚠️  Could not fetch location config:", error.message);
    }

    // Default to Delhi, India coordinates
    return {
      latitude: 28.5355,
      longitude: 77.391,
      accuracy: 100,
      enabled: true,
    };
  }

  // Fetch sign-in work location preference from Firestore
  async fetchWorkLocationConfig() {
    if (!this.db) {
      // Return default if Firebase not available
      return {
        workLocation: "Office", // Default to "Office"
        remarks: "",
      };
    }

    try {
      const workLocationDoc = await this.db
        .collection("config")
        .doc("work_location")
        .get();
      if (workLocationDoc.exists) {
        const data = workLocationDoc.data();
        return {
          workLocation: data.workLocation || "Office", // "Office" or "Work From Home"
          remarks: data.remarks || "",
        };
      }
    } catch (error) {
      console.warn("⚠️  Could not fetch work location config:", error.message);
    }

    // Default to Office
    return {
      workLocation: "Office",
      remarks: "",
    };
  }

  getTodayDateString() {
    const date = new Date();
    return date.toISOString().split("T")[0]; // YYYY-MM-DD
  }

  // Check if a date string (YYYY-MM-DD) is before the initial date
  isBeforeInitialDate(dateString) {
    return dateString < INITIAL_DATE;
  }

  async checkStatus() {
    // If force mode is enabled, skip the check
    if (this.force) {
      console.log("⚡ Force mode enabled - bypassing status check");
      return false;
    }

    if (!this.db) return false;

    const today = this.getTodayDateString();

    // Check if date is before initial date
    if (this.isBeforeInitialDate(today)) {
      console.log(
        `⏸️  Date ${today} is before initial date ${INITIAL_DATE}. Data not available.`
      );
      // Mark as PENDING in database
      await this.updateStatus("PENDING");
      return true; // Exit early
    }

    try {
      const doc = await this.db.collection("daily_logs").doc(today).get();
      if (doc.exists) {
        const data = doc.data();
        if (data.status === "DONE") {
          console.log("✅ Already marked as DONE for today. Exiting.");
          return true;
        }
        if (data.status === "SKIP") {
          console.log("⏭️  Marked as SKIP for today. Exiting.");
          return true;
        }
        if (
          data.status === "PENDING" &&
          data.message &&
          data.message.includes("before initial day")
        ) {
          console.log("⏸️  Date is before initial date. Exiting.");
          return true;
        }
      }
    } catch (error) {
      console.error("❌ Error checking status:", error.message);
    }
    return false;
  }

  async updateStatus(status, swipeTimeOrReason = null) {
    if (!this.db) {
      console.warn("⚠️  Firebase not initialized, skipping status update");
      return;
    }

    const today = this.getTodayDateString();

    // Check if date is before initial date
    if (this.isBeforeInitialDate(today)) {
      console.log(
        `⏸️  Date ${today} is before initial date ${INITIAL_DATE}. Marking as PENDING.`
      );
      try {
        const updateData = {
          status: "PENDING",
          message:
            "Data not available - date is before initial day (November 20, 2025)",
          timestamp: new Date().toISOString(),
          empId: this.empId,
        };
        const docRef = this.db.collection("daily_logs").doc(today);
        await docRef.set(updateData, { merge: true });
        console.log(
          `💾 Status set to PENDING for ${today} (before initial date)`
        );
      } catch (error) {
        console.error("❌ Error updating status to Firebase:", error.message);
      }
      return;
    }

    try {
      const updateData = {
        status: status,
        timestamp: new Date().toISOString(),
        empId: this.empId,
      };

      // Handle both swipe time (for DONE status) and failure reason (for FAILED status)
      if (swipeTimeOrReason) {
        if (status === "DONE") {
          updateData.swipeTime = swipeTimeOrReason;
          console.log(`   📅 Swipe time recorded: ${swipeTimeOrReason}`);
        } else if (status === "FAILED") {
          updateData.failureReason = swipeTimeOrReason;
          console.log(`   ❌ Failure reason: ${swipeTimeOrReason}`);
        } else {
          updateData.message = swipeTimeOrReason;
        }
      }

      // Use set() with merge to create document if it doesn't exist
      const docRef = this.db.collection("daily_logs").doc(today);
      await docRef.set(updateData, { merge: true });
      console.log(`💾 Status updated to ${status} for ${today}`);
    } catch (error) {
      // Provide more detailed error information
      console.error("❌ Error updating status to Firebase:");
      console.error(`   Error code: ${error.code || "UNKNOWN"}`);
      console.error(`   Error message: ${error.message}`);

      // Check for specific Firestore errors
      if (error.code === 5 || error.message.includes("NOT_FOUND")) {
        console.error("   💡 This usually means:");
        console.error(
          "      1. Firestore database is not enabled in Firebase Console"
        );
        console.error(
          "      2. Service account doesn't have proper permissions"
        );
        console.error("      3. Wrong database ID or database mode");
        console.error("   📖 Check: https://console.firebase.google.com/");
        console.error(
          "   → Go to Firestore Database → Create database (if not exists)"
        );
      } else if (
        error.code === 7 ||
        error.message.includes("PERMISSION_DENIED")
      ) {
        console.error(
          "   💡 Permission denied - check service account permissions"
        );
      } else {
        console.error(`   Full error:`, error);
      }
    }
  }

  validateCredentials() {
    if (!this.empId || !this.password) {
      console.error("❌ Missing credentials!");
      console.error("💡 Please set EMP_ID and PASSWORD in .env file");
      if (isStandaloneMode) {
        process.exit(1);
      } else {
        throw new Error(
          "Missing credentials: EMP_ID and PASSWORD must be set in .env file"
        );
      }
    }
    console.log(`✅ Credentials loaded for Employee ID: ${this.empId}\n`);
  }

  async init() {
    console.log("🤖 Starting GreytHR Automation...\n");

    await this.initFirebase();
    if (await this.checkStatus()) {
      if (isStandaloneMode) {
        process.exit(0);
      } else {
        throw new Error("Task already completed for today");
      }
    }

    this.validateCredentials();

    // Support headless mode via environment variable or NODE_ENV
    // Defaults to headless in production, can be overridden with HEADLESS env var
    const isProduction = process.env.NODE_ENV === "production";
    const headless =
      process.env.HEADLESS === "true" ||
      process.env.HEADLESS === "1" ||
      (isProduction && process.env.HEADLESS !== "false");

    if (isProduction && headless) {
      console.log("🌐 Production mode: Running in headless mode");
    } else if (headless) {
      console.log("🌐 Running in headless mode (HEADLESS=true)");
    } else {
      console.log("🖥️  Running in headed mode (browser visible)");
    }

    this.browser = await puppeteer.launch({
      headless: headless,
      defaultViewport: null,
      args: headless
        ? [
            "--no-sandbox",
            "--disable-setuid-sandbox",
            "--disable-dev-shm-usage",
            "--disable-blink-features=AutomationControlled",
            "--disable-features=IsolateOrigins,site-per-process",
            "--disable-web-security",
            "--disable-features=VizDisplayCompositor",
          ]
        : ["--start-maximized", "--no-sandbox", "--disable-setuid-sandbox"],
    });

    // Grant geolocation permissions before creating page
    const context = this.browser.defaultBrowserContext();
    await context.overridePermissions(this.baseUrl, ["geolocation"]);

    this.page = await this.browser.newPage();

    // Set user agent to avoid detection
    await this.page.setUserAgent(
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    );

    // Set viewport for headless mode
    if (headless) {
      await this.page.setViewport({ width: 1920, height: 1080 });
    }

    // Set geolocation using Chrome CDP (Chrome DevTools Protocol)
    try {
      const locationConfig = await this.fetchLocationConfig();
      if (locationConfig.enabled) {
        console.log(
          `📍 Setting GPS location: ${locationConfig.latitude}° N, ${locationConfig.longitude}° E`
        );

        // Set geolocation using CDP
        const client = await this.page.target().createCDPSession();
        await client.send("Emulation.setGeolocationOverride", {
          latitude: locationConfig.latitude,
          longitude: locationConfig.longitude,
          accuracy: locationConfig.accuracy,
        });
        console.log("✅ GPS location set successfully");
      }
    } catch (error) {
      console.warn("⚠️  Could not set GPS location:", error.message);
      console.warn("   Continuing without GPS override...");
    }

    this.page.on("console", (msg) => {
      if (msg.type() === "error") {
        console.log(`[PAGE ERROR]:`, msg.text());
      }
    });
  }

  async navigate() {
    console.log(`🌐 Navigating to ${this.baseUrl}...`);
    try {
      // Use domcontentloaded for more reliable loading in headless mode
      // This is more stable than networkidle2 which can timeout in headless
      await this.page.goto(this.baseUrl, {
        waitUntil: "domcontentloaded",
        timeout: 60000,
      });
      console.log("✅ Page loaded\n");

      // Wait for page to stabilize after DOM is loaded
      // Give time for JavaScript to execute and elements to render
      await this.wait(3000);
    } catch (error) {
      console.warn(`⚠️  Navigation warning: ${error.message}`);
      // Even if navigation fails, try to continue after a wait
      await this.wait(3000);
    }
  }

  async login() {
    console.log("🔐 Attempting login...");

    try {
      await this.loginStrategy1();
    } catch (e) {
      console.log("⚠️  Strategy 1 failed, trying alternative approach...");
      try {
        await this.loginStrategy2();
      } catch (e2) {
        console.log(
          "⚠️  Strategy 2 failed, trying manual element detection..."
        );
        await this.loginStrategy3();
      }
    }
  }

  async loginStrategy1() {
    console.log("   → Strategy 1: Standard form fields");

    // Wait for page to be stable before looking for inputs
    try {
      await this.page.waitForSelector("input", { timeout: 15000 });
      await this.wait(1000); // Additional wait for page stability
    } catch (e) {
      throw new Error("Page inputs not found or page not stable");
    }

    // Employee ID
    const empIdSelectors = [
      'input[name="username"]',
      'input[name="employeeId"]',
      'input[id="username"]',
      'input[type="text"]',
    ];

    let empIdFilled = false;
    for (const selector of empIdSelectors) {
      try {
        const element = await this.page.$(selector);
        if (element) {
          await element.click({ delay: 100 });
          await this.wait(500);
          await element.type(this.empId, { delay: 50 });
          empIdFilled = true;
          break;
        }
      } catch (e) {
        // Continue to next selector if this one fails
        continue;
      }
    }

    if (!empIdFilled) throw new Error("Could not find employee ID field");

    await this.wait(500);

    // Password
    const passwordSelectors = [
      'input[name="password"]',
      'input[type="password"]',
      'input[id="password"]',
    ];
    let passwordFilled = false;
    for (const selector of passwordSelectors) {
      try {
        const element = await this.page.$(selector);
        if (element) {
          await element.click({ delay: 100 });
          await this.wait(500);
          await element.type(this.password, { delay: 50 });
          passwordFilled = true;
          break;
        }
      } catch (e) {
        // Continue to next selector if this one fails
        continue;
      }
    }

    if (!passwordFilled) throw new Error("Could not find password field");

    await this.wait(1000);

    // Submit - use Promise.race to handle navigation
    const submitSelectors = [
      'button[type="submit"]',
      'button:has-text("Login")',
      'button:has-text("Sign In")',
    ];
    let submitted = false;

    // Set up navigation promise before clicking
    const navigationPromise = Promise.race([
      this.page
        .waitForNavigation({ waitUntil: "domcontentloaded", timeout: 20000 })
        .catch(() => null),
      this.wait(20000), // Max wait time
    ]);

    for (const selector of submitSelectors) {
      try {
        const element = await this.page.$(selector);
        if (element) {
          await element.click({ delay: 100 });
          submitted = true;
          break;
        }
      } catch (e) {
        continue;
      }
    }

    if (!submitted) {
      await this.page.keyboard.press("Enter");
    }

    // Wait for navigation
    await navigationPromise;
    await this.wait(2000); // Additional wait after navigation

    // Check if login was successful
    const currentUrl = this.page.url();
    if (
      currentUrl.includes("dashboard") ||
      currentUrl.includes("home") ||
      currentUrl.includes("greythr")
    ) {
      console.log("✅ Login successful!\n");
    } else {
      // Don't throw immediately - might still be loading
      console.log(`   ⚠️ URL check: ${currentUrl}`);
      await this.wait(3000);
      const finalUrl = this.page.url();
      if (
        !finalUrl.includes("dashboard") &&
        !finalUrl.includes("home") &&
        !finalUrl.includes("greythr")
      ) {
        throw new Error(
          "Login might have failed - URL doesn't match expected pattern"
        );
      }
      console.log("✅ Login successful (after additional wait)!\n");
    }
  }

  async loginStrategy2() {
    // Simplified backup strategy
    console.log("   → Strategy 2: XPath");

    try {
      // Wait for inputs to be available
      await this.page.waitForSelector("input", { timeout: 10000 });
      await this.wait(1000);

      const [empIdInput] = await this.page.$x(
        '//input[@type="text" or @name="username"]'
      );
      if (empIdInput) {
        await empIdInput.click({ delay: 100 });
        await this.wait(500);
        await empIdInput.type(this.empId, { delay: 50 });
      } else {
        throw new Error("Employee ID input not found");
      }

      await this.wait(500);

      const [passInput] = await this.page.$x('//input[@type="password"]');
      if (passInput) {
        await passInput.click({ delay: 100 });
        await this.wait(500);
        await passInput.type(this.password, { delay: 50 });
      } else {
        throw new Error("Password input not found");
      }

      await this.wait(1000);

      // Set up navigation promise
      const navigationPromise = Promise.race([
        this.page
          .waitForNavigation({ waitUntil: "domcontentloaded", timeout: 20000 })
          .catch(() => null),
        this.wait(20000),
      ]);

      const [submitBtn] = await this.page.$x('//button[@type="submit"]');
      if (submitBtn) {
        await submitBtn.click({ delay: 100 });
      } else {
        await this.page.keyboard.press("Enter");
      }

      await navigationPromise;
      await this.wait(3000);

      const currentUrl = this.page.url();
      if (
        !currentUrl.includes("dashboard") &&
        !currentUrl.includes("home") &&
        !currentUrl.includes("greythr")
      ) {
        throw new Error("Login might have failed");
      }
      console.log("✅ Login successful!\n");
    } catch (error) {
      if (error.message.includes("Execution context was destroyed")) {
        // Navigation happened, check if we're logged in
        await this.wait(3000);
        const currentUrl = this.page.url();
        if (
          currentUrl.includes("dashboard") ||
          currentUrl.includes("home") ||
          currentUrl.includes("greythr")
        ) {
          console.log("✅ Login successful (navigation detected)!\n");
          return;
        }
      }
      throw error;
    }
  }

  async loginStrategy3() {
    // Fallback
    console.log("   → Strategy 3: Generic Inputs");

    try {
      // Wait for page to be stable
      await this.page.waitForSelector("input", { timeout: 10000 });
      await this.wait(2000); // Wait for page to fully stabilize

      // Re-query inputs to ensure they're still valid
      const inputs = await this.page.$$("input");
      if (inputs.length >= 2) {
        // Use evaluate to interact with inputs more safely
        await this.page.evaluate(
          (empId, password) => {
            const inputs = Array.from(document.querySelectorAll("input"));
            if (inputs.length >= 2) {
              // Find text input (usually first)
              const textInput =
                inputs.find(
                  (inp) =>
                    inp.type === "text" ||
                    inp.type === "email" ||
                    (!inp.type && inp.tagName === "INPUT")
                ) || inputs[0];

              // Find password input
              const passInput =
                inputs.find((inp) => inp.type === "password") || inputs[1];

              if (textInput && passInput) {
                textInput.focus();
                textInput.value = empId;
                textInput.dispatchEvent(new Event("input", { bubbles: true }));
                textInput.dispatchEvent(new Event("change", { bubbles: true }));

                passInput.focus();
                passInput.value = password;
                passInput.dispatchEvent(new Event("input", { bubbles: true }));
                passInput.dispatchEvent(new Event("change", { bubbles: true }));
              }
            }
          },
          this.empId,
          this.password
        );

        await this.wait(1000);

        // Set up navigation promise before submitting
        const navigationPromise = Promise.race([
          this.page
            .waitForNavigation({
              waitUntil: "domcontentloaded",
              timeout: 20000,
            })
            .catch(() => null),
          this.wait(20000),
        ]);

        await this.page.keyboard.press("Enter");

        await navigationPromise;
        await this.wait(3000);

        const currentUrl = this.page.url();
        if (
          !currentUrl.includes("dashboard") &&
          !currentUrl.includes("home") &&
          !currentUrl.includes("greythr")
        ) {
          throw new Error("Login might have failed");
        }
        console.log("✅ Login successful!\n");
      } else {
        throw new Error("Not enough input fields found");
      }
    } catch (error) {
      if (error.message.includes("Execution context was destroyed")) {
        // Navigation happened, check if we're logged in
        await this.wait(3000);
        const currentUrl = this.page.url();
        if (
          currentUrl.includes("dashboard") ||
          currentUrl.includes("home") ||
          currentUrl.includes("greythr")
        ) {
          console.log("✅ Login successful (navigation detected)!\n");
          return;
        }
      }
      throw error;
    }
  }

  // ============================================================================
  // MODULAR METHODS - ATTENDANCE ACTIONS
  // ============================================================================

  /**
   * View Swipes - Opens the View Swipes modal and fetches the first swipe-in time
   * @returns {Promise<{hasInSwipe: boolean, swipeTime: string|null}>}
   */
  async viewSwipes() {
    console.log("   🔍 Checking swipe status via View Swipes modal...");

    try {
      // Find View Swipes button in the attendance widget
      const viewSwipesBtn = await this.page.evaluateHandle(() => {
        const attendanceInfo = document.querySelector(SELECTORS.ATTENDANCE_WIDGET);
        if (!attendanceInfo) return null;

        const buttons = Array.from(attendanceInfo.querySelectorAll("gt-button"));
        return buttons.find((btn) => {
          const name = btn.getAttribute("name");
          const text = btn.innerText || btn.textContent || "";
          return name === SELECTORS.BUTTON_VIEW_SWIPES || text.includes(SELECTORS.BUTTON_VIEW_SWIPES);
        });
      });

      if (!viewSwipesBtn || !viewSwipesBtn.asElement()) {
        console.log("   ℹ️ 'View Swipes' button not found.");
        return { hasInSwipe: false, swipeTime: null };
      }

      console.log("   ✓ 'View Swipes' button found. Opening modal...");
      await viewSwipesBtn.asElement().click();
      await this.wait(WAIT_TIMES.MODAL_APPEAR);

      // Wait for modal to appear
      await this.page.waitForSelector(SELECTORS.SWIPES_MODAL, {
        timeout: 5000,
      });
      await this.wait(WAIT_TIMES.TABLE_RENDER);

      // Extract swipe data from modal
      const swipeData = await this.page.evaluate((selectors, columns) => {
        const modal = document.querySelector(selectors.SWIPES_MODAL);
        if (!modal) return { hasInSwipe: false, swipeTime: null };

        const rows = Array.from(modal.querySelectorAll(selectors.TABLE_ROW));
        if (rows.length === 0) return { hasInSwipe: false, swipeTime: null };

        // Find the row with "IN" in the IN_OUT column and extract time from TIME column
        for (const row of rows) {
          const cells = Array.from(row.querySelectorAll(selectors.TABLE_CELL));
          if (cells.length >= 2) {
            const inOutCell = cells[columns.IN_OUT];
            const timeCell = cells[columns.TIME];
            const inOutText = (inOutCell.innerText || inOutCell.textContent || "").trim();

            if (inOutText === "IN" || inOutText.includes("IN")) {
              const swipeTime = (timeCell.innerText || timeCell.textContent || "").trim();
              return { hasInSwipe: true, swipeTime: swipeTime };
            }
          }
        }

        return { hasInSwipe: false, swipeTime: null };
      }, SELECTORS, SWIPE_TABLE_COLUMNS);

      // Close modal
      try {
        const closeBtn = await this.page.$(SELECTORS.MODAL_CLOSE);
        if (closeBtn) {
          await closeBtn.click();
          await this.wait(WAIT_TIMES.MODAL_CLOSE);
        }
      } catch (err) {
        console.log("   ⚠️ Could not close modal:", err.message);
        await this.page.keyboard.press("Escape");
        await this.wait(WAIT_TIMES.MODAL_CLOSE);
      }

      if (swipeData.hasInSwipe) {
        console.log("✅ Verified 'IN' swipe from modal.");
        if (swipeData.swipeTime) {
          console.log(`   ⏰ Swipe time: ${swipeData.swipeTime}`);
        }
      } else {
        console.log("   ℹ️ No 'IN' entry detected in modal.");
      }

      return swipeData;
    } catch (e) {
      console.log("   ⚠️ Error checking 'View Swipes':", e.message);
      return { hasInSwipe: false, swipeTime: null };
    }
  }

  /**
   * Sign In - Finds widget with Sign In button, clicks it, selects location, and verifies success
   * @returns {Promise<boolean>} True if sign-in successful, false otherwise
   */
  async signIn() {
    console.log("   🔍 Looking for 'Sign In' button in widget...");

    try {
      // Wait for shadow DOM to initialize
      await this.wait(WAIT_TIMES.SHADOW_DOM_INIT);

      // Find Sign In button in the attendance widget
      const signInBtn = await this.page.evaluateHandle((selectors) => {
        const attendanceInfo = document.querySelector(selectors.ATTENDANCE_WIDGET);
        if (!attendanceInfo) return null;

        const buttons = Array.from(attendanceInfo.querySelectorAll("gt-button"));
        for (const btn of buttons) {
          let text = (btn.innerText || btn.textContent || "").trim();
          
          if (btn.shadowRoot) {
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (shadowButton) {
              text = (shadowButton.innerText || shadowButton.textContent || "").trim();
            }
          }
          
          if (text.includes(selectors.BUTTON_SIGN_IN)) {
            return btn;
          }
        }
        return null;
      }, SELECTORS);

      if (!signInBtn || !signInBtn.asElement()) {
        console.log("   ❌ 'Sign In' button not found in widget");
        return false;
      }

      console.log("   ✓ Found 'Sign In' button. Clicking...");
      
      // Click the Sign In button
      await this.page.evaluate(() => {
        const attendanceInfo = document.querySelector(SELECTORS.ATTENDANCE_WIDGET);
        if (!attendanceInfo) return false;
        const buttons = Array.from(attendanceInfo.querySelectorAll("gt-button"));
        for (const btn of buttons) {
          if (btn.shadowRoot) {
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (shadowButton) {
              const text = (shadowButton.innerText || shadowButton.textContent || "").trim();
              if (text.includes(SELECTORS.BUTTON_SIGN_IN)) {
                shadowButton.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
                shadowButton.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
                shadowButton.dispatchEvent(new MouseEvent('click', { bubbles: true }));
                shadowButton.click();
                return true;
              }
            }
          }
        }
        return false;
      });

      console.log("   ⏳ Waiting for sign-in location modal...");
      await this.wait(WAIT_TIMES.MODAL_APPEAR);

      // Handle the sign-in location modal
      const modalHandled = await this.handleSignInModal();
      if (!modalHandled) {
        console.log("   ⚠️ Sign-in modal handling failed");
        return false;
      }

      console.log("   ⏳ Waiting for swipe to process...");
      await this.wait(WAIT_TIMES.SWIPE_PROCESS);

      // Verify sign-in success by checking for Sign Out button
      const verified = await this.verifySignInSuccess();
      if (verified) {
        console.log("   ✅ Sign-in completed and verified successfully");
        return true;
      } else {
        console.log("   ❌ Sign-in verification failed");
        return false;
      }
    } catch (error) {
      console.log(`   ❌ Error during sign-in: ${error.message}`);
      return false;
    }
  }

  /**
   * Sign Out - Finds widget with Sign Out button, clicks it, confirms, and verifies success
   * @returns {Promise<boolean>} True if sign-out successful, false otherwise
   */
  async signOut() {
    console.log("   🔍 Looking for 'Sign Out' button in widget...");

    try {
      // Wait for shadow DOM to initialize
      await this.wait(WAIT_TIMES.SHADOW_DOM_INIT);

      // Find Sign Out button in the attendance widget
      const signOutBtn = await this.page.evaluateHandle((selectors) => {
        const attendanceInfo = document.querySelector(selectors.ATTENDANCE_WIDGET);
        if (!attendanceInfo) return null;

        const buttons = Array.from(attendanceInfo.querySelectorAll("gt-button"));
        for (const btn of buttons) {
          const shade = btn.getAttribute("shade");
          let text = (btn.innerText || btn.textContent || "").trim();
          
          if (btn.shadowRoot) {
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (shadowButton) {
              text = (shadowButton.innerText || shadowButton.textContent || "").trim();
            }
          }
          
          // Look for Sign Out button with primary shade
          if (text.includes(selectors.BUTTON_SIGN_OUT) && shade === selectors.BUTTON_SHADE_PRIMARY) {
            return btn;
          }
        }
        return null;
      }, SELECTORS);

      if (!signOutBtn || !signOutBtn.asElement()) {
        console.log("   ℹ️ 'Sign Out' button not found - already signed out");
        return false;
      }

      console.log("   ✓ Found 'Sign Out' button. Clicking...");
      
      // Click the Sign Out button
      await this.page.evaluate(() => {
        const attendanceInfo = document.querySelector(SELECTORS.ATTENDANCE_WIDGET);
        if (!attendanceInfo) return false;
        const buttons = Array.from(attendanceInfo.querySelectorAll("gt-button"));
        for (const btn of buttons) {
          if (btn.shadowRoot) {
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (shadowButton) {
              const text = (shadowButton.innerText || shadowButton.textContent || "").trim();
              if (text.includes(SELECTORS.BUTTON_SIGN_OUT)) {
                shadowButton.click();
                return true;
              }
            }
          }
        }
        return false;
      });

      console.log("   ⏳ Waiting for sign-out to process...");
      await this.wait(WAIT_TIMES.SWIPE_PROCESS);

      // Verify sign-out success by checking for Sign In button
      const verified = await this.verifySignOutSuccess();
      if (verified) {
        console.log("   ✅ Sign-out completed and verified successfully");
        return true;
      } else {
        console.log("   ❌ Sign-out verification failed");
        return false;
      }
    } catch (error) {
      console.log(`   ❌ Error during sign-out: ${error.message}`);
      return false;
    }
  }

  /**
   * Verify Sign In Success - Checks if widget now shows Sign Out button
   * @returns {Promise<boolean>}
   */
  async verifySignInSuccess() {
    return await this.page.evaluate((selectors) => {
      const widgetDiv = document.querySelector(selectors.WIDGET_DIV) || 
                        document.querySelector(selectors.ATTENDANCE_WIDGET);
      if (!widgetDiv) return false;

      const buttons = Array.from(widgetDiv.querySelectorAll("gt-button"));
      for (const btn of buttons) {
        if (!btn.shadowRoot) continue;
        const shadowButton = btn.shadowRoot.querySelector("button");
        if (shadowButton) {
          const text = (shadowButton.textContent || shadowButton.innerText || "").trim();
          const shade = btn.getAttribute("shade");
          const name = shadowButton.getAttribute("name") || btn.getAttribute("name") || "";
          
          if (text.includes(selectors.BUTTON_SIGN_OUT) && 
              shade === selectors.BUTTON_SHADE_PRIMARY && 
              (name === selectors.BUTTON_NAME_PRIMARY || name === "")) {
            return true;
          }
        }
      }
      return false;
    }, SELECTORS);
  }

  /**
   * Verify Sign Out Success - Checks if widget now shows Sign In button
   * @returns {Promise<boolean>}
   */
  async verifySignOutSuccess() {
    return await this.page.evaluate((selectors) => {
      const widgetDiv = document.querySelector(selectors.WIDGET_DIV) || 
                        document.querySelector(selectors.ATTENDANCE_WIDGET);
      if (!widgetDiv) return false;

      const buttons = Array.from(widgetDiv.querySelectorAll("gt-button"));
      for (const btn of buttons) {
        if (!btn.shadowRoot) continue;
        const shadowButton = btn.shadowRoot.querySelector("button");
        if (shadowButton) {
          const text = (shadowButton.textContent || shadowButton.innerText || "").trim();
          if (text.includes(selectors.BUTTON_SIGN_IN)) {
            return true;
          }
        }
      }
      return false;
    }, SELECTORS);
  }

  // ============================================================================
  // SIGN-IN MODAL HANDLING
  // ============================================================================

  async handleSignInModal() {
    console.log("   🔍 Checking for sign-in location dropdown...");

    try {
      // Wait a bit for dropdown to appear after sign-in button click
      await this.wait(1000);

      // Fetch work location config from Firebase
      const workLocationConfig = await this.fetchWorkLocationConfig();
      console.log(`   → Work location: ${workLocationConfig.workLocation}`);
      if (workLocationConfig.remarks) {
        console.log(`   → Remarks: ${workLocationConfig.remarks}`);
      }

      // Find dropdown directly by looking for gt-dropdown with "Enter Sign-In Location" label
      console.log("   🔍 Looking for sign-in location dropdown...");
      let dropdownFound = false;
      let attempts = 0;
      const maxAttempts = 20; // 20 attempts * 500ms = 10 seconds max

      while (!dropdownFound && attempts < maxAttempts) {
        const dropdownCheck = await this.page.evaluate((selectors) => {
          // Find all gt-dropdown elements
          const dropdowns = document.querySelectorAll(selectors.DROPDOWN);

          for (const dropdown of dropdowns) {
            if (!dropdown.shadowRoot) continue;

            // Check if this dropdown has the "Enter Sign-In Location" label
            const label = dropdown.shadowRoot.querySelector(
              selectors.DROPDOWN_LABEL
            );
            if (
              label &&
              label.textContent &&
              label.textContent.includes(selectors.DROPDOWN_LABEL_TEXT)
            ) {
              // Verify dropdown is visible
              const computed = window.getComputedStyle(dropdown);
              const isVisible =
                computed.display !== "none" &&
                computed.visibility !== "hidden" &&
                computed.opacity !== "0";

              if (isVisible || dropdown.offsetParent !== null) {
                return { found: true };
              }
            }
          }
          return { found: false };
        });

        if (dropdownCheck.found) {
          dropdownFound = true;
          console.log(`   ✓ Dropdown found after ${attempts * 500}ms!`);
          break;
        }

        attempts++;
        await this.wait(500);
      }

      if (!dropdownFound) {
        console.log(
          `   ℹ️ No sign-in location dropdown appeared after ${
            maxAttempts * 500
          }ms`
        );
        return false;
      }

      await this.wait(500); // Give dropdown time to fully render

      console.log("   📍 Filling sign-in location...");

      // Click the dropdown to open options
      console.log("   🖱️ Opening location dropdown...");
      const dropdownOpened = await this.page.evaluate((selectors) => {
        // Find the dropdown with "Enter Sign-In Location" label
        const dropdowns = document.querySelectorAll(selectors.DROPDOWN);

        for (const dropdown of dropdowns) {
          if (!dropdown.shadowRoot) continue;

          const label = dropdown.shadowRoot.querySelector(
            selectors.DROPDOWN_LABEL
          );
          if (
            label &&
            label.textContent &&
            label.textContent.includes(selectors.DROPDOWN_LABEL_TEXT)
          ) {
            const button = dropdown.shadowRoot.querySelector(
              selectors.DROPDOWN_BUTTON
            );
            if (button) {
              button.click();
              return { success: true };
            }
          }
        }
        return { success: false, reason: "Dropdown button not found" };
      }, SELECTORS);

      if (!dropdownOpened.success) {
        console.log(`   ⚠️ Could not open dropdown: ${dropdownOpened.reason}`);
        throw new Error(
          `Failed to open work location dropdown: ${dropdownOpened.reason}`
        );
      }

      console.log("   ✓ Dropdown opened");
      await this.wait(WAIT_TIMES.DROPDOWN_OPEN); // Wait for dropdown items to appear

      // Select the option based on config
      console.log(
        `   🔍 Looking for option: "${workLocationConfig.workLocation}"`
      );
      const optionSelected = await this.page.evaluate((targetLocation, selectors) => {
        // Find the dropdown with "Enter Sign-In Location" label
        const dropdowns = document.querySelectorAll(selectors.DROPDOWN);
        let targetDropdown = null;

        for (const dropdown of dropdowns) {
          if (!dropdown.shadowRoot) continue;

          const label = dropdown.shadowRoot.querySelector(
            selectors.DROPDOWN_LABEL
          );
          if (
            label &&
            label.textContent &&
            label.textContent.includes(selectors.DROPDOWN_LABEL_TEXT)
          ) {
            targetDropdown = dropdown;
            break;
          }
        }

        if (!targetDropdown || !targetDropdown.shadowRoot) {
          return { success: false, found: ["Dropdown not found"] };
        }

        // Look for dropdown items in shadow DOM - they're in .dropdown-container .dropdown-body .dropdown-item
        const dropdownContainer = targetDropdown.shadowRoot.querySelector(
          selectors.DROPDOWN_CONTAINER
        );
        if (!dropdownContainer) {
          return { success: false, found: ["No dropdown-container"] };
        }

        const items = dropdownContainer.querySelectorAll(selectors.DROPDOWN_ITEM);
        const foundOptions = [];

        for (const item of items) {
          // The actual text is in .item-label inside .dropdown-item
          const label = item.querySelector(selectors.DROPDOWN_ITEM_LABEL);
          if (!label) continue;

          const text = (label.textContent || label.innerText || "").trim();
          foundOptions.push(text);

          // Match location - be flexible with variations
          const textLower = text.toLowerCase();
          const targetLower = targetLocation.toLowerCase();

          if (
            (targetLower.includes("office") && textLower.includes("office")) ||
            (targetLower.includes("work from home") &&
              textLower.includes("work from home")) ||
            (targetLower.includes("home") &&
              textLower.includes("home") &&
              !textLower.includes("office")) ||
            (targetLower.includes("client location") &&
              textLower.includes("client location")) ||
            (targetLower.includes("on-duty") && textLower.includes("on-duty"))
          ) {
            item.click();
            return { success: true, matched: text, found: foundOptions };
          }
        }

        return { success: false, found: foundOptions };
      }, workLocationConfig.workLocation, SELECTORS);

      if (!optionSelected.success) {
        console.log(
          `   ⚠️ Could not select dropdown option for "${workLocationConfig.workLocation}"`
        );
        console.log(
          `   → Available options: ${optionSelected.found.join(", ")}`
        );

        // Try fallback: case-insensitive match
        if (optionSelected.found.length > 0) {
          console.log("   → Trying case-insensitive match...");
          const fallbackSelected = await this.page.evaluate(
            (targetLocation, selectors) => {
              const dropdowns = document.querySelectorAll(selectors.DROPDOWN);
              let targetDropdown = null;

              for (const dropdown of dropdowns) {
                if (!dropdown.shadowRoot) continue;
                const label = dropdown.shadowRoot.querySelector(
                  selectors.DROPDOWN_LABEL
                );
                if (
                  label &&
                  label.textContent &&
                  label.textContent.includes(selectors.DROPDOWN_LABEL_TEXT)
                ) {
                  targetDropdown = dropdown;
                  break;
                }
              }

              if (!targetDropdown || !targetDropdown.shadowRoot) return false;

              const items =
                targetDropdown.shadowRoot.querySelectorAll(selectors.DROPDOWN_ITEM);
              const targetLower = targetLocation.toLowerCase();

              for (const item of items) {
                const label = item.querySelector(selectors.DROPDOWN_ITEM_LABEL);
                if (!label) continue;

                const text = (label.textContent || label.innerText || "")
                  .trim()
                  .toLowerCase();

                if (
                  (targetLower.includes("office") && text.includes("office")) ||
                  (targetLower.includes("work") &&
                    targetLower.includes("home") &&
                    text.includes("work") &&
                    text.includes("home")) ||
                  (targetLower.includes("home") &&
                    text.includes("home") &&
                    !text.includes("office"))
                ) {
                  item.click();
                  return true;
                }
              }
              return false;
            },
            workLocationConfig.workLocation,
            SELECTORS
          );

          if (fallbackSelected) {
            console.log("   ✓ Location selected (fallback)");
          } else {
            throw new Error(
              `Failed to select location: "${
                workLocationConfig.workLocation
              }". Available: ${optionSelected.found.join(", ")}`
            );
          }
        } else {
          throw new Error(
            `Failed to select location: "${
              workLocationConfig.workLocation
            }". Available: ${optionSelected.found.join(", ")}`
          );
        }
      } else {
        console.log(`   ✓ Location selected: "${optionSelected.matched}"`);
      }

      await this.wait(500);

      // Fill remarks if provided
      if (workLocationConfig.remarks) {
        const remarksFilled = await this.page.evaluate((remarks, selectors) => {
          // Find gt-text-area element (should be near the dropdown)
          const textAreas = document.querySelectorAll(selectors.TEXT_AREA);

          for (const textArea of textAreas) {
            if (!textArea.shadowRoot) continue;

            const textarea = textArea.shadowRoot.querySelector(selectors.TEXT_AREA_INPUT);
            if (textarea) {
              textarea.value = remarks;
              textarea.dispatchEvent(new Event("input", { bubbles: true }));
              textarea.dispatchEvent(new Event("change", { bubbles: true }));
              return true;
            }
          }
          return false;
        }, workLocationConfig.remarks, SELECTORS);

        if (remarksFilled) {
          console.log("   ✓ Remarks filled");
        } else {
          console.log("   ⚠️ Could not find remarks textarea");
        }
      }

      await this.wait(500);

      // Click the Sign In button in the modal
      console.log("   🖱️ Looking for Sign In button in modal...");

      const buttonResult = await this.page.evaluate((selectors) => {
        // Find the modal body with slot="modal-body" - this is where the Sign In button is
        const modalBody = document.querySelector(selectors.MODAL_BODY);
        if (!modalBody) {
          return { success: false, reason: "Modal body not found" };
        }

        // Find gt-button elements within the modal body
        const buttons = Array.from(modalBody.querySelectorAll("gt-button"));

        if (buttons.length === 0) {
          return { success: false, reason: "No buttons found in modal body" };
        }

        // Try to find button by shade="primary" and text="Sign In" first (most reliable)
        for (const btn of buttons) {
          const shade = btn.getAttribute("shade");
          if (shade === selectors.BUTTON_SHADE_PRIMARY && btn.shadowRoot) {
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (shadowButton) {
              const text = (
                shadowButton.textContent ||
                shadowButton.innerText ||
                ""
              ).trim();
              const isDisabled = shadowButton.disabled;

              if (text.includes(selectors.BUTTON_SIGN_IN)) {
                if (isDisabled) {
                  return {
                    success: false,
                    reason: "Sign In button found but is disabled",
                    buttonText: text,
                  };
                }

                // Try multiple click methods
                shadowButton.focus();
                shadowButton.click();

                // Also dispatch events to ensure it registers
                shadowButton.dispatchEvent(
                  new MouseEvent("mousedown", { bubbles: true })
                );
                shadowButton.dispatchEvent(
                  new MouseEvent("mouseup", { bubbles: true })
                );
                shadowButton.dispatchEvent(
                  new MouseEvent("click", { bubbles: true })
                );

                return {
                  success: true,
                  buttonText: text,
                  method: "by shade=primary in modal-body",
                };
              }
            }
          }
        }

        // Fallback: Find by text content "Sign In" in modal body
        for (const btn of buttons) {
          if (!btn.shadowRoot) continue;

          const shadowButton = btn.shadowRoot.querySelector("button");
          if (shadowButton) {
            const text = (
              shadowButton.textContent ||
              shadowButton.innerText ||
              ""
            ).trim();
            if (text.includes(selectors.BUTTON_SIGN_IN)) {
              if (shadowButton.disabled) {
                return {
                  success: false,
                  reason: "Sign In button found but is disabled",
                  buttonText: text,
                };
              }

              shadowButton.focus();
              shadowButton.click();
              shadowButton.dispatchEvent(
                new MouseEvent("mousedown", { bubbles: true })
              );
              shadowButton.dispatchEvent(
                new MouseEvent("mouseup", { bubbles: true })
              );
              shadowButton.dispatchEvent(
                new MouseEvent("click", { bubbles: true })
              );

              return {
                success: true,
                buttonText: text,
                method: "by text in modal-body",
              };
            }
          }
        }

        return {
          success: false,
          reason: "No Sign In button found in modal body",
        };
      });

      if (!buttonResult.success) {
        console.log(`   ⚠️ Sign In button not clicked: ${buttonResult.reason}`);
        throw new Error(
          `Failed to click Sign In button: ${buttonResult.reason}`
        );
      }

      console.log(
        `   ✓ Sign In button clicked (${buttonResult.method}): "${buttonResult.buttonText}"`
      );

      // Wait for modal to close and swipe to process
      console.log("   ⏳ Waiting for modal to close and swipe to process...");
      await this.wait(3000); // Wait for modal to close and page to update

      // Verify success by checking if the main widget now shows "Sign Out" button
      console.log(
        "   🔍 Verifying sign-in success by checking for 'Sign Out' button..."
      );
      const verificationResult = await this.page.evaluate((selectors) => {
        // Look for the main widget div (widget-border bg-primary-50) or gt-attendance-info
        const widgetDiv = document.querySelector(
          `${selectors.WIDGET_DIV}, ${selectors.ATTENDANCE_WIDGET}`
        );
        if (!widgetDiv) {
          return { success: false, reason: "Main widget not found" };
        }

        // Find all buttons in the widget (check both in widget div and gt-attendance-info)
        const buttons = Array.from(widgetDiv.querySelectorAll("gt-button"));

        // Also check if widgetDiv is gt-attendance-info and search within it
        let allButtons = buttons;
        if (widgetDiv.tagName === "GT-ATTENDANCE-INFO") {
          allButtons = Array.from(widgetDiv.querySelectorAll("gt-button"));
        }

        for (const btn of allButtons) {
          if (!btn.shadowRoot) continue;

          const shadowButton = btn.shadowRoot.querySelector("button");
          if (shadowButton) {
            const text = (
              shadowButton.textContent ||
              shadowButton.innerText ||
              ""
            ).trim();
            const shade = btn.getAttribute("shade");
            const name =
              shadowButton.getAttribute("name") ||
              btn.getAttribute("name") ||
              "";

            // Check if we found a "Sign Out" button with shade="primary" and name="primary"
            if (
              text.includes(selectors.BUTTON_SIGN_OUT) &&
              shade === selectors.BUTTON_SHADE_PRIMARY &&
              (name === selectors.BUTTON_NAME_PRIMARY || name === "")
            ) {
              return {
                success: true,
                buttonText: text,
                found: "Sign Out button found in main widget",
                widgetFound: true,
              };
            }
          }
        }

        // If we didn't find Sign Out, check what buttons are available
        const availableButtons = allButtons
          .map((btn) => {
            if (!btn.shadowRoot) return null;
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (!shadowButton) return null;
            const text = (
              shadowButton.textContent ||
              shadowButton.innerText ||
              ""
            ).trim();
            const shade = btn.getAttribute("shade");
            const name =
              shadowButton.getAttribute("name") ||
              btn.getAttribute("name") ||
              "";
            return { text, shade, name };
          })
          .filter(Boolean);

        return {
          success: false,
          reason: "Sign Out button not found in main widget",
          availableButtons: availableButtons,
          widgetFound: true,
        };
      }, SELECTORS);

      if (verificationResult.success) {
        console.log(
          `   ✅ Sign-in verified successfully: ${verificationResult.found}`
        );
        console.log(
          `   → Main widget now shows: "${verificationResult.buttonText}"`
        );
        return true; // Success - sign-in completed
      } else {
        console.log(`   ❌ Verification failed: ${verificationResult.reason}`);
        if (verificationResult.availableButtons) {
          console.log(
            `   → Available buttons in widget: ${JSON.stringify(
              verificationResult.availableButtons
            )}`
          );
        }
        // If verification fails, don't mark as DONE - throw error to prevent status update
        console.log("   ⚠️ Sign-in verification failed - not marking as DONE");
        throw new Error(
          `Sign-in verification failed: ${verificationResult.reason}. Sign Out button not found - sign-in may not have completed successfully.`
        );
      }
    } catch (error) {
      if (error.message && error.message.includes("Waiting for selector")) {
        // Dropdown didn't appear - this is normal if no dropdown is needed
        console.log("   ℹ️ No sign-in location dropdown appeared (timeout)");

        // Debug: Check what's on the page
        const pageInfo = await this.page.evaluate(() => {
          return {
            hasModal: !!document.querySelector(".gt-popup-modal"),
            hasModalBlock: !!document.querySelector(".gt-popup-modal.block"),
            hasModalContainer: !!document.querySelector(".modal-container"),
            hasAttendanceInfo: !!document.querySelector("gt-attendance-info"),
            bodyText: document.body.textContent.substring(0, 200),
          };
        });
        console.log(`   → Debug: Modal elements: ${JSON.stringify(pageInfo)}`);

        return false;
      }
      throw error;
    }
  }

  async swipeIn() {
    console.log("⏰ Attempting swipe-in...");

    // Wait for dashboard to fully load
    await this.wait(5000);

    // Debug: Check what's on the page
    const pageInfo = await this.page.evaluate((selectors) => {
      return {
        url: window.location.href,
        title: document.title,
        hasAttendanceInfo: !!document.querySelector(selectors.ATTENDANCE_WIDGET),
        bodyClasses: document.body.className,
        visibleText: document.body.textContent.substring(0, 500),
      };
    }, SELECTORS);
    console.log(`   → Current URL: ${pageInfo.url}`);
    console.log(`   → Page title: ${pageInfo.title}`);
    console.log(`   → Has gt-attendance-info: ${pageInfo.hasAttendanceInfo}`);

    // Wait for attendance widget to appear with longer timeout
    try {
      await this.page.waitForSelector(SELECTORS.ATTENDANCE_WIDGET, { timeout: 20000 });
      console.log("   ✓ Attendance widget loaded");
      await this.wait(WAIT_TIMES.SHADOW_DOM_INIT); // Give shadow DOM time to initialize
    } catch (e) {
      console.log("   ❌ Attendance widget not found after 20s");
      console.log(
        `   → Visible text: ${pageInfo.visibleText.substring(0, 200)}...`
      );

      // Try to take a screenshot for debugging
      try {
        await this.page.screenshot({ path: "screenshots/no-widget-debug.png" });
        console.log(
          "   → Debug screenshot saved to screenshots/no-widget-debug.png"
        );
      } catch (screenshotError) {
        console.log("   → Could not save debug screenshot");
      }

      throw new Error(
        `Attendance widget (${SELECTORS.ATTENDANCE_WIDGET}) not found on page`
      );
    }

    // Strategy 1: Detection Phase - Check if already swiped via "View Swipes" modal
    const swipeData = await this.viewSwipes();
    
    if (swipeData.hasInSwipe) {
      console.log("✅ Already swiped in - verified via View Swipes");
      if (swipeData.swipeTime) {
        await this.updateStatus("DONE", swipeData.swipeTime);
      }
      return;
    }

    // Strategy 2: Action Phase - Perform Sign In if not already swiped
    try {
      // Use the modular signIn() method
      const signInSuccess = await this.signIn();
      
      if (!signInSuccess) {
        throw new Error("Sign-in failed - could not complete sign-in process");
      }

      // Verify swipe was successful and extract swipe time
      let newSwipeTime = null;
      try {
        await this.page.waitForSelector(`gt-button[name="${SELECTORS.BUTTON_VIEW_SWIPES}"]`, {
          timeout: 3000,
        });
        console.log("   ✓ Swipe confirmed - 'View Swipes' button appeared");

        // Extract the swipe time from View Swipes modal
        const swipeDataAfter = await this.viewSwipes();
        newSwipeTime = swipeDataAfter.swipeTime;
      } catch (e) {
        console.log("   ⚠️ Could not verify swipe completion");
      }

      // Update status with swipe time
      if (newSwipeTime) {
        await this.updateStatus("DONE", newSwipeTime);
      } else {
        // Fallback: use current time if we can't extract from modal
        const currentTime = new Date().toLocaleTimeString("en-US", {
          hour12: false,
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        });
        await this.updateStatus("DONE", currentTime);
      }
    } catch (e) {
      console.log("   ⚠️ Error during sign-in process:", e.message);
      await this.updateStatus("FAILED", `Sign-in error: ${e.message}`);
      throw e;
    }
  }

  async wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
        const attendanceInfo = document.querySelector("gt-attendance-info");
        if (!attendanceInfo) return { hasWidget: false };

        const buttons = Array.from(
          attendanceInfo.querySelectorAll("gt-button")
        );
        const buttonData = buttons.map((btn) => {
          const hasShadowRoot = !!btn.shadowRoot;
          let shadowText = "";
          let shadowHTML = "";
          if (btn.shadowRoot) {
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (shadowButton) {
              shadowText = (
                shadowButton.innerText ||
                shadowButton.textContent ||
                ""
              ).trim();
              shadowHTML = shadowButton.outerHTML.substring(0, 150);
            }
          }
          const regularText = (btn.innerText || btn.textContent || "").trim();
          const shade = btn.getAttribute("shade");
          const name = btn.getAttribute("name");

          return {
            hasShadowRoot,
            shadowText,
            shadowHTML,
            regularText,
            shade,
            name,
          };
        });

        return {
          hasWidget: true,
          buttonCount: buttons.length,
          buttons: buttonData,
        };
      });

      console.log(
        `   → Debug: Found ${buttonInfo.buttonCount} gt-button(s) in attendance widget`
      );
      if (buttonInfo.buttons && buttonInfo.buttons.length > 0) {
        buttonInfo.buttons.forEach((btn, idx) => {
          console.log(`   → Button ${idx + 1}:`);
          console.log(`      - Has shadow DOM: ${btn.hasShadowRoot}`);
          console.log(`      - Shadow text: "${btn.shadowText}"`);
          console.log(`      - Regular text: "${btn.regularText}"`);
          console.log(`      - Shade: "${btn.shade}"`);
          console.log(`      - Name: "${btn.name}"`);
          if (btn.shadowHTML) {
            console.log(`      - Shadow HTML: ${btn.shadowHTML}`);
          }
        });
      }

      // Look for Sign In button inside gt-attendance-info
      // Need to handle both shadow DOM and regular DOM
      const signInBtn = await this.page.evaluateHandle(() => {
        const attendanceInfo = document.querySelector("gt-attendance-info");
        if (!attendanceInfo) return null;

        const buttons = Array.from(
          attendanceInfo.querySelectorAll("gt-button")
        );

        // Find button by checking both:
        // 1. Direct text content (regular DOM)
        // 2. Shadow DOM button text
        for (const btn of buttons) {
          // Check regular DOM text
          let text = (btn.innerText || btn.textContent || "").trim();

          // Check shadow DOM if shadowRoot exists
          if (btn.shadowRoot) {
            const shadowButton = btn.shadowRoot.querySelector("button");
            if (shadowButton) {
              text = (
                shadowButton.innerText ||
                shadowButton.textContent ||
                ""
              ).trim();
            }
          }

          if (text.includes("Sign In") || text.includes("Swipe In")) {
            return btn;
          }
        }

        return null;
      });

      if (signInBtn && signInBtn.asElement()) {
        console.log("   ✓ Found 'Sign In' button.");

        // Try multiple click methods to ensure it works
        try {
          // Method 1: Direct click on shadow button
          await this.page.evaluate(() => {
            const attendanceInfo = document.querySelector("gt-attendance-info");
            if (!attendanceInfo) return false;
            const buttons = Array.from(
              attendanceInfo.querySelectorAll("gt-button")
            );
            for (const btn of buttons) {
              if (btn.shadowRoot) {
                const shadowButton = btn.shadowRoot.querySelector("button");
                if (shadowButton) {
                  const text = (
                    shadowButton.innerText ||
                    shadowButton.textContent ||
                    ""
                  ).trim();
                  if (text.includes("Sign In")) {
                    // Dispatch proper click events
                    shadowButton.dispatchEvent(
                      new MouseEvent("mousedown", { bubbles: true })
                    );
                    shadowButton.dispatchEvent(
                      new MouseEvent("mouseup", { bubbles: true })
                    );
                    shadowButton.dispatchEvent(
                      new MouseEvent("click", { bubbles: true })
                    );
                    shadowButton.click();
                    return true;
                  }
                }
              }
            }
            return false;
          });
          console.log("   ✓ Click events dispatched");
        } catch (clickError) {
          console.log("   ⚠️ Error dispatching events, trying regular click");
          await signInBtn.asElement().click();
        }

        console.log("   ⏳ Waiting 2s for modal to start appearing...");
        await this.wait(2000); // Increased wait before checking for modal

        // COMPREHENSIVE DOM INSPECTION - Find what's ACTUALLY on the page
        console.log(
          "   🔍 COMPREHENSIVE DOM SCAN - Looking for ANY modal-like elements..."
        );
        const domScan = await this.page.evaluate(() => {
          const results = {
            timestamp: new Date().toISOString(),
            allDivs: [],
            modalLikeElements: [],
            allClassesContainingModal: [],
            bodyChildren: [],
            shadowHosts: [],
            highZIndexElements: [],
          };

          // Scan ALL divs in the page
          const allDivs = document.querySelectorAll("div");
          allDivs.forEach((div, idx) => {
            const classes = div.className || "";
            const id = div.id || "";
            const style = div.getAttribute("style") || "";
            const zIndex = window.getComputedStyle(div).zIndex;
            const display = window.getComputedStyle(div).display;
            const visibility = window.getComputedStyle(div).visibility;

            // Collect divs with 'modal', 'popup', 'dialog' in class or id
            if (
              classes.toLowerCase().includes("modal") ||
              classes.toLowerCase().includes("popup") ||
              classes.toLowerCase().includes("dialog") ||
              id.toLowerCase().includes("modal") ||
              id.toLowerCase().includes("popup")
            ) {
              results.modalLikeElements.push({
                tag: "div",
                classes: classes,
                id: id,
                style: style.substring(0, 100),
                zIndex: zIndex,
                display: display,
                visibility: visibility,
                textContent: (div.textContent || "").substring(0, 100),
                innerHTML: (div.innerHTML || "").substring(0, 200),
              });
            }

            // Collect elements with high z-index
            const zIndexNum = parseInt(zIndex);
            if (!isNaN(zIndexNum) && zIndexNum > 1000) {
              results.highZIndexElements.push({
                tag: div.tagName,
                classes: classes,
                id: id,
                zIndex: zIndex,
                display: display,
                visibility: visibility,
                textContent: (div.textContent || "").substring(0, 100),
              });
            }
          });

          // Check for custom elements with shadow roots
          const customElements = document.querySelectorAll("*");
          customElements.forEach((el) => {
            if (el.shadowRoot && el.tagName.includes("-")) {
              results.shadowHosts.push({
                tag: el.tagName,
                classes: el.className,
                hasShadowRoot: true,
              });
            }
          });

          // Get direct children of body
          Array.from(document.body.children).forEach((child) => {
            results.bodyChildren.push({
              tag: child.tagName,
              classes: child.className || "",
              id: child.id || "",
              display: window.getComputedStyle(child).display,
              zIndex: window.getComputedStyle(child).zIndex,
            });
          });

          return results;
        });

        console.log("   📊 DOM SCAN RESULTS:");
        console.log(
          `      - Modal-like elements found: ${domScan.modalLikeElements.length}`
        );
        if (domScan.modalLikeElements.length > 0) {
          domScan.modalLikeElements.forEach((el, idx) => {
            console.log(
              `      ${idx + 1}. ${el.tag}.${el.classes || "(no class)"}`
            );
            console.log(`         ID: ${el.id || "(none)"}`);
            console.log(
              `         Z-Index: ${el.zIndex}, Display: ${el.display}, Visibility: ${el.visibility}`
            );
            console.log(`         Text: "${el.textContent}"`);
            console.log(`         HTML: ${el.innerHTML}`);
          });
        }

        console.log(
          `      - High z-index elements: ${domScan.highZIndexElements.length}`
        );
        if (domScan.highZIndexElements.length > 0) {
          domScan.highZIndexElements.forEach((el, idx) => {
            console.log(
              `      ${idx + 1}. ${el.tag}.${el.classes || "(no class)"} - z:${
                el.zIndex
              }, display:${el.display}, vis:${el.visibility}`
            );
            console.log(`         Text: "${el.textContent}"`);
          });
        }

        console.log(`      - Body children: ${domScan.bodyChildren.length}`);
        domScan.bodyChildren.slice(-5).forEach((el, idx) => {
          console.log(
            `      ${idx + 1}. ${el.tag}.${el.classes || "(no class)"} - z:${
              el.zIndex
            }, display:${el.display}`
          );
        });

        // Handle sign-in location modal if it appears
        try {
          const modalHandled = await this.handleSignInModal();
          if (modalHandled) {
            console.log("   ✓ Sign-in location modal handled successfully");
            console.log("   ⏳ Waiting 3s for swipe to process...");
            await this.wait(3000); // Additional wait after modal submission for swipe to complete
          } else {
            console.log("   ℹ️ No modal appeared within timeout");
            console.log(
              "   ⏳ Waiting 4s for swipe to process without modal..."
            );
            await this.wait(4000); // Wait longer since no modal appeared
          }
        } catch (modalError) {
          console.log(
            "   ❌ Error handling sign-in modal:",
            modalError.message
          );
          await this.updateStatus(
            "FAILED",
            `Modal error: ${modalError.message}`
          );
          throw new Error(
            `Sign-in modal handling failed: ${modalError.message}`
          );
        }

        swiped = true;

        // Verify swipe was successful and extract swipe time
        let newSwipeTime = null;
        try {
          await this.page.waitForSelector('gt-button[name="View Swipes"]', {
            timeout: 3000,
          });
          console.log("   ✓ Swipe confirmed - 'View Swipes' button appeared");

          // Extract the swipe time from the modal
          try {
            const viewSwipesBtnAfter = await this.page.evaluateHandle(() => {
              const attendanceInfo =
                document.querySelector("gt-attendance-info");
              if (!attendanceInfo) return null;
              const buttons = Array.from(
                attendanceInfo.querySelectorAll("gt-button")
              );
              return buttons.find((btn) => {
                const name = btn.getAttribute("name");
                const text = btn.innerText || btn.textContent || "";
                return name === "View Swipes" || text.includes("View Swipes");
              });
            });

            if (viewSwipesBtnAfter && viewSwipesBtnAfter.asElement()) {
              await viewSwipesBtnAfter.asElement().click();
              await this.wait(1500);

              const swipeDataAfter = await this.page.evaluate(() => {
                const modal = document.querySelector("attendance-swipes-modal");
                if (!modal) return { swipeTime: null };
                const rows = Array.from(
                  modal.querySelectorAll("table tbody tr")
                );
                if (rows.length === 0) return { swipeTime: null };

                // Get the most recent row (first row) with "IN"
                for (const row of rows) {
                  const cells = Array.from(row.querySelectorAll("td"));
                  if (cells.length >= 2) {
                    const inOutCell = cells[1];
                    const timeCell = cells[0];
                    const inOutText = (
                      inOutCell.innerText ||
                      inOutCell.textContent ||
                      ""
                    ).trim();
                    if (inOutText === "IN" || inOutText.includes("IN")) {
                      return {
                        swipeTime: (
                          timeCell.innerText ||
                          timeCell.textContent ||
                          ""
                        ).trim(),
                      };
                    }
                  }
                }
                return { swipeTime: null };
              });

              newSwipeTime = swipeDataAfter.swipeTime;

              // Close modal
              try {
                const closeBtn = await this.page.$(
                  "attendance-swipes-modal .close"
                );
                if (closeBtn) await closeBtn.click();
                else await this.page.keyboard.press("Escape");
                await this.wait(500);
              } catch (e) {}
            }
          } catch (e) {
            console.log("   ⚠️ Could not extract swipe time:", e.message);
          }
        } catch (e) {
          console.log("   ⚠️ Could not verify swipe completion");
        }

        // Update status with swipe time
        if (newSwipeTime) {
          await this.updateStatus("DONE", newSwipeTime);
        } else {
          // Fallback: use current time if we can't extract from modal
          const currentTime = new Date().toLocaleTimeString("en-US", {
            hour12: false,
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
          });
          await this.updateStatus("DONE", currentTime);
        }
      } else {
        // Fallback: Try generic button search
        console.log("   → Trying fallback button search...");
        const button = await this.page.evaluateHandle(() => {
          const buttons = Array.from(
            document.querySelectorAll("button, gt-button")
          );
          return buttons.find((b) => {
            const text = (b.innerText || b.textContent || "").trim();
            return text.includes("Sign In") || text.includes("Swipe In");
          });
        });

        if (button && button.asElement()) {
          console.log("   ✓ Found swipe button via generic search");
          await button.asElement().click();
          console.log("   ⏳ Waiting for modal or swipe completion...");
          await this.wait(2500);

          // Handle sign-in location modal if it appears
          try {
            const modalHandled = await this.handleSignInModal();
            if (modalHandled) {
              console.log("   ✓ Sign-in location modal handled successfully");
              await this.wait(2000);
            } else {
              console.log(
                "   ℹ️ No modal appeared, proceeding to verification..."
              );
            }
          } catch (modalError) {
            console.log(
              "   ❌ Error handling sign-in modal:",
              modalError.message
            );
            await this.updateStatus(
              "FAILED",
              `Modal error: ${modalError.message}`
            );
            throw new Error(
              `Sign-in modal handling failed: ${modalError.message}`
            );
          }

          swiped = true;

          // Try to extract swipe time after fallback swipe
          const currentTime = new Date().toLocaleTimeString("en-US", {
            hour12: false,
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
          });
          await this.updateStatus("DONE", currentTime);
        }
      }
    } catch (e) {
      console.log("   ⚠️ Error finding 'Sign In' button:", e.message);
    }

    if (!swiped) {
      console.log(
        "   ⚠️ Could not auto-locate swipe button. Please click it manually if visible."
      );
      await this.wait(5000);
    }

    // CRITICAL: Verify final result and report accurately
    if (swiped) {
      console.log("✅ Swipe action triggered.");
      console.log(
        "   🔍 Verifying swipe success by checking for 'View Swipes' button..."
      );

      // Double-check by verifying "View Swipes" button appeared
      try {
        const verifyInfo = await this.page.evaluate(() => {
          const attendanceInfo = document.querySelector("gt-attendance-info");
          if (!attendanceInfo) return { hasWidget: false };

          const buttons = Array.from(
            attendanceInfo.querySelectorAll("gt-button")
          );
          const buttonData = buttons.map((btn) => {
            const name = btn.getAttribute("name");
            let shadowText = "";
            if (btn.shadowRoot) {
              const shadowButton = btn.shadowRoot.querySelector("button");
              if (shadowButton) {
                shadowText = (
                  shadowButton.innerText ||
                  shadowButton.textContent ||
                  ""
                ).trim();
              }
            }
            return {
              name,
              shadowText,
              isViewSwipes:
                name === "View Swipes" || shadowText.includes("View Swipes"),
            };
          });

          const viewSwipesBtn = buttons.find((btn) => {
            const name = btn.getAttribute("name");
            let shadowText = "";
            if (btn.shadowRoot) {
              const shadowButton = btn.shadowRoot.querySelector("button");
              if (shadowButton) {
                shadowText = (
                  shadowButton.innerText ||
                  shadowButton.textContent ||
                  ""
                ).trim();
              }
            }
            return name === "View Swipes" || shadowText.includes("View Swipes");
          });

          return {
            hasWidget: true,
            buttonCount: buttons.length,
            buttons: buttonData,
            viewSwipesFound: !!viewSwipesBtn,
          };
        });

        console.log(
          `   → Found ${verifyInfo.buttonCount} button(s) after swipe:`
        );
        if (verifyInfo.buttons) {
          verifyInfo.buttons.forEach((btn, idx) => {
            console.log(
              `      ${idx + 1}. name="${btn.name}", text="${
                btn.shadowText
              }", isViewSwipes=${btn.isViewSwipes}`
            );
          });
        }

        if (!verifyInfo.viewSwipesFound) {
          console.log(
            "⚠️ WARNING: Swipe button was clicked but 'View Swipes' did not appear!"
          );
          console.log("   This may indicate the swipe was not successful.");
          await this.updateStatus(
            "FAILED",
            "Swipe button clicked but not verified"
          );
          throw new Error(
            "Swipe verification failed - 'View Swipes' button not found after swipe"
          );
        } else {
          console.log(
            "✅ Swipe verified successfully - 'View Swipes' button confirmed"
          );
        }
      } catch (verifyError) {
        console.log("❌ Swipe verification error:", verifyError.message);
        await this.updateStatus("FAILED", "Swipe verification error");
        throw verifyError;
      }
    } else {
      console.log("❌ FAILED: Swipe action could not be completed.");
      console.log("   Reason: Sign In button not found or not clickable");
      await this.updateStatus("FAILED", "Sign In button not found");
      throw new Error(
        "Swipe failed - Sign In button not found or not accessible"
      );
    }
  }

  async wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  // Helper to safely interact with elements (handles navigation during interaction)
  async safeElementAction(action, retries = 3) {
    for (let i = 0; i < retries; i++) {
      try {
        return await action();
      } catch (error) {
        if (
          error.message.includes("Execution context was destroyed") &&
          i < retries - 1
        ) {
          console.log(
            `   ⚠️  Context destroyed, retrying (${i + 1}/${retries})...`
          );
          await this.wait(1000);
          continue;
        }
        throw error;
      }
    }
  }

  async run() {
    try {
      await this.init();
      await this.navigate();
      await this.login();
      await this.wait(3000);
      await this.swipeIn();

      console.log("\n✅ Automation completed successfully!");
      console.log("   ✓ All tasks verified and confirmed");
      console.log("   Closing in 5 seconds...");
      await this.wait(5000);
      await this.browser.close();
    } catch (error) {
      console.error("\n❌ AUTOMATION FAILED!");
      console.error(`   Error: ${error.message}`);
      console.error(`   Stack: ${error.stack}`);

      // Ensure failure is recorded in Firebase
      try {
        await this.updateStatus("FAILED", error.message);
      } catch (updateError) {
        console.error(
          "   ⚠️ Could not update failure status to Firebase:",
          updateError.message
        );
      }

      if (this.browser) {
        try {
          await this.browser.close();
        } catch (closeError) {
          console.error("   ⚠️ Error closing browser:", closeError.message);
        }
      }

      if (isStandaloneMode) {
        process.exit(1);
      } else {
        throw error; // Re-throw error so server can handle it
      }
    }
  }
}

// Auto-run only if this file is executed directly (not imported)
// This allows: node src/automate-login.js (standalone)
// But prevents auto-run when imported by server.js
if (isStandaloneMode) {
  // Parse command-line arguments for force mode
  // Supports: --force, force=true, or FORCE=true environment variable
  const args = process.argv.slice(2);
  const hasForceFlag = args.includes("--force") || args.includes("force=true");
  const envForce = process.env.FORCE === "true" || process.env.FORCE === "1";
  const force = hasForceFlag || envForce;

  if (force) {
    console.log(
      "⚡ Force mode enabled via command-line argument or environment variable"
    );
  }

  const automation = new GreytHRAutomation(force);
  automation.run().catch(console.error);
}
