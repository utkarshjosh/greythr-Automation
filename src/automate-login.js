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

// Check if running standalone (not imported as a module)
const isStandaloneMode =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(__filename);

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

  getTodayDateString() {
    const date = new Date();
    return date.toISOString().split("T")[0]; // YYYY-MM-DD
  }

  async checkStatus() {
    // If force mode is enabled, skip the check
    if (this.force) {
      console.log("⚡ Force mode enabled - bypassing status check");
      return false;
    }

    if (!this.db) return false;

    const today = this.getTodayDateString();
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
      }
    } catch (error) {
      console.error("❌ Error checking status:", error.message);
    }
    return false;
  }

  async updateStatus(status, swipeTime = null) {
    if (!this.db) {
      console.warn("⚠️  Firebase not initialized, skipping status update");
      return;
    }

    const today = this.getTodayDateString();
    try {
      const updateData = {
        status: status,
        timestamp: new Date().toISOString(),
        empId: this.empId,
      };

      // Add swipe time if provided
      if (swipeTime) {
        updateData.swipeTime = swipeTime;
        console.log(`   📅 Swipe time recorded: ${swipeTime}`);
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
          ]
        : ["--start-maximized", "--no-sandbox", "--disable-setuid-sandbox"],
    });

    this.page = await this.browser.newPage();

    this.page.on("console", (msg) => {
      if (msg.type() === "error") {
        console.log(`[PAGE ERROR]:`, msg.text());
      }
    });
  }

  async navigate() {
    console.log(`🌐 Navigating to ${this.baseUrl}...`);
    await this.page.goto(this.baseUrl, {
      waitUntil: "networkidle2",
      timeout: 60000,
    });
    console.log("✅ Page loaded\n");
    await this.wait(2000);
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

    await this.page.waitForSelector("input", { timeout: 10000 });

    // Employee ID
    const empIdSelectors = [
      'input[name="username"]',
      'input[name="employeeId"]',
      'input[id="username"]',
      'input[type="text"]',
    ];

    let empIdFilled = false;
    for (const selector of empIdSelectors) {
      const element = await this.page.$(selector);
      if (element) {
        await element.click();
        await this.page.keyboard.type(this.empId, { delay: 50 });
        empIdFilled = true;
        break;
      }
    }

    if (!empIdFilled) throw new Error("Could not find employee ID field");

    // Password
    const passwordSelectors = [
      'input[name="password"]',
      'input[type="password"]',
      'input[id="password"]',
    ];
    let passwordFilled = false;
    for (const selector of passwordSelectors) {
      const element = await this.page.$(selector);
      if (element) {
        await element.click();
        await this.page.keyboard.type(this.password, { delay: 50 });
        passwordFilled = true;
        break;
      }
    }

    if (!passwordFilled) throw new Error("Could not find password field");

    // Submit
    const submitSelectors = [
      'button[type="submit"]',
      'button:has-text("Login")',
      'button:has-text("Sign In")',
    ];
    let submitted = false;
    for (const selector of submitSelectors) {
      const element = await this.page.$(selector);
      if (element) {
        await element.click();
        submitted = true;
        break;
      }
    }

    if (!submitted) {
      await this.page.keyboard.press("Enter");
    }

    await this.page
      .waitForNavigation({ waitUntil: "networkidle2", timeout: 15000 })
      .catch(() => console.log("   ⚠️ Navigation timeout, checking URL..."));

    const currentUrl = this.page.url();
    if (currentUrl.includes("dashboard") || currentUrl.includes("home")) {
      console.log("✅ Login successful!\n");
    } else {
      throw new Error("Login might have failed");
    }
  }

  async loginStrategy2() {
    // Simplified backup strategy
    console.log("   → Strategy 2: XPath");
    const [empIdInput] = await this.page.$x(
      '//input[@type="text" or @name="username"]'
    );
    if (empIdInput) await empIdInput.type(this.empId);

    const [passInput] = await this.page.$x('//input[@type="password"]');
    if (passInput) await passInput.type(this.password);

    const [submitBtn] = await this.page.$x('//button[@type="submit"]');
    if (submitBtn) await submitBtn.click();
    else await this.page.keyboard.press("Enter");

    await this.wait(5000);
  }

  async loginStrategy3() {
    // Fallback
    console.log("   → Strategy 3: Generic Inputs");
    const inputs = await this.page.$$("input");
    if (inputs.length >= 2) {
      await inputs[0].type(this.empId);
      await inputs[1].type(this.password);
      await this.page.keyboard.press("Enter");
    }
    await this.wait(5000);
  }

  async swipeIn() {
    console.log("⏰ Attempting swipe-in...");

    // Wait for dashboard to fully load
    await this.wait(5000);

    // Wait for attendance widget to appear
    try {
      await this.page.waitForSelector("gt-attendance-info", { timeout: 10000 });
      console.log("   ✓ Attendance widget loaded");
    } catch (e) {
      console.log("   ⚠️ Attendance widget not found:", e.message);
    }

    // Strategy 1: Detection Phase - Check if already swiped via "View Swipes" modal
    try {
      console.log("   🔍 Checking swipe status via modal...");

      // Look for "View Swipes" button inside gt-attendance-info
      // Handle shadow DOM by using evaluateHandle to find the button
      const viewSwipesBtn = await this.page.evaluateHandle(() => {
        const attendanceInfo = document.querySelector("gt-attendance-info");
        if (!attendanceInfo) return null;

        // Find button with name="View Swipes" - check both attribute and text content
        const buttons = Array.from(
          attendanceInfo.querySelectorAll("gt-button")
        );
        return buttons.find((btn) => {
          const name = btn.getAttribute("name");
          const text = btn.innerText || btn.textContent || "";
          return name === "View Swipes" || text.includes("View Swipes");
        });
      });

      if (viewSwipesBtn && viewSwipesBtn.asElement()) {
        console.log("   ✓ 'View Swipes' button found. Opening modal...");

        // Click the button (handles shadow DOM)
        await viewSwipesBtn.asElement().click();
        await this.wait(1000);

        // Wait for modal to appear
        await this.page.waitForSelector("attendance-swipes-modal", {
          timeout: 5000,
        });
        await this.wait(1500); // Give table time to render

        // Check for "IN" in the 2nd column and extract swipe time from 1st column
        const swipeData = await this.page.evaluate(() => {
          const modal = document.querySelector("attendance-swipes-modal");
          if (!modal) return { hasInSwipe: false, swipeTime: null };

          const rows = Array.from(modal.querySelectorAll("table tbody tr"));
          if (rows.length === 0) return { hasInSwipe: false, swipeTime: null };

          // Find the row with "IN" in the 2nd column and extract time from 1st column
          for (const row of rows) {
            const cells = Array.from(row.querySelectorAll("td"));
            if (cells.length >= 2) {
              const inOutCell = cells[1]; // 2nd column (In/Out)
              const timeCell = cells[0]; // 1st column (Swipe Time)
              const inOutText = (
                inOutCell.innerText ||
                inOutCell.textContent ||
                ""
              ).trim();

              if (inOutText === "IN" || inOutText.includes("IN")) {
                const swipeTime = (
                  timeCell.innerText ||
                  timeCell.textContent ||
                  ""
                ).trim();
                return { hasInSwipe: true, swipeTime: swipeTime };
              }
            }
          }

          return { hasInSwipe: false, swipeTime: null };
        });

        // Close modal
        try {
          const closeBtn = await this.page.$("attendance-swipes-modal .close");
          if (closeBtn) {
            await closeBtn.click();
            await this.wait(500);
          }
        } catch (err) {
          console.log("   ⚠️ Could not close modal:", err.message);
          // Try pressing Escape as fallback
          await this.page.keyboard.press("Escape");
          await this.wait(500);
        }

        if (swipeData.hasInSwipe) {
          console.log("✅ Verified 'IN' swipe from modal.");
          if (swipeData.swipeTime) {
            console.log(`   ⏰ Swipe time: ${swipeData.swipeTime}`);
          }
          await this.updateStatus("DONE", swipeData.swipeTime);
          return;
        } else {
          console.log(
            "   ℹ️ 'View Swipes' found but no 'IN' entry detected in modal."
          );
          console.log("   → Proceeding to swipe in...");
        }
      } else {
        console.log(
          "   ℹ️ 'View Swipes' button not found. User likely hasn't swiped yet."
        );
      }
    } catch (e) {
      console.log("   ⚠️ Error checking 'View Swipes':", e.message);
      console.log("   → Proceeding to swipe in...");
    }

    // Strategy 2: Action Phase - Perform Swipe In if not already swiped
    let swiped = false;
    try {
      console.log("   🔍 Looking for 'Sign In' button...");

      // Look for Sign In button inside gt-attendance-info
      const signInBtn = await this.page.evaluateHandle(() => {
        const attendanceInfo = document.querySelector("gt-attendance-info");
        if (!attendanceInfo) return null;

        const buttons = Array.from(
          attendanceInfo.querySelectorAll("gt-button")
        );
        return buttons.find((btn) => {
          const text = (btn.innerText || btn.textContent || "").trim();
          return text.includes("Sign In") || text.includes("Swipe In");
        });
      });

      if (signInBtn && signInBtn.asElement()) {
        console.log("   ✓ Found 'Sign In' button.");
        await signInBtn.asElement().click();
        swiped = true;
        await this.wait(2000); // Wait for swipe to process

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
          swiped = true;
          await this.wait(2000);

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

    if (swiped) {
      console.log("✅ Swipe action triggered.");
      // Status already updated above with swipe time
    } else {
      console.log("❌ Swipe action failed or not found.");
    }
  }

  async wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async run() {
    try {
      await this.init();
      await this.navigate();
      await this.login();
      await this.wait(3000);
      await this.swipeIn();

      console.log("\n✅ Automation completed!");
      console.log("   Closing in 5 seconds...");
      await this.wait(5000);
      await this.browser.close();
    } catch (error) {
      console.error("\n❌ Automation failed:", error.message);
      if (this.browser) await this.browser.close();
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
  const automation = new GreytHRAutomation();
  automation.run().catch(console.error);
}
