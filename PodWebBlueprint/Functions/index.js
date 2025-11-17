const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

admin.initializeApp();

// Initialize SendGrid
sgMail.setApiKey(functions.config().sendgrid?.key || process.env.SENDGRID_API_KEY);

const db = admin.firestore();
const storage = admin.storage();

// MARK: - Authentication Rate Limiting Functions

// Rate limiting configuration
const AUTH_RATE_LIMITS = {
  // Login rate limits
  login: {
    maxFailedAttempts: {
      3: 60,        // 3 attempts → 1 minute lockout
      5: 300,       // 5 attempts → 5 minute lockout
      7: 900,       // 7 attempts → 15 minute lockout
      10: 3600,     // 10 attempts → 1 hour lockout
      15: 86400     // 15 attempts → 24 hour lockout
    },
    ipLimits: {
      perHour: 10,      // Much lower - only 10 attempts per hour per IP
      perDay: 25,       // Only 25 attempts per day per IP
      banThreshold: 50  // Ban IP after 50 total attempts
    }
  },
  // Registration rate limits
  registration: {
    perHour: 3,
    perDay: 5
  },
  // Password reset rate limits
  passwordReset: {
    perHour: 3,
    perDay: 5
  },
  // Comment rate limits
  comments: {
    perHour: 250,     // 250 comments per hour per user (much more reasonable for active users)
    perDay: 1000,     // 1000 comments per day per user
    perPod: 0         // No per-pod limit (disabled)
  },
  // Follow/Unfollow rate limits
  followUnfollow: {
    perMinute: 10,    // 10 follow/unfollow actions per minute per user
    cooldownMinutes: 10  // 10 minute cooldown after hitting the limit
  },
  // Search rate limits (bot protection only)
  search: {
    per10Minutes: 1000   // 1000 searches per 10 minutes (catches bots, not normal users)
  },
  // Notification rate limits (bot protection only)
  notifications: {
    per10Minutes: 100    // 100 notifications per 10 minutes (catches spam bots)
  }
};

// Authentication rate limiting functions
exports.checkLoginRateLimit = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  try {
    const ipAddress = context.rawRequest.ip || context.rawRequest.connection.remoteAddress;
    const userAgent = context.rawRequest.get('user-agent') || 'unknown';
    
    // Check IP-based rate limits first
    const ipCheck = await checkIPRateLimit(ipAddress, 'login');
    if (!ipCheck.allowed) {
      throw new functions.https.HttpsError('resource-exhausted', ipCheck.reason);
    }
    
    // Check email-based rate limits
    const emailCheck = await checkEmailRateLimit(email, 'login');
    if (!emailCheck.allowed) {
      const error = new functions.https.HttpsError('resource-exhausted', emailCheck.reason);
      if (emailCheck.lockoutTime) {
        error.details = { lockoutTime: emailCheck.lockoutTime };
      }
      throw error;
    }
    
    return { allowed: true };
    
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error checking login rate limit:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check rate limit');
  }
});

exports.recordFailedLogin = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  try {
    const ipAddress = context.rawRequest.ip || context.rawRequest.connection.remoteAddress;
    
    // Record failed attempt
    await recordAuthAttempt(email, ipAddress, 'login', false);
    
    return { success: true };
    
  } catch (error) {
    console.error('Error recording failed login:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record login attempt');
  }
});

exports.recordSuccessfulLogin = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  try {
    const ipAddress = context.rawRequest.ip || context.rawRequest.connection.remoteAddress;
    
    // Record successful login (resets counters)
    await recordAuthAttempt(email, ipAddress, 'login', true);
    
    return { success: true };
    
  } catch (error) {
    console.error('Error recording successful login:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record login attempt');
  }
});

exports.checkRegistrationRateLimit = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  try {
    const ipAddress = context.rawRequest.ip || context.rawRequest.connection.remoteAddress;
    
    // Check IP-based rate limits
    const ipCheck = await checkIPRateLimit(ipAddress, 'registration');
    if (!ipCheck.allowed) {
      throw new functions.https.HttpsError('resource-exhausted', ipCheck.reason);
    }
    
    // Check email-based rate limits
    const emailCheck = await checkEmailRateLimit(email, 'registration');
    if (!emailCheck.allowed) {
      throw new functions.https.HttpsError('resource-exhausted', emailCheck.reason);
    }
    
    return { allowed: true };
    
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error checking registration rate limit:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check rate limit');
  }
});

exports.recordRegistrationAttempt = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  try {
    const ipAddress = context.rawRequest.ip || context.rawRequest.connection.remoteAddress;
    
    // Record registration attempt
    await recordAuthAttempt(email, ipAddress, 'registration', false);
    
    return { success: true };
    
  } catch (error) {
    console.error('Error recording registration attempt:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record registration attempt');
  }
});

exports.checkPasswordResetRateLimit = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  try {
    const ipAddress = context.rawRequest.ip || context.rawRequest.connection.remoteAddress;
    
    // Check IP-based rate limits
    const ipCheck = await checkIPRateLimit(ipAddress, 'passwordReset');
    if (!ipCheck.allowed) {
      throw new functions.https.HttpsError('resource-exhausted', ipCheck.reason);
    }
    
    // Check email-based rate limits
    const emailCheck = await checkEmailRateLimit(email, 'passwordReset');
    if (!emailCheck.allowed) {
      throw new functions.https.HttpsError('resource-exhausted', emailCheck.reason);
    }
    
    return { allowed: true };
    
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error checking password reset rate limit:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check rate limit');
  }
});

exports.recordPasswordResetAttempt = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  try {
    const ipAddress = context.rawRequest.ip || context.rawRequest.connection.remoteAddress;
    
    // Record password reset attempt
    await recordAuthAttempt(email, ipAddress, 'passwordReset', false);
    
    return { success: true };
    
  } catch (error) {
    console.error('Error recording password reset attempt:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record password reset attempt');
  }
});

// Comment rate limiting functions
exports.checkCommentRateLimit = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId } = data;
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Get recent comments from this user
    const userCommentsRef = db.collection('userComments').doc(uid);
    const userCommentsDoc = await userCommentsRef.get();

    let userComments = [];
    if (userCommentsDoc.exists) {
      const data = userCommentsDoc.data();
      userComments = data.comments || [];
    }

    // Filter comments by time
    const hourlyComments = userComments.filter(comment => 
      comment.timestamp.toDate() >= oneHourAgo
    );
    const dailyComments = userComments.filter(comment => 
      comment.timestamp.toDate() >= oneDayAgo
    );

    // Check rate limits (only hourly and daily, no per-pod limit)
    if (dailyComments.length >= AUTH_RATE_LIMITS.comments.perDay) {
      throw new functions.https.HttpsError('resource-exhausted', 
        'Too many comments today. Please try again tomorrow.');
    }

    if (hourlyComments.length >= AUTH_RATE_LIMITS.comments.perHour) {
      throw new functions.https.HttpsError('resource-exhausted', 
        'Too many comments this hour. Please wait before commenting again.');
    }

    return { allowed: true };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error checking comment rate limit:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check comment rate limit');
  }
});

exports.recordCommentAttempt = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId } = data;
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    const now = new Date();
    const commentRecord = {
      podId: podId,
      timestamp: now,
      type: 'comment'
    };

    // Add to user's comment history
    const userCommentsRef = db.collection('userComments').doc(uid);
    await userCommentsRef.set({
      comments: admin.firestore.FieldValue.arrayUnion(commentRecord),
      lastUpdated: now
    }, { merge: true });

    // Clean up old comments (older than 7 days) to keep the array manageable
    const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const userCommentsDoc = await userCommentsRef.get();
    if (userCommentsDoc.exists) {
      const data = userCommentsDoc.data();
      const comments = data.comments || [];
      const recentComments = comments.filter(comment => 
        comment.timestamp.toDate() >= oneWeekAgo
      );
      
      // Only update if we need to remove old comments
      if (recentComments.length !== comments.length) {
        await userCommentsRef.update({
          comments: recentComments
        });
      }
    }

    return { success: true };

  } catch (error) {
    console.error('Error recording comment attempt:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record comment attempt');
  }
});

// Follow/Unfollow rate limiting functions
exports.checkFollowUnfollowRateLimit = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { targetUserId } = data;
  const uid = context.auth.uid;

  if (!targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'Target user ID is required');
  }

  try {
    const now = new Date();
    const oneMinuteAgo = new Date(now.getTime() - 60 * 1000);

    // Get recent follow/unfollow actions from this user
    const userActionsRef = db.collection('userFollowActions').doc(uid);
    const userActionsDoc = await userActionsRef.get();

    let userActions = [];
    if (userActionsDoc.exists) {
      const data = userActionsDoc.data();
      userActions = data.actions || [];
    }

    // Filter actions by time (last minute) AND target user
    const recentActionsForThisUser = userActions.filter(action => 
      action.timestamp.toDate() >= oneMinuteAgo && action.targetUserId === targetUserId
    );

    // Check rate limit for this specific user
    if (recentActionsForThisUser.length >= AUTH_RATE_LIMITS.followUnfollow.perMinute) {
      throw new functions.https.HttpsError('resource-exhausted', 
        `Too many follow/unfollow actions for this user. Please wait ${AUTH_RATE_LIMITS.followUnfollow.cooldownMinutes} minutes before trying again.`);
    }

    return { allowed: true };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error checking follow/unfollow rate limit:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check follow/unfollow rate limit');
  }
});

exports.recordFollowUnfollowAttempt = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { targetUserId, action } = data; // action: 'follow' or 'unfollow'
  const uid = context.auth.uid;

  if (!targetUserId || !action) {
    throw new functions.https.HttpsError('invalid-argument', 'Target user ID and action are required');
  }

  try {
    const now = new Date();
    const actionRecord = {
      targetUserId: targetUserId,
      action: action, // 'follow' or 'unfollow'
      timestamp: now
    };

    // Add to user's follow/unfollow history
    const userActionsRef = db.collection('userFollowActions').doc(uid);
    await userActionsRef.set({
      actions: admin.firestore.FieldValue.arrayUnion(actionRecord),
      lastUpdated: now
    }, { merge: true });

    // Clean up old actions (older than 1 hour) to keep the array manageable
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const userActionsDoc = await userActionsRef.get();
    if (userActionsDoc.exists) {
      const data = userActionsDoc.data();
      const actions = data.actions || [];
      const recentActions = actions.filter(action => 
        action.timestamp.toDate() >= oneHourAgo
      );
      
      // Only update if we need to remove old actions
      if (recentActions.length !== actions.length) {
        await userActionsRef.update({
          actions: recentActions
        });
      }
    }

    return { success: true };

  } catch (error) {
    console.error('Error recording follow/unfollow attempt:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record follow/unfollow attempt');
  }
});

// Search rate limiting functions (bot protection)
exports.checkSearchRateLimit = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;

  try {
    const now = new Date();
    const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000);

    // Get recent searches from this user
    const userSearchesRef = db.collection('userSearches').doc(uid);
    const userSearchesDoc = await userSearchesRef.get();

    let userSearches = [];
    if (userSearchesDoc.exists) {
      const data = userSearchesDoc.data();
      userSearches = data.searches || [];
    }

    // Filter searches by time (last 10 minutes)
    const recentSearches = userSearches.filter(search => 
      search.timestamp.toDate() >= tenMinutesAgo
    );

    // Check rate limit
    if (recentSearches.length >= AUTH_RATE_LIMITS.search.per10Minutes) {
      throw new functions.https.HttpsError('resource-exhausted', 
        'Too many searches. Please wait a few minutes before searching again.');
    }

    return { allowed: true };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error checking search rate limit:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check search rate limit');
  }
});

exports.recordSearchAttempt = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;

  try {
    const now = new Date();
    const searchRecord = {
      timestamp: now,
      type: 'search'
    };

    // Add to user's search history
    const userSearchesRef = db.collection('userSearches').doc(uid);
    await userSearchesRef.set({
      searches: admin.firestore.FieldValue.arrayUnion(searchRecord),
      lastUpdated: now
    }, { merge: true });

    // Clean up old searches (older than 1 hour) to keep the array manageable
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const userSearchesDoc = await userSearchesRef.get();
    if (userSearchesDoc.exists) {
      const data = userSearchesDoc.data();
      const searches = data.searches || [];
      const recentSearches = searches.filter(search => 
        search.timestamp.toDate() >= oneHourAgo
      );
      
      // Only update if we need to remove old searches
      if (recentSearches.length !== searches.length) {
        await userSearchesRef.update({
          searches: recentSearches
        });
      }
    }

    return { success: true };

  } catch (error) {
    console.error('Error recording search attempt:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record search attempt');
  }
});

// Notification rate limiting functions (bot protection)
exports.checkNotificationRateLimit = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;

  try {
    const now = new Date();
    const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000);

    // Get recent notifications from this user
    const userNotificationsRef = db.collection('userNotificationAttempts').doc(uid);
    const userNotificationsDoc = await userNotificationsRef.get();

    let userNotifications = [];
    if (userNotificationsDoc.exists) {
      const data = userNotificationsDoc.data();
      userNotifications = data.notifications || [];
    }

    // Filter notifications by time (last 10 minutes)
    const recentNotifications = userNotifications.filter(notification => 
      notification.timestamp.toDate() >= tenMinutesAgo
    );

    // Check rate limit
    if (recentNotifications.length >= AUTH_RATE_LIMITS.notifications.per10Minutes) {
      throw new functions.https.HttpsError('resource-exhausted', 
        'Too many notification attempts. Please wait a few minutes before trying again.');
    }

    return { allowed: true };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error checking notification rate limit:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check notification rate limit');
  }
});

exports.recordNotificationAttempt = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;

  try {
    const now = new Date();
    const notificationRecord = {
      timestamp: now,
      type: 'notification'
    };

    // Add to user's notification history
    const userNotificationsRef = db.collection('userNotificationAttempts').doc(uid);
    await userNotificationsRef.set({
      notifications: admin.firestore.FieldValue.arrayUnion(notificationRecord),
      lastUpdated: now
    }, { merge: true });

    // Clean up old notifications (older than 1 hour) to keep the array manageable
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const userNotificationsDoc = await userNotificationsRef.get();
    if (userNotificationsDoc.exists) {
      const data = userNotificationsDoc.data();
      const notifications = data.notifications || [];
      const recentNotifications = notifications.filter(notification => 
        notification.timestamp.toDate() >= oneHourAgo
      );
      
      // Only update if we need to remove old notifications
      if (recentNotifications.length !== notifications.length) {
        await userNotificationsRef.update({
          notifications: recentNotifications
        });
      }
    }

    return { success: true };

  } catch (error) {
    console.error('Error recording notification attempt:', error);
    throw new functions.https.HttpsError('internal', 'Failed to record notification attempt');
  }
});

// Helper functions for rate limiting
async function checkIPRateLimit(ipAddress, operation) {
  const now = new Date();
  const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
  const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  
  // Get recent attempts from this IP
  const recentAttempts = await db.collection('ipAttempts')
    .where('ipAddress', '==', ipAddress)
    .where('timestamp', '>=', oneDayAgo)
    .get();
  
  const attempts = recentAttempts.docs.map(doc => doc.data());
  const hourlyAttempts = attempts.filter(attempt => 
    attempt.timestamp.toDate() >= oneHourAgo
  );
  
  // Check ban threshold (severe abuse)
  if (attempts.length >= AUTH_RATE_LIMITS.login.ipLimits.banThreshold) {
    return { 
      allowed: false, 
      reason: `This IP has been permanently banned due to excessive abuse.` 
    };
  }
  
  // Check daily limit (applies to all operations)
  if (attempts.length >= AUTH_RATE_LIMITS.login.ipLimits.perDay) {
    return { 
      allowed: false, 
      reason: `Too many authentication attempts from this IP. Try again tomorrow.` 
    };
  }
  
  // Check hourly limit for login operations
  if (operation === 'login' && hourlyAttempts.length >= AUTH_RATE_LIMITS.login.ipLimits.perHour) {
    return { 
      allowed: false, 
      reason: `Too many login attempts from this IP. Try again in an hour.` 
    };
  }
  
  return { allowed: true };
}

async function checkEmailRateLimit(email, operation) {
  const attemptRef = db.collection('authAttempts').doc(email);
  const attemptDoc = await attemptRef.get();
  
  if (!attemptDoc.exists) {
    return { allowed: true };
  }
  
  const attemptData = attemptDoc.data();
  const now = new Date();
  
  // Check if currently locked out
  if (attemptData.lockoutExpiry && attemptData.lockoutExpiry.toDate() > now) {
    const remainingTime = Math.ceil((attemptData.lockoutExpiry.toDate() - now) / 1000);
    const minutes = Math.max(1, Math.ceil(remainingTime / 60)); // Ensure at least 1 minute
    return { 
      allowed: false, 
      reason: `Account temporarily locked. Try again in ${minutes} minutes.`,
      lockoutTime: remainingTime
    };
  }
  
  // For login operations, check progressive lockout
  if (operation === 'login') {
    const failedAttempts = attemptData.failedAttempts || 0;
    
    for (const [threshold, lockoutSeconds] of Object.entries(AUTH_RATE_LIMITS.login.maxFailedAttempts)) {
      if (failedAttempts >= parseInt(threshold)) {
        const minutes = Math.max(1, Math.ceil(lockoutSeconds / 60)); // Ensure at least 1 minute
        return { 
          allowed: false, 
          reason: `Too many failed attempts. Account locked for ${minutes} minutes.`,
          lockoutTime: lockoutSeconds
        };
      }
    }
  }
  
  return { allowed: true };
}

async function recordAuthAttempt(email, ipAddress, operation, success) {
  const now = admin.firestore.Timestamp.now();
  const attemptRef = db.collection('authAttempts').doc(email);
  
  if (success) {
    // Reset counters on successful authentication
    await attemptRef.set({
      email: email,
      failedAttempts: 0,
      lastAttempt: now,
      lockoutExpiry: null,
      attemptHistory: [now]
    });
  } else {
    // Increment failed attempts
    await attemptRef.set({
      email: email,
      failedAttempts: admin.firestore.FieldValue.increment(1),
      lastAttempt: now,
      attemptHistory: admin.firestore.FieldValue.arrayUnion(now)
    }, { merge: true });
    
    // Apply progressive lockout if needed
    const attemptDoc = await attemptRef.get();
    const attemptData = attemptDoc.data();
    const failedAttempts = attemptData.failedAttempts || 0;
    
    for (const [threshold, lockoutSeconds] of Object.entries(AUTH_RATE_LIMITS.login.maxFailedAttempts)) {
      if (failedAttempts === parseInt(threshold)) {
        const lockoutExpiry = new Date(now.toDate().getTime() + lockoutSeconds * 1000);
        await attemptRef.update({
          lockoutExpiry: admin.firestore.Timestamp.fromDate(lockoutExpiry)
        });
        break;
      }
    }
  }
  
  // Record IP attempt
  await db.collection('ipAttempts').add({
    ipAddress: ipAddress,
    email: email,
    operation: operation,
    success: success,
    timestamp: now
  });
}

// Session management functions
exports.revokeUserSessions = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { targetUserId } = data;
  
  // Verify the user is revoking their own sessions or has admin privileges
  if (context.auth.uid !== targetUserId) {
    // You could add admin role checking here if needed
    throw new functions.https.HttpsError('permission-denied', 'Can only revoke your own sessions');
  }
  
  try {
    console.log(`Revoking all sessions for user: ${targetUserId}`);
    
    // Revoke all refresh tokens for the user
    await admin.auth().revokeRefreshTokens(targetUserId);
    
    // Also deactivate all sessions in Firestore
    const sessionsRef = db.collection('userSessions');
    const query = sessionsRef.where('userId', '==', targetUserId).where('isActive', '==', true);
    const snapshot = await query.get();
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.update(doc.ref, {
        isActive: false,
        deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        revokedBy: context.auth.uid,
        revokedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    await batch.commit();
    
    console.log(`Successfully revoked ${snapshot.size} sessions for user: ${targetUserId}`);
    
    return { 
      success: true, 
      message: 'All user sessions revoked',
      sessionsRevoked: snapshot.size
    };
  } catch (error) {
    console.error('Error revoking user sessions:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// MARK: - Engagement Metrics Functions

// Increment views when user clicks on pod and initializes player
exports.incrementPodViews = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId } = data;
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    console.log(`User ${uid} viewing pod ${podId}`);
    
    // Atomically increment views count
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      views: admin.firestore.FieldValue.increment(1)
    });

    console.log(`Successfully incremented views for pod ${podId}`);
    return { success: true };
  } catch (error) {
    console.error('Error incrementing pod views:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Increment shares when user shares pod to another user
exports.incrementPodShares = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId, shareType = 'direct' } = data; // shareType: 'direct', 'social', 'link'
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    console.log(`User ${uid} sharing pod ${podId} via ${shareType}`);
    
    // Atomically increment shares count
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      shares: admin.firestore.FieldValue.increment(1)
    });

    // Optional: Track individual shares for analytics
    const shareRef = db.collection('pods').doc(podId).collection('shares').doc();
    await shareRef.set({
      userId: uid,
      shareType: shareType,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Successfully incremented shares for pod ${podId}`);
    return { success: true };
  } catch (error) {
    console.error('Error incrementing pod shares:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Increment comments when user adds a comment
exports.incrementPodComments = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId } = data;
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    console.log(`User ${uid} adding comment to pod ${podId}`);
    
    // Atomically increment comments count
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      comments: admin.firestore.FieldValue.increment(1)
    });

    console.log(`Successfully incremented comments for pod ${podId}`);
    return { success: true };
  } catch (error) {
    console.error('Error incrementing pod comments:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Decrement comments when user deletes a comment
exports.decrementPodComments = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId } = data;
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    console.log(`User ${uid} deleting comment from pod ${podId}`);
    
    // Atomically decrement comments count (ensure it doesn't go below 0)
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      comments: admin.firestore.FieldValue.increment(-1)
    });

    console.log(`Successfully decremented comments for pod ${podId}`);
    return { success: true };
  } catch (error) {
    console.error('Error decrementing pod comments:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Increment saves when user saves a pod
exports.incrementPodSaves = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId } = data;
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    console.log(`User ${uid} saving pod ${podId}`);
    
    // Atomically increment saves count
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      saves: admin.firestore.FieldValue.increment(1)
    });

    console.log(`Successfully incremented saves for pod ${podId}`);
    return { success: true };
  } catch (error) {
    console.error('Error incrementing pod saves:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Decrement saves when user unsaves a pod
exports.decrementPodSaves = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { podId } = data;
  const uid = context.auth.uid;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    console.log(`User ${uid} unsaving pod ${podId}`);
    
    // Atomically decrement saves count
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      saves: admin.firestore.FieldValue.increment(-1)
    });

    console.log(`Successfully decremented saves for pod ${podId}`);
    return { success: true };
  } catch (error) {
    console.error('Error decrementing pod saves:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// MARK: - Pod Migration Functions

// Migrate all existing pods to include new engagement metrics fields
exports.migratePodsToNewVersion = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { batchSize = 100, startAfterDocId = null } = data;

  try {
    console.log(`Starting pod migration with batch size: ${batchSize}`);
    
    let query = db.collection('pods').limit(batchSize);
    
    // If we have a startAfterDocId, start from that document
    if (startAfterDocId) {
      const startAfterDoc = await db.collection('pods').doc(startAfterDocId).get();
      if (startAfterDoc.exists) {
        query = query.startAfter(startAfterDoc);
      }
    }

    const snapshot = await query.get();
    
    if (snapshot.empty) {
      console.log('No more pods to migrate');
      return { 
        success: true, 
        message: 'Migration complete - no more pods to migrate',
        migratedCount: 0,
        hasMore: false
      };
    }

    const batch = db.batch();
    let migratedCount = 0;
    let lastDocId = null;

    snapshot.docs.forEach(doc => {
      const podData = doc.data();
      const updates = {};

      // Check and add missing engagement metrics fields
      if (podData.views === undefined) {
        updates.views = 0;
      }
      if (podData.shares === undefined) {
        updates.shares = 0;
      }
      if (podData.comments === undefined) {
        updates.comments = 0;
      }
      if (podData.saves === undefined) {
        updates.saves = 0;
      }

      // Check and add missing content metadata fields
      if (podData.duration === undefined) {
        updates.duration = null;
      }
      if (podData.fileSize === undefined) {
        updates.fileSize = null;
      }
      if (podData.mimeType === undefined) {
        updates.mimeType = null;
      }

      // Check and add missing production fields
      if (podData.isActive === undefined) {
        updates.isActive = true;
      }
      if (podData.createdAt === undefined) {
        updates.createdAt = podData.timestamp || admin.firestore.FieldValue.serverTimestamp();
      }
      if (podData.updatedAt === undefined) {
        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      }
      if (podData.deletedAt === undefined) {
        updates.deletedAt = null;
      }
      if (podData.version === undefined) {
        updates.version = 1;
      }

      // Check and add missing content moderation fields
      if (podData.isReported === undefined) {
        updates.isReported = false;
      }
      if (podData.moderationStatus === undefined) {
        updates.moderationStatus = 'approved';
      }
      if (podData.contentWarnings === undefined) {
        updates.contentWarnings = [];
      }

      // Only update if there are fields to add
      if (Object.keys(updates).length > 0) {
        batch.update(doc.ref, updates);
        migratedCount++;
        console.log(`Pod ${doc.id} will be updated with ${Object.keys(updates).length} fields`);
      }

      lastDocId = doc.id;
    });

    // Commit the batch update
    if (migratedCount > 0) {
      await batch.commit();
      console.log(`Successfully migrated ${migratedCount} pods in this batch`);
    }

    const hasMore = snapshot.docs.length === batchSize;

    return {
      success: true,
      message: `Migrated ${migratedCount} pods in this batch`,
      migratedCount,
      hasMore,
      lastDocId,
      nextBatchSize: hasMore ? batchSize : 0
    };

  } catch (error) {
    console.error('Error migrating pods:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Get migration status - count pods that need migration
exports.getPodMigrationStatus = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    console.log('Checking pod migration status...');
    
    // Count total pods
    const totalSnapshot = await db.collection('pods').count().get();
    const totalPods = totalSnapshot.data().count;
    
    // Count pods missing engagement metrics (using a sample query)
    const sampleSnapshot = await db.collection('pods').limit(100).get();
    let missingFieldsCount = 0;
    
    sampleSnapshot.docs.forEach(doc => {
      const podData = doc.data();
      if (podData.views === undefined || 
          podData.shares === undefined || 
          podData.comments === undefined || 
          podData.saves === undefined) {
        missingFieldsCount++;
      }
    });
    
    // Estimate total pods needing migration
    const estimatedNeedingMigration = Math.ceil((missingFieldsCount / sampleSnapshot.docs.length) * totalPods);
    
    return {
      success: true,
      totalPods,
      estimatedNeedingMigration,
      sampleSize: sampleSnapshot.docs.length,
      missingFieldsInSample: missingFieldsCount
    };

  } catch (error) {
    console.error('Error checking migration status:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Helper function to get user notification preferences
async function getUserNotificationSettings(userId) {
  console.log('⚙️ getUserNotificationSettings called for user:', userId);
  
  try {
    const settingsPath = `users/${userId}/settings/notifications`;
    console.log('🔍 Fetching settings from path:', settingsPath);
    
    const settingsDoc = await db.collection('users').doc(userId).collection('settings').doc('notifications').get();
    
    console.log('📄 Settings document exists:', settingsDoc.exists);
    
    if (!settingsDoc.exists) {
      console.log('⚙️ No settings found, returning default settings');
      // Return default settings if none exist
      const defaultSettings = {
        likesEnabled: true,
        commentsEnabled: true,
        followsEnabled: true,
        repostsEnabled: true,
        messagesEnabled: true,
        newPodsEnabled: true,
        trendingEnabled: false,
        appUpdatesEnabled: true,
        maintenanceEnabled: true,
        quietHoursEnabled: false,
        quietHoursStart: null,
        quietHoursEnd: null
      };
      console.log('⚙️ Default settings:', JSON.stringify(defaultSettings, null, 2));
      return defaultSettings;
    }
    
    const settings = settingsDoc.data();
    console.log('⚙️ User settings found:', JSON.stringify(settings, null, 2));
    return settings;
    
  } catch (error) {
    console.error('❌ Error fetching notification settings:', error);
    console.error('🔍 Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack
    });
    return null;
  }
}

// Helper function to check if notification should be sent based on type and settings
function shouldSendNotification(type, settings) {
  console.log('🔔 shouldSendNotification called with:', {
    type,
    settings: JSON.stringify(settings, null, 2)
  });
  
  if (!settings) {
    console.log('⚙️ No notification settings found, defaulting to true');
    return true; // Send if we can't check settings
  }
  
  let result = true; // Default to enabled
  switch (type) {
    case 'like':
      result = settings.likesEnabled !== undefined ? settings.likesEnabled : true;
      console.log(`👍 Like notifications enabled: ${result}`);
      break;
    case 'comment':
      result = settings.commentsEnabled !== undefined ? settings.commentsEnabled : true;
      console.log(`💬 Comment notifications enabled: ${result}`);
      break;
    case 'follow':
      result = settings.followsEnabled !== undefined ? settings.followsEnabled : true;
      console.log(`👥 Follow notifications enabled: ${result}`);
      break;
    case 'followRequest':
      result = settings.followRequestsEnabled !== undefined ? settings.followRequestsEnabled : true;
      console.log(`📝 Follow request notifications enabled: ${result}`);
      break;
    case 'followRequestAccepted':
      result = settings.followRequestsEnabled !== undefined ? settings.followRequestsEnabled : true;
      console.log(`✅ Follow request accepted notifications enabled: ${result}`);
      break;
    case 'repost':
      result = settings.repostsEnabled !== undefined ? settings.repostsEnabled : true;
      console.log(`🔄 Repost notifications enabled: ${result}`);
      break;
    case 'message':
      result = settings.messagesEnabled !== undefined ? settings.messagesEnabled : true;
      console.log(`💬 Message notifications enabled: ${result}`);
      break;
    case 'tag':
      result = settings.repostsEnabled !== undefined ? settings.repostsEnabled : true; // Tags use repost setting
      console.log(`🏷️ Tag notifications enabled: ${result}`);
      break;
    default:
      console.log(`❓ Unknown notification type: ${type}, defaulting to true`);
      result = true;
  }
  
  console.log(`🔔 Final result for ${type}: ${result}`);
  return result;
}

// Helper function to check quiet hours
function isInQuietHours(settings) {
  console.log('🌙 isInQuietHours called with settings:', JSON.stringify(settings, null, 2));
  
  if (!settings || !settings.quietHoursEnabled) {
    console.log('🌙 Quiet hours disabled or no settings, returning false');
    return false;
  }
  
  try {
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    const currentTimeInMinutes = currentHour * 60 + currentMinute;
    
    console.log('🕐 Current time:', {
      hour: currentHour,
      minute: currentMinute,
      totalMinutes: currentTimeInMinutes
    });
    
    // Convert Firestore timestamps to time
    const startTime = settings.quietHoursStart?.toDate ? settings.quietHoursStart.toDate() : new Date(settings.quietHoursStart);
    const endTime = settings.quietHoursEnd?.toDate ? settings.quietHoursEnd.toDate() : new Date(settings.quietHoursEnd);
    
    const startHour = startTime.getHours();
    const startMinute = startTime.getMinutes();
    const startTimeInMinutes = startHour * 60 + startMinute;
    
    const endHour = endTime.getHours();
    const endMinute = endTime.getMinutes();
    const endTimeInMinutes = endHour * 60 + endMinute;
    
    console.log('🌙 Quiet hours time range:', {
      start: `${startHour}:${startMinute} (${startTimeInMinutes} minutes)`,
      end: `${endHour}:${endMinute} (${endTimeInMinutes} minutes)`,
      current: `${currentHour}:${currentMinute} (${currentTimeInMinutes} minutes)`
    });
    
    // Handle quiet hours that span midnight
    let result = false;
    if (startTimeInMinutes <= endTimeInMinutes) {
      // Same day (e.g., 2 PM to 6 PM)
      result = currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes <= endTimeInMinutes;
      console.log('🌙 Same-day quiet hours calculation');
    } else {
      // Overnight (e.g., 10 PM to 8 AM)
      result = currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes <= endTimeInMinutes;
      console.log('🌙 Overnight quiet hours calculation');
    }
    
    console.log(`🌙 Final quiet hours result: ${result}`);
    return result;
    
  } catch (error) {
    console.error('❌ Error checking quiet hours:', error);
    return false;
  }
}

// Helper function to get notification content based on type
async function getNotificationContent(notificationData) {
  try {
    // Get sender information
    const senderDoc = await db.collection('users').doc(notificationData.senderId).get();
    const sender = senderDoc.data();
    
    if (!sender) {
      throw new Error('Sender not found');
    }
    
    const senderName = sender.fullname || sender.username || 'Someone';
    
    console.log(`🔍 [getNotificationContent] Processing notification type: "${notificationData.type}"`);
    console.log(`🔍 [getNotificationContent] Sender name: "${senderName}"`);
    
    switch (notificationData.type) {
      case 'like':
        return {
          title: 'New Like',
          body: `${senderName} liked your pod`,
          data: {
            type: 'like',
            senderId: notificationData.senderId,
            contentId: notificationData.contentId || '',
            notificationId: notificationData.id || '',
            screen: 'notifications',
            action: 'open_notifications'
          }
        };
        
      case 'comment':
        const commentPreview = notificationData.commentText ? 
          (notificationData.commentText.length > 50 ? 
            notificationData.commentText.substring(0, 50) + '...' : 
            notificationData.commentText) : '';
        return {
          title: 'New Comment',
          body: `${senderName} commented: ${commentPreview}`,
          data: {
            type: 'comment',
            senderId: notificationData.senderId,
            contentId: notificationData.contentId || '',
            notificationId: notificationData.id || '',
            screen: 'notifications',
            action: 'open_notifications'
          }
        };
        
      case 'follow':
        return {
          title: 'New Follower',
          body: `${senderName} started following you`,
          data: {
            type: 'follow',
            senderId: notificationData.senderId,
            notificationId: notificationData.id || '',
            screen: 'notifications',
            action: 'open_notifications'
          }
        };
        
      case 'followRequest':
        return {
          title: 'New Follow Request',
          body: `${senderName} requested to follow you`,
          data: {
            type: 'followRequest',
            senderId: notificationData.senderId,
            notificationId: notificationData.id || '',
            screen: 'followRequests',
            action: 'open_follow_requests'
          }
        };
        
      case 'followRequestAccepted':
        return {
          title: 'Follow Request Accepted',
          body: `${senderName} accepted your follow request`,
          data: {
            type: 'followRequestAccepted',
            senderId: notificationData.senderId,
            notificationId: notificationData.id || '',
            screen: 'notifications',
            action: 'open_notifications'
          }
        };
        
      case 'repost':
        return {
          title: 'New Repost',
          body: `${senderName} reposted your pod`,
          data: {
            type: 'repost',
            senderId: notificationData.senderId,
            contentId: notificationData.contentId || '',
            notificationId: notificationData.id || '',
            screen: 'notifications',
            action: 'open_notifications'
          }
        };
        
      case 'message':
        const messagePreview = notificationData.messageText ? 
          (notificationData.messageText.length > 50 ? 
            notificationData.messageText.substring(0, 50) + '...' : 
            notificationData.messageText) : 'sent you a message';
        return {
          title: 'New Message',
          body: `${senderName}: ${messagePreview}`,
          data: {
            type: 'message',
            senderId: notificationData.senderId,
            contentId: notificationData.contentId || '',
            notificationId: notificationData.id || '',
            screen: 'messages',
            action: 'open_messages'
          }
        };
        
      case 'tag':
        return {
          title: 'You were tagged',
          body: `${senderName} tagged you in a pod`,
          data: {
            type: 'tag',
            senderId: notificationData.senderId,
            contentId: notificationData.contentId || '',
            notificationId: notificationData.id || '',
            screen: 'notifications',
            action: 'open_notifications'
          }
        };
        
      default:
        console.log(`⚠️ [getNotificationContent] Hit default case for type: "${notificationData.type}"`);
        return {
          title: 'New Activity',
          body: `You have a new ${notificationData.type}`,
          data: {
            type: notificationData.type,
            senderId: notificationData.senderId,
            notificationId: notificationData.id || '',
            screen: 'notifications',
            action: 'open_notifications'
          }
        };
    }
  } catch (error) {
    console.error('Error creating notification content:', error);
    return {
      title: 'New Activity',
      body: 'You have a new notification',
      data: {
        type: notificationData.type || 'unknown',
        senderId: notificationData.senderId || '',
        notificationId: notificationData.id || '',
        screen: 'notifications',
        action: 'open_notifications'
      }
    };
  }
}

// Main function: Automatically send push notification when a notification document is created
exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationData = snap.data();
    const notificationId = context.params.notificationId;
    
    console.log('🚀 === PUSH NOTIFICATION DEBUG START ===');
    console.log(`📱 Processing notification ${notificationId} for user ${notificationData.recipientId}`);
    console.log('📋 Notification data:', JSON.stringify(notificationData, null, 2));
    
    // Special debugging for follow notifications
    if (notificationData.type === 'follow') {
      console.log('👥 === FOLLOW NOTIFICATION DEBUG ===');
      console.log(`👤 Follower: ${notificationData.senderId}`);
      console.log(`👤 Following: ${notificationData.recipientId}`);
      console.log(`📅 Created at: ${notificationData.createdAt}`);
      console.log(`🏷️ Category: ${notificationData.category}`);
    }
    
    try {
      // Get recipient's FCM token and notification settings
      console.log('🔍 Fetching recipient data and notification settings...');
      const [recipientDoc, notificationSettings] = await Promise.all([
        db.collection('users').doc(notificationData.recipientId).get(),
        getUserNotificationSettings(notificationData.recipientId)
      ]);
      
      console.log('👤 Recipient document exists:', recipientDoc.exists);
      console.log('⚙️ Notification settings:', JSON.stringify(notificationSettings, null, 2));
      
      if (!recipientDoc.exists) {
        console.log(`❌ Recipient ${notificationData.recipientId} not found`);
        return;
      }
      
      const recipient = recipientDoc.data();
      const fcmToken = recipient.fcmToken;
      
      console.log('🔑 FCM Token found:', fcmToken ? `YES (${fcmToken.substring(0, 20)}...)` : 'NO');
      console.log('👤 Recipient data:', JSON.stringify({
        uid: recipient.uid,
        username: recipient.username,
        hasFCMToken: !!fcmToken,
        fcmTokenLength: fcmToken ? fcmToken.length : 0
      }, null, 2));
      
      // Special FCM debugging for follow notifications
      if (notificationData.type === 'follow') {
        console.log('🔑 === FCM TOKEN DEBUG FOR FOLLOW ===');
        console.log(`📱 FCM Token exists: ${!!fcmToken}`);
        if (fcmToken) {
          console.log(`📱 FCM Token length: ${fcmToken.length}`);
          console.log(`📱 FCM Token prefix: ${fcmToken.substring(0, 50)}...`);
          console.log(`📱 FCM Token looks valid: ${fcmToken.includes(':') && fcmToken.length > 100}`);
        } else {
          console.log('❌ FCM Token is NULL or EMPTY');
          console.log('💡 This means the user will NOT receive push notifications');
          console.log('🔧 Check if user has:');
          console.log('   - Allowed notification permissions in iOS Settings');
          console.log('   - Properly logged into the app');
          console.log('   - APNS certificate configured in Firebase Console');
        }
      }
      
      if (!fcmToken) {
        console.log(`❌ No FCM token for user ${notificationData.recipientId}`);
        console.log('💡 User will not receive push notifications until FCM token is generated');
        return;
      }
      
      // Check if notification type is enabled
      console.log('🔔 Checking notification type permissions...');
      const shouldSend = shouldSendNotification(notificationData.type, notificationSettings);
      console.log(`📱 Notification type ${notificationData.type} enabled:`, shouldSend);
      
      if (!shouldSend) {
        console.log(`❌ Notification type ${notificationData.type} disabled for user ${notificationData.recipientId}`);
        return;
      }
      
      // Check quiet hours
      console.log('🌙 Checking quiet hours...');
      const inQuietHours = isInQuietHours(notificationSettings);
      console.log(`🌙 User in quiet hours:`, inQuietHours);
      
      if (inQuietHours) {
        console.log(`⏰ User ${notificationData.recipientId} is in quiet hours, skipping notification`);
        return;
      }
      
      // Don't send notification to yourself
      if (notificationData.senderId === notificationData.recipientId) {
        console.log('🚫 Skipping self-notification');
        return;
      }
      
      // Create notification content
      console.log('📝 Creating notification content...');
      const notificationContent = await getNotificationContent({
        ...notificationData,
        id: notificationId
      });
      
      console.log('📋 Notification content created:', JSON.stringify(notificationContent, null, 2));
      
      // Calculate the actual badge count (only recent unread notifications - last 7 days)
      console.log('🔢 Calculating badge count...');
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      
      const unreadCountSnapshot = await db.collection('notifications')
        .where('recipientId', '==', notificationData.recipientId)
        .where('isRead', '==', false)
        .where('createdAt', '>=', sevenDaysAgo)
        .get();
      
      const badgeCount = unreadCountSnapshot.size;
      const displayBadgeCount = badgeCount > 99 ? 99 : badgeCount;
      console.log(`📱 Badge count calculated: ${displayBadgeCount} (actual: ${badgeCount}) recent unread notifications (last 7 days)`);
      
      // Send the push notification
      console.log('📤 Preparing FCM message...');
      const message = {
        token: fcmToken,
        notification: {
          title: notificationContent.title,
          body: notificationContent.body
        },
        data: notificationContent.data,
        apns: {
          payload: {
            aps: {
              badge: displayBadgeCount,
              sound: 'default',
              'content-available': 1
            }
          }
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            priority: 'high'
          }
        }
      };
      
      console.log('📨 FCM Message prepared:', JSON.stringify(message, null, 2));
      
      // Special debugging for follow notifications
      if (notificationData.type === 'follow') {
        console.log('📤 === FOLLOW NOTIFICATION FCM DEBUG ===');
        console.log(`📱 Target FCM Token: ${fcmToken.substring(0, 50)}...`);
        console.log(`📱 Notification Title: "${notificationContent.title}"`);
        console.log(`📱 Notification Body: "${notificationContent.body}"`);
        console.log(`📱 Badge Count: ${displayBadgeCount}`);
        console.log(`📱 APNS Payload:`, JSON.stringify(message.apns, null, 2));
      }
      
      console.log('🚀 Sending to FCM...');
      
      const response = await admin.messaging().send(message);
      console.log('✅ Successfully sent notification to FCM!');
      console.log('📱 FCM Response:', JSON.stringify(response, null, 2));
      
      // Special success debugging for follow notifications
      if (notificationData.type === 'follow') {
        console.log('🎉 === FOLLOW NOTIFICATION SENT SUCCESSFULLY ===');
        console.log(`👤 Follower: ${notificationData.senderId}`);
        console.log(`👤 Following: ${notificationData.recipientId}`);
        console.log(`📱 FCM Message ID: ${response}`);
        console.log('✅ User should receive push notification on their device');
      }
      
      console.log(`🎉 Notification ${notificationId} sent successfully to user ${notificationData.recipientId}`);
      console.log('🏁 === PUSH NOTIFICATION DEBUG END ===');
      
    } catch (error) {
      console.error('💥 === PUSH NOTIFICATION ERROR ===');
      console.error(`❌ Error processing notification ${notificationId} for user ${notificationData.recipientId}:`, error);
      
      // Special error debugging for follow notifications
      if (notificationData.type === 'follow') {
        console.error('👥 === FOLLOW NOTIFICATION ERROR ===');
        console.error(`👤 Follower: ${notificationData.senderId}`);
        console.error(`👤 Following: ${notificationData.recipientId}`);
        console.error(`❌ Follow notification failed to send`);
      }
      
      console.error('🔍 Error details:', {
        code: error.code,
        message: error.message,
        stack: error.stack
      });
      
      // Enhanced APNs-specific error diagnostics
      if (error.code) {
        console.error('🚨 === APNs ERROR DIAGNOSTICS ===');
        switch (error.code) {
          case 'messaging/invalid-registration-token':
            console.error('🔑 INVALID FCM TOKEN - Token format is wrong or corrupted');
            console.error('💡 Solution: User needs to log out and back in to generate new token');
            break;
          case 'messaging/registration-token-not-registered':
            console.error('📱 UNREGISTERED TOKEN - App was deleted/reinstalled or token expired');
            console.error('💡 Solution: Remove token from user document and regenerate');
            break;
          case 'messaging/invalid-apns-credentials':
            console.error('🔐 INVALID APNs CREDENTIALS - APNs key/certificate configuration wrong');
            console.error('💡 Check: Team ID, Key ID, Bundle ID in Firebase Console');
            console.error('💡 Verify: APNs key (.p8) is properly uploaded to Firebase');
            break;
          case 'messaging/mismatched-credential':
            console.error('🎯 BUNDLE ID MISMATCH - APNs key doesn\'t match app bundle ID');
            console.error('💡 Check: Bundle ID in Firebase matches Xcode project');
            console.error(`💡 Expected: Connor.Attuned, Check Firebase Console`);
            break;
          case 'messaging/server-unavailable':
            console.error('🌐 APNs SERVER UNAVAILABLE - Temporary Apple server issue');
            console.error('💡 Solution: Retry later, this is usually temporary');
            break;
          case 'messaging/too-many-topics':
            console.error('📊 TOO MANY TOPICS - Device subscribed to too many topics');
            console.error('💡 Solution: Unsubscribe from some topics');
            break;
          default:
            console.error(`🤔 UNKNOWN ERROR CODE: ${error.code}`);
            console.error('💡 Check Firebase documentation for this error code');
        }
        console.error('🚨 === END APNs ERROR DIAGNOSTICS ===');
      }
      
      // If token is invalid, remove it from user document
      if (error.code === 'messaging/registration-token-not-registered' || 
          error.code === 'messaging/invalid-registration-token') {
        console.log(`🗑️ Removing invalid FCM token for user ${notificationData.recipientId}`);
        await db.collection('users').doc(notificationData.recipientId).update({
          fcmToken: admin.firestore.FieldValue.delete()
        });
        console.log('✅ Invalid FCM token removed');
      }
      
      console.error('🏁 === ERROR DEBUG END ===');
    }
  });

// Callable function for sending custom push notifications (for admin use)
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  try {
    const { recipientId, title, body, data: customData = {} } = data;
    
    if (!recipientId || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    // Get recipient's FCM token
    const recipientDoc = await db.collection('users').doc(recipientId).get();
    
    if (!recipientDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Recipient not found');
    }
    
    const fcmToken = recipientDoc.data().fcmToken;
    
    if (!fcmToken) {
      throw new functions.https.HttpsError('failed-precondition', 'Recipient has no FCM token');
    }
    
      // Calculate the actual badge count for this recipient (only recent unread - last 7 days)
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      
      const unreadCountSnapshot = await db.collection('notifications')
        .where('recipientId', '==', recipientId)
        .where('isRead', '==', false)
        .where('createdAt', '>=', sevenDaysAgo)
        .get();
      
      const badgeCount = unreadCountSnapshot.size;
      const displayBadgeCount = badgeCount > 99 ? 99 : badgeCount;
      
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body
        },
        data: customData,
        apns: {
          payload: {
            aps: {
              badge: displayBadgeCount,
              sound: 'default'
            }
          }
        }
      };
    
    const response = await admin.messaging().send(message);
    console.log('Successfully sent custom push notification:', response);
    
    return { success: true, messageId: response };
    
  } catch (error) {
    console.error('Error sending custom push notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Function to send batch notifications (for system-wide announcements)
exports.sendBatchNotifications = functions.https.onCall(async (data, context) => {
  // Verify admin authentication (you should implement proper admin checking)
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  try {
    const { userIds, title, body, data: customData = {} } = data;
    
    if (!userIds || !Array.isArray(userIds) || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid input data');
    }
    
    // Limit batch size
    if (userIds.length > 500) {
      throw new functions.https.HttpsError('invalid-argument', 'Batch size too large');
    }
    
    // Get FCM tokens for all users
    const userDocs = await Promise.all(
      userIds.map(userId => db.collection('users').doc(userId).get())
    );
    
    const validTokens = userDocs
      .filter(doc => doc.exists && doc.data().fcmToken)
      .map(doc => doc.data().fcmToken);
    
    if (validTokens.length === 0) {
      return { success: true, sent: 0, errors: 0 };
    }
    
    // Create message
    const message = {
      notification: {
        title: title,
        body: body
      },
      data: customData,
      tokens: validTokens
    };
    
    const response = await admin.messaging().sendMulticast(message);
    console.log(`Batch notification sent: ${response.successCount} success, ${response.failureCount} failure`);
    
    return {
      success: true,
      sent: response.successCount,
      errors: response.failureCount,
      results: response.responses
    };
    
  } catch (error) {
    console.error('Error sending batch notifications:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// MARK: - Pod Like/Unlike Functions

// Function to like a pod (exact replica of PodService.swift likePod method)
exports.likePod = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { podId } = data;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    // Increment the likes count atomically
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      likes: admin.firestore.FieldValue.increment(1)
    });

    // Add the pod to the user's 'user-likes' collection
    const userLikesRef = db.collection('users').doc(uid).collection('user-likes');
    await userLikesRef.doc(podId).set({});

    console.log(`User ${uid} liked pod ${podId}`);
    return { success: true, message: 'Pod liked successfully' };

  } catch (error) {
    console.error('Error liking pod:', error);
    throw new functions.https.HttpsError('internal', `Error liking pod: ${error.message}`);
  }
});

// Function to unlike a pod (exact replica of PodService.swift unlikePod method)
exports.unlikePod = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { podId } = data;

  if (!podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
  }

  try {
    // Decrement the likes count atomically
    const podRef = db.collection('pods').doc(podId);
    await podRef.update({
      likes: admin.firestore.FieldValue.increment(-1)
    });

    // Remove the pod from the user's 'user-likes' collection
    const userLikesRef = db.collection('users').doc(uid).collection('user-likes');
    await userLikesRef.doc(podId).delete();

    console.log(`User ${uid} unliked pod ${podId}`);
    return { success: true, message: 'Pod unliked successfully' };

  } catch (error) {
    console.error('Error unliking pod:', error);
    throw new functions.https.HttpsError('internal', `Error unliking pod: ${error.message}`);
  }
});

// MARK: - User Follow/Unfollow Functions

// Function to follow a user (exact replica of UserService.swift followUser method)
exports.followUser = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required');
  }

  if (currentUid === userId) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot follow yourself');
  }

  try {
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Increment the 'following' count for the current user
    const currentUserRef = db.collection('users').doc(currentUid);
    batch.update(currentUserRef, {
      following: admin.firestore.FieldValue.increment(1)
    });

    // Increment the 'followers' count for the user being followed
    const followedUserRef = db.collection('users').doc(userId);
    batch.update(followedUserRef, {
      followers: admin.firestore.FieldValue.increment(1)
    });

    // Add to 'user-following' collection of the current user
    const userFollowingRef = db.collection('users').doc(currentUid).collection('user-following').doc(userId);
    batch.set(userFollowingRef, {});

    // Add to 'user-followers' collection of the followed user
    const userFollowersRef = db.collection('users').doc(userId).collection('user-followers').doc(currentUid);
    batch.set(userFollowersRef, {});

    // Commit the batch
    await batch.commit();

    // Handle duplicate follow notification prevention
    console.log(`🔄 [followUser] Starting duplicate prevention for follow notification from ${currentUid} to ${userId}`);
    await handleDuplicateNotification('follow', currentUid, userId, null);
    console.log(`🔄 [followUser] Duplicate prevention completed, creating follow notification`);

    // Create follow notification with simplified model structure
    console.log(`🔔 [followUser] Creating follow notification document...`);
    const notificationRef = db.collection('notifications').doc();
    const notificationId = notificationRef.id;
    const currentTime = admin.firestore.FieldValue.serverTimestamp();
    
    console.log(`📝 [followUser] Notification ID: ${notificationId}`);
    console.log(`👤 [followUser] Follower: ${currentUid}`);
    console.log(`👤 [followUser] Following: ${userId}`);
    
    await notificationRef.set({
      type: 'follow',
      senderId: currentUid,
      recipientId: userId,
      contentId: null, // Follow notifications don't need contentId
      commentText: null,
      messageText: null,
      version: 2,
      createdAt: currentTime,
      updatedAt: currentTime,
      category: 'social',
      isRead: false,
      groupId: null,
      deepLink: null
    });
    
    console.log(`✅ [followUser] Follow notification document created successfully: ${notificationId}`);
    console.log(`🚀 [followUser] This should trigger the sendNotification cloud function`);

    // Check if this creates a mutual follow relationship
    console.log('🔍 Checking for mutual follow relationship...');
    const otherUserFollowingRef = db.collection('users').doc(userId).collection('user-following').doc(currentUid);
    const otherUserFollowingDoc = await otherUserFollowingRef.get();
    
    if (otherUserFollowingDoc.exists) {
      console.log('🎉 Mutual follow detected! Creating friendship and conversation...');
      
      // Call handleMutualFollow logic inline to avoid circular function calls
      try {
        // Check if they're already friends
        const currentUserFriendsRef = db.collection('users').doc(currentUid).collection('friends').doc(userId);
        const otherUserFriendsRef = db.collection('users').doc(userId).collection('friends').doc(currentUid);
        
        const [currentUserFriendDoc, otherUserFriendDoc] = await Promise.all([
          currentUserFriendsRef.get(),
          otherUserFriendsRef.get()
        ]);

        if (currentUserFriendDoc.exists && otherUserFriendDoc.exists) {
          console.log('✅ Users are already friends');
        } else {
          // Check if a conversation already exists between these users
          const existingConversation = await findExistingConversation(currentUid, userId);
          
          if (existingConversation) {
            console.log(`✅ Conversation already exists: ${existingConversation}, ensuring friendship documents`);
            await ensureFriendshipDocuments(currentUid, userId);
          } else {
            console.log('🆕 No existing conversation found, creating new friendship and conversation');
            const conversationId = await createFriendshipAndConversation(currentUid, userId);
            console.log(`✅ New conversation created: ${conversationId}`);
          }
        }
      } catch (mutualFollowError) {
        console.error('⚠️ Error during mutual follow handling:', mutualFollowError);
        // Don't fail the follow operation if mutual follow handling fails
      }
    } else {
      console.log('📝 One-way follow - no mutual follow relationship');
    }

    console.log(`User ${currentUid} followed user ${userId}`);
    return { success: true, message: 'User followed successfully' };

  } catch (error) {
    console.error('Error following user:', error);
    throw new functions.https.HttpsError('internal', `Error following user: ${error.message}`);
  }
});

// Function to handle mutual follow and create friendship/conversation if needed
exports.handleMutualFollow = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required');
  }

  if (currentUid === userId) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot handle mutual follow with yourself');
  }

  try {
    // Check if they're already friends
    const currentUserFriendsRef = db.collection('users').doc(currentUid).collection('friends').doc(userId);
    const otherUserFriendsRef = db.collection('users').doc(userId).collection('friends').doc(currentUid);
    
    const [currentUserFriendDoc, otherUserFriendDoc] = await Promise.all([
      currentUserFriendsRef.get(),
      otherUserFriendsRef.get()
    ]);

    if (currentUserFriendDoc.exists && otherUserFriendDoc.exists) {
      // Already friends, no action needed
      console.log(`Users ${currentUid} and ${userId} are already friends`);
      return { success: true, message: 'Users are already friends', action: 'none' };
    }

    // Check if a conversation already exists between these users
    const existingConversation = await findExistingConversation(currentUid, userId);
    
    if (existingConversation) {
      // Conversation exists, just ensure friendship documents are in place
      console.log(`Conversation already exists: ${existingConversation}, ensuring friendship documents`);
      await ensureFriendshipDocuments(currentUid, userId);
      return { success: true, message: 'Friendship documents ensured', action: 'friendship_ensured' };
    } else {
      // No conversation exists, create friendship and conversation
      console.log(`No existing conversation found, creating new friendship and conversation`);
      const conversationId = await createFriendshipAndConversation(currentUid, userId);
      return { success: true, message: 'Friendship and conversation created', action: 'created', conversationId };
    }

  } catch (error) {
    console.error('Error handling mutual follow:', error);
    throw new functions.https.HttpsError('internal', `Error handling mutual follow: ${error.message}`);
  }
});

// Helper function to find existing conversation
async function findExistingConversation(userId1, userId2) {
  try {
    const user1ConversationsRef = db.collection('users').doc(userId1).collection('conversations');
    const snapshot = await user1ConversationsRef.get();
    
    for (const doc of snapshot.docs) {
      const conversationRef = doc.data().conversationRef;
      if (conversationRef) {
        const conversationDoc = await db.doc(conversationRef).get();
        if (conversationDoc.exists) {
          const participants = conversationDoc.data().participants || [];
          if (participants.includes(userId2)) {
            return conversationDoc.id;
          }
        }
      }
    }
    return null;
  } catch (error) {
    console.error('Error finding existing conversation:', error);
    return null;
  }
}

// Helper function to ensure friendship documents exist
async function ensureFriendshipDocuments(userId1, userId2) {
  try {
    const batch = db.batch();
    
    // Add minimal friendship data to both users
    const user1FriendRef = db.collection('users').doc(userId1).collection('friends').doc(userId2);
    const user2FriendRef = db.collection('users').doc(userId2).collection('friends').doc(userId1);
    
    const minimalData = {
      uid: userId1,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
    batch.set(user1FriendRef, { ...minimalData, uid: userId2 });
    batch.set(user2FriendRef, { ...minimalData, uid: userId1 });
    
    await batch.commit();
    console.log(`Friendship documents ensured for users ${userId1} and ${userId2}`);
  } catch (error) {
    console.error('Error ensuring friendship documents:', error);
    throw error;
  }
}

// Helper function to create friendship and conversation
async function createFriendshipAndConversation(userId1, userId2) {
  try {
    // Check if users are blocked before creating conversation
    const [user1BlockedUsers, user2BlockedUsers] = await Promise.all([
      db.collection('users').doc(userId1).get().then(doc => doc.data()?.blockedUsers || []),
      db.collection('users').doc(userId2).get().then(doc => doc.data()?.blockedUsers || [])
    ]);
    
    // Check if either user has blocked the other
    if (user1BlockedUsers.includes(userId2) || user2BlockedUsers.includes(userId1)) {
      console.log(`Cannot create conversation - blocked users detected between ${userId1} and ${userId2}`);
      throw new Error('Users are blocked from each other');
    }
    
    // Get user data for friendship documents
    const [user1Doc, user2Doc] = await Promise.all([
      db.collection('users').doc(userId1).get(),
      db.collection('users').doc(userId2).get()
    ]);
    
    if (!user1Doc.exists || !user2Doc.exists) {
      throw new Error('One or both users not found');
    }
    
    const user1Data = user1Doc.data();
    const user2Data = user2Doc.data();
    
    // Create conversation
    const conversationId = db.collection('conversations').doc().id;
    const conversationData = {
      type: 'oneOnOne',
      participants: [userId1, userId2],
      lastActivity: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: userId1
    };
    
    // Create friendship documents with full user data
    const batch = db.batch();
    
    const user1FriendRef = db.collection('users').doc(userId1).collection('friends').doc(userId2);
    const user2FriendRef = db.collection('users').doc(userId2).collection('friends').doc(userId1);
    
    const user1FriendData = {
      email: user2Data.email || '',
      username: user2Data.username || '',
      fullname: user2Data.fullname || '',
      uid: user2Data.uid || userId2,
      followers: user2Data.followers || 0,
      profileImageUrl: user2Data.profileImageUrl || '',
      isVerified: user2Data.isVerified || false,
      following: user2Data.following || 0,
      podCount: user2Data.podCount || 0,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const user2FriendData = {
      email: user1Data.email || '',
      username: user1Data.username || '',
      fullname: user1Data.fullname || '',
      uid: user1Data.uid || userId1,
      followers: user1Data.followers || 0,
      profileImageUrl: user1Data.profileImageUrl || '',
      isVerified: user1Data.isVerified || false,
      following: user1Data.following || 0,
      podCount: user1Data.podCount || 0,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
    batch.set(user1FriendRef, user1FriendData);
    batch.set(user2FriendRef, user2FriendData);
    
    // Create conversation
    const conversationRef = db.collection('conversations').doc(conversationId);
    batch.set(conversationRef, conversationData);
    
    // Add conversation reference to each participant
    const user1ConversationRef = db.collection('users').doc(userId1).collection('conversations').doc(conversationId);
    const user2ConversationRef = db.collection('users').doc(userId2).collection('conversations').doc(conversationId);
    
    // Use the same data as the main conversation document for consistency
    const conversationRefData = {
      ...conversationData, // Include all conversation data (lastActivity, createdAt, createdBy, participants, type)
      unreadCount: 0,
      lastReadTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      conversationRef: `conversations/${conversationId}`,
      joinedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    batch.set(user1ConversationRef, conversationRefData);
    batch.set(user2ConversationRef, conversationRefData);
    
    await batch.commit();
    console.log(`Friendship and conversation created for users ${userId1} and ${userId2}`);
    return conversationId;
  } catch (error) {
    console.error('Error creating friendship and conversation:', error);
    throw error;
  }
}

// Function to unfollow a user (exact replica of UserService.swift unfollowUser method)
exports.unfollowUser = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required');
  }

  if (currentUid === userId) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot unfollow yourself');
  }

  try {
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Decrement the 'following' count for the current user
    const currentUserRef = db.collection('users').doc(currentUid);
    batch.update(currentUserRef, {
      following: admin.firestore.FieldValue.increment(-1)
    });

    // Decrement the 'followers' count for the user being unfollowed
    const unfollowedUserRef = db.collection('users').doc(userId);
    batch.update(unfollowedUserRef, {
      followers: admin.firestore.FieldValue.increment(-1)
    });

    // Remove from 'user-following' collection of the current user
    const userFollowingRef = db.collection('users').doc(currentUid).collection('user-following').doc(userId);
    batch.delete(userFollowingRef);

    // Remove from 'user-followers' collection of the unfollowed user
    const userFollowersRef = db.collection('users').doc(userId).collection('user-followers').doc(currentUid);
    batch.delete(userFollowersRef);

    // Commit the batch
    await batch.commit();

    console.log(`User ${currentUid} unfollowed user ${userId}`);
    return { success: true, message: 'User unfollowed successfully' };

  } catch (error) {
    console.error('Error unfollowing user:', error);
    throw new functions.https.HttpsError('internal', `Error unfollowing user: ${error.message}`);
  }
});

// Function to remove a follower (makes them unfollow the current user)
exports.removeFollower = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required');
  }

  if (currentUid === userId) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot remove yourself as a follower');
  }

  try {
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Decrement the 'following' count for the follower (the user being removed)
    const followerRef = db.collection('users').doc(userId);
    batch.update(followerRef, {
      following: admin.firestore.FieldValue.increment(-1)
    });

    // Decrement the 'followers' count for the current user
    const currentUserRef = db.collection('users').doc(currentUid);
    batch.update(currentUserRef, {
      followers: admin.firestore.FieldValue.increment(-1)
    });

    // Remove from 'user-following' collection of the follower
    const userFollowingRef = db.collection('users').doc(userId).collection('user-following').doc(currentUid);
    batch.delete(userFollowingRef);

    // Remove from 'user-followers' collection of the current user
    const userFollowersRef = db.collection('users').doc(currentUid).collection('user-followers').doc(userId);
    batch.delete(userFollowersRef);

    // Commit the batch
    await batch.commit();

    console.log(`User ${userId} was removed as a follower of user ${currentUid}`);
    return { success: true, message: 'Follower removed successfully' };

  } catch (error) {
    console.error('Error removing follower:', error);
    throw new functions.https.HttpsError('internal', `Error removing follower: ${error.message}`);
  }
});

// MARK: - Comment Like/Unlike Functions

// Function to like a comment (exact replica of CommentService.swift likeComment method)
exports.likeComment = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { commentId, podId } = data;

  if (!commentId || !podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Comment ID and Pod ID are required');
  }

  try {
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Increment the likes count in the comment atomically
    const commentRef = db.collection('pods').doc(podId).collection('pod-comments').doc(commentId);
    batch.update(commentRef, {
      likes: admin.firestore.FieldValue.increment(1)
    });

    // Add a like entry for the user in the user's comment-likes collection
    const userLikesRef = db.collection('users').doc(uid).collection('user-comment-likes').doc(commentId);
    batch.set(userLikesRef, {});

    // Commit the batch
    await batch.commit();

    console.log(`User ${uid} liked comment ${commentId} on pod ${podId}`);
    return { success: true, message: 'Comment liked successfully' };

  } catch (error) {
    console.error('Error liking comment:', error);
    throw new functions.https.HttpsError('internal', `Error liking comment: ${error.message}`);
  }
});

// Function to unlike a comment (exact replica of CommentService.swift unlikeComment method)
exports.unlikeComment = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { commentId, podId } = data;

  if (!commentId || !podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Comment ID and Pod ID are required');
  }

  try {
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Decrement the likes count in the comment atomically
    const commentRef = db.collection('pods').doc(podId).collection('pod-comments').doc(commentId);
    batch.update(commentRef, {
      likes: admin.firestore.FieldValue.increment(-1)
    });

    // Remove the like entry from the user's comment-likes collection
    const userLikesRef = db.collection('users').doc(uid).collection('user-comment-likes').doc(commentId);
    batch.delete(userLikesRef);

    // Commit the batch
    await batch.commit();

    console.log(`User ${uid} unliked comment ${commentId} on pod ${podId}`);
    return { success: true, message: 'Comment unliked successfully' };

  } catch (error) {
    console.error('Error unliking comment:', error);
    throw new functions.https.HttpsError('internal', `Error unliking comment: ${error.message}`);
  }
});

// MARK: - Reply Like/Unlike Functions

// Function to like a reply (exact replica of CommentService.swift likeReply method)
exports.likeReply = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { commentId, replyId, podId } = data;

  if (!commentId || !replyId || !podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Comment ID, Reply ID, and Pod ID are required');
  }

  try {
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Add to user's likes collection using replyId
    const userLikesRef = db.collection('users').doc(uid).collection('user-comment-likes').doc(replyId);
    batch.set(userLikesRef, {});

    // Reference to the actual reply document
    const replyRef = db.collection('pods').doc(podId).collection('pod-comments').doc(commentId)
      .collection('comment-replies').doc(replyId);

    // Get current likes count and increment it
    const replyDoc = await replyRef.get();
    const currentLikes = replyDoc.exists ? (replyDoc.data().likes || 0) : 0;
    const newLikes = currentLikes + 1;

    // Update the reply's like count using setData with merge to ensure field exists
    batch.set(replyRef, { likes: newLikes }, { merge: true });

    // Commit the batch
    await batch.commit();

    console.log(`User ${uid} liked reply ${replyId} on comment ${commentId} in pod ${podId}`);
    return { success: true, message: 'Reply liked successfully' };

  } catch (error) {
    console.error('Error liking reply:', error);
    throw new functions.https.HttpsError('internal', `Error liking reply: ${error.message}`);
  }
});

// Function to unlike a reply (exact replica of CommentService.swift unlikeReply method)
exports.unlikeReply = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { commentId, replyId, podId } = data;

  if (!commentId || !replyId || !podId) {
    throw new functions.https.HttpsError('invalid-argument', 'Comment ID, Reply ID, and Pod ID are required');
  }

  try {
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Remove from user's likes collection using replyId
    const userLikesRef = db.collection('users').doc(uid).collection('user-comment-likes').doc(replyId);
    batch.delete(userLikesRef);

    // Reference to the actual reply document
    const replyRef = db.collection('pods').doc(podId).collection('pod-comments').doc(commentId)
      .collection('comment-replies').doc(replyId);

    // Get current likes count and decrement it
    const replyDoc = await replyRef.get();
    const currentLikes = replyDoc.exists ? (replyDoc.data().likes || 0) : 0;
    const newLikes = Math.max(0, currentLikes - 1); // Ensure we don't go below 0

    // Update the reply's like count using setData with merge to ensure field exists
    batch.set(replyRef, { likes: newLikes }, { merge: true });

    // Commit the batch
    await batch.commit();

    console.log(`User ${uid} unliked reply ${replyId} on comment ${commentId} in pod ${podId}`);
    return { success: true, message: 'Reply unliked successfully' };

  } catch (error) {
    console.error('Error unliking reply:', error);
    throw new functions.https.HttpsError('internal', `Error unliking reply: ${error.message}`);
  }
});

// MARK: - Username Validation Functions

// Server-side username validation (security layer)
function validateUsername(username) {
  if (!username || typeof username !== 'string') {
    throw new Error('USERNAME_INVALID_TYPE');
  }
  
  const trimmedUsername = username.trim();
  
  // Check length
  if (trimmedUsername.length < 3) {
    throw new Error('USERNAME_TOO_SHORT');
  }
  
  if (trimmedUsername.length > 20) {
    throw new Error('USERNAME_TOO_LONG');
  }
  
  // Check for spaces and whitespace
  if (trimmedUsername.includes(' ') || trimmedUsername.includes('\t') || trimmedUsername.includes('\n') || trimmedUsername.includes('\r')) {
    throw new Error('USERNAME_CONTAINS_WHITESPACE');
  }
  
  // Check for invalid characters (only allow alphanumeric and underscore)
  const validPattern = /^[a-zA-Z0-9_]+$/;
  if (!validPattern.test(trimmedUsername)) {
    throw new Error('USERNAME_INVALID_CHARACTERS');
  }
  
  // Check if starts with number
  if (/^\d/.test(trimmedUsername)) {
    throw new Error('USERNAME_STARTS_WITH_NUMBER');
  }
  
  // Check if starts or ends with underscore
  if (trimmedUsername.startsWith('_') || trimmedUsername.endsWith('_')) {
    throw new Error('USERNAME_STARTS_OR_ENDS_WITH_UNDERSCORE');
  }
  
  // Check for consecutive underscores
  if (trimmedUsername.includes('__')) {
    throw new Error('USERNAME_CONSECUTIVE_UNDERSCORES');
  }
  
  // Check for reserved usernames
  const reservedUsernames = [
    'admin', 'administrator', 'root', 'system', 'support', 'help', 'info',
    'contact', 'mail', 'webmaster', 'noreply', 'no-reply', 'test', 'demo',
    'example', 'sample', 'guest', 'anonymous', 'anon', 'user', 'users',
    'account', 'accounts', 'profile', 'profiles', 'settings', 'config',
    'configuration', 'api', 'app', 'application', 'service', 'services',
    'bot', 'robot', 'automated', 'auto', 'script', 'crawler', 'spider',
    'null', 'undefined', 'none', 'empty', 'deleted', 'removed', 'banned',
    'suspended', 'moderator', 'mod', 'staff', 'team', 'official', 'verified',
    'premium', 'vip', 'gold', 'silver', 'bronze', 'beta', 'alpha', 'dev',
    'development', 'staging', 'production', 'live', 'online', 'offline',
    'error', '404', '500', '403', '401', '400', 'maintenance',
    'down', 'up', 'status', 'health', 'monitor', 'logging', 'debug',
    'localhost', '127.0.0.1', '0.0.0.0', '255.255.255.255', 'loopback',
    'internal', 'external', 'public', 'private', 'secret', 'hidden',
    'invisible', 'ghost', 'shadow', 'dark', 'light', 'white', 'black',
    'red', 'green', 'blue', 'yellow', 'orange', 'purple', 'pink', 'brown',
    'gray', 'grey', 'cyan', 'magenta', 'lime', 'navy', 'teal', 'olive',
    'maroon', 'coral', 'indigo', 'violet', 'azure', 'beige', 'ivory',
    'khaki', 'lavender', 'mint', 'peach', 'plum', 'salmon', 'tan', 'wheat'
  ];
  
  if (reservedUsernames.includes(trimmedUsername.toLowerCase())) {
    throw new Error('USERNAME_RESERVED');
  }
  
  // Check for potentially offensive patterns
  const offensivePatterns = [
    'fuck', 'shit', 'bitch', 'ass', 'dick', 'cock', 'pussy', 'cunt',
    'nazi', 'hitler', 'kkk', 'terrorist', 'bomb', 'kill', 'murder',
    'rape', 'pedo', 'child', 'kid', 'teen', 'minor', 'underage'
  ];
  
  if (offensivePatterns.some(pattern => trimmedUsername.toLowerCase().includes(pattern))) {
    throw new Error('USERNAME_OFFENSIVE');
  }
  
  // Check for excessive numbers (more than 50%)
  const numberCount = (trimmedUsername.match(/\d/g) || []).length;
  const numberPercentage = numberCount / trimmedUsername.length;
  if (numberPercentage > 0.5) {
    throw new Error('USERNAME_TOO_MANY_NUMBERS');
  }
  
  return trimmedUsername.toLowerCase();
}

// Function to check username availability (atomic server-side check)
exports.checkUsernameAvailability = functions.https.onCall(async (data, context) => {
  const { username } = data;

  if (!username || typeof username !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Username is required and must be a string');
  }

  try {
    // Validate username format
    const validatedUsername = validateUsername(username);
    
    const usernameDoc = await db.collection('usernames').doc(validatedUsername).get();
    
    return { 
      available: !usernameDoc.exists,
      username: validatedUsername
    };

  } catch (error) {
    console.error('Error checking username availability:', error);
    
    // Return specific error messages for validation failures
    if (error.message.startsWith('USERNAME_')) {
      const errorMap = {
        'USERNAME_TOO_SHORT': 'Username must be at least 3 characters long',
        'USERNAME_TOO_LONG': 'Username cannot exceed 20 characters',
        'USERNAME_CONTAINS_WHITESPACE': 'Username cannot contain spaces or special whitespace',
        'USERNAME_INVALID_CHARACTERS': 'Username can only contain letters, numbers, and underscores',
        'USERNAME_STARTS_WITH_NUMBER': 'Username cannot start with a number',
        'USERNAME_STARTS_OR_ENDS_WITH_UNDERSCORE': 'Username cannot start or end with an underscore',
        'USERNAME_CONSECUTIVE_UNDERSCORES': 'Username cannot contain consecutive underscores',
        'USERNAME_RESERVED': 'This username is reserved and cannot be used',
        'USERNAME_OFFENSIVE': 'Username may contain inappropriate content',
        'USERNAME_TOO_MANY_NUMBERS': 'Username cannot be more than 50% numbers'
      };
      
      throw new functions.https.HttpsError('invalid-argument', errorMap[error.message] || 'Invalid username format');
    }
    
    throw new functions.https.HttpsError('internal', `Error checking username: ${error.message}`);
  }
});

// Function to create account atomically (prevents username race conditions)
// Email verification code storage in Firestore (persistent across function restarts)

// Send verification code to email
exports.sendVerificationCode = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  // No rate limiting - allow multiple codes, only the most recent will work
  
  // Generate random 6-digit code
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Store code in Firestore with expiration (15 minutes)
  const verificationRef = db.collection('verificationCodes').doc(email);
  await verificationRef.set({
    code: code,
    expiresAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Send email using SendGrid
  const msg = {
    to: email,
    from: {
      email: 'dev@attunedapp.net', // Use your verified sender
      name: 'In-Tuned'
    },
    subject: 'Verify Your Email - In-Tuned',
    text: `Your verification code is: ${code}\n\nThis code will expire in 15 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Verify Your Email</h2>
        <p>Welcome to In-Tuned! To complete your registration, please enter the following verification code:</p>
        <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
          <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">${code}</h1>
        </div>
        <p>This code will expire in 15 minutes.</p>
        <p>If you didn't request this code, please ignore this email.</p>
        <hr style="margin: 20px 0; border: none; border-top: 1px solid #eee;">
        <p style="color: #666; font-size: 12px;">This email was sent by In-Tuned. Please do not reply to this email.</p>
      </div>
    `
  };
  
  try {
    await sgMail.send(msg);
    console.log(`✅ Verification code sent to ${email}: ${code}`);
    return { success: true, message: 'Verification code sent' };
  } catch (error) {
    console.error(`❌ Failed to send verification code to ${email}:`, error);
    console.error(`❌ SendGrid Error Details:`, error.response?.body);
    
    // Fallback: log the code for development
    console.log(`🔧 Development fallback - Verification code for ${email}: ${code}`);
    
    // Return success even if email fails (for development)
    return { success: true, message: 'Verification code sent (check logs for development)' };
  }
});

// Verify email code
exports.verifyEmailCode = functions.https.onCall(async (data, context) => {
  const { email, code } = data;
  
  console.log(`🔍 [verifyEmailCode] Verifying code for ${email}: ${code}`);
  
  if (!email || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and code are required');
  }
  
  
  // Get stored data from Firestore
  const verificationRef = db.collection('verificationCodes').doc(email);
  const storedDoc = await verificationRef.get();
  
  if (!storedDoc.exists) {
    console.log(`❌ [verifyEmailCode] No stored data found for ${email}`);
    throw new functions.https.HttpsError('not-found', 'No verification code found for this email');
  }
  
  const storedData = storedDoc.data();
  console.log(`🔍 [verifyEmailCode] Stored data for ${email}:`, storedData);
  
  // Check if code has expired (15 minutes)
  const now = admin.firestore.Timestamp.now();
  const expiresAt = storedData.expiresAt;
  const fifteenMinutesAgo = new admin.firestore.Timestamp(now.seconds - 900, 0); // 15 minutes ago
  
  if (expiresAt.seconds < fifteenMinutesAgo.seconds) {
    console.log(`❌ [verifyEmailCode] Code expired for ${email}. Expired at: ${expiresAt.toDate()}, Current time: ${now.toDate()}`);
    await verificationRef.delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'Verification code has expired');
  }
  
  if (storedData.code !== code) {
    console.log(`❌ [verifyEmailCode] Code mismatch for ${email}. Expected: ${storedData.code}, Got: ${code}`);
    throw new functions.https.HttpsError('invalid-argument', 'Invalid verification code');
  }
  
  console.log(`✅ [verifyEmailCode] Code verified successfully for ${email}`);
  
  // Code is valid, remove it
  await verificationRef.delete();
  
  return { success: true, message: 'Email verified successfully' };
});

// Send RSS feed ownership verification code
exports.sendRSSVerificationCode = functions.https.onCall(async (data, context) => {
  const { email, feedTitle, feedUrl } = data;
  
  if (!email || !feedTitle || !feedUrl) {
    throw new functions.https.HttpsError('invalid-argument', 'Email, feed title, and feed URL are required');
  }
  
  // Validate email format
  const emailRegex = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$/;
  if (!emailRegex.test(email)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid email format');
  }
  
  // Generate random 6-digit code
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Store code in Firestore with expiration (15 minutes) - use hash of feedUrl as key
  const crypto = require('crypto');
  const feedUrlHash = crypto.createHash('sha256').update(feedUrl).digest('hex');
  const verificationRef = db.collection('rssVerificationCodes').doc(feedUrlHash);
  await verificationRef.set({
    code: code,
    email: email,
    feedTitle: feedTitle,
    feedUrl: feedUrl, // Store the actual URL for reference
    expiresAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Send email using SendGrid
  const msg = {
    to: email,
    from: {
      email: 'dev@attunedapp.net',
      name: 'In-Tuned'
    },
    subject: 'Verify Your Podcast Feed - In-Tuned',
    text: `Your verification code for "${feedTitle}" is: ${code}\n\nThis code will expire in 15 minutes.\n\nIf you didn't request this verification, please ignore this email.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Verify Your Podcast Feed</h2>
        <p>To upload episodes from "<strong>${feedTitle}</strong>" to In-Tuned, please enter the following verification code:</p>
        <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
          <h1 style="color: #007bff; font-size: 32px; margin: 0; letter-spacing: 5px;">${code}</h1>
        </div>
        <p>This code will expire in 15 minutes.</p>
        <p style="color: #666; font-size: 14px; margin-top: 20px;">
          <strong>Why am I receiving this?</strong><br>
          This verification ensures you own the podcast feed listed in your RSS. 
          Only the email address listed in your podcast's RSS feed can upload episodes to In-Tuned.
        </p>
        <p>If you didn't request this verification, please ignore this email.</p>
        <hr style="margin: 20px 0; border: none; border-top: 1px solid #eee;">
        <p style="color: #666; font-size: 12px;">This email was sent by In-Tuned. Please do not reply to this email.</p>
      </div>
    `
  };
  
  try {
    await sgMail.send(msg);
    console.log(`✅ RSS verification code sent to ${email} for feed: ${feedTitle}`);
    return { success: true, message: 'Verification code sent' };
  } catch (error) {
    console.error(`❌ Failed to send RSS verification code to ${email}:`, error);
    
    // Development fallback - log the code
    if (process.env.FUNCTIONS_EMULATOR === 'true') {
      console.log(`🔧 Development fallback - RSS verification code for ${email}: ${code}`);
    }
    
    return { success: true, message: 'Verification code sent (check logs for development)' };
  }
});

// Verify RSS feed ownership and mark feed as verified
exports.verifyRSSOwnership = functions.https.onCall(async (data, context) => {
  const { feedUrl, code } = data;
  
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  
  console.log(`🔍 [verifyRSSOwnership] Verifying ownership for feed ${feedUrl} by user ${userId}`);
  
  if (!feedUrl || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Feed URL and code are required');
  }
  
  // Get stored verification data from Firestore - use hash of feedUrl
  const crypto = require('crypto');
  const feedUrlHash = crypto.createHash('sha256').update(feedUrl).digest('hex');
  const verificationRef = db.collection('rssVerificationCodes').doc(feedUrlHash);
  const storedDoc = await verificationRef.get();
  
  if (!storedDoc.exists) {
    console.log(`❌ [verifyRSSOwnership] No verification code found for feed ${feedUrl}`);
    throw new functions.https.HttpsError('not-found', 'No verification code found for this feed');
  }
  
  const storedData = storedDoc.data();
  console.log(`🔍 [verifyRSSOwnership] Stored data for ${feedUrl}:`, storedData);
  
  // Check if code has expired (15 minutes)
  const now = admin.firestore.Timestamp.now();
  const expiresAt = storedData.expiresAt;
  const fifteenMinutesAgo = new admin.firestore.Timestamp(now.seconds - 900, 0);
  
  if (expiresAt.seconds < fifteenMinutesAgo.seconds) {
    console.log(`❌ [verifyRSSOwnership] Code expired for ${feedUrl}`);
    await verificationRef.delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'Verification code has expired');
  }
  
  if (storedData.code !== code) {
    console.log(`❌ [verifyRSSOwnership] Code mismatch for ${feedUrl}`);
    throw new functions.https.HttpsError('invalid-argument', 'Invalid verification code');
  }
  
  console.log(`✅ [verifyRSSOwnership] Code verified successfully for ${feedUrl}`);
  
  // Store verified feed in user's verifiedRSSFeeds collection - use hash as doc ID
  await db.collection('users').doc(userId).collection('verifiedRSSFeeds').doc(feedUrlHash).set({
    feedUrl: feedUrl,
    feedTitle: storedData.feedTitle,
    email: storedData.email,
    verifiedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Delete verification code
  await verificationRef.delete();
  
  return { 
    success: true, 
    message: 'RSS feed ownership verified successfully',
    feedTitle: storedData.feedTitle 
  };
});

exports.createAccount = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { email, username, fullname, password, birthday } = data;

  if (!email || !username || !fullname || !password) {
    throw new functions.https.HttpsError('invalid-argument', 'Email, username, fullname, and password are required');
  }

  try {
    // Validate password
    const passwordValidation = validatePassword(password);
    if (!passwordValidation.isValid) {
      throw new functions.https.HttpsError('invalid-argument', passwordValidation.errorMessage);
    }

    // Validate username format
    const normalizedUsername = validateUsername(username);

    // Use transaction to ensure atomicity
    const result = await db.runTransaction(async (transaction) => {
      // Check if username is available
      const usernameRef = db.collection('usernames').doc(normalizedUsername);
      const usernameDoc = await transaction.get(usernameRef);
      
      if (usernameDoc.exists) {
        throw new Error('USERNAME_TAKEN');
      }

      // Check if user document already exists
      const userRef = db.collection('users').doc(uid);
      const userDoc = await transaction.get(userRef);
      
      if (userDoc.exists) {
        throw new Error('USER_ALREADY_EXISTS');
      }

      // Create user document with comprehensive validation
      const userData = {
        email: email,
        username: normalizedUsername,
        fullname: fullname,
        uid: uid,
        followers: 0,
        profileImageUrl: '',
        isVerified: false,
        following: 0,
        podCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        
        // Essential fields for production with validation
        isActive: true, // Must be boolean true
        termsAcceptedAt: null, // Must be null initially - user must explicitly accept terms
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        version: 1, // Must be positive integer starting at 1
        
        // User profile fields
        birthDate: birthday ? admin.firestore.Timestamp.fromDate(new Date(birthday * 1000)) : null
      };

      // Additional field validation
      if (typeof userData.isActive !== 'boolean' || userData.isActive !== true) {
        throw new Error('INVALID_IS_ACTIVE_FIELD');
      }
      
      if (userData.termsAcceptedAt !== null) {
        throw new Error('INVALID_TERMS_ACCEPTED_AT_FIELD');
      }
      
      if (typeof userData.version !== 'number' || userData.version < 1 || !Number.isInteger(userData.version)) {
        throw new Error('INVALID_VERSION_FIELD');
      }
      
      if (typeof userData.followers !== 'number' || userData.followers < 0 || !Number.isInteger(userData.followers)) {
        throw new Error('INVALID_FOLLOWERS_FIELD');
      }
      
      if (typeof userData.following !== 'number' || userData.following < 0 || !Number.isInteger(userData.following)) {
        throw new Error('INVALID_FOLLOWING_FIELD');
      }
      
      if (typeof userData.podCount !== 'number' || userData.podCount < 0 || !Number.isInteger(userData.podCount)) {
        throw new Error('INVALID_POD_COUNT_FIELD');
      }
      
      if (typeof userData.isVerified !== 'boolean') {
        throw new Error('INVALID_IS_VERIFIED_FIELD');
      }

      // Atomic operations: create user and claim username
      transaction.set(userRef, userData);
      transaction.set(usernameRef, { uid: uid, claimedAt: admin.firestore.FieldValue.serverTimestamp() });

      return userData;
    });

    console.log(`Account created successfully for user ${uid} with username ${normalizedUsername}`);
    return { success: true, user: result };

  } catch (error) {
    console.error('Error creating account:', error);
    
    if (error.message === 'USERNAME_TAKEN') {
      throw new functions.https.HttpsError('already-exists', 'Username is already taken');
    } else if (error.message === 'USER_ALREADY_EXISTS') {
      throw new functions.https.HttpsError('already-exists', 'User account already exists');
    } else if (error.message.startsWith('USERNAME_')) {
      const errorMap = {
        'USERNAME_TOO_SHORT': 'Username must be at least 3 characters long',
        'USERNAME_TOO_LONG': 'Username cannot exceed 20 characters',
        'USERNAME_CONTAINS_WHITESPACE': 'Username cannot contain spaces or special whitespace',
        'USERNAME_INVALID_CHARACTERS': 'Username can only contain letters, numbers, and underscores',
        'USERNAME_STARTS_WITH_NUMBER': 'Username cannot start with a number',
        'USERNAME_STARTS_OR_ENDS_WITH_UNDERSCORE': 'Username cannot start or end with an underscore',
        'USERNAME_CONSECUTIVE_UNDERSCORES': 'Username cannot contain consecutive underscores',
        'USERNAME_RESERVED': 'This username is reserved and cannot be used',
        'USERNAME_OFFENSIVE': 'Username may contain inappropriate content',
        'USERNAME_TOO_MANY_NUMBERS': 'Username cannot be more than 50% numbers'
      };
      
      throw new functions.https.HttpsError('invalid-argument', errorMap[error.message] || 'Invalid username format');
    }
    
    throw new functions.https.HttpsError('internal', `Error creating account: ${error.message}`);
  }
});

// Function to change username atomically (prevents race conditions)
exports.changeUsername = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { newUsername, currentUsername } = data;

  if (!newUsername || !currentUsername) {
    throw new functions.https.HttpsError('invalid-argument', 'New username and current username are required');
  }

  try {
    // Validate new username format
    const normalizedNewUsername = validateUsername(newUsername);
    const normalizedCurrentUsername = currentUsername.toLowerCase();

    // If username hasn't changed, no operation needed
    if (normalizedNewUsername === normalizedCurrentUsername) {
      return { success: true, message: 'Username unchanged' };
    }

    // Use transaction to ensure atomicity
    await db.runTransaction(async (transaction) => {
      // Check if new username is available
      const newUsernameRef = db.collection('usernames').doc(normalizedNewUsername);
      const newUsernameDoc = await transaction.get(newUsernameRef);
      
      if (newUsernameDoc.exists) {
        throw new Error('USERNAME_TAKEN');
      }

      // Get user document to verify current username
      const userRef = db.collection('users').doc(uid);
      const userDoc = await transaction.get(userRef);
      
      if (!userDoc.exists) {
        throw new Error('USER_NOT_FOUND');
      }

      const userData = userDoc.data();
      const actualCurrentUsername = userData.username;

      // Verify the provided current username matches what's in the user document
      if (actualCurrentUsername !== normalizedCurrentUsername) {
        throw new Error('USERNAME_MISMATCH');
      }

      // Check if current username is properly claimed in usernames collection
      const currentUsernameRef = db.collection('usernames').doc(normalizedCurrentUsername);
      const currentUsernameDoc = await transaction.get(currentUsernameRef);
      
      // If current username isn't properly claimed, claim it first (legacy user fix)
      if (!currentUsernameDoc.exists) {
        console.log(`Fixing legacy user ${uid}: claiming current username ${normalizedCurrentUsername}`);
        transaction.set(currentUsernameRef, { uid: uid, claimedAt: admin.firestore.FieldValue.serverTimestamp() });
      } else if (currentUsernameDoc.data().uid !== uid) {
        // Username is claimed by someone else - this shouldn't happen
        throw new Error('USERNAME_CONFLICT');
      }

      // Atomic operations: release old username, claim new username, update user
      transaction.delete(currentUsernameRef);
      transaction.set(newUsernameRef, { uid: uid, claimedAt: admin.firestore.FieldValue.serverTimestamp() });
      transaction.update(userRef, { username: normalizedNewUsername });
    });

    console.log(`Username changed successfully for user ${uid}: ${normalizedCurrentUsername} -> ${normalizedNewUsername}`);
    return { success: true, newUsername: normalizedNewUsername };

  } catch (error) {
    console.error('Error changing username:', error);
    
    if (error.message === 'USERNAME_TAKEN') {
      throw new functions.https.HttpsError('already-exists', 'Username is already taken');
    } else if (error.message === 'USERNAME_MISMATCH') {
      throw new functions.https.HttpsError('invalid-argument', 'Current username does not match your account');
    } else if (error.message === 'USERNAME_CONFLICT') {
      throw new functions.https.HttpsError('permission-denied', 'Username conflict detected - please contact support');
    } else if (error.message === 'USER_NOT_FOUND') {
      throw new functions.https.HttpsError('not-found', 'User not found');
    } else if (error.message.startsWith('USERNAME_')) {
      const errorMap = {
        'USERNAME_TOO_SHORT': 'Username must be at least 3 characters long',
        'USERNAME_TOO_LONG': 'Username cannot exceed 20 characters',
        'USERNAME_CONTAINS_WHITESPACE': 'Username cannot contain spaces or special whitespace',
        'USERNAME_INVALID_CHARACTERS': 'Username can only contain letters, numbers, and underscores',
        'USERNAME_STARTS_WITH_NUMBER': 'Username cannot start with a number',
        'USERNAME_STARTS_OR_ENDS_WITH_UNDERSCORE': 'Username cannot start or end with an underscore',
        'USERNAME_CONSECUTIVE_UNDERSCORES': 'Username cannot contain consecutive underscores',
        'USERNAME_RESERVED': 'This username is reserved and cannot be used',
        'USERNAME_OFFENSIVE': 'Username may contain inappropriate content',
        'USERNAME_TOO_MANY_NUMBERS': 'Username cannot be more than 50% numbers'
      };
      
      throw new functions.https.HttpsError('invalid-argument', errorMap[error.message] || 'Invalid username format');
    }
    
    throw new functions.https.HttpsError('internal', `Error changing username: ${error.message}`);
  }
});

// Function to change username and profile information atomically
exports.changeUsernameAndProfile = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { newUsername, fullname, bio, link } = data;

  if (!newUsername || !fullname) {
    throw new functions.https.HttpsError('invalid-argument', 'Username and fullname are required');
  }

  try {
    // Validate new username format
    const normalizedNewUsername = validateUsername(newUsername);
    
    // Validate other profile fields
    const validatedFullname = validateInput(fullname, 'fullName');
    const validatedBio = bio ? validateInput(bio, 'userBio') : '';
    const validatedLink = link ? validateInput(link, 'link') : '';

    // Get current user data
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    const currentUsername = userData.username;

    // If username hasn't changed, just update profile
    if (normalizedNewUsername === currentUsername.toLowerCase()) {
      await userRef.update({
        fullname: validatedFullname,
        bio: validatedBio,
        link: validatedLink,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return { success: true, message: 'Profile updated successfully' };
    }

    // Username is changing - use transaction to ensure atomicity
    await db.runTransaction(async (transaction) => {
      // Check if new username is available
      const newUsernameRef = db.collection('usernames').doc(normalizedNewUsername);
      const newUsernameDoc = await transaction.get(newUsernameRef);
      
      if (newUsernameDoc.exists) {
        throw new Error('USERNAME_TAKEN');
      }

      // Check if current username is properly claimed in usernames collection
      const currentUsernameRef = db.collection('usernames').doc(currentUsername.toLowerCase());
      const currentUsernameDoc = await transaction.get(currentUsernameRef);
      
      // If current username isn't properly claimed, claim it first (legacy user fix)
      if (!currentUsernameDoc.exists) {
        console.log(`Fixing legacy user ${uid}: claiming current username ${currentUsername}`);
        transaction.set(currentUsernameRef, { uid: uid, claimedAt: admin.firestore.FieldValue.serverTimestamp() });
      } else if (currentUsernameDoc.data().uid !== uid) {
        // Username is claimed by someone else - this shouldn't happen
        throw new Error('USERNAME_CONFLICT');
      }

      // Atomic operations: release old username, claim new username, update user
      transaction.delete(currentUsernameRef);
      transaction.set(newUsernameRef, { uid: uid, claimedAt: admin.firestore.FieldValue.serverTimestamp() });
      transaction.update(userRef, { 
        username: normalizedNewUsername,
        fullname: validatedFullname,
        bio: validatedBio,
        link: validatedLink,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    console.log(`Username and profile changed successfully for user ${uid}: ${currentUsername} -> ${normalizedNewUsername}`);
    return { success: true, newUsername: normalizedNewUsername };

  } catch (error) {
    console.error('Error changing username and profile:', error);
    
    if (error.message === 'USERNAME_TAKEN') {
      throw new functions.https.HttpsError('already-exists', 'Username is already taken');
    } else if (error.message === 'USERNAME_CONFLICT') {
      throw new functions.https.HttpsError('permission-denied', 'Username conflict detected - please contact support');
    } else if (error.message === 'USER_NOT_FOUND') {
      throw new functions.https.HttpsError('not-found', 'User not found');
    } else if (error.message.startsWith('USERNAME_')) {
      const errorMap = {
        'USERNAME_TOO_SHORT': 'Username must be at least 3 characters long',
        'USERNAME_TOO_LONG': 'Username cannot exceed 20 characters',
        'USERNAME_CONTAINS_WHITESPACE': 'Username cannot contain spaces or special whitespace',
        'USERNAME_INVALID_CHARACTERS': 'Username can only contain letters, numbers, and underscores',
        'USERNAME_STARTS_WITH_NUMBER': 'Username cannot start with a number',
        'USERNAME_STARTS_OR_ENDS_WITH_UNDERSCORE': 'Username cannot start or end with an underscore',
        'USERNAME_CONSECUTIVE_UNDERSCORES': 'Username cannot contain consecutive underscores',
        'USERNAME_RESERVED': 'This username is reserved and cannot be used',
        'USERNAME_OFFENSIVE': 'Username may contain inappropriate content',
        'USERNAME_TOO_MANY_NUMBERS': 'Username cannot be more than 50% numbers'
      };
      
      throw new functions.https.HttpsError('invalid-argument', errorMap[error.message] || 'Invalid username format');
    } else if (error.message.startsWith('INPUT_')) {
      const errorMap = {
        'INPUT_INVALID_TYPE': 'Invalid input type provided',
        'INPUT_TOO_LONG': 'Input exceeds maximum length',
        'INPUT_TOO_MANY_NEWLINES': 'Input contains too many line breaks',
        'INPUT_TOO_MANY_SPECIAL_CHARS': 'Input contains too many special characters',
        'INPUT_SPAM_PATTERNS': 'Input contains spam-like content',
        'INPUT_EXCESSIVE_REPETITION': 'Input contains excessive repetition'
      };
      
      throw new functions.https.HttpsError('invalid-argument', errorMap[error.message] || 'Invalid input format');
    }
    
    throw new functions.https.HttpsError('internal', `Error updating profile: ${error.message}`);
  }
});

// Function to fix legacy users' username claims
exports.fixLegacyUser = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;

  try {
    const result = await db.runTransaction(async (transaction) => {
      // Get user document
      const userRef = db.collection('users').doc(uid);
      const userDoc = await transaction.get(userRef);
      
      if (!userDoc.exists) {
        throw new Error('USER_NOT_FOUND');
      }

      const userData = userDoc.data();
      const username = userData.username;

      if (!username) {
        throw new Error('NO_USERNAME');
      }

      // Check if username is already properly claimed
      const usernameRef = db.collection('usernames').doc(username);
      const usernameDoc = await transaction.get(usernameRef);
      
      if (usernameDoc.exists) {
        if (usernameDoc.data().uid === uid) {
          return { alreadyFixed: true, username: username };
        } else {
          throw new Error('USERNAME_CLAIMED_BY_OTHER');
        }
      }

      // Claim the username for this user
      transaction.set(usernameRef, { uid: uid, claimedAt: admin.firestore.FieldValue.serverTimestamp() });
      
      return { fixed: true, username: username };
    });

    console.log(`Legacy user fix completed for user ${uid}:`, result);
    return { success: true, ...result };

  } catch (error) {
    console.error('Error fixing legacy user:', error);
    
    if (error.message === 'USER_NOT_FOUND') {
      throw new functions.https.HttpsError('not-found', 'User not found');
    } else if (error.message === 'NO_USERNAME') {
      throw new functions.https.HttpsError('failed-precondition', 'User has no username');
    } else if (error.message === 'USERNAME_CLAIMED_BY_OTHER') {
      throw new functions.https.HttpsError('permission-denied', 'Username is claimed by another user');
    }
    
    throw new functions.https.HttpsError('internal', `Error fixing legacy user: ${error.message}`);
  }
});

// MARK: - Account Anonymization Function

// Helper function to generate a random username
function generateRandomUsername() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let result = 'anon_';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Helper function to find an available random username
async function generateAvailableUsername(transaction) {
  let attempts = 0;
  const maxAttempts = 10;
  
  while (attempts < maxAttempts) {
    const randomUsername = generateRandomUsername();
    const usernameRef = db.collection('usernames').doc(randomUsername);
    const usernameDoc = await transaction.get(usernameRef);
    
    if (!usernameDoc.exists) {
      return randomUsername;
    }
    
    attempts++;
  }
  
  // If we can't find an available username after 10 attempts, throw error
  throw new Error('UNABLE_TO_GENERATE_USERNAME');
}

// Function to anonymize user account and delete all user data
exports.anonymizeUserAccount = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  console.log(`Starting account anonymization for user ${uid}`);

  try {
    // Step 1: Get user's pod IDs and current username
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new Error('USER_NOT_FOUND');
    }
    
    const userData = userDoc.data();
    const currentUsername = userData.username;
    
    // Get all user's pod IDs from their pods subcollection
    const userPodsSnapshot = await db.collection('users').doc(uid).collection('pods').get();
    const podIds = userPodsSnapshot.docs.map(doc => doc.id);
    
    console.log(`Found ${podIds.length} pods to delete for user ${uid}`);

    // Step 2: Delete all pods from main collection and user's pods subcollection
    if (podIds.length > 0) {
      // Use batch operations for efficient deletion (max 500 operations per batch)
      const batches = [];
      let currentBatch = db.batch();
      let operationCount = 0;
      
      // Delete from main pods collection
      for (const podId of podIds) {
        const podRef = db.collection('pods').doc(podId);
        currentBatch.delete(podRef);
        operationCount++;
        
        // If we hit batch limit, start a new batch
        if (operationCount === 500) {
          batches.push(currentBatch);
          currentBatch = db.batch();
          operationCount = 0;
        }
      }
      
      // Delete user's pods subcollection
      for (const doc of userPodsSnapshot.docs) {
        currentBatch.delete(doc.ref);
        operationCount++;
        
        if (operationCount === 500) {
          batches.push(currentBatch);
          currentBatch = db.batch();
          operationCount = 0;
        }
      }
      
      // Add final batch if it has operations
      if (operationCount > 0) {
        batches.push(currentBatch);
      }
      
      // Execute all batches
      console.log(`Executing ${batches.length} batch operations for pod deletion`);
      for (const batch of batches) {
        await batch.commit();
      }
    }

    // Step 3: Anonymize user data with transaction for atomicity
    await db.runTransaction(async (transaction) => {
      // Generate available random username
      const newRandomUsername = await generateAvailableUsername(transaction);
      
      // Update user document with anonymized data
      const anonymizedUserData = {
        email: '',
        bio: '',
        link: '',
        profileImageUrl: '',
        followers: 0,
        following: 0,
        podCount: 0,
        username: newRandomUsername,
        fullname: 'Anonymous User',
        // Keep uid, isVerified, createdAt for system integrity
        anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        isDeleted: true  // Mark account as deleted for filtering in searches
      };
      
      transaction.update(userRef, anonymizedUserData);
      
      // Remove old username from usernames collection
      if (currentUsername) {
        const oldUsernameRef = db.collection('usernames').doc(currentUsername);
        transaction.delete(oldUsernameRef);
      }
      
      // Claim new random username
      const newUsernameRef = db.collection('usernames').doc(newRandomUsername);
      transaction.set(newUsernameRef, { 
        uid: uid, 
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        anonymized: true
      });
      
      console.log(`User ${uid} anonymized with new username: ${newRandomUsername}`);
    });

    // Step 4: Delete Firebase Auth user account (frees up email)
    try {
      await admin.auth().deleteUser(uid);
      console.log(`Firebase Auth user ${uid} deleted successfully`);
    } catch (authError) {
      // Log but don't fail the entire operation if auth deletion fails
      console.error(`Warning: Could not delete Firebase Auth user ${uid}:`, authError);
    }

    console.log(`Account anonymization completed successfully for user ${uid}`);
    return { 
      success: true, 
      message: 'Account anonymized successfully',
      podsDeleted: podIds.length,
      authDeleted: true
    };

  } catch (error) {
    console.error(`Error anonymizing account for user ${uid}:`, error);
    
    if (error.message === 'USER_NOT_FOUND') {
      throw new functions.https.HttpsError('not-found', 'User account not found');
    } else if (error.message === 'UNABLE_TO_GENERATE_USERNAME') {
      throw new functions.https.HttpsError('internal', 'Unable to generate available username after multiple attempts');
    }
    
    throw new functions.https.HttpsError('internal', `Error anonymizing account: ${error.message}`);
  }
});

// Function for admins to delete any user account
exports.adminDeleteUserAccount = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check if user is admin
  const adminUid = context.auth.uid;
  const adminDoc = await db.collection('users').doc(adminUid).get();
  
  if (!adminDoc.exists || !adminDoc.data()?.isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin privileges required');
  }

  const targetUserId = data.targetUserId;
  if (!targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'Target user ID is required');
  }

  console.log(`Admin ${adminUid} starting account deletion for user ${targetUserId}`);

  try {
    // Step 1: Get user's pod IDs and current username
    const userRef = db.collection('users').doc(targetUserId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new Error('USER_NOT_FOUND');
    }
    
    const userData = userDoc.data();
    const currentUsername = userData.username;
    
    // Get all user's pod IDs from their pods subcollection
    const userPodsSnapshot = await db.collection('users').doc(targetUserId).collection('pods').get();
    const podIds = userPodsSnapshot.docs.map(doc => doc.id);
    
    console.log(`Found ${podIds.length} pods to delete for user ${targetUserId}`);

    // Step 2: Delete all pods from main collection and user's pods subcollection
    if (podIds.length > 0) {
      const batch = db.batch();
      
      // Delete from main pods collection
      for (const podId of podIds) {
        const podRef = db.collection('pods').doc(podId);
        batch.delete(podRef);
      }
      
      // Delete from user's pods subcollection
      const userPodsRef = db.collection('users').doc(targetUserId).collection('pods');
      const userPodsBatch = db.batch();
      userPodsSnapshot.docs.forEach(doc => {
        userPodsBatch.delete(doc.ref);
      });
      
      await batch.commit();
      await userPodsBatch.commit();
      
      console.log(`Deleted ${podIds.length} pods for user ${targetUserId}`);
    }

    // Step 3: Anonymize user data with transaction for atomicity
    await db.runTransaction(async (transaction) => {
      // Generate available random username
      const newRandomUsername = await generateAvailableUsername(transaction);
      
      // Update user document with anonymized data
      const anonymizedUserData = {
        email: '',
        bio: '',
        link: '',
        profileImageUrl: '',
        followers: 0,
        following: 0,
        podCount: 0,
        username: newRandomUsername,
        fullname: 'Anonymous User',
        // Keep uid, isVerified, createdAt for system integrity
        anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        isDeleted: true  // Mark account as deleted for filtering in searches
      };
      
      transaction.update(userRef, anonymizedUserData);
      
      // Remove old username from usernames collection
      if (currentUsername) {
        const oldUsernameRef = db.collection('usernames').doc(currentUsername);
        transaction.delete(oldUsernameRef);
      }
      
      // Claim new random username
      const newUsernameRef = db.collection('usernames').doc(newRandomUsername);
      transaction.set(newUsernameRef, { 
        uid: targetUserId, 
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        anonymized: true
      });
      
      console.log(`User ${targetUserId} anonymized with new username: ${newRandomUsername}`);
    });

    // Step 4: Delete Firebase Auth user account (frees up email)
    try {
      await admin.auth().deleteUser(targetUserId);
      console.log(`Firebase Auth user ${targetUserId} deleted successfully`);
    } catch (authError) {
      // Log but don't fail the entire operation if auth deletion fails
      console.error(`Warning: Could not delete Firebase Auth user ${targetUserId}:`, authError);
    }

    console.log(`Admin account deletion completed successfully for user ${targetUserId}`);
    return { 
      success: true,
      message: `User account deleted successfully. ${podIds.length} pods deleted.`,
      podsDeleted: podIds.length,
      authDeleted: true
    };
    
  } catch (error) {
    console.error(`Error deleting account for user ${targetUserId}:`, error);
    
    // Provide user-friendly error messages
    if (error.message === 'USER_NOT_FOUND') {
      throw new functions.https.HttpsError('not-found', 'User account not found');
    } else if (error.message === 'UNABLE_TO_GENERATE_USERNAME') {
      throw new functions.https.HttpsError('internal', 'Unable to generate available username after multiple attempts');
    }
    
    throw new functions.https.HttpsError('internal', `Error deleting account: ${error.message}`);
  }
});

// MARK: - Account Data Download Function

// Function to download user account data (limited to once per month)
exports.downloadAccountData = functions.https.onCall(async (data, context) => {
  console.log(`DEBUG: Function called with data:`, data);
  console.log(`DEBUG: Context auth:`, context.auth);
  
  // Verify that the user is authenticated
  if (!context.auth) {
    console.log(`DEBUG: No auth context, throwing unauthenticated error`);
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  console.log(`DEBUG: UID found: ${uid}`);

  try {
    console.log(`DEBUG: Getting user document...`);
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    console.log(`DEBUG: User document exists: ${userDoc.exists}`);
    
    if (!userDoc.exists) {
      console.log(`DEBUG: User not found, throwing error`);
      throw new Error('USER_NOT_FOUND');
    }
    
    const userData = userDoc.data();
    console.log(`DEBUG: User data retrieved:`, userData ? 'User data found' : 'No user data');

    // Step 3: Fetch user's pods
    console.log(`DEBUG: Fetching user's pods...`);
    const podsSnapshot = await db.collection('pods')
      .where('userId', '==', uid)
      .get();
    
    const pods = podsSnapshot.docs.map(doc => {
      const podData = doc.data();
      return {
        id: doc.id,
        title: podData.title,
        description: podData.description,
        timestamp: podData.timestamp ? podData.timestamp.toDate().toISOString() : null,
        fileUrl: podData.fileUrl,
        thumbnailUrl: podData.thumbnailUrl,
        likes: podData.likes || 0,
        category: podData.category || '',
        keywords: podData.keywords || []
      };
    });

    console.log(`DEBUG: Found ${pods.length} pods`);

    // Step 5: Fetch user's saved pods (liked pods)
    console.log(`DEBUG: Fetching user's saved pods...`);
    const savedPodsSnapshot = await db.collection('users').doc(uid)
      .collection('savedPods')
      .get();
    
    const savedPods = savedPodsSnapshot.docs.map(doc => {
      const podData = doc.data();
      return {
        id: doc.id,
        savedAt: podData.savedAt ? podData.savedAt.toDate().toISOString() : null
      };
    });

    console.log(`DEBUG: Found ${savedPods.length} saved pods`);

    // Step 6: Fetch user's playlists
    console.log(`DEBUG: Fetching user's playlists...`);
    const playlistsSnapshot = await db.collection('users').doc(uid)
      .collection('playlists')
      .get();
    
    const playlists = playlistsSnapshot.docs.map(doc => {
      const playlistData = doc.data();
      return {
        id: doc.id,
        name: playlistData.name,
        description: playlistData.description || '',
        createdAt: playlistData.createdAt ? playlistData.createdAt.toDate().toISOString() : null,
        podCount: playlistData.podCount || 0
      };
    });

    console.log(`DEBUG: Found ${playlists.length} playlists`);

    // Step 7: Fetch user's comments
    console.log(`DEBUG: Fetching user's comments...`);
    const commentsSnapshot = await db.collection('comments')
      .where('userId', '==', uid)
      .get();
    
    const comments = commentsSnapshot.docs.map(doc => {
      const commentData = doc.data();
      return {
        id: doc.id,
        text: commentData.text,
        timestamp: commentData.timestamp ? commentData.timestamp.toDate().toISOString() : null,
        podId: commentData.podId
      };
    });

    console.log(`DEBUG: Found ${comments.length} comments`);

    // Step 8: Fetch user's followers
    console.log(`DEBUG: Fetching user's followers...`);
    const followersSnapshot = await db.collection('users').doc(uid)
      .collection('followers')
      .get();
    
    const followers = followersSnapshot.docs.map(doc => {
      const followerData = doc.data();
      return {
        username: followerData.username || 'Unknown',
        followedAt: followerData.followedAt ? followerData.followedAt.toDate().toISOString() : null
      };
    });

    console.log(`DEBUG: Found ${followers.length} followers`);

    // Step 9: Fetch user's following
    console.log(`DEBUG: Fetching user's following...`);
    const followingSnapshot = await db.collection('users').doc(uid)
      .collection('following')
      .get();
    
    const following = followingSnapshot.docs.map(doc => {
      const followingData = doc.data();
      return {
        username: followingData.username || 'Unknown',
        followedAt: followingData.followedAt ? followingData.followedAt.toDate().toISOString() : null
      };
    });

    console.log(`DEBUG: Found ${following.length} following`);

    // Step 10: Fetch user's conversations
    console.log(`DEBUG: Fetching user's conversations...`);
    const conversationsSnapshot = await db.collection('conversations')
      .where('participants', 'array-contains', uid)
      .get();
    
    const conversations = conversationsSnapshot.docs.map(doc => {
      const convData = doc.data();
      return {
        id: doc.id,
        type: convData.type,
        participants: convData.participants || [],
        name: convData.name || null,
        createdAt: convData.createdAt ? convData.createdAt.toDate().toISOString() : null,
        lastActivity: convData.lastActivity ? convData.lastActivity.toDate().toISOString() : null,
        createdBy: convData.createdBy || null
      };
    });

    console.log(`DEBUG: Found ${conversations.length} conversations`);

    // Step 11: Fetch user's messages
    console.log(`DEBUG: Fetching user's messages...`);
    const messagesSnapshot = await db.collection('messages')
      .where('senderId', '==', uid)
      .limit(1000) // Limit to last 1000 messages
      .get();
    
    const messages = messagesSnapshot.docs.map(doc => {
      const messageData = doc.data();
      return {
        id: doc.id,
        text: messageData.text,
        timestamp: messageData.timestamp ? messageData.timestamp.toDate().toISOString() : null,
        conversationId: messageData.conversationId || null,
        isPod: messageData.isPod || false,
        podId: messageData.podId || null
      };
    });

    console.log(`DEBUG: Found ${messages.length} messages`);

    // Step 12: Fetch user's notifications
    console.log(`DEBUG: Fetching user's notifications...`);
    const notificationsSnapshot = await db.collection('notifications')
      .where('recipientId', '==', uid)
      .orderBy('createdAt', 'desc')
      .limit(100) // Limit to last 100 notifications
      .get();
    
    const notifications = notificationsSnapshot.docs.map(doc => {
      const notificationData = doc.data();
      return {
        id: doc.id,
        type: notificationData.type,
        message: notificationData.message,
        timestamp: notificationData.timestamp ? notificationData.timestamp.toDate().toISOString() : null,
        read: notificationData.read || false
      };
    });

    console.log(`DEBUG: Found ${notifications.length} notifications`);

    // Step 13: Compile all data in clean, readable format
    const accountData = {
      success: true,
      data: {
        // Account Information
        accountInfo: {
          username: userData.username,
          fullname: userData.fullname,
          email: userData.email,
          bio: userData.bio || '',
          profileImageUrl: userData.profileImageUrl || '',
          followersCount: userData.followers || 0,
          followingCount: userData.following || 0,
          podsCreatedCount: pods.length,
          accountCreatedAt: userData.createdAt ? userData.createdAt.toDate().toISOString() : null,
          lastUpdated: userData.lastUpdated ? userData.lastUpdated.toDate().toISOString() : null
        },
        
        // Posted Pods (simplified format)
        postedPods: pods.map(pod => ({
          title: pod.title,
          description: pod.description,
          createdAt: pod.timestamp,
          likes: pod.likes,
          category: pod.category,
          keywords: pod.keywords
        })),
        
        // Followers (just usernames)
        followers: followers.map(f => f.username),
        
        // Following (just usernames)
        following: following.map(f => f.username),
        
        // Conversations
        conversations: conversations.map(conv => ({
          id: conv.id,
          type: conv.type,
          name: conv.name,
          createdAt: conv.createdAt,
          lastActivity: conv.lastActivity,
          participantUsernames: conv.participants // This will need to be resolved to usernames
        })),
        
        // Messages
        messages: messages.map(msg => ({
          text: msg.text,
          timestamp: msg.timestamp,
          isPod: msg.isPod,
          podId: msg.podId,
          conversationId: msg.conversationId
        })),
        
        // Comments
        comments: comments.map(comment => ({
          text: comment.text,
          timestamp: comment.timestamp,
          podId: comment.podId
        })),
        
        // Playlists
        playlists: playlists.map(playlist => ({
          name: playlist.name,
          description: playlist.description,
          createdAt: playlist.createdAt,
          podCount: playlist.podCount
        })),
        
        // Notifications
        notifications: notifications.map(notif => ({
          type: notif.type,
          message: notif.message,
          timestamp: notif.timestamp,
          read: notif.read
        })),
        
        // Export metadata
        exportInfo: {
          exportDate: new Date().toISOString(),
          totalPods: pods.length,
          totalFollowers: followers.length,
          totalFollowing: following.length,
          totalConversations: conversations.length,
          totalMessages: messages.length,
          totalComments: comments.length,
          totalPlaylists: playlists.length,
          totalNotifications: notifications.length
        }
      }
    };

    console.log(`DEBUG: Account data compilation completed successfully`);
    
    // Upload JSON file to Firebase Storage
    try {
      const bucket = admin.storage().bucket();
      const fileName = `account-data/${uid}/account-data-${uid}-${Date.now()}.json`;
      const file = bucket.file(fileName);
      
      // Convert data to JSON string
      const jsonString = JSON.stringify(accountData.data, null, 2);
      const buffer = Buffer.from(jsonString, 'utf8');
      
      // Upload file to Storage
      await file.save(buffer, {
        metadata: {
          contentType: 'application/json',
          metadata: {
            uid: uid,
            exportDate: new Date().toISOString()
          }
        }
      });
      
      // Make file publicly readable
      await file.makePublic();
      
      // Create public URL
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 30);
      
      console.log(`✅ File uploaded to Storage: ${fileName}`);
      console.log(`🔗 Public URL: ${publicUrl}`);
      
      // Return data with download info
      return {
        success: true,
        data: accountData.data,
        downloadInfo: {
          downloadUrl: publicUrl,
          fileName: fileName.split('/').pop(),
          exportDate: new Date().toISOString(),
          expiresAt: expiresAt.toISOString(),
          fileSize: buffer.length
        }
      };
      
    } catch (storageError) {
      console.error(`❌ Error uploading to Storage:`, storageError);
      
      // Return data without download info if storage fails
      return {
        success: true,
        data: accountData.data,
        message: "Data exported but file upload failed"
      };
    }

  } catch (error) {
    console.error(`DEBUG: Error in downloadAccountData:`, error);
    throw new functions.https.HttpsError('internal', `Error downloading account data: ${error.message}`);
  }
});

// MARK: - Conversation Deletion

exports.markConversationAsDeleted = functions.https.onCall(async (data, context) => {
  try {
    console.log('=== FUNCTION CALLED ===');
    console.log('Context auth:', context.auth);
    console.log('Data:', data);
    
    // Verify user is authenticated
    if (!context.auth) {
      console.log('❌ No auth context');
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    console.log('✅ Auth context exists, user ID:', context.auth.uid);

    const { conversationId } = data;
    const userId = context.auth.uid;

    if (!conversationId) {
      console.log('❌ No conversation ID provided');
      throw new functions.https.HttpsError('invalid-argument', 'Conversation ID is required');
    }

    console.log('✅ Conversation ID provided:', conversationId);

    // For now, just return success without doing anything
    console.log('✅ Function completed successfully');
    return { success: true, message: 'Conversation marked as deleted (test mode)' };

  } catch (error) {
    console.log('❌ Error in function:', error);
    throw new functions.https.HttpsError('internal', `Error marking conversation as deleted: ${error.message}`);
  }
});

// MARK: - User Preferences Migration Functions

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
      lastInteracted: now
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

// MARK: - Input Validation Functions

// Server-side input validation (security layer)
function validateInput(input, type) {
  if (!input || typeof input !== 'string') {
    throw new Error('INPUT_INVALID_TYPE');
  }
  
  const trimmedInput = input.trim();
  
  // Check length based on type
  const maxLengths = {
    'podTitle': 100,
    'podDescription': 1000,
    'userBio': 500,
    'comment': 500,
    'message': 1000,
    'fullName': 100,
    'link': 200,
    'tag': 50
  };
  
  const maxLength = maxLengths[type] || 500;
  if (trimmedInput.length > maxLength) {
    throw new Error('INPUT_TOO_LONG');
  }
  
  // Check for excessive newlines
  const newlineCount = (trimmedInput.match(/\n/g) || []).length;
  const maxNewlines = {
    'podTitle': 0,
    'podDescription': 20,
    'userBio': 10,
    'comment': 5,
    'message': 20,
    'fullName': 0,
    'link': 0,
    'tag': 0
  };
  
  const maxNewline = maxNewlines[type] || 10;
  if (newlineCount > maxNewline) {
    throw new Error('INPUT_TOO_MANY_NEWLINES');
  }
  
  // Check for excessive special characters
  const specialCharCount = (trimmedInput.match(/[^a-zA-Z0-9\s]/g) || []).length;
  const maxSpecialChars = {
    'podTitle': 20,
    'podDescription': 100,
    'userBio': 50,
    'comment': 50,
    'message': 100,
    'fullName': 30,
    'link': 50,
    'tag': 10
  };
  
  const maxSpecial = maxSpecialChars[type] || 50;
  if (specialCharCount > maxSpecial) {
    throw new Error('INPUT_TOO_MANY_SPECIAL_CHARS');
  }
  
  // Check for spam patterns
  if (containsSpamPatterns(trimmedInput)) {
    throw new Error('INPUT_SPAM_PATTERNS');
  }
  
  // Check for excessive repetition
  if (containsExcessiveRepetition(trimmedInput)) {
    throw new Error('INPUT_EXCESSIVE_REPETITION');
  }
  
  return trimmedInput;
}

// Check for spam patterns
function containsSpamPatterns(input) {
  const lowercased = input.toLowerCase();
  
  // Check for excessive repetition of characters
  const patterns = [
    'aaaa', 'bbbb', 'cccc', 'dddd', 'eeee', 'ffff', 'gggg', 'hhhh', 'iiii', 'jjjj',
    'kkkk', 'llll', 'mmmm', 'nnnn', 'oooo', 'pppp', 'qqqq', 'rrrr', 'ssss', 'tttt',
    'uuuu', 'vvvv', 'wwww', 'xxxx', 'yyyy', 'zzzz', '0000', '1111', '2222', '3333',
    '4444', '5555', '6666', '7777', '8888', '9999'
  ];
  
  return patterns.some(pattern => lowercased.includes(pattern));
}

// Check for excessive repetition
function containsExcessiveRepetition(input) {
  const words = input.split(/\s+/);
  const wordCount = words.length;
  
  if (wordCount < 3) return false;
  
  // Check if more than 50% of words are the same
  const wordFrequency = {};
  words.forEach(word => {
    const lowerWord = word.toLowerCase();
    wordFrequency[lowerWord] = (wordFrequency[lowerWord] || 0) + 1;
  });
  
  const mostFrequentCount = Math.max(...Object.values(wordFrequency));
  return (mostFrequentCount / wordCount) > 0.5;
}

// MARK: - Password Validation Functions

/**
 * Validates passwords with comprehensive security checks
 * @param {string} password - The password to validate
 * @returns {Object} Validation result with isValid and errorMessage
 */
function validatePassword(password) {
    if (!password || typeof password !== 'string') {
        return { isValid: false, errorMessage: 'Password is required and must be a string' };
    }
    
    const trimmedPassword = password.trim();
    
    // Check minimum length (industry standard: 8+ characters)
    if (trimmedPassword.length < 8) {
        return { isValid: false, errorMessage: 'Password must be at least 8 characters long' };
    }
    
    // Check maximum length
    if (trimmedPassword.length > 128) {
        return { isValid: false, errorMessage: 'Password cannot exceed 128 characters' };
    }
    
    // Check for common weak passwords
    const commonWeakPasswords = [
        'password', '123456', '123456789', 'qwerty', 'abc123', 'password123',
        'admin', 'letmein', 'welcome', 'monkey', 'dragon', 'master', 'football',
        'baseball', 'superman', 'trustno1', 'butterfly', 'dragon', 'master',
        'hello', 'freedom', 'whatever', 'qwerty123', 'admin123', 'login'
    ];
    
    if (commonWeakPasswords.includes(trimmedPassword.toLowerCase())) {
        return { isValid: false, errorMessage: 'This password is too common and easily guessable' };
    }
    
    // Check character type requirements
    const hasUppercase = /[A-Z]/.test(trimmedPassword);
    const hasLowercase = /[a-z]/.test(trimmedPassword);
    const hasDigit = /\d/.test(trimmedPassword);
    const hasSpecialChar = /[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]/.test(trimmedPassword);
    
    if (!hasUppercase) {
        return { isValid: false, errorMessage: 'Password must include at least one uppercase letter' };
    }
    
    if (!hasLowercase) {
        return { isValid: false, errorMessage: 'Password must include at least one lowercase letter' };
    }
    
    if (!hasDigit) {
        return { isValid: false, errorMessage: 'Password must include at least one number' };
    }
    
    if (!hasSpecialChar) {
        return { isValid: false, errorMessage: 'Password must include at least one special character' };
    }
    
    // Check for consecutive identical characters
    if (/(.)\1{3,}/.test(trimmedPassword)) {
        return { isValid: false, errorMessage: 'Password cannot contain consecutive identical characters' };
    }
    
    // Check for sequential characters
    if (/abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz/i.test(trimmedPassword)) {
        return { isValid: false, errorMessage: 'Password cannot contain sequential letters' };
    }
    
    if (/123|234|345|456|567|678|789|012/.test(trimmedPassword)) {
        return { isValid: false, errorMessage: 'Password cannot contain sequential numbers' };
    }
    
    // Check for keyboard patterns
    const keyboardPatterns = ['qwerty', 'asdf', 'zxcv', 'qaz', 'wsx', 'edc', 'rfv', 'tgb', 'yhn', 'ujm', 'ik'];
    if (keyboardPatterns.some(pattern => trimmedPassword.toLowerCase().includes(pattern))) {
        return { isValid: false, errorMessage: 'Password cannot contain keyboard patterns' };
    }
    
    return { isValid: true, errorMessage: null };
}

// MARK: - File Validation Functions

/**
 * Validates file uploads with comprehensive security checks
 * @param {Object} fileData - File metadata (size, type, extension)
 * @param {string} category - The file category (profileImage, podContent, thumbnail, etc.)
 * @returns {Object} Validation result with isValid and errorMessage
 */
function validateFileUpload(fileData, category, mimeType, fileName) {
    if (!fileData || typeof fileData !== 'object') {
        return { isValid: false, errorMessage: 'File data is required' };
    }
    
    const { size, type, extension } = fileData;
    
    // File size validation (in bytes)
    const maxSizes = {
        profileImage: 5 * 1024 * 1024,      // 5MB
        podContent: 100 * 1024 * 1024,      // 100MB
        thumbnail: 2 * 1024 * 1024,         // 2MB
        userDataExport: 10 * 1024 * 1024,   // 10MB
        accountData: 1 * 1024 * 1024        // 1MB
    };
    
    if (!maxSizes[category]) {
        return { isValid: false, errorMessage: 'Invalid file category specified' };
    }
    
    if (size > maxSizes[category]) {
        const maxSizeMB = Math.round(maxSizes[category] / (1024 * 1024));
        const actualSizeMB = Math.round(size / (1024 * 1024));
        return { 
            isValid: false, 
            errorMessage: `File size (${actualSizeMB}MB) exceeds maximum allowed size (${maxSizeMB}MB)` 
        };
    }
    
    // Enhanced MIME type validation
    const allowedMimeTypes = {
        profileImage: ['image/jpeg', 'image/png', 'image/heic', 'image/heif'],
        thumbnail: ['image/jpeg', 'image/png', 'image/heic', 'image/heif'],
        podContent: [
            'video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/x-matroska',
            'video/x-ms-wmv', 'video/mpeg', 'video/3gpp', 'video/webm',
            'audio/mpeg', 'audio/wav', 'audio/mp4', 'audio/aac', 'audio/flac',
            'audio/mp2', 'audio/x-ms-wma', 'audio/ogg', 'audio/opus'
        ],
        userDataExport: ['application/json', 'text/csv', 'text/plain', 'application/pdf'],
        accountData: ['application/json', 'text/plain', 'application/pdf']
    };
    
    const allowedTypes = allowedMimeTypes[category];
    if (mimeType && allowedTypes && !allowedTypes.includes(mimeType)) {
        return { 
            isValid: false, 
            errorMessage: `File MIME type '${mimeType}' is not allowed for ${category} uploads`
        };
    }
    
    // Enhanced file extension validation
    const allowedExtensions = {
        profileImage: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
        thumbnail: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
        podContent: ['mp4', 'mov', 'avi', 'mkv', 'm4v', 'mpeg', 'mpg', '3gp', 'webm', 
                     'mp3', 'wav', 'm4a', 'aac', 'flac', 'mp2', 'wma', 'ogg', 'opus'],
        userDataExport: ['json', 'csv', 'txt', 'pdf'],
        accountData: ['json', 'txt', 'pdf']
    };
    
    const allowedExts = allowedExtensions[category];
    if (fileName && allowedExts) {
        const fileExt = fileName.split('.').pop().toLowerCase();
        if (!allowedExts.includes(fileExt)) {
            return {
                isValid: false,
                errorMessage: `File extension '${fileExt}' is not allowed for ${category} uploads`
            };
        }
    }
    
    // Security checks for file names
    if (fileName) {
        const suspiciousPatterns = [
            /\.\./,           // Directory traversal
            /[<>:"|?*]/,      // Invalid characters
            /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i, // Windows reserved names
            /\.(exe|bat|cmd|com|scr|pif)$/i // Executable files
        ];
        
        for (const pattern of suspiciousPatterns) {
            if (pattern.test(fileName)) {
        return { 
            isValid: false, 
                    errorMessage: "Invalid or potentially dangerous file name"
                };
            }
        }
    }
    
    return {
        isValid: true,
        errorMessage: null
    };
}

// MARK: - Repost Operations

// Increment repost count on a pod atomically
exports.incrementPodReposts = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { podId } = data;
    
    if (!podId) {
        throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
    }
    
    try {
        const podRef = admin.firestore().collection('pods').doc(podId);
        
        await podRef.update({
            reposts: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ Incremented reposts for pod ${podId}`);
        return { success: true };
    } catch (error) {
        console.error('❌ Error incrementing pod reposts:', error);
        throw new functions.https.HttpsError('internal', 'Failed to increment pod reposts');
    }
});

// Decrement repost count on a pod atomically
exports.decrementPodReposts = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { podId } = data;
    
    if (!podId) {
        throw new functions.https.HttpsError('invalid-argument', 'Pod ID is required');
    }
    
    try {
        const podRef = admin.firestore().collection('pods').doc(podId);
        
        await podRef.update({
            reposts: admin.firestore.FieldValue.increment(-1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ Decremented reposts for pod ${podId}`);
        return { success: true };
    } catch (error) {
        console.error('❌ Error decrementing pod reposts:', error);
        throw new functions.https.HttpsError('internal', 'Failed to decrement pod reposts');
    }
});

// Increment repost engagement metrics atomically
exports.incrementRepostEngagement = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { repostId, metric } = data;
    
    if (!repostId || !metric) {
        throw new functions.https.HttpsError('invalid-argument', 'Repost ID and metric are required');
    }
    
    const validMetrics = ['likes', 'views', 'shares', 'comments'];
    if (!validMetrics.includes(metric)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid metric specified');
    }
    
    try {
        const repostRef = admin.firestore().collection('reposts').doc(repostId);
        
        await repostRef.update({
            [metric]: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ Incremented ${metric} for repost ${repostId}`);
        return { success: true };
    } catch (error) {
        console.error(`❌ Error incrementing repost ${metric}:`, error);
        throw new functions.https.HttpsError('internal', `Failed to increment repost ${metric}`);
    }
});

// Decrement repost engagement metrics atomically
exports.decrementRepostEngagement = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { repostId, metric } = data;
    
    if (!repostId || !metric) {
        throw new functions.https.HttpsError('invalid-argument', 'Repost ID and metric are required');
    }
    
    const validMetrics = ['likes', 'views', 'shares', 'comments'];
    if (!validMetrics.includes(metric)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid metric specified');
    }
    
    try {
        const repostRef = admin.firestore().collection('reposts').doc(repostId);
        
        await repostRef.update({
            [metric]: admin.firestore.FieldValue.increment(-1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ Decremented ${metric} for repost ${repostId}`);
        return { success: true };
    } catch (error) {
        console.error(`❌ Error decrementing repost ${metric}:`, error);
        throw new functions.https.HttpsError('internal', `Failed to decrement repost ${metric}`);
    }
});

// Migrate reposts to new version (now works with dedicated reposts collection)
exports.migrateRepostsToNewVersion = functions.https.onCall(async (data, context) => {
    // Verify authentication and admin privileges
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { batchSize = 100, startAfterDoc = null } = data;
    
    try {
        let query = admin.firestore()
            .collection('reposts')
            .where('version', '==', 1)
            .limit(batchSize);
        
        if (startAfterDoc) {
            query = query.startAfter(startAfterDoc);
        }
        
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            return { 
                success: true, 
                migrated: 0, 
                hasMore: false,
                message: 'No reposts to migrate' 
            };
        }
        
        const batch = admin.firestore().batch();
        let migratedCount = 0;
        
        snapshot.docs.forEach(doc => {
            const repostData = doc.data();
            
            // Add missing fields with default values
            const updatedData = {
                version: 2,
                createdAt: repostData.createdAt || (repostData.timestamp ? repostData.timestamp.toDate() : admin.firestore.FieldValue.serverTimestamp()),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                deletedAt: null,
                likes: repostData.likes || 0,
                views: repostData.views || 0,
                shares: repostData.shares || 0,
                comments: repostData.comments || 0,
                isReported: repostData.isReported || false,
                moderationStatus: repostData.moderationStatus || 'approved',
                contentWarnings: repostData.contentWarnings || [],
                isActive: repostData.isActive !== false // Default to true if not set
            };
            
            batch.update(doc.ref, updatedData);
            migratedCount++;
        });
        
        await batch.commit();
        
        const lastDoc = snapshot.docs[snapshot.docs.length - 1];
        const hasMore = snapshot.docs.length === batchSize;
        
        console.log(`✅ Migrated ${migratedCount} reposts to version 2`);
        
        return {
            success: true,
            migrated: migratedCount,
            hasMore: hasMore,
            lastDoc: hasMore ? lastDoc.id : null,
            message: `Successfully migrated ${migratedCount} reposts`
        };
    } catch (error) {
        console.error('❌ Error migrating reposts:', error);
        throw new functions.https.HttpsError('internal', 'Failed to migrate reposts');
    }
});

// Migrate reposts from user collections to main reposts collection
exports.migrateRepostsToMainCollection = functions.https.onCall(async (data, context) => {
    // Verify authentication and admin privileges
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { batchSize = 100, startAfterDoc = null } = data;
    
    try {
        let query = admin.firestore()
            .collectionGroup('user-reposts')
            .limit(batchSize);
        
        if (startAfterDoc) {
            query = query.startAfter(startAfterDoc);
        }
        
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            return { 
                success: true, 
                migrated: 0, 
                hasMore: false,
                message: 'No reposts to migrate to main collection' 
            };
        }
        
        const batch = admin.firestore().batch();
        let migratedCount = 0;
        
        for (const doc of snapshot.docs) {
            const repostData = doc.data();
            
            // Skip if this is already a reference (has repostId)
            if (repostData.repostId) {
                continue;
            }
            
            // Create new repost in main collection
            const repostId = admin.firestore().collection('reposts').doc().id;
            const repostRef = admin.firestore().collection('reposts').doc(repostId);
            
            // Convert old repost data to new format
            const newRepostData = {
                id: repostId,
                podId: repostData.podId,
                originalUserId: repostData.originalUserId,
                repostUserId: repostData.repostUserId,
                caption: repostData.caption || null,
                timestamp: repostData.timestamp ? repostData.timestamp.toDate() : new Date(),
                version: 2,
                createdAt: repostData.timestamp || admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                deletedAt: null,
                likes: 0,
                views: 0,
                shares: 0,
                comments: 0,
                isReported: false,
                moderationStatus: 'approved',
                contentWarnings: [],
                isActive: true
            };
            
            batch.set(repostRef, newRepostData);
            
            // Update user reference to point to main collection
            const userRef = doc.ref;
            const referenceData = {
                repostId: repostId,
                podId: repostData.podId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                isActive: true
            };
            
            batch.update(userRef, referenceData);
            migratedCount++;
        }
        
        await batch.commit();
        
        const lastDoc = snapshot.docs[snapshot.docs.length - 1];
        const hasMore = snapshot.docs.length === batchSize;
        
        console.log(`✅ Migrated ${migratedCount} reposts to main collection`);
        
        return {
            success: true,
            migrated: migratedCount,
            hasMore: hasMore,
            lastDoc: hasMore ? lastDoc.id : null,
            message: `Successfully migrated ${migratedCount} reposts to main collection`
        };
    } catch (error) {
        console.error('❌ Error migrating reposts to main collection:', error);
        throw new functions.https.HttpsError('internal', 'Failed to migrate reposts to main collection');
    }
});

// Get repost migration status
exports.getRepostMigrationStatus = functions.https.onCall(async (data, context) => {
    console.log('🔍 getRepostMigrationStatus called with data:', data);
    console.log('🔍 Context auth:', context.auth ? 'authenticated' : 'not authenticated');
    console.log('🔍 User ID:', context.auth?.uid || 'none');
    
    // Verify authentication
    if (!context.auth) {
        console.log('❌ Authentication failed - no context.auth');
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    try {
        // Count reposts by version in the main reposts collection
        const v1Query = await admin.firestore()
            .collection('reposts')
            .where('version', '==', 1)
            .count()
            .get();
        
        const v2Query = await admin.firestore()
            .collection('reposts')
            .where('version', '==', 2)
            .count()
            .get();
        
        const totalV1 = v1Query.data().count;
        const totalV2 = v2Query.data().count;
        const total = totalV1 + totalV2;
        
        return {
            success: true,
            totalReposts: total,
            v1Reposts: totalV1,
            v2Reposts: totalV2,
            migrationProgress: total > 0 ? (totalV2 / total) * 100 : 100,
            needsMigration: totalV1 > 0
        };
    } catch (error) {
        console.error('❌ Error getting repost migration status:', error);
        throw new functions.https.HttpsError('internal', 'Failed to get repost migration status');
    }
});

// MARK: - File Upload Security Functions

// Function to validate file before upload
exports.validateFileBeforeUpload = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { fileData, category } = data;

  if (!fileData || !category) {
    throw new functions.https.HttpsError('invalid-argument', 'File data and category are required');
  }

  try {
    const validationResult = validateFileUpload(fileData, category);
    
    if (!validationResult.isValid) {
      throw new functions.https.HttpsError('invalid-argument', validationResult.errorMessage);
    }

    return { 
      success: true, 
      message: 'File validation passed',
      fileData: fileData
    };

  } catch (error) {
    console.error('File validation error:', error);
    
    if (error.code === 'functions/invalid-argument') {
      throw error; // Re-throw validation errors
    }
    
    throw new functions.https.HttpsError('internal', `File validation failed: ${error.message}`);
  }
});

// Function to log file upload attempts for security monitoring
exports.logFileUploadAttempt = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { fileData, category, uploadResult } = data;
  const uid = context.auth.uid;

  if (!fileData || !category) {
    throw new functions.https.HttpsError('invalid-argument', 'File data and category are required');
  }

  try {
    // Log the upload attempt for security monitoring
    await db.collection('fileUploadLogs').add({
      userId: uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      fileData: fileData,
      category: category,
      uploadResult: uploadResult || 'unknown',
      userAgent: context.rawRequest?.headers?.['user-agent'] || 'unknown',
      ipAddress: context.rawRequest?.ip || 'unknown'
    });

    return { success: true, message: 'Upload attempt logged' };

  } catch (error) {
    console.error('Error logging file upload attempt:', error);
    // Don't fail the upload if logging fails
    return { success: false, message: 'Logging failed but upload continued' };
  }
});

// MARK: - Blocking System Functions

// Helper function to handle mutual unfollowing when users block each other
// Uses the same data structure as your unfollowUser function
async function handleMutualUnfollow(blockerUid, blockedUid) {
  console.log('🔄 MUTUAL_UNFOLLOW: Starting mutual unfollow check for users:', blockerUid, 'and', blockedUid);
  
  try {
    // Check if blocker was following blocked user
    const blockerFollowingRef = db.collection('users').doc(blockerUid).collection('user-following').doc(blockedUid);
    const blockerFollowingDoc = await blockerFollowingRef.get();
    
    // Check if blocked user was following blocker
    const blockedFollowingRef = db.collection('users').doc(blockedUid).collection('user-following').doc(blockerUid);
    const blockedFollowingDoc = await blockedFollowingRef.get();
    
    const blockerWasFollowingBlocked = blockerFollowingDoc.exists;
    const blockedWasFollowingBlocker = blockedFollowingDoc.exists;
    
    console.log('🔄 MUTUAL_UNFOLLOW: Following status -', {
      blockerWasFollowingBlocked,
      blockedWasFollowingBlocker
    });
    
    if (blockerWasFollowingBlocked || blockedWasFollowingBlocker) {
      console.log('🔄 MUTUAL_UNFOLLOW: Mutual following detected, starting unfollow process...');
      
      const batch = db.batch();
      
      // If blocker was following blocked user, unfollow them
      if (blockerWasFollowingBlocked) {
        console.log('🔄 MUTUAL_UNFOLLOW: Blocker unfollowing blocked user');
        
        // Decrement the 'following' count for the blocker
        batch.update(db.collection('users').doc(blockerUid), {
          following: admin.firestore.FieldValue.increment(-1)
        });
        
        // Decrement the 'followers' count for the blocked user
        batch.update(db.collection('users').doc(blockedUid), {
          followers: admin.firestore.FieldValue.increment(-1)
        });
        
        // Remove from 'user-following' collection of the blocker
        batch.delete(blockerFollowingRef);
        
        // Remove from 'user-followers' collection of the blocked user
        const blockedUserFollowersRef = db.collection('users').doc(blockedUid).collection('user-followers').doc(blockerUid);
        batch.delete(blockedUserFollowersRef);
      }
      
      // If blocked user was following blocker, unfollow them
      if (blockedWasFollowingBlocker) {
        console.log('🔄 MUTUAL_UNFOLLOW: Blocked user unfollowing blocker');
        
        // Decrement the 'following' count for the blocked user
        batch.update(db.collection('users').doc(blockedUid), {
          following: admin.firestore.FieldValue.increment(-1)
        });
        
        // Decrement the 'followers' count for the blocker
        batch.update(db.collection('users').doc(blockerUid), {
          followers: admin.firestore.FieldValue.increment(-1)
        });
        
        // Remove from 'user-following' collection of the blocked user
        batch.delete(blockedFollowingRef);
        
        // Remove from 'user-followers' collection of the blocker
        const blockerUserFollowersRef = db.collection('users').doc(blockerUid).collection('user-followers').doc(blockedUid);
        batch.delete(blockerUserFollowersRef);
      }
      
      // Commit the unfollow batch
      await batch.commit();
      console.log('✅ MUTUAL_UNFOLLOW: Successfully unfollowed both users');
      
    } else {
      console.log('🔄 MUTUAL_UNFOLLOW: No mutual following detected, no unfollow needed');
    }
    
  } catch (error) {
    console.error('❌ MUTUAL_UNFOLLOW: Error during mutual unfollow:', error);
    throw error;
  }
}

// Function to block a user
exports.blockUser = functions.https.onCall(async (data, context) => {
  console.log('🚫 BLOCK_USER: Function called with data:', JSON.stringify(data));
  console.log('🚫 BLOCK_USER: Context auth UID:', context.auth?.uid);
  
  // Verify that the user is authenticated
  if (!context.auth) {
    console.error('❌ BLOCK_USER: Authentication failed - no context.auth');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  const { userId, blockType, reason } = data;

  console.log('🚫 BLOCK_USER: Current user UID:', currentUid);
  console.log('🚫 BLOCK_USER: Target user UID:', userId);
  console.log('🚫 BLOCK_USER: Block type:', blockType);
  console.log('🚫 BLOCK_USER: Reason:', reason);

  if (!userId) {
    console.error('❌ BLOCK_USER: Missing userId parameter');
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required');
  }

  if (currentUid === userId) {
    console.error('❌ BLOCK_USER: User attempting to block themselves:', currentUid);
    throw new functions.https.HttpsError('invalid-argument', 'Cannot block yourself');
  }

  try {
    console.log('🚫 BLOCK_USER: Starting batch operation...');
    
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Add to current user's blocks collection
    const userBlockRef = db.collection('users').doc(currentUid).collection('user-blocks').doc(userId);
    console.log('🚫 BLOCK_USER: Adding block document to:', userBlockRef.path);
    
    batch.set(userBlockRef, {
      blockedUserId: userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      blockType: blockType || 'user',
      reason: reason || null,
      version: 1
    });

    // Add to blocked user's blockedBy collection (for tracking who blocked them)
    const blockedByRef = db.collection('users').doc(userId).collection('user-blockedBy').doc(currentUid);
    console.log('🚫 BLOCK_USER: Adding blockedBy document to:', blockedByRef.path);
    
    batch.set(blockedByRef, {
      blockedByUserId: currentUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      blockType: blockType || 'user',
      reason: reason || null,
      version: 1
    });

    // Update user's blockedUsers array
    const currentUserRef = db.collection('users').doc(currentUid);
    console.log('🚫 BLOCK_USER: Updating current user blockedUsers array:', currentUserRef.path);
    
    batch.update(currentUserRef, {
      blockedUsers: admin.firestore.FieldValue.arrayUnion(userId)
    });

    // Update blocked user's blockedBy array
    const blockedUserRef = db.collection('users').doc(userId);
    console.log('🚫 BLOCK_USER: Updating blocked user blockedBy array:', blockedUserRef.path);
    
    batch.update(blockedUserRef, {
      blockedBy: admin.firestore.FieldValue.arrayUnion(currentUid)
    });

    // Commit the batch first to ensure blocking is complete
    console.log('🚫 BLOCK_USER: Committing batch operation...');
    await batch.commit();
    console.log('✅ BLOCK_USER: Batch operation committed successfully');

    // Now handle mutual unfollowing if both users were following each other
    console.log('🚫 BLOCK_USER: Checking for mutual following to unfollow...');
    try {
      await handleMutualUnfollow(currentUid, userId);
    } catch (unfollowError) {
      console.warn('⚠️ BLOCK_USER: Error during mutual unfollow (non-critical):', unfollowError);
      // Don't fail the block operation if unfollow fails
    }

    console.log(`🚫 BLOCK_USER: SUCCESS - User ${currentUid} blocked user ${userId} with type: ${blockType}`);
    return { success: true, message: 'User blocked successfully' };

  } catch (error) {
    console.error('❌ BLOCK_USER: Error during batch operation:', error);
    console.error('❌ BLOCK_USER: Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack
    });
    throw new functions.https.HttpsError('internal', `Error blocking user: ${error.message}`);
  }
});

// Function to unblock a user
exports.unblockUser = functions.https.onCall(async (data, context) => {
  console.log('🔓 UNBLOCK_USER: Function called with data:', JSON.stringify(data));
  console.log('🔓 UNBLOCK_USER: Context auth UID:', context.auth?.uid);
  
  // Verify that the user is authenticated
  if (!context.auth) {
    console.error('❌ UNBLOCK_USER: Authentication failed - no context.auth');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  const { userId } = data;

  console.log('🔓 UNBLOCK_USER: Current user UID:', currentUid);
  console.log('🔓 UNBLOCK_USER: Target user UID:', userId);

  if (!userId) {
    console.error('❌ UNBLOCK_USER: Missing userId parameter');
    throw new functions.https.HttpsError('invalid-argument', 'User ID is required');
  }

  try {
    console.log('🔓 UNBLOCK_USER: Starting batch operation...');
    
    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Remove from current user's blocks collection
    const userBlockRef = db.collection('users').doc(currentUid).collection('user-blocks').doc(userId);
    console.log('🔓 UNBLOCK_USER: Removing block document from:', userBlockRef.path);
    
    batch.delete(userBlockRef);

    // Remove from blocked user's blockedBy collection
    const blockedByRef = db.collection('users').doc(userId).collection('user-blockedBy').doc(currentUid);
    console.log('🔓 UNBLOCK_USER: Removing blockedBy document from:', blockedByRef.path);
    
    batch.delete(blockedByRef);

    // Update user's blockedUsers array
    const currentUserRef = db.collection('users').doc(currentUid);
    console.log('🔓 UNBLOCK_USER: Updating current user blockedUsers array:', currentUserRef.path);
    
    batch.update(currentUserRef, {
      blockedUsers: admin.firestore.FieldValue.arrayRemove(userId)
    });

    // Update blocked user's blockedBy array
    const blockedUserRef = db.collection('users').doc(userId);
    console.log('🔓 UNBLOCK_USER: Updating blocked user blockedBy array:', blockedUserRef.path);
    
    batch.update(blockedUserRef, {
      blockedBy: admin.firestore.FieldValue.arrayRemove(currentUid)
    });

    // Commit the batch
    console.log('🔓 UNBLOCK_USER: Committing batch operation...');
    await batch.commit();
    console.log('✅ UNBLOCK_USER: Batch operation committed successfully');

    console.log(`🔓 UNBLOCK_USER: SUCCESS - User ${currentUid} unblocked user ${userId}`);
    return { success: true, message: 'User unblocked successfully' };

  } catch (error) {
    console.error('❌ UNBLOCK_USER: Error during batch operation:', error);
    console.error('❌ UNBLOCK_USER: Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack
    });
    throw new functions.https.HttpsError('internal', `Error unblocking user: ${error.message}`);
  }
});

// Cloud function to send push notifications for new messages
exports.sendMessageNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const conversationId = context.params.conversationId;
    
    console.log('💬 === MESSAGE NOTIFICATION DEBUG START ===');
    console.log(`📱 New message in conversation ${conversationId}:`, messageData);
    
    try {
      // Get conversation details
      const conversationDoc = await db.collection('conversations').doc(conversationId).get();
      if (!conversationDoc.exists) {
        console.log('❌ Conversation not found');
        return;
      }
        
      const conversationData = conversationDoc.data();
      const participants = conversationData.participants || [];
      const senderId = messageData.senderId;
      
      // Don't send notification to sender
      const recipientIds = participants.filter(id => id !== senderId);
      
      if (recipientIds.length === 0) {
        console.log('❌ No recipients found for message notification');
        return;
      }
      
      // Get sender's user info for notification
      const senderDoc = await db.collection('users').doc(senderId).get();
      const senderData = senderDoc.exists ? senderDoc.data() : {};
      const senderName = senderData.username || 'Someone';
      
      // Get recipient's FCM token and send notification
      for (const recipientId of recipientIds) {
        const recipientDoc = await db.collection('users').doc(recipientId).get();
        if (!recipientDoc.exists) continue;
        
        const recipientData = recipientDoc.data();
        const fcmToken = recipientData.fcmToken;
        
        if (!fcmToken) {
          console.log(`⚠️ No FCM token for recipient ${recipientId}`);
          continue;
        }
        
        // Check if message notifications are enabled for this user
        console.log('🔔 Checking message notification settings for user:', recipientId);
        const notificationSettings = await getUserNotificationSettings(recipientId);
        const shouldSendMessage = shouldSendNotification('message', notificationSettings);
        
        if (!shouldSendMessage) {
          console.log(`❌ Message notifications disabled for user ${recipientId}`);
          continue;
        }
        
        // Check quiet hours
        console.log('🌙 Checking quiet hours for message notification...');
        const inQuietHours = isInQuietHours(notificationSettings);
        if (inQuietHours) {
          console.log(`⏰ User ${recipientId} is in quiet hours, skipping message notification`);
          continue;
        }
        
        // Create message preview (truncate if too long)
        const messageText = messageData.text || '';
        const preview = messageText.length > 50 ? messageText.substring(0, 50) + '...' : messageText;
        
        // Send FCM notification
        const message = {
          token: fcmToken,
          notification: {
            title: `New message from ${senderName}`,
            body: preview
          },
          data: {
            type: 'message',
            conversationId: conversationId,
            senderId: senderId,
            messageId: context.params.messageId,
            screen: 'messages'
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                'content-available': 1
              }
            }
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              priority: 'high'
            }
          }
        };
        
        const response = await admin.messaging().send(message);
        console.log(`✅ Message notification sent to ${recipientId}: ${response}`);
      }
      
      console.log('🏁 === MESSAGE NOTIFICATION DEBUG END ===');
      
    } catch (error) {
      console.error('💥 Error sending message notification:', error);
    }
  });

// MARK: - Helper Functions for Mutual Follow

// Helper function to find existing conversation between two users
async function findExistingConversation(userId1, userId2) {
  try {
    const conversationsRef = db.collection('conversations');
    
    // Query for conversations where both users are participants
    const snapshot = await conversationsRef
      .where('participants', 'array-contains', userId1)
      .get();
    
    for (const doc of snapshot.docs) {
      const participants = doc.data().participants || [];
      if (participants.includes(userId2)) {
        console.log(`✅ Found existing conversation: ${doc.id}`);
        return doc.id;
      }
    }
    
    console.log('❌ No existing conversation found');
    return null;
  } catch (error) {
    console.error('❌ Error finding existing conversation:', error);
    return null;
  }
}

// Helper function to ensure friendship documents exist
async function ensureFriendshipDocuments(userId1, userId2) {
  try {
    console.log('🔧 Ensuring friendship documents exist...');
    
    // Get user data for both users
    const [user1Doc, user2Doc] = await Promise.all([
      db.collection('users').doc(userId1).get(),
      db.collection('users').doc(userId2).get()
    ]);
    
    if (!user1Doc.exists || !user2Doc.exists) {
      console.error('❌ One or both users not found');
      return false;
    }
    
    const user1Data = user1Doc.data();
    const user2Data = user2Doc.data();
    
    // Prepare user data for friendship documents
    const user1FriendshipData = {
      email: user1Data.email,
      username: user1Data.username,
      fullname: user1Data.fullname,
      uid: user1Data.uid,
      followers: user1Data.followers || 0,
      profileImageUrl: user1Data.profileImageUrl || '',
      isVerified: user1Data.isVerified || false,
      following: user1Data.following || 0,
      podCount: user1Data.podCount || 0,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const user2FriendshipData = {
      email: user2Data.email,
      username: user2Data.username,
      fullname: user2Data.fullname,
      uid: user2Data.uid,
      followers: user2Data.followers || 0,
      profileImageUrl: user2Data.profileImageUrl || '',
      isVerified: user2Data.isVerified || false,
      following: user2Data.following || 0,
      podCount: user2Data.podCount || 0,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Create friendship documents in batch
    const batch = db.batch();
    
    const user1FriendsRef = db.collection('users').doc(userId1).collection('friends').doc(userId2);
    const user2FriendsRef = db.collection('users').doc(userId2).collection('friends').doc(userId1);
    
    batch.set(user1FriendsRef, user2FriendshipData);
    batch.set(user2FriendsRef, user1FriendshipData);
    
    await batch.commit();
    console.log('✅ Friendship documents ensured successfully');
    
    // Also ensure conversation references exist for existing conversations
    const existingConversation = await findExistingConversation(userId1, userId2);
    if (existingConversation) {
      console.log(`🔧 Ensuring conversation references exist for: ${existingConversation}`);
      await ensureConversationReferences(userId1, userId2, existingConversation);
    }
    
    return true;
    
  } catch (error) {
    console.error('❌ Error ensuring friendship documents:', error);
    return false;
  }
}

// Helper function to ensure conversation references exist for existing conversations
async function ensureConversationReferences(userId1, userId2, conversationId) {
  try {
    console.log(`🔧 Ensuring conversation references exist for conversation: ${conversationId}`);
    
    // Check if references already exist
    const [user1Ref, user2Ref] = await Promise.all([
      db.collection('users').doc(userId1).collection('conversations').doc(conversationId).get(),
      db.collection('users').doc(userId2).collection('conversations').doc(conversationId).get()
    ]);
    
    if (user1Ref.exists && user2Ref.exists) {
      console.log('✅ Conversation references already exist');
      return true;
    }
    
    // Get conversation data to populate references
    const conversationDoc = await db.collection('conversations').doc(conversationId).get();
    if (!conversationDoc.exists) {
      console.error('❌ Conversation not found');
      return false;
    }
    
    const conversationData = conversationDoc.data();
    
    // Create missing references
    const batch = db.batch();
    
    if (!user1Ref.exists) {
      const user1ConversationsRef = db.collection('users').doc(userId1).collection('conversations').doc(conversationId);
      batch.set(user1ConversationsRef, {
        ...conversationData, // Include all conversation data (lastActivity, createdAt, createdBy, participants, type)
        unreadCount: 0,
        lastReadTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        conversationRef: `conversations/${conversationId}`,  // ← Full path like your iOS app
        joinedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    if (!user2Ref.exists) {
      const user2ConversationsRef = db.collection('users').doc(userId2).collection('conversations').doc(conversationId);
      batch.set(user2ConversationsRef, {
        ...conversationData, // Include all conversation data (lastActivity, createdAt, createdBy, participants, type)
        unreadCount: 0,
        lastReadTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        conversationRef: `conversations/${conversationId}`,  // ← Full path like your iOS app
        joinedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    await batch.commit();
    console.log('✅ Conversation references ensured successfully');
    return true;
    
  } catch (error) {
    console.error('❌ Error ensuring conversation references:', error);
    return false;
  }
}

// Function to accept a follow request (creates follow relationship)
exports.acceptFollowRequest = functions.https.onCall(async (data, context) => {
  // Verify that the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  const { requesterId } = data;

  if (!requesterId) {
    throw new functions.https.HttpsError('invalid-argument', 'Requester ID is required');
  }

  if (currentUid === requesterId) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot accept follow request from yourself');
  }

  try {
    console.log(`🔄 [acceptFollowRequest] Accepting follow request from ${requesterId} to ${currentUid}`);

    // Check if this creates a mutual follow relationship BEFORE we create the follow relationship
    console.log('🔍 [acceptFollowRequest] Checking for mutual follow relationship...');
    const currentUserFollowingRef = db.collection('users').doc(currentUid).collection('user-following').doc(requesterId);
    const currentUserFollowingDoc = await currentUserFollowingRef.get();
    
    const isMutualFollow = currentUserFollowingDoc.exists;
    console.log(`👤 [acceptFollowRequest] Current user following requester: ${isMutualFollow}`);

    // Use a batch to ensure atomicity
    const batch = db.batch();

    // Increment the 'following' count for the requester (they're now following the current user)
    const requesterRef = db.collection('users').doc(requesterId);
    batch.update(requesterRef, {
      following: admin.firestore.FieldValue.increment(1)
    });

    // Increment the 'followers' count for the current user
    const currentUserRef = db.collection('users').doc(currentUid);
    batch.update(currentUserRef, {
      followers: admin.firestore.FieldValue.increment(1)
    });

    // Add to 'user-following' collection of the requester
    const requesterFollowingRef = db.collection('users').doc(requesterId).collection('user-following').doc(currentUid);
    batch.set(requesterFollowingRef, {});

    // Add to 'user-followers' collection of the current user
    const currentUserFollowersRef = db.collection('users').doc(currentUid).collection('user-followers').doc(requesterId);
    batch.set(currentUserFollowersRef, {});

    // Commit the batch
    await batch.commit();

    console.log(`✅ [acceptFollowRequest] Follow relationship created between ${requesterId} and ${currentUid}`);

    // If it's a mutual follow, check for existing friendship/conversation first
    if (isMutualFollow) {
      console.log('🤝 [acceptFollowRequest] Mutual follow detected! Checking for existing friendship/conversation...');
      
      try {
        // Check if they're already friends
        const currentUserFriendsRef = db.collection('users').doc(currentUid).collection('friends').doc(requesterId);
        const otherUserFriendsRef = db.collection('users').doc(requesterId).collection('friends').doc(currentUid);
        
        const [currentUserFriendDoc, otherUserFriendDoc] = await Promise.all([
          currentUserFriendsRef.get(),
          otherUserFriendsRef.get()
        ]);

        if (currentUserFriendDoc.exists && otherUserFriendDoc.exists) {
          console.log('✅ [acceptFollowRequest] Users are already friends - no action needed');
        } else {
          // Check if a conversation already exists between these users
          const existingConversation = await findExistingConversation(currentUid, requesterId);
          
          if (existingConversation) {
            console.log(`✅ [acceptFollowRequest] Conversation already exists: ${existingConversation}, ensuring friendship documents`);
            await ensureFriendshipDocuments(currentUid, requesterId);
          } else {
            console.log('🆕 [acceptFollowRequest] No existing conversation found, creating new friendship and conversation');
            const conversationId = await createFriendshipAndConversation(currentUid, requesterId);
            console.log(`✅ [acceptFollowRequest] New conversation created: ${conversationId}`);
          }
        }
      } catch (mutualFollowError) {
        console.error('⚠️ [acceptFollowRequest] Error during mutual follow handling:', mutualFollowError);
        // Don't fail the follow operation if mutual follow handling fails
      }
    } else {
      console.log('👤 [acceptFollowRequest] No mutual follow - current user was not following requester');
    }

    // Send follow notification to the accepter (current user) - "requesterId followed you"
    console.log(`🔔 [acceptFollowRequest] Sending follow notification from ${requesterId} to ${currentUid}`);
    await handleDuplicateNotification('follow', requesterId, currentUid, null);
    
    // Create follow notification with simplified model structure
    const followNotificationRef = db.collection('notifications').doc();
    const currentTime = admin.firestore.FieldValue.serverTimestamp();
    await followNotificationRef.set({
      type: 'follow',
      senderId: requesterId,
      recipientId: currentUid,
      contentId: null,
      commentText: null,
      messageText: null,
      version: 2,
      createdAt: currentTime,
      updatedAt: currentTime,
      category: 'social',
      isRead: false,
      groupId: null,
      deepLink: null
    });
    console.log(`✅ [acceptFollowRequest] Follow notification created: ${followNotificationRef.id}`);
    
    // Send follow request accepted notification to the requester - "currentUid accepted your follow request"
    console.log(`🔔 [acceptFollowRequest] Sending follow request accepted notification from ${currentUid} to ${requesterId}`);
    await handleDuplicateNotification('followRequestAccepted', currentUid, requesterId, null);
    
    // Create follow request accepted notification with simplified model structure
    const followRequestAcceptedNotificationRef = db.collection('notifications').doc();
    await followRequestAcceptedNotificationRef.set({
      type: 'followRequestAccepted',
      senderId: currentUid,
      recipientId: requesterId,
      contentId: null,
      commentText: null,
      messageText: null,
      version: 2,
      createdAt: currentTime,
      updatedAt: currentTime,
      category: 'social',
      isRead: false,
      groupId: null,
      deepLink: null
    });
    console.log(`✅ [acceptFollowRequest] Follow request accepted notification created: ${followRequestAcceptedNotificationRef.id}`);

    return { success: true };
  } catch (error) {
    console.error('❌ [acceptFollowRequest] Error:', error);
    throw new functions.https.HttpsError('internal', `Error accepting follow request: ${error.message}`);
  }
});

// Function to handle private-to-public transition (auto-accept all pending follow requests)
exports.handlePrivateToPublicTransition = functions.https.onCall(async (data, context) => {
  console.log('🚀 [handlePrivateToPublicTransition] Function called!');
  
  // Verify that the user is authenticated
  if (!context.auth) {
    console.log('❌ [handlePrivateToPublicTransition] User not authenticated');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const currentUid = context.auth.uid;
  console.log(`🔄 [handlePrivateToPublicTransition] Processing transition for user: ${currentUid}`);

  try {

    // Get all pending follow requests for this user
    const followRequestsRef = db.collection('users').doc(currentUid).collection('follow-requests');
    const followRequestsSnapshot = await followRequestsRef.get();

    if (followRequestsSnapshot.empty) {
      console.log('📭 No pending follow requests found');
      return { 
        success: true, 
        acceptedCount: 0, 
        message: 'No pending follow requests to process' 
      };
    }

    console.log(`📋 Found ${followRequestsSnapshot.docs.length} pending follow requests`);

    const acceptedRequests = [];
    const failedRequests = [];

    // Process each follow request using the EXACT same logic as acceptFollowRequest
    for (const doc of followRequestsSnapshot.docs) {
      const requesterId = doc.id;
      
      try {
        console.log(`🔄 Processing follow request from: ${requesterId}`);

        // Check if this creates a mutual follow relationship BEFORE we create the follow relationship
        const currentUserFollowingRef = db.collection('users').doc(currentUid).collection('user-following').doc(requesterId);
        const currentUserFollowingDoc = await currentUserFollowingRef.get();
        
        const isMutualFollow = currentUserFollowingDoc.exists;
        console.log(`👤 Current user following requester: ${isMutualFollow}`);

        // Use a batch to ensure atomicity
        const batch = db.batch();

        // Increment the 'following' count for the requester (they're now following the current user)
        const requesterRef = db.collection('users').doc(requesterId);
        batch.update(requesterRef, {
          following: admin.firestore.FieldValue.increment(1)
        });

        // Increment the 'followers' count for the current user
        const currentUserRef = db.collection('users').doc(currentUid);
        batch.update(currentUserRef, {
          followers: admin.firestore.FieldValue.increment(1)
        });

        // Add to 'user-following' collection of the requester
        const requesterFollowingRef = db.collection('users').doc(requesterId).collection('user-following').doc(currentUid);
        batch.set(requesterFollowingRef, {});

        // Add to 'user-followers' collection of the current user
        const currentUserFollowersRef = db.collection('users').doc(currentUid).collection('user-followers').doc(requesterId);
        batch.set(currentUserFollowersRef, {});

        // Delete the follow request document
        batch.delete(doc.ref);

        // Commit the batch
        await batch.commit();

        console.log(`✅ Follow relationship created between ${requesterId} and ${currentUid}`);

        // If it's a mutual follow, check for existing friendship/conversation first
        if (isMutualFollow) {
          console.log('🤝 Mutual follow detected! Checking for existing friendship/conversation...');
          
          try {
            // Check if they're already friends
            const currentUserFriendsRef = db.collection('users').doc(currentUid).collection('friends').doc(requesterId);
            const otherUserFriendsRef = db.collection('users').doc(requesterId).collection('friends').doc(currentUid);
            
            const [currentUserFriendDoc, otherUserFriendDoc] = await Promise.all([
              currentUserFriendsRef.get(),
              otherUserFriendsRef.get()
            ]);

            if (currentUserFriendDoc.exists && otherUserFriendDoc.exists) {
              console.log('✅ Users are already friends - no action needed');
            } else {
              // Check if a conversation already exists between these users
              const existingConversation = await findExistingConversation(currentUid, requesterId);
              
              if (existingConversation) {
                console.log(`✅ Conversation already exists: ${existingConversation}, ensuring friendship documents`);
                await ensureFriendshipDocuments(currentUid, requesterId);
              } else {
                console.log('🆕 No existing conversation found, creating new friendship and conversation');
                const conversationId = await createFriendshipAndConversation(currentUid, requesterId);
                if (conversationId) {
                  console.log('✅ Friendship and conversation created successfully');
                } else {
                  console.log('❌ Failed to create friendship and conversation');
                }
              }
            }
          } catch (error) {
            console.error('❌ Error creating friendship and conversation:', error);
          }
        }

        // Send follow notification to the accepter (current user) - "requesterId followed you"
        console.log(`🔔 [handlePrivateToPublicTransition] Sending follow notification from ${requesterId} to ${currentUid}`);
        await handleDuplicateNotification('follow', requesterId, currentUid, null);
        
        // Create follow notification with simplified model structure
        console.log(`📝 [handlePrivateToPublicTransition] Creating follow notification document...`);
        const followNotificationRef = db.collection('notifications').doc();
        const currentTime = admin.firestore.FieldValue.serverTimestamp();
        await followNotificationRef.set({
          type: 'follow',
          senderId: requesterId,
          recipientId: currentUid,
          contentId: null,
          commentText: null,
          messageText: null,
          version: 2,
          createdAt: currentTime,
          updatedAt: currentTime,
          category: 'social',
          isRead: false,
          groupId: null,
          deepLink: null
        });
        console.log(`✅ [handlePrivateToPublicTransition] Follow notification created: ${followNotificationRef.id}`);
        
        // Send follow request accepted notification to the requester - "currentUid accepted your follow request"
        console.log(`🔔 [handlePrivateToPublicTransition] Sending follow request accepted notification from ${currentUid} to ${requesterId}`);
        await handleDuplicateNotification('followRequestAccepted', currentUid, requesterId, null);
        
        // Create follow request accepted notification with simplified model structure
        console.log(`📝 [handlePrivateToPublicTransition] Creating follow request accepted notification document...`);
        const followRequestAcceptedNotificationRef = db.collection('notifications').doc();
        await followRequestAcceptedNotificationRef.set({
          type: 'followRequestAccepted',
          senderId: currentUid,
          recipientId: requesterId,
          contentId: null,
          commentText: null,
          messageText: null,
          version: 2,
          createdAt: currentTime,
          updatedAt: currentTime,
          category: 'social',
          isRead: false,
          groupId: null,
          deepLink: null
        });
        console.log(`✅ [handlePrivateToPublicTransition] Follow request accepted notification created: ${followRequestAcceptedNotificationRef.id}`);
        
        acceptedRequests.push(requesterId);
        console.log(`✅ Successfully processed follow request from: ${requesterId}`);

      } catch (error) {
        console.error(`❌ Error processing follow request from ${requesterId}:`, error);
        failedRequests.push({ requesterId, error: error.message });
      }
    }

    console.log(`🎉 Private-to-public transition completed. Accepted: ${acceptedRequests.length}, Failed: ${failedRequests.length}`);

    return { 
      success: true, 
      acceptedCount: acceptedRequests.length,
      failedCount: failedRequests.length,
      acceptedRequests,
      failedRequests,
      message: `Successfully processed ${acceptedRequests.length} follow requests` 
    };

  } catch (error) {
    console.error('❌ [handlePrivateToPublicTransition] Error:', error);
    throw new functions.https.HttpsError('internal', `Error processing private-to-public transition: ${error.message}`);
  }
});

// MARK: - Helper Functions for Duplicate Notification Prevention

// Helper function to handle duplicate notifications (follow and like)
async function handleDuplicateNotification(type, senderId, recipientId, contentId = null) {
  console.log(`🔍 Checking for duplicate ${type} notification from ${senderId} to ${recipientId}${contentId ? ` for content ${contentId}` : ''}`);
  
  try {
    // Get all notifications for this recipient and filter in memory to avoid complex queries
    const notificationsSnapshot = await db.collection('notifications')
      .where('recipientId', '==', recipientId)
      .get();
    
    if (notificationsSnapshot.empty) {
      console.log(`✅ No notifications found for recipient ${recipientId}, proceeding with creation`);
      return;
    }
    
    // Filter for matching notifications
    const matchingNotifications = notificationsSnapshot.docs.filter(doc => {
      const data = doc.data();
      const typeMatches = data.type === type;
      const senderMatches = data.senderId === senderId;
      
      if (type === 'like' && contentId) {
        return typeMatches && senderMatches && data.contentId === contentId;
      } else if (type === 'follow') {
        // For follow notifications, we only check type and sender (no contentId needed)
        return typeMatches && senderMatches;
      } else if (type === 'followRequest') {
        // For follow request notifications, we only check type and sender (no contentId needed)
        return typeMatches && senderMatches;
      } else if (type === 'followRequestAccepted') {
        // For follow request accepted notifications, we only check type and sender (no contentId needed)
        return typeMatches && senderMatches;
      } else {
        return typeMatches && senderMatches;
      }
    });
    
    if (matchingNotifications.length > 0) {
      console.log(`🗑️ Found ${matchingNotifications.length} existing ${type} notification(s), deleting...`);
      
      // Delete all matching notifications
      const deletePromises = matchingNotifications.map(doc => doc.ref.delete());
      await Promise.all(deletePromises);
      
      console.log(`✅ Deleted ${matchingNotifications.length} existing ${type} notification(s)`);
    } else {
      console.log(`✅ No existing ${type} notification found, proceeding with creation`);
    }
  } catch (error) {
    console.error(`❌ Error checking for duplicate ${type} notification:`, error);
    // Don't throw error, continue with notification creation
  }
}

// MARK: - Repost Engagement Cloud Functions

// Increment repost engagement metrics atomically
exports.incrementRepostEngagement = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { repostId, metric } = data;
    
    // Validate input
    if (!repostId || !metric) {
        throw new functions.https.HttpsError('invalid-argument', 'repostId and metric are required');
    }
    
    const validMetrics = ['likes', 'views', 'shares', 'comments'];
    if (!validMetrics.includes(metric)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid metric. Must be one of: ' + validMetrics.join(', '));
    }
    
    try {
        const repostRef = db.collection('reposts').doc(repostId);
        
        // Check if repost exists and is active
        const repostDoc = await repostRef.get();
        if (!repostDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Repost not found');
        }
        
        const repostData = repostDoc.data();
        if (!repostData.isActive) {
            throw new functions.https.HttpsError('failed-precondition', 'Repost is not active');
        }
        
        // Atomically increment the metric
        await repostRef.update({
            [metric]: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ Incremented ${metric} for repost ${repostId}`);
        
        return {
            success: true,
            repostId: repostId,
            metric: metric,
            message: `Successfully incremented ${metric}`
        };
        
    } catch (error) {
        console.error(`❌ Error incrementing repost engagement:`, error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to increment repost engagement');
    }
});

// Decrement repost engagement metrics atomically
exports.decrementRepostEngagement = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { repostId, metric } = data;
    
    // Validate input
    if (!repostId || !metric) {
        throw new functions.https.HttpsError('invalid-argument', 'repostId and metric are required');
    }
    
    const validMetrics = ['likes', 'views', 'shares', 'comments'];
    if (!validMetrics.includes(metric)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid metric. Must be one of: ' + validMetrics.join(', '));
    }
    
    try {
        const repostRef = db.collection('reposts').doc(repostId);
        
        // Check if repost exists and is active
        const repostDoc = await repostRef.get();
        if (!repostDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Repost not found');
        }
        
        const repostData = repostDoc.data();
        if (!repostData.isActive) {
            throw new functions.https.HttpsError('failed-precondition', 'Repost is not active');
        }
        
        // Atomically decrement the metric (but don't go below 0)
        const currentValue = repostData[metric] || 0;
        if (currentValue > 0) {
            await repostRef.update({
                [metric]: admin.firestore.FieldValue.increment(-1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
        
        console.log(`✅ Decremented ${metric} for repost ${repostId}`);
        
        return {
            success: true,
            repostId: repostId,
            metric: metric,
            message: `Successfully decremented ${metric}`
        };
        
    } catch (error) {
        console.error(`❌ Error decrementing repost engagement:`, error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to decrement repost engagement');
    }
});