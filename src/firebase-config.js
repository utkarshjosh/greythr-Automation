import admin from "firebase-admin";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const serviceAccountPath = path.join(__dirname, "..", "serviceAccountKey.json");

// Track if settings have been applied
let settingsApplied = false;

export const initFirebase = () => {
    if (!fs.existsSync(serviceAccountPath)) {
        const errorMsg = "serviceAccountKey.json not found! Please place your Firebase service account key in the server/ directory.";
        console.error("❌ " + errorMsg);
        console.error("💡 Please place your Firebase service account key in the server/ directory.");
        throw new Error(errorMsg);
    }

    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));

    const isNewApp = !admin.apps.length;
    
    if (isNewApp) {
        try {
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            console.log(`🔥 Firebase initialized for project: ${serviceAccount.project_id}`);
        } catch (error) {
            console.error("❌ Failed to initialize Firebase:", error.message);
            throw error;
        }
    }

    const db = admin.firestore();
    
    // Set Firestore settings only once, and only if we just initialized the app
    if (isNewApp && !settingsApplied) {
        try {
            db.settings({
                ignoreUndefinedProperties: true
            });
            settingsApplied = true;
        } catch (error) {
            // Settings might have been set elsewhere, that's okay
            console.warn("⚠️  Could not set Firestore settings:", error.message);
        }
    }
    
    return db;
};

// Middleware to verify Firebase Auth tokens
export const verifyAuthToken = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: 'Unauthorized',
                message: 'Missing or invalid authorization header. Expected: Bearer <token>'
            });
        }

        const idToken = authHeader.split('Bearer ')[1];
        
        try {
            const decodedToken = await admin.auth().verifyIdToken(idToken);
            req.user = decodedToken; // Attach user info to request
            next();
        } catch (error) {
            console.warn('⚠️ Token verification failed:', error.message);
            return res.status(401).json({
                error: 'Unauthorized',
                message: 'Invalid or expired token'
            });
        }
    } catch (error) {
        console.error('❌ Auth middleware error:', error);
        return res.status(500).json({
            error: 'Internal Server Error',
            message: 'Authentication verification failed'
        });
    }
};
