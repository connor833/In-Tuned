# Push Notifications System

This directory contains Firebase Cloud Functions that handle push notifications for the PodWebBlueprint app.

## Features

- ✅ **Automatic Push Notifications**: Triggers when notification documents are created
- ✅ **User Preferences**: Respects notification settings (likes, comments, follows, etc.)
- ✅ **Quiet Hours**: Honors user-defined quiet hours
- ✅ **Rich Notifications**: Includes sender info and content previews
- ✅ **Error Handling**: Removes invalid FCM tokens automatically
- ✅ **Batch Notifications**: Support for sending to multiple users
- ✅ **Custom Notifications**: Admin-level custom push notifications

## Functions

### 1. `sendNotification` (Firestore Trigger)
**Automatically triggered when a notification document is created**

**Features:**
- Fetches user notification preferences
- Checks quiet hours
- Prevents self-notifications
- Creates rich notification content based on type
- Removes invalid FCM tokens

### 2. `sendPushNotification` (Callable)
**For sending custom notifications**

```javascript
// Usage from iOS
let functions = Functions.functions()
let sendNotification = functions.httpsCallable("sendPushNotification")

sendNotification.call([
    "recipientId": "user123",
    "title": "Custom Title",
    "body": "Custom message",
    "data": ["key": "value"]
])
```

### 3. `sendBatchNotifications` (Callable)
**For sending notifications to multiple users**

```javascript
// Usage from iOS
let sendBatch = functions.httpsCallable("sendBatchNotifications")

sendBatch.call([
    "userIds": ["user1", "user2", "user3"],
    "title": "Announcement",
    "body": "Important update for all users",
    "data": ["type": "announcement"]
])
```

## Deployment

### Prerequisites
1. Ensure Firebase CLI is installed: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Initialize project: `firebase init functions`

### Deploy Functions
```bash
cd Functions
npm install
firebase deploy --only functions
```

### Deploy Specific Function
```bash
firebase deploy --only functions:sendNotification
firebase deploy --only functions:sendPushNotification
firebase deploy --only functions:sendBatchNotifications
```

## Configuration

### Firestore Security Rules
Add these rules to allow the functions to read user data:

```javascript
// In firestore.rules
match /users/{userId} {
  allow read: if request.auth != null;
  
  match /settings/notifications {
    allow read: if request.auth != null;
  }
}

match /notifications/{notificationId} {
  allow read, write: if request.auth != null;
}
```

### Environment Variables (if needed)
```bash
firebase functions:config:set someservice.key="THE API KEY"
```

## Testing

### 1. Test Automatic Notifications
```swift
// In your iOS app
NotificationService().createNotification(
    type: .like,
    senderId: "sender123",
    recipientId: "recipient456",
    contentId: "pod789"
) { success in
    print("Notification created: \(success)")
}
```

### 2. Test Custom Notifications
```swift
// Send custom notification
FCMService.shared.sendCustomPushNotification(
    to: "userId",
    title: "Test",
    body: "This is a test notification"
) { success in
    print("Custom notification sent: \(success)")
}
```

### 3. Test Cloud Functions Locally
```bash
cd Functions
npm run serve
```

Then use the Firebase Functions shell to test:
```javascript
sendNotification({
    senderId: "test_sender",
    recipientId: "test_recipient",
    type: "like",
    contentId: "test_content",
    timestamp: admin.firestore.Timestamp.now(),
    isRead: false
})
```

## Monitoring

### View Logs
```bash
# Real-time logs
firebase functions:log

# Function-specific logs
firebase functions:log --only sendNotification
```

### Firebase Console
- Navigate to Firebase Console > Functions
- Monitor execution count, errors, and performance
- Check Cloud Firestore for notification documents

## Troubleshooting

### Common Issues

1. **Notifications not being sent**
   - Check FCM token is valid in user document
   - Verify notification preferences allow the notification type
   - Check if user is in quiet hours

2. **Invalid FCM token errors**
   - Function automatically removes invalid tokens
   - User needs to log in again to refresh token

3. **Function timeout**
   - Default timeout is 60 seconds
   - For batch operations, consider pagination

4. **Permission errors**
   - Ensure service account has proper permissions
   - Check Firestore security rules

### Debug Mode
Add this to your cloud function for detailed logging:

```javascript
console.log('Debug: Notification data:', notificationData);
console.log('Debug: User settings:', notificationSettings);
console.log('Debug: Quiet hours check:', isInQuietHours(notificationSettings));
```

## Performance Considerations

1. **Batch Operations**: Limited to 500 users per batch
2. **Rate Limiting**: FCM has daily quotas
3. **Function Memory**: Default 256MB, increase if needed
4. **Cold Starts**: Functions may have ~1-2 second delay on first invocation

## Security

1. **Authentication**: All callable functions require authentication
2. **Data Validation**: Input validation on all parameters
3. **Token Management**: Invalid tokens are automatically cleaned up
4. **User Preferences**: Only sends notifications if user has opted in

## Next Steps

1. **Analytics**: Add notification delivery tracking
2. **A/B Testing**: Test different notification content
3. **Scheduling**: Add support for scheduled notifications
4. **Rich Media**: Support for images in notifications
5. **Topics**: Subscribe users to notification topics 