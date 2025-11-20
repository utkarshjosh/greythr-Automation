// src/notify.js
import admin from 'firebase-admin';
// Firebase will be initialized by server.js or automate-login.js
// No need to initialize here as it's already done elsewhere

/**
 * Sends a simple notification via Firebase Cloud Messaging.
 * Adjust `topic` or `token` as needed.
 */
export async function sendNotification(title, body) {
    try {
        const message = {
            notification: { title, body },
            // Example: send to a topic named "greyt-automation"
            topic: 'greyt-automation',
        };
        const response = await admin.messaging().send(message);
        console.log('📣 Notification sent:', response);
    } catch (err) {
        console.warn('⚠️ Notification failed:', err.message);
    }
}
