# 📢 Announcement System Guide

## Overview
This system lets you send **custom announcements** to your users, including "What's New" messages, important updates, feature releases, or any message you want. Users only see each announcement once.

## How It Works

### For Users:
1. When they open the app, unseen announcements pop up automatically
2. They can read and dismiss each announcement
3. If there are multiple announcements, they'll see them one at a time
4. Once dismissed, they'll never see that announcement again

### For You (The Developer):
You control announcements via **Firestore** - no app update needed!

---

## Creating Announcements

### 1. In Firestore Console
Go to your Firestore database and create a collection called `announcements`

### 2. Add a Document
Create a new document with these fields:

```javascript
{
  "title": "What's New in Version 2.0",
  "message": "We've added dark mode, improved performance, and fixed several bugs. Enjoy the new experience!",
  "createdAt": [Timestamp] // Firebase server timestamp
  "expiresAt": [Timestamp] // When this announcement should stop showing (e.g., 30 days from now)
  "priority": "high", // Options: "low", "medium", "high", "critical"
  "imageURL": null, // Optional: URL to an image to display
  "actionButtonText": null, // Optional: "Learn More", "Try Now", etc.
  "actionButtonURL": null, // Optional: Deep link or web URL
  "targetAudience": "all", // Options: "all", "new_users", "existing_users"
  "minAppVersion": null, // Optional: "1.5.0" - only show to users on this version or higher
  "maxAppVersion": null // Optional: "2.0.0" - only show to users below this version
}
```

---

## Example Announcements

### Example 1: Simple Version Update
```javascript
{
  "title": "Welcome to Version 2.1! 🎉",
  "message": "We've improved the explore feed and added new podcast categories. Happy listening!",
  "createdAt": [Server Timestamp],
  "expiresAt": [30 days from now],
  "priority": "medium",
  "imageURL": null,
  "actionButtonText": null,
  "actionButtonURL": null,
  "targetAudience": "all",
  "minAppVersion": "2.1.0",
  "maxAppVersion": null
}
```

### Example 2: Feature Announcement with Image
```javascript
{
  "title": "New Feature: Live Podcasts! 🎙️",
  "message": "Join live podcast sessions with your favorite creators. Tap below to explore live shows happening now!",
  "createdAt": [Server Timestamp],
  "expiresAt": [60 days from now],
  "priority": "high",
  "imageURL": "https://your-cdn.com/live-feature-banner.jpg",
  "actionButtonText": "Explore Live Shows",
  "actionButtonURL": "podwebblueprint://explore/live", // Your deep link
  "targetAudience": "all",
  "minAppVersion": null,
  "maxAppVersion": null
}
```

### Example 3: Targeted to New Users Only
```javascript
{
  "title": "Welcome to PodWeb! 👋",
  "message": "Thanks for joining! Here's a quick tip: Follow your favorite podcasts to see them in your personalized feed.",
  "createdAt": [Server Timestamp],
  "expiresAt": [90 days from now],
  "priority": "medium",
  "imageURL": null,
  "actionButtonText": "Get Started",
  "actionButtonURL": "podwebblueprint://onboarding",
  "targetAudience": "new_users", // Only users created in last 30 days
  "minAppVersion": null,
  "maxAppVersion": null
}
```

### Example 4: Critical Maintenance Notice
```javascript
{
  "title": "Scheduled Maintenance",
  "message": "We'll be performing system maintenance on Oct 15 from 2-4 AM EST. The app may be temporarily unavailable.",
  "createdAt": [Server Timestamp],
  "expiresAt": [Oct 15, 2025 4:00 AM],
  "priority": "critical",
  "imageURL": null,
  "actionButtonText": null,
  "actionButtonURL": null,
  "targetAudience": "all",
  "minAppVersion": null,
  "maxAppVersion": null
}
```

---

## Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | String | ✅ Yes | The headline of your announcement |
| `message` | String | ✅ Yes | The detailed message body |
| `createdAt` | Timestamp | ✅ Yes | When the announcement was created |
| `expiresAt` | Timestamp | ✅ Yes | When to stop showing this (can be far future) |
| `priority` | String | ✅ Yes | `"low"`, `"medium"`, `"high"`, or `"critical"` |
| `imageURL` | String | ⬜ No | URL to an image to display |
| `actionButtonText` | String | ⬜ No | Text for an action button |
| `actionButtonURL` | String | ⬜ No | URL or deep link for the button |
| `targetAudience` | String | ✅ Yes | `"all"`, `"new_users"`, or `"existing_users"` |
| `minAppVersion` | String | ⬜ No | Minimum app version (e.g., `"1.5.0"`) |
| `maxAppVersion` | String | ⬜ No | Maximum app version (e.g., `"2.0.0"`) |

---

## Priority Levels

- **Low**: General information, non-urgent
- **Medium**: Feature announcements, tips
- **High**: Important updates (shows orange dot)
- **Critical**: Urgent messages (shows red dot)

---

## Target Audiences

- **`all`**: Every user sees this
- **`new_users`**: Only users who created their account in the last 30 days
- **`existing_users`**: Only users older than 30 days

---

## Testing

To test announcements during development:

1. Create a test announcement in Firestore
2. Run the app - it should pop up
3. Dismiss it
4. To see it again, call this in your code (or debug console):
   ```swift
   AnnouncementService.shared.clearSeenAnnouncements()
   ```
5. Restart the app

---

## Firestore Security Rules

Add these rules to your `firestore.rules` to protect the announcements collection:

```javascript
// Only admins can write announcements, but authenticated users can read them
match /announcements/{announcementId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
}
```

---

## Tips

✅ **DO:**
- Keep messages concise and clear
- Use high priority sparingly (only for truly important messages)
- Set reasonable expiration dates (30-90 days typical)
- Test announcements before sending to all users

❌ **DON'T:**
- Create too many announcements at once (users will get fatigued)
- Use critical priority for marketing messages
- Forget to set expiration dates
- Make messages too long (users won't read them)

---

## How Users See Announcements

1. **On App Launch**: Announcements pop up automatically in a nice sheet modal
2. **One at a Time**: If you have multiple announcements, users see them sequentially
3. **Only Once**: Each user only sees each announcement once
4. **Clean UI**: Modern, dismissible sheet with optional images and action buttons

---

## Future Enhancements (Optional)

You could extend this system to:
- Add an "Announcements" page where users can review past announcements
- Send push notifications when critical announcements are added
- Add A/B testing for different message variants
- Track analytics on announcement engagement
- Support rich text formatting or markdown

