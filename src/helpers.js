/**
 * Helper utilities for GreytHR automation
 */

export class Logger {
  static info(message) {
    console.log(`ℹ️  ${message}`);
  }

  static success(message) {
    console.log(`✅ ${message}`);
  }

  static error(message) {
    console.log(`❌ ${message}`);
  }

  static warning(message) {
    console.log(`⚠️  ${message}`);
  }

  static debug(message) {
    console.log(`🔍 ${message}`);
  }

  static network(method, url) {
    console.log(`📡 ${method} ${url}`);
  }

  static section(title) {
    console.log(`\n${'='.repeat(60)}`);
    console.log(title);
    console.log('='.repeat(60));
  }
}

export class Timer {
  static async wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  static async waitForCondition(condition, timeout = 30000, interval = 500) {
    const startTime = Date.now();
    while (Date.now() - startTime < timeout) {
      if (await condition()) {
        return true;
      }
      await this.wait(interval);
    }
    throw new Error(`Condition not met within ${timeout}ms`);
  }
}

export class NetworkCapture {
  static isApiCall(url) {
    return url.includes('/api/') || 
           url.includes('/v3/') || 
           url.includes('/v2/') ||
           url.includes('.json');
  }

  static isAuthRelated(url) {
    return url.includes('auth') ||
           url.includes('login') ||
           url.includes('token') ||
           url.includes('jwks') ||
           url.includes('oauth') ||
           url.includes('session');
  }

  static isAttendanceRelated(url) {
    return url.includes('attendance') ||
           url.includes('swipe') ||
           url.includes('punch') ||
           url.includes('checkin') ||
           url.includes('check-in');
  }

  static extractTokens(data) {
    const tokens = {};
    const dataStr = JSON.stringify(data);
    
    // Common token patterns
    const patterns = {
      access_token: /"access_token"\s*:\s*"([^"]+)"/,
      id_token: /"id_token"\s*:\s*"([^"]+)"/,
      refresh_token: /"refresh_token"\s*:\s*"([^"]+)"/,
      token: /"token"\s*:\s*"([^"]+)"/,
      jwt: /"jwt"\s*:\s*"([^"]+)"/
    };

    for (const [key, pattern] of Object.entries(patterns)) {
      const match = dataStr.match(pattern);
      if (match) {
        tokens[key] = match[1];
      }
    }

    return tokens;
  }

  static formatRequest(request) {
    return {
      url: request.url(),
      method: request.method(),
      headers: request.headers(),
      postData: request.postData(),
      resourceType: request.resourceType()
    };
  }

  static async formatResponse(response) {
    let body = null;
    try {
      const contentType = response.headers()['content-type'] || '';
      if (contentType.includes('json') || contentType.includes('text')) {
        body = await response.text();
      }
    } catch (e) {
      body = `[Error: ${e.message}]`;
    }

    return {
      url: response.url(),
      status: response.status(),
      headers: response.headers(),
      body: body
    };
  }
}

export class FormHandler {
  static async findAndFillInput(page, selectors, value, label = 'input') {
    for (const selector of selectors) {
      try {
        const element = await page.$(selector);
        if (element) {
          await element.click();
          await page.keyboard.type(value, { delay: 100 });
          Logger.success(`${label} filled using: ${selector}`);
          return true;
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  static async findAndClickButton(page, selectors, label = 'button') {
    for (const selector of selectors) {
      try {
        const element = await page.$(selector);
        if (element) {
          await element.click();
          Logger.success(`${label} clicked: ${selector}`);
          return true;
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  static async waitForNavigation(page, timeout = 10000) {
    try {
      await page.waitForNavigation({ 
        waitUntil: 'networkidle2',
        timeout 
      });
      return true;
    } catch (e) {
      Logger.warning(`Navigation wait timeout: ${e.message}`);
      return false;
    }
  }
}

export class FileSystem {
  static ensureDir(dirPath) {
    const fs = await import('fs');
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
  }

  static saveJson(filePath, data) {
    const fs = await import('fs');
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  }

  static loadJson(filePath) {
    const fs = await import('fs');
    if (!fs.existsSync(filePath)) {
      return null;
    }
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  }

  static getLatestFile(dirPath, pattern) {
    const fs = await import('fs');
    if (!fs.existsSync(dirPath)) {
      return null;
    }

    const files = fs.readdirSync(dirPath)
      .filter(f => f.match(pattern))
      .map(f => ({
        name: f,
        path: `${dirPath}/${f}`,
        time: fs.statSync(`${dirPath}/${f}`).mtime.getTime()
      }))
      .sort((a, b) => b.time - a.time);

    return files.length > 0 ? files[0] : null;
  }
}


