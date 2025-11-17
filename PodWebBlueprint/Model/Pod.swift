import Foundation
import FirebaseFirestore
import Firebase

// MARK: - Enums for Type Safety

enum ModerationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
}

// MARK: - Pod Model

struct Pod: Identifiable, Codable, Hashable, Equatable {
    
    @DocumentID var id: String?
    var title: String
    let timestamp: Timestamp
    var description: String
    let fileUrl: String
    let thumbnailUrl: String
    let userId: String
    
    // Engagement metrics - all consistent with default values
    var likes: Int = 0
    var views: Int = 0
    var shares: Int = 0
    var comments: Int = 0
    var saves: Int = 0

    // Optional properties
    var category: String?          // Optional category
    var keywords: [String]?       // Optional list of keywords
    
    // Content metadata
    var duration: TimeInterval?    // Audio duration in seconds
    var fileSize: Int64?          // File size in bytes
    var mimeType: String?         // MIME type of the audio file
    var rssGuid: String?          // Original RSS GUID for tracking (only for RSS-imported pods)
    var rssStreamId: String?      // RSS stream this pod belongs to (only for RSS-imported pods)

    // Additional properties for UI interactions
    var titleLowercased: String?
    var user: User?
    var didLike: Bool? = false
    var didSave: Bool? = false
    var isDeleted: Bool? = false // Marks if the pod has been deleted
    
    // Essential fields for production (optional for backward compatibility)
    var isActive: Bool? = true
    var createdAt: Timestamp?        // Explicit creation timestamp
    var updatedAt: Timestamp?        // Last update timestamp
    var deletedAt: Timestamp?        // Soft delete timestamp
    var version: Int? = 1
    
    // Content moderation
    var isReported: Bool? = false
    var moderationStatus: ModerationStatus? = .approved
    var contentWarnings: [String]? = []

    // MARK: - Validation
    
    /// Validates the pod data for required fields and constraints
    var isValid: Bool {
        return !title.isEmpty && 
               title.count <= 200 &&
               !description.isEmpty &&
               description.count <= 5000 && // Increased from 1000 to support RSS descriptions
               !fileUrl.isEmpty &&
               !thumbnailUrl.isEmpty &&
               !userId.isEmpty &&
               views >= 0 &&
               shares >= 0 &&
               comments >= 0 &&
               saves >= 0 &&
               likes >= 0
    }
    
    /// Returns validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []
        
        if title.isEmpty {
            errors.append("Title is required")
        } else if title.count > 200 {
            errors.append("Title must be 200 characters or less")
        }
        
        if description.isEmpty {
            errors.append("Description is required")
        } else if description.count > 5000 {
            errors.append("Description must be 5000 characters or less")
        }
        
        if fileUrl.isEmpty {
            errors.append("File URL is required")
        }
        
        if thumbnailUrl.isEmpty {
            errors.append("Thumbnail URL is required")
        }
        
        if userId.isEmpty {
            errors.append("User ID is required")
        }
        
        if views < 0 {
            errors.append("Views cannot be negative")
        }
        
        if shares < 0 {
            errors.append("Shares cannot be negative")
        }
        
        if comments < 0 {
            errors.append("Comments cannot be negative")
        }
        
        if saves < 0 {
            errors.append("Saves cannot be negative")
        }
        
        if likes < 0 {
            errors.append("Likes cannot be negative")
        }
        
        return errors
    }
    
    /// Creates a sanitized version of the pod with validated data
    func sanitized() -> Pod {
        var sanitizedPod = self
        
        // Sanitize title
        sanitizedPod.title = String(title.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Sanitize description
        sanitizedPod.description = String(description.prefix(5000)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure engagement metrics are non-negative
        sanitizedPod.views = max(0, views)
        sanitizedPod.shares = max(0, shares)
        sanitizedPod.comments = max(0, comments)
        sanitizedPod.saves = max(0, saves)
        sanitizedPod.likes = max(0, likes)
        
        // Set timestamps if missing
        if sanitizedPod.createdAt == nil {
            sanitizedPod.createdAt = timestamp
        }
        
        if sanitizedPod.updatedAt == nil {
            sanitizedPod.updatedAt = Timestamp()
        }
        
        return sanitizedPod
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the pod is soft deleted
    var isSoftDeleted: Bool {
        return deletedAt != nil || (isDeleted == true)
    }
    
    /// Returns the creation date, preferring createdAt over timestamp
    var creationDate: Date {
        return createdAt?.dateValue() ?? timestamp.dateValue()
    }
    
    /// Returns the last update date
    var lastUpdateDate: Date? {
        return updatedAt?.dateValue()
    }
    
    // MARK: - Equality & Hashing
    
    static func == (lhs: Pod, rhs: Pod) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
