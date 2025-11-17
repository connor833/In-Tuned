const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Function to validate username format
function validateUsername(username) {
  if (!username || typeof username !== 'string') {
    throw new Error('USERNAME_INVALID');
  }
  
  const trimmedUsername = username.trim();
  
  if (trimmedUsername.length < 3) {
    throw new Error('USERNAME_TOO_SHORT');
  }
  
  if (trimmedUsername.length > 20) {
    throw new Error('USERNAME_TOO_LONG');
  }
  
  if (/\s/.test(trimmedUsername)) {
    throw new Error('USERNAME_CONTAINS_WHITESPACE');
  }
  
  if (!/^[a-zA-Z0-9_]+$/.test(trimmedUsername)) {
    throw new Error('USERNAME_INVALID_CHARACTERS');
  }
  
  if (/^[0-9]/.test(trimmedUsername)) {
    throw new Error('USERNAME_STARTS_WITH_NUMBER');
  }
  
  if (trimmedUsername.startsWith('_') || trimmedUsername.endsWith('_')) {
    throw new Error('USERNAME_STARTS_OR_ENDS_WITH_UNDERSCORE');
  }
  
  if (/_+/.test(trimmedUsername)) {
    throw new Error('USERNAME_CONSECUTIVE_UNDERSCORES');
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
        'USERNAME_INVALID': 'Username is invalid'
      };
      
      throw new functions.https.HttpsError('invalid-argument', errorMap[error.message] || 'Invalid username format');
    }
    
    throw new functions.https.HttpsError('internal', 'Error checking username availability');
  }
});
