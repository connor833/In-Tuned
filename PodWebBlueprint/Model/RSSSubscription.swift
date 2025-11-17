import Foundation
import FirebaseFirestore
import Firebase

// MARK: - RSS Subscription Model

struct RSSSubscription: Identifiable, Codable, Hashable, Equatable {
    
    @DocumentID var id: String?
    let feedUrl: String
    var feedTitle: String
    var feedDescription: String?
    let feedImageURL: String?
    var lastChecked: Timestamp?
    @available(*, deprecated, message: "Use importedEpisodes subcollection instead")
    var importedEpisodeGuids: [String] // Deprecated - kept for backwards compatibility during migration
    var streamId: String?  // Reference to auto-created RSS stream
    var isActive: Bool
    let createdAt: Timestamp
    var updatedAt: Timestamp?
    
    // MARK: - Validation
    
    /// Validates the RSS subscription data for required fields and constraints
    var isValid: Bool {
        return !feedUrl.isEmpty &&
               !feedTitle.isEmpty &&
               feedTitle.count <= 200 &&
               isValidURL(feedUrl)
               // Note: importedEpisodeGuids validation removed - now uses subcollection
    }
    
    /// Returns validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []
        
        if feedUrl.isEmpty {
            errors.append("Feed URL is required")
        } else if !isValidURL(feedUrl) {
            errors.append("Feed URL must be a valid URL")
        }
        
        if feedTitle.isEmpty {
            errors.append("Feed title is required")
        } else if feedTitle.count > 200 {
            errors.append("Feed title must be 200 characters or less")
        }
        
        if let description = feedDescription, description.count > 1000 {
            errors.append("Feed description must be 1000 characters or less")
        }
        
        // Note: importedEpisodeGuids validation removed - now uses subcollection
        
        return errors
    }
    
    /// Creates a sanitized version of the subscription with validated data
    func sanitized() -> RSSSubscription {
        var sanitizedSubscription = self
        
        // Sanitize feed title
        sanitizedSubscription.feedTitle = String(feedTitle.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Sanitize feed description
        if let description = feedDescription {
            sanitizedSubscription.feedDescription = String(description.prefix(1000)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Note: GUID array sanitization removed - now uses subcollection
        
        // Set updatedAt timestamp
        sanitizedSubscription.updatedAt = Timestamp()
        
        return sanitizedSubscription
    }
    
    // MARK: - Helper Methods
    
    /// Checks if the subscription has any imported episodes (legacy check)
    @available(*, deprecated, message: "This only checks the deprecated array. Use subcollection query instead.")
    var hasImportedEpisodes: Bool {
        return !importedEpisodeGuids.isEmpty
    }
    
    /// Returns the last update date
    var lastUpdateDate: Date? {
        return updatedAt?.dateValue()
    }
    
    /// Returns the creation date
    var creationDate: Date {
        return createdAt.dateValue()
    }
    
    /// Returns the last checked date
    var lastCheckedDate: Date? {
        return lastChecked?.dateValue()
    }
    
    /// Checks if this subscription matches another feed by content (for duplicate detection)
    func matchesFeed(title: String, description: String?) -> Bool {
        // Normalize titles for comparison
        let normalizedCurrentTitle = feedTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNewTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check title match
        let titleMatch = normalizedCurrentTitle == normalizedNewTitle
        
        // Check description match if both exist
        if let currentDesc = feedDescription?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           let newDesc = description?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           !currentDesc.isEmpty && !newDesc.isEmpty {
            let descriptionMatch = currentDesc == newDesc
            return titleMatch && descriptionMatch
        }
        
        // If descriptions don't exist or are empty, rely on title match
        return titleMatch
    }
    
    // MARK: - Private Helpers
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    // MARK: - Equality & Hashing
    
    static func == (lhs: RSSSubscription, rhs: RSSSubscription) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - RSS Subscription Creation Helper

extension RSSSubscription {
    
    /// Creates a new RSS subscription from RSS feed data
    static func create(
        from rssData: RSSFeedData,
        feedUrl: String,
        userId: String,
        importedGuids: [String] = []
    ) -> RSSSubscription {
        return RSSSubscription(
            feedUrl: feedUrl,
            feedTitle: rssData.channelTitle,
            feedDescription: rssData.channelDescription,
            feedImageURL: rssData.channelImageURL,
            lastChecked: Timestamp(),  // Set to current time when created
            importedEpisodeGuids: importedGuids,
            isActive: true,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
}
