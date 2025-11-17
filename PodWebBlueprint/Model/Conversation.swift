//
//  Conversation.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/23.
//

import Foundation
import Firebase
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var type: ConversationType
    var participants: [String]
    var lastMessage: Message?
    var lastActivity: Date
    var name: String?
    var createdAt: Date
    var createdBy: String
    var lastMessageReadBy: [String]? // Array of user IDs who have read the last message
    
    // Essential production fields for migration and data integrity
    var version: Int? = 1
    
    // Group chat specific fields
    var avatarUrl: String?                // Group avatar image URL
    var maxParticipants: Int? = 50        // Maximum number of participants
    
    // Content moderation and settings
    var isReported: Bool? = false         // If conversation has been reported
    var moderationStatus: String? = "approved"  // pending, approved, rejected
    var contentWarnings: [String]? = []   // Content warnings applied
    var isMuted: Bool? = false            // If conversation is muted globally
    
    // Analytics and engagement
    var totalMessages: Int? = 0           // Total message count
    var lastMessageAt: Date?              // When last message was sent
    var lastSeenBy: [String: Date]? = [:] // Last seen timestamp for each participant
    
    // Custom coding keys to exclude computed properties from encoding
    enum CodingKeys: String, CodingKey {
        case id, type, participants, lastMessage, lastActivity, name, createdAt, createdBy, lastMessageReadBy
        case version
        case avatarUrl, maxParticipants
        case isReported, moderationStatus, contentWarnings, isMuted
        case totalMessages, lastMessageAt, lastSeenBy
    }
    
    // MARK: - Computed Properties
    
    
    /// Returns true if this is a group conversation
    var isGroup: Bool {
        return type == .group
    }
    
    /// Returns true if this is a one-on-one conversation
    var isOneOnOne: Bool {
        return type == .oneOnOne
    }
    
    /// Returns the participant count
    var participantCount: Int {
        return participants.count
    }
    
    /// Returns true if conversation has reached max participants
    var isFull: Bool {
        guard let maxParticipants = maxParticipants else { return false }
        return participants.count >= maxParticipants
    }
    
    /// Returns true if user is a participant in the conversation
    func isParticipant(_ userId: String) -> Bool {
        return participants.contains(userId)
    }
    
    /// Returns true if user can add others to the conversation
    func canAddParticipants(_ userId: String) -> Bool {
        return isParticipant(userId) && !isFull
    }
    
    // MARK: - Equality & Hashing
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.participants == rhs.participants &&
               lhs.lastActivity == rhs.lastActivity
    }
}

// MARK: - Supporting Types

enum ConversationType: String, Codable, CaseIterable {
    case oneOnOne = "oneOnOne"
    case group = "group"
    
    var displayName: String {
        switch self {
        case .oneOnOne: return "Direct Message"
        case .group: return "Group Chat"
        }
    }
}


struct ConversationMetadata: Identifiable, Codable {
    @DocumentID var id: String?
    var unreadCount: Int
    var lastReadTimestamp: Date
    var conversationRef: String
    var joinedAt: Date
    
    // Additional metadata fields
    var isMuted: Bool? = false            // If user has muted this conversation
    var isPinned: Bool? = false           // If user has pinned this conversation
    var notificationSettings: [String: Bool]? = [:]  // Granular notification preferences
    
    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case id, unreadCount, lastReadTimestamp, conversationRef, joinedAt
        case isMuted, isPinned, notificationSettings
    }
} 
