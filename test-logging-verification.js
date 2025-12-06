
import { GreytHRAutomation } from './src/automate-login.js';

// Mock Firebase
const mockDb = {
    collection: (name) => {
        if (name === 'config') {
            return {
                doc: (docName) => ({
                    get: async () => {
                        if (docName === 'work_location') {
                            return {
                                exists: true,
                                data: () => ({ workLocation: 'Test Office', remarks: 'Test Remarks' })
                            };
                        }
                        return { exists: false };
                    }
                })
            };
        }
        if (name === 'daily_logs') {
            return {
                doc: (docName) => ({
                    set: async (data, options) => {
                        console.log('--- Mock Firestore Set ---');
                        console.log(`Doc: ${docName}`);
                        console.log('Data:', JSON.stringify(data, null, 2));
                        console.log('Options:', options);
                        console.log('--------------------------');

                        if (data.workLocation === 'Test Office') {
                            console.log('✅ Verification SUCCESS: workLocation is present and correct.');
                        } else {
                            console.error('❌ Verification FAILED: workLocation is missing or incorrect.');
                            process.exit(1);
                        }
                    },
                    get: async () => ({ exists: false }) // Mock get for checkStatus
                })
            };
        }
        return { doc: () => ({ get: async () => ({ exists: false }) }) };
    }
};

// Mock initFirebase
const mockInitFirebase = () => mockDb;

// Override initFirebase in the module context (this is tricky with ES modules without a proper mock loader)
// Instead, we'll instantiate the class and manually inject the db property since we modified the class to use this.db

async function runTest() {
    console.log('🚀 Starting Verification Test...');

    const automation = new GreytHRAutomation();

    // Manually inject the mock DB
    automation.db = mockDb;

    // Mock getTodayDateString to return a fixed date
    automation.getTodayDateString = () => "2025-12-06";

    // Mock isBeforeInitialDate to always return false
    automation.isBeforeInitialDate = () => false;

    console.log('Testing updateStatus with DONE status...');
    await automation.updateStatus('DONE', '10:00 AM');

    console.log('Test completed.');
}

runTest().catch(console.error);
