//
//  Playlist.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/18/23.
//

import Foundation
import FirebaseFirestore
import Firebase

struct Playlist: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var thumbnailUrl: String
    let userId: String
    var likes: Int
    
    // Essential production fields
    let version: Int?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Content and metadata
    var description: String?
    var podCount: Int
    var isPublic: Bool
    var isActive: Bool
    
    // Content moderation (optional for future use)
    var isReported: Bool?
    var moderationStatus: ModerationStatus?
    var contentWarnings: [String]?
    
    // UI state (not stored)
    var user: User?
    var didLike: Bool? = false
    var didSave: Bool? = false
    
    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case id, title, thumbnailUrl, userId, likes
        case version, createdAt, updatedAt
        case description, podCount, isPublic, isActive
        case isReported, moderationStatus, contentWarnings
        // Exclude UI state fields
    }
    
    // Default initializer
    init(title: String, thumbnailUrl: String, userId: String, likes: Int = 0, description: String? = nil) {
        self.id = nil
        self.title = title
        self.thumbnailUrl = thumbnailUrl
        self.userId = userId
        self.likes = likes
        self.version = 1
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
        self.description = description
        self.podCount = 0
        self.isPublic = true  // Always public by default
        self.isActive = true  // Always active by default
        self.isReported = nil
        self.moderationStatus = nil
        self.contentWarnings = nil
        self.user = nil
        self.didLike = false
        self.didSave = false
    }
    
    // MARK: - Validation
    
    /// Validates the playlist data
    var isValid: Bool {
        return !title.isEmpty && 
               !thumbnailUrl.isEmpty && 
               !userId.isEmpty &&
               title.count <= 100 &&
               (description?.count ?? 0) <= 500
    }
    
    /// Returns validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []
        
        if title.isEmpty { errors.append("Title is required") }
        if title.count > 100 { errors.append("Title must be 100 characters or less") }
        if thumbnailUrl.isEmpty { errors.append("Thumbnail URL is required") }
        if userId.isEmpty { errors.append("User ID is required") }
        if let description = description, description.count > 500 { 
            errors.append("Description must be 500 characters or less") 
        }
        
        return errors
    }
    
    /// Sanitizes the playlist data
    func sanitized() -> Playlist {
        var sanitizedPlaylist = self
        sanitizedPlaylist.title = InputSanitizer.clean(title, type: .playlistTitle)
        if let description = description {
            sanitizedPlaylist.description = InputSanitizer.clean(description, type: .playlistDescription)
        }
        return sanitizedPlaylist
    }
    
    // MARK: - Computed Properties
    
    /// Check if playlist is active
    var isPlaylistActive: Bool {
        return isActive
    }
    
    /// Get creation date
    var creationDate: Date? {
        return createdAt?.dateValue()
    }
    
    /// Get last update date
    var lastUpdateDate: Date? {
        return updatedAt?.dateValue()
    }
}
