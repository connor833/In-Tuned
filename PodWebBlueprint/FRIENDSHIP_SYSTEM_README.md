# Friendship and Conversation System

## Overview

The friendship system has been redesigned to work as a "conversation has been established" flag rather than a traditional friendship system. This ensures that conversations are not duplicated and users can maintain access to their chat history even when following relationships change.

## How It Works

### 1. Follow/Unfollow Behavior

- **Following a user**: Creates a follow relationship (increments counts, adds to following/followers collections)
- **Unfollowing a user**: Removes the follow relationship (decrements counts, removes from following/followers collections)
- **Important**: Unfollowing does NOT remove friendship status or conversation access

### 2. Friendship Creation

Friendship is automatically created when:
- User A follows User B AND User B already follows User A (mutual follow)
- User A accepts a follow request from User B (creates mutual follow)

**Before creating friendship, the system checks:**
1. Are they already friends? → No action needed
2. Does a conversation already exist? → Just ensure friendship documents exist
3. No conversation exists? → Create new friendship AND conversation

### 3. Conversation Management

- **Conversations are permanent**: Once created, they are never deleted
- **Friendship = Access**: Friendship documents grant access to existing conversations
- **No duplicates**: Multiple conversations between the same users are prevented

## Code Changes Made

### UserService.swift

#### New Methods Added:
- `handleMutualFollow(withUid:completion:)` - Handles mutual follow scenarios via cloud function
- `removeFriendship(with:completion:)` - Explicitly removes friendship (for complete removal)

#### Modified Methods:
- `addFriend(user:completion:)` - Now checks for existing conversations before creating new ones
- `unaddFriend(user:completion:)` - Updated comments to clarify it shouldn't be used for unfollowing

### UserViewModel.swift

#### Modified Methods:
- `followUser()` - Now calls `handleMutualFollow` instead of `addFriend` for mutual follow scenarios
- `unfollowUser()` - Removed `unaddFriend` call to preserve friendship when unfollowing

### Cloud Functions (index.js)

#### New Function:
- `handleMutualFollow` - Cloud function that handles mutual follow logic
- `findExistingConversation` - Helper to check for existing conversations
- `ensureFriendshipDocuments` - Helper to ensure friendship documents exist
- `createFriendshipAndConversation` - Helper to create new friendship and conversation

## Data Flow Examples

### Scenario 1: New Mutual Follow
1. User A follows User B
2. User B follows User A back
3. System detects mutual follow
4. Checks if conversation exists → None found
5. Creates friendship documents for both users
6. Creates new conversation
7. Both users can now message each other

### Scenario 2: Re-following After Unfollow
1. User A and User B are friends with conversation
2. User A unfollows User B
3. **Friendship remains** (conversation accessible)
4. User A follows User B again
5. System detects mutual follow
6. Checks if conversation exists → Found existing
7. Just ensures friendship documents exist
8. **No new conversation created**

### Scenario 3: Accepting Follow Request
1. User A sends follow request to User B
2. User B accepts follow request
3. Creates mutual follow relationship
4. System handles mutual follow logic
5. Creates friendship/conversation if needed

## Key Benefits

1. **No Duplicate Conversations**: Users can't accidentally create multiple conversations
2. **Persistent Chat History**: Unfollowing doesn't delete conversation history
3. **Efficient Resource Usage**: Prevents unnecessary conversation creation
4. **Clear Separation**: Follow/unfollow vs. friendship are separate concepts
5. **Cloud-Side Logic**: All complex logic handled server-side for consistency

## Usage Guidelines

### For Developers:
- Use `handleMutualFollow` when mutual follow relationships are established
- Use `removeFriendship` only when users explicitly want to remove friendship
- Never call `unaddFriend` during unfollow operations
- Friendship documents serve as conversation access flags

### For Users:
- Following someone doesn't automatically create a conversation
- Conversations are only created when both users follow each other
- Unfollowing someone doesn't remove your chat history
- You can still message someone if you're friends, even if you don't follow them

## Migration Notes

- Existing friendships and conversations will continue to work
- New mutual follow relationships will use the new logic
- Unfollowing behavior has changed (no longer removes friendship)
- Users may need to explicitly remove friendship if they want to completely remove someone

## Testing Scenarios

1. **New mutual follow** → Should create friendship and conversation
2. **Re-following** → Should not create duplicate conversation
3. **Unfollowing** → Should preserve friendship and conversation access
4. **Follow request acceptance** → Should trigger mutual follow logic
5. **Explicit friendship removal** → Should remove friendship but preserve conversation

## Future Enhancements

- Add conversation archiving for removed friendships
- Implement conversation search/filtering
- Add friendship status indicators in UI
- Consider conversation privacy settings
