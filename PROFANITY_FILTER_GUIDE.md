# 🚫 Profanity Filter Implementation Guide

## Overview
English-only profanity filter for **public-facing content**, implemented client-side for instant feedback.

### What's Protected with Profanity Filtering:
✅ **Usernames** - Public, visible everywhere  
✅ **Full Names** - Public profile information  
✅ **User Bios** - Public profile information  
✅ **Pod Titles** - Public podcast content  
✅ **Pod Descriptions** - Public podcast content  
✅ **Tags/Keywords** - Public podcast metadata  
✅ **Playlist Titles** - Public user-created playlists  
✅ **Playlist Descriptions** - Public user-created playlists  
✅ **Comments** - Public content on pods  
✅ **Replies** - Public responses to comments  
✅ **Messages** - Direct messages (has filtering but note: private between users)  

### Everything is Protected:
All public-facing content now has profanity filtering enabled!

## Implementation Details

### 1. **InputSanitizer.swift** - Core Filtering Logic

**Profanity List:**
- Curated list of ~15 obvious English profanity words
- Stored as `Set<String>` for O(1) lookup performance
- Easy to expand by adding more words to the array

**Pattern Matching to Catch Evasion:**
The filter normalizes text to catch common bypass attempts:

| Evasion Technique | Example | Normalized To |
|-------------------|---------|---------------|
| Spacing | "f u c k" | "fuck" |
| L33t speak | "sh1t", "b!tch" | "shit", "bitch" |
| Numbers | "a55hole", "d4mn" | "asshole", "damn" |
| Special chars | "f*ck", "sh-t" | "fuck", "shit" |

**Normalization Rules:**
```
Remove spaces → catches "f u c k"
0 → o, 1 → i, 3 → e, 4 → a, 5 → s, 7 → t, 8 → b
@ → a, $ → s, ! → i
Remove: *, -, _, ., ,
```

### 2. **Integration Points**

**CommentField.swift:**
- User clicks send button
- `InputSanitizer.sanitize(message, type: .comment)` is called
- If profanity detected → Shows alert: "Cannot Post Comment"
- If clean → Uploads comment normally

**ReplyField.swift:**
- Same logic as CommentField
- Shows alert: "Cannot Post Reply"

**UserEditView.swift:**
- User clicks save button
- `InputSanitizer.sanitize(fullname, type: .fullName)` is called
- `InputSanitizer.sanitize(bio, type: .userBio)` is called
- If profanity detected → Shows error banner with specific field message
- If clean → Updates profile normally

**RegistrationView.swift:**
- User clicks sign up button
- `InputSanitizer.sanitize(fullname, type: .fullName)` is called
- If profanity detected → Shows error banner: "Invalid full name"
- If clean → Proceeds to birthday verification

**OnboardingView.swift:**
- User saves bio during onboarding
- `InputSanitizer.sanitize(bio, type: .userBio)` is called
- If profanity detected → Shows error banner
- If clean → Saves bio to Firestore

**UsernameValidator.swift:**
- Uses `InputSanitizer.containsProfanity()` for consistency
- Same profanity list and normalization as comments/profiles
- Shows error: "Username may contain inappropriate content"

**CreatePlaylistView.swift:**
- User clicks create button
- `InputSanitizer.sanitize(title, type: .playlistTitle)` is called
- If profanity detected → Shows error alert: "Invalid Playlist Title"
- If clean → Creates playlist with sanitized title

**EditPlaylistNameView.swift:**
- User clicks save button
- `InputSanitizer.sanitize(title, type: .playlistTitle)` is called
- If profanity detected → Shows error alert: "Invalid Playlist Title"
- If clean → Updates playlist with sanitized title

**UploadPodView.swift (Individual Pod Upload):**
- User clicks upload/start button
- Validates title: `InputSanitizer.sanitize(podName, type: .podTitle)`
- Validates description: `InputSanitizer.sanitize(description, type: .podDescription)`
- Validates each tag: `InputSanitizer.sanitize(tag, type: .tag)`
- If any profanity detected → Shows error alert: "Cannot Upload Pod"
- If clean → Proceeds with upload to queue
- Tags are also validated when added (immediate feedback)

### 3. **User Experience**

**What happens when user tries to post profanity:**
1. Clicks send button
2. ⚠️ Alert appears immediately: "Cannot post comment. Please remove inappropriate language."
3. User clicks "OK"
4. Comment text stays in field (not lost)
5. User can edit and try again

**No loading delay** - instant client-side validation

## Testing the Filter

**Test Cases:**

✅ **Direct profanity:**
- "This is shit" → BLOCKED

✅ **Spacing evasion:**
- "This is s h i t" → BLOCKED

✅ **L33t speak:**
- "This is sh1t" → BLOCKED
- "This is 5h1t" → BLOCKED

✅ **Special characters:**
- "This is sh*t" → BLOCKED
- "This is s-h-i-t" → BLOCKED

✅ **Numbers:**
- "This is 5h17" → BLOCKED

✅ **Clean text:**
- "This is great!" → ALLOWED
- "I love this podcast" → ALLOWED

## False Positives to Watch For

The filter checks if profanity exists **anywhere** in the normalized text:

⚠️ **Potential issues:**
- "Scunthorpe" contains "cunt" → might be BLOCKED
- "assassin" contains "ass" → might be BLOCKED
- "classic" contains "ass" → might be BLOCKED

**Solution if this becomes a problem:**
Change from `normalized.contains(word)` to word-boundary checking.

## Expanding the Filter

### Adding More Words:

```swift
private static let profanityList: Set<String> = [
    // Existing words...
    "fuck", "shit", "bitch",
    
    // Add new words here:
    "newword1", "newword2", "newword3"
]
```

### Adding Spanish Support Later:

```swift
private static let profanityList_en: Set<String> = [/* English words */]
private static let profanityList_es: Set<String> = [/* Spanish words */]

static func containsProfanity(_ input: String) -> Bool {
    let normalized = normalizeForProfanityCheck(input)
    
    // Check both languages
    for word in profanityList_en {
        if normalized.contains(word) { return true }
    }
    for word in profanityList_es {
        if normalized.contains(word) { return true }
    }
    
    return false
}
```

## Architecture

```
┌─────────────────────────┐
│   User Types Comment    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Clicks Send Button     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  InputSanitizer.sanitize()          │
│  1. Check length                    │
│  2. Check newlines                  │
│  3. Check special chars             │
│  4. ★ Check profanity ★             │
│  5. Check spam patterns             │
│  6. Check repetition                │
└───────────┬─────────────────────────┘
            │
     ┌──────┴──────┐
     ▼             ▼
┌─────────┐   ┌──────────┐
│  VALID  │   │ INVALID  │
└────┬────┘   └────┬─────┘
     │             │
     ▼             ▼
┌─────────┐   ┌──────────────────┐
│ Upload  │   │ Show Alert       │
│ Comment │   │ Keep text        │
└─────────┘   │ Don't upload     │
              └──────────────────┘
```

## Why Client-Side Only?

**Pros:**
✅ Instant feedback (no network delay)
✅ Works offline
✅ Better UX - user sees error immediately
✅ Simpler implementation
✅ Already have report system as backup

**Cons:**
⚠️ Could be bypassed by modifying app
⚠️ Need app update to change word list

**Verdict:** Good enough for 95% of use cases. Most users won't try to bypass. Power users trying to bypass will be caught by the reporting system.

## Maintenance

**Updating the word list:**
1. Edit `InputSanitizer.swift`
2. Add/remove words from `profanityList` array
3. Test with sample text
4. Deploy app update

**Monitoring:**
- Watch for user reports about comments with profanity
- Add reported words to the list
- Check for false positives in user feedback

## Files Modified

**Core Sanitization:**
- ✅ `PodWebBlueprint/Util/InputSanitizer.swift` - Added profanity detection for comments, messages, bios, and full names
- ✅ `PodWebBlueprint/Util/UsernameValidator.swift` - Now uses InputSanitizer's profanity detection for consistency

**Comments & Replies:**
- ✅ `PodWebBlueprint/Core/Comments/Views/CommentField.swift` - Added alert for profanity
- ✅ `PodWebBlueprint/Core/Comments/Views/ReplyField.swift` - Added alert for profanity

**User Profiles:**
- ✅ `PodWebBlueprint/Core/Profile/Views/UserEditView.swift` - Added validation for full name & bio
- ✅ `PodWebBlueprint/Core/Auth/Views/RegistrationView.swift` - Added validation for full name during signup
- ✅ `PodWebBlueprint/Core/Auth/Views/OnboardingView.swift` - Added validation for bio during onboarding

**Playlists:**
- ✅ `PodWebBlueprint/Core/Profile/PlaylistViews/CreatePlaylistView.swift` - Added validation for playlist titles
- ✅ `PodWebBlueprint/Core/Profile/PlaylistViews/EditPlaylistNameView.swift` - Added validation for playlist titles
- ✅ `PodWebBlueprint/Model/Playlist.swift` - Updated to use .playlistTitle and .playlistDescription types

**Pod Content (Individual Uploads):**
- ✅ `PodWebBlueprint/Core/Uploading/Views/UploadPodView.swift` - Added validation for pod title, description, and tags
- ✅ `PodWebBlueprint/Util/InputSanitizer.swift` - Updated .podTitle, .podDescription, and .tag types to check profanity

## Future Enhancements

1. **Add Spanish support** when user base grows
2. **Add Chinese support** if significant Chinese content
3. **Server-side backup** using bad-words npm package
4. **Analytics** to track profanity attempts
5. **User strike system** for repeat offenders

