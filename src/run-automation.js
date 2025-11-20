// src/run-automation.js
import { GreytHRAutomation } from './automate-login.js';

export async function runAutomation(force = false) {
    const automation = new GreytHRAutomation(force);
    await automation.run();
}
