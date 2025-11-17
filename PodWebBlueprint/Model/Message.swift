//
//  Message.swift
//  CryptChat
//
//  Created by Connor Adams on 8/9/22.
//

import Foundation
import Firebase
import FirebaseFirestore

struct Message: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var text: String
    var senderId: String
    var timestamp: Date
    var isPod: Bool
    var podId: String?
    var isRead: Bool?
    
    // Essential production fields for migration and data integrity
    var version: Int? = 1
    
    // Message type and content
    var conversationId: String?        // Reference to parent conversation
    
    // Content moderation
    var isReported: Bool? = false
    
    // Read status (isRead for one-on-one, readBy for group chats)
    var readBy: [String: Date]? = [:]  // User ID -> Read timestamp
    
    // Analytics
    var reactions: [String: [String]]? = [:]  // Emoji -> User IDs
    
    // UI data (not stored in Firestore)
    var user: User?
    var pod: Pod?
    
    // TODO: Re-enable liking functionality
    // var isLiked: Bool?
    // var likedBy: [String]?
    
    // Custom coding keys to exclude UI data from encoding
    enum CodingKeys: String, CodingKey {
        case id, text, senderId, timestamp, isPod, podId, isRead
        case version
        case conversationId
        case isReported
        case readBy
        case reactions
        // Exclude 'user', 'pod' as they're not stored
    }
    
    // MARK: - Computed Properties
    
    /// Returns the creation date (timestamp is the creation date)
    var creationDate: Date {
        return timestamp
    }
    
    
    /// Returns the number of users who have read this message
    var readCount: Int {
        return readBy?.count ?? 0
    }
    
    /// Returns true if a specific user has read this message
    func isReadBy(_ userId: String) -> Bool {
        return readBy?[userId] != nil
    }
    
    /// Returns the total number of reactions
    var totalReactions: Int {
        return reactions?.values.flatMap { $0 }.count ?? 0
    }
    
    /// Returns true if message has any reactions
    var hasReactions: Bool {
        return totalReactions > 0
    }
    
    // MARK: - Equality & Hashing
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.senderId == rhs.senderId &&
               lhs.timestamp == rhs.timestamp &&
               lhs.isPod == rhs.isPod &&
               lhs.podId == rhs.podId &&
               lhs.isRead == rhs.isRead &&
               lhs.version == rhs.version
    }
}
