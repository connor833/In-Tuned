//
//  Comment.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/25/22.
//

import Foundation
import FirebaseFirestore
import Firebase

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    let caption: String
    let timestamp: Timestamp
    let uid: String
    var likes: Int
    var replyCount: Int
    
    // Essential production fields for migration and data integrity
    var isActive: Bool? = true
    var createdAt: Timestamp?
    var updatedAt: Timestamp?
    var deletedAt: Timestamp?
    var version: Int? = 1
    
    // Content reference and moderation
    var podId: String?              // ID of the pod being commented on
    var isReported: Bool? = false   // If comment has been reported
    
    // UI data (not stored in Firestore)
    var user: User?
    var pod: Pod?
    var didLike: Bool? = false
    
    // Custom coding keys to exclude UI data from encoding
    enum CodingKeys: String, CodingKey {
        case id, caption, timestamp, uid, likes, replyCount
        case isActive, createdAt, updatedAt, deletedAt, version
        case podId, isReported
        // Exclude 'user', 'pod', 'didLike' as they're not stored
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the comment is soft deleted
    var isSoftDeleted: Bool {
        return deletedAt != nil || (isActive == false)
    }
    
    /// Returns the creation date, preferring createdAt over timestamp
    var creationDate: Date {
        return createdAt?.dateValue() ?? timestamp.dateValue()
    }
    
    /// Returns the last update date
    var lastUpdateDate: Date? {
        return updatedAt?.dateValue()
    }
}
