const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();

/**
 * Cloud Function to migrate existing users to the new user preferences system
 * This function should be called once to migrate all existing users
 */
exports.migrateUserPreferences = functions.https.onRequest(async (req, res) => {
    try {
        console.log('🚀 Starting user preferences migration...');
        
        // Get all users
        const usersSnapshot = await db.collection('users').get();
        console.log(`📊 Found ${usersSnapshot.size} users to migrate`);
        
        let migratedCount = 0;
        let errorCount = 0;
        
        // Process each user
        for (const userDoc of usersSnapshot.docs) {
            try {
                await migrateSingleUser(userDoc.id);
                migratedCount++;
                console.log(`✅ Migrated user: ${userDoc.id}`);
            } catch (error) {
                errorCount++;
                console.error(`❌ Error migrating user ${userDoc.id}:`, error);
            }
        }
        
        console.log(`🎉 Migration complete! Migrated: ${migratedCount}, Errors: ${errorCount}`);
        
        res.json({
            success: true,
            message: 'User preferences migration completed',
            migrated: migratedCount,
            errors: errorCount,
            total: usersSnapshot.size
        });
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * Migrate a single user's preferences
 */
async function migrateSingleUser(userId) {
    const userRef = db.collection('users').doc(userId);
    const preferencesRef = userRef.collection('user-preferences').doc('preferences');
    
    // Check if user already has new preferences
    const existingPrefs = await preferencesRef.get();
    if (existingPrefs.exists) {
        const data = existingPrefs.data();
        if (data.categorizationVersion === '1.0') {
            console.log(`⏭️ User ${userId} already migrated, skipping`);
            return;
        }
    }
    
    // Get old preferences if they exist
    let oldPreferences = null;
    try {
        const oldPrefsDoc = await preferencesRef.get();
        if (oldPrefsDoc.exists) {
            oldPreferences = oldPrefsDoc.data();
        }
    } catch (error) {
        console.log(`📝 No old preferences found for user ${userId}, creating new ones`);
    }
    
    // Create new preferences structure
    const newPreferences = createNewPreferences(userId, oldPreferences);
    
    // Save new preferences
    await preferencesRef.set(newPreferences);
    
    console.log(`💾 Saved new preferences for user ${userId}`);
}

/**
 * Create new preferences structure for a user
 */
function createNewPreferences(userId, oldPreferences) {
    const now = new Date();
    
    // Default categories (user can modify these later)
    const defaultCategories = ["Technology", "Health & Fitness", "Entertainment"];
    
    // Create category preferences
    const selectedCategories = defaultCategories.map(category => ({
        id: generateUUID(),
        category: category,
        weight: 0.5,
        lastInteracted: now
    }));
    
    // Create keyword preferences (5 random keywords from selected categories)
    const selectedKeywords = generateDefaultKeywords(defaultCategories);
    
    return {
        userId: userId,
        selectedCategories: selectedCategories,
        selectedKeywords: selectedKeywords,
        categorizationVersion: "1.0",
        lastUpdated: now,
        createdAt: now
    };
}

/**
 * Generate default keywords for selected categories
 */
function generateDefaultKeywords(categories) {
    // This is a simplified version - in production you'd want to use your AI processor
    const categoryKeywords = {
        "Technology": ["AI", "Machine Learning", "Programming", "Cybersecurity", "Blockchain", "Cloud Computing", "IoT", "Data Science", "Web Development", "Mobile Apps"],
        "Health & Fitness": ["Exercise", "Nutrition", "Mental Health", "Wellness", "Workouts", "Healthy Eating", "Meditation", "Fitness Tips", "Medical News", "Wellness Trends"],
        "Entertainment": ["Movies", "TV Shows", "Celebrity", "Streaming", "Awards", "Behind the Scenes", "Reviews", "Interviews", "Gossip", "Trends"]
    };
    
    const allKeywords = [];
    categories.forEach(category => {
        if (categoryKeywords[category]) {
            allKeywords.push(...categoryKeywords[category]);
        }
    });
    
    // Randomly select 5 keywords
    const shuffled = allKeywords.sort(() => 0.5 - Math.random());
    const selectedKeywordsList = shuffled.slice(0, 5);
    
    return selectedKeywordsList.map(keyword => {
        // Find which category this keyword belongs to
        const category = categories.find(cat => categoryKeywords[cat]?.includes(keyword)) || categories[0];
        
        return {
            id: generateUUID(),
            keyword: keyword,
            weight: 0.5,
            category: category,
            lastInteracted: new Date()
        };
    });
}

/**
 * Generate a simple UUID (for demo purposes)
 */
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

/**
 * Function to migrate a specific user (can be called individually)
 */
exports.migrateSingleUser = functions.https.onCall(async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const userId = context.auth.uid;
    
    try {
        await migrateSingleUser(userId);
        return { success: true, message: 'User preferences migrated successfully' };
    } catch (error) {
        throw new functions.https.HttpsError('internal', 'Migration failed: ' + error.message);
    }
});

/**
 * Function to check migration status
 */
exports.checkMigrationStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const userId = context.auth.uid;
    const userRef = db.collection('users').doc(userId);
    const preferencesRef = userRef.collection('user-preferences').doc('preferences');
    
    try {
        const prefsDoc = await preferencesRef.get();
        
        if (!prefsDoc.exists) {
            return { 
                migrated: false, 
                message: 'No preferences found - user needs migration' 
            };
        }
        
        const data = prefsDoc.data();
        const isMigrated = data.categorizationVersion === '1.0';
        
        return {
            migrated: isMigrated,
            version: data.categorizationVersion || 'unknown',
            message: isMigrated ? 'User already migrated' : 'User needs migration'
        };
        
    } catch (error) {
        throw new functions.https.HttpsError('internal', 'Check failed: ' + error.message);
    }
});
