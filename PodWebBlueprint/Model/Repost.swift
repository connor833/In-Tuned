//
//  Repost.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import Foundation
import FirebaseFirestore

struct Repost: Identifiable, Codable, Hashable, Equatable {
    var id: String?
    let podId: String
    let originalUserId: String
    let repostUserId: String
    let caption: String?
    let timestamp: Date
    
    // Essential production fields
    let version: Int?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    let deletedAt: Timestamp?
    
    // Engagement metrics
    let likes: Int
    let views: Int
    let shares: Int
    let comments: Int
    
    // Content moderation
    let isReported: Bool
    let moderationStatus: ModerationStatus
    let contentWarnings: [String]
    
    // Soft delete support
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case podId
        case originalUserId
        case repostUserId
        case caption
        case timestamp
        case version
        case createdAt
        case updatedAt
        case deletedAt
        case likes
        case views
        case shares
        case comments
        case isReported
        case moderationStatus
        case contentWarnings
        case isActive
    }
    
    init(podId: String, originalUserId: String, repostUserId: String, caption: String? = nil, timestamp: Date = Date()) {
        self.id = nil
        self.podId = podId
        self.originalUserId = originalUserId
        self.repostUserId = repostUserId
        self.caption = caption
        self.timestamp = timestamp
        self.version = 1
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
        self.deletedAt = nil
        self.likes = 0
        self.views = 0
        self.shares = 0
        self.comments = 0
        self.isReported = false
        self.moderationStatus = .approved
        self.contentWarnings = []
        self.isActive = true
    }
    
    // MARK: - Validation
    
    /// Validates the repost data
    var isValid: Bool {
        return !podId.isEmpty && 
               !originalUserId.isEmpty && 
               !repostUserId.isEmpty &&
               originalUserId != repostUserId &&
               (caption?.count ?? 0) <= 500
    }
    
    /// Returns validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []
        
        if podId.isEmpty { errors.append("Pod ID is required") }
        if originalUserId.isEmpty { errors.append("Original user ID is required") }
        if repostUserId.isEmpty { errors.append("Repost user ID is required") }
        if originalUserId == repostUserId { errors.append("Cannot repost your own content") }
        if let caption = caption, caption.count > 500 { errors.append("Caption must be 500 characters or less") }
        
        return errors
    }
    
    /// Sanitizes the repost data
    func sanitized() -> Repost {
        var sanitizedRepost = self
        if let caption = caption {
            sanitizedRepost = Repost(
                podId: podId,
                originalUserId: originalUserId,
                repostUserId: repostUserId,
                caption: InputSanitizer.clean(caption, type: .podDescription),
                timestamp: timestamp
            )
        }
        return sanitizedRepost
    }
    
    // MARK: - Computed Properties
    
    /// Get the version number (defaults to 1 if not set)
    var versionNumber: Int {
        return version ?? 1
    }
    
    /// Check if repost is soft deleted
    var isSoftDeleted: Bool {
        return deletedAt != nil || !isActive
    }
    
    /// Get creation date
    var creationDate: Date? {
        return createdAt?.dateValue()
    }
    
    /// Get last update date
    var lastUpdateDate: Date? {
        return updatedAt?.dateValue()
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(podId)
        hasher.combine(repostUserId)
    }
    
    static func == (lhs: Repost, rhs: Repost) -> Bool {
        return lhs.id == rhs.id &&
               lhs.podId == rhs.podId &&
               lhs.repostUserId == rhs.repostUserId &&
               lhs.timestamp == rhs.timestamp
    }
} 

// Combined struct for reposts with pod data
struct RepostWithPod: Identifiable, Hashable {
    let repost: Repost
    let pod: Pod
    
    var id: String? { repost.id }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RepostWithPod, rhs: RepostWithPod) -> Bool {
        return lhs.id == rhs.id
    }
} 