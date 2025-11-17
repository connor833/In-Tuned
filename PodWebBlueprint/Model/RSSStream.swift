import Foundation
import FirebaseFirestore
import Firebase

// MARK: - RSS Stream Model

struct RSSStream: Identifiable, Codable, Hashable, Equatable {
    
    @DocumentID var id: String?
    let subscriptionId: String      // Link back to RSSSubscription
    let userId: String             // Stream creator/owner
    var title: String              // RSS feed title
    var description: String?       // RSS feed description
    var thumbnailUrl: String       // RSS feed image
    var episodeCount: Int = 0      // Number of episodes in stream
    
    // RSS metadata from feed
    var feedUrl: String            // Original RSS URL
    var author: String?            // From RSS <author> or <itunes:author>
    var language: String?          // From RSS <language>
    var category: String?          // From RSS <category> or <itunes:category>
    var explicit: Bool = false     // From RSS <itunes:explicit>
    var lastEpisodeDate: Timestamp?  // Most recent episode pub date
    
    // Engagement metrics
    var likes: Int = 0             // Users can like entire podcasts
    var views: Int = 0             // Stream page views
    
    // Status and timestamps
    let createdAt: Timestamp
    var updatedAt: Timestamp?
    var isActive: Bool = true      // Mirrors subscription status
    var isPublic: Bool = true      // Discoverable by others
    
    // Essential production fields
    let version: Int? = 1
    
    // MARK: - Validation
    
    /// Validates the RSS stream data for required fields and constraints
    var isValid: Bool {
        return !subscriptionId.isEmpty &&
               !userId.isEmpty &&
               !title.isEmpty &&
               title.count <= 200 &&
               !feedUrl.isEmpty &&
               !thumbnailUrl.isEmpty &&
               isValidURL(feedUrl) &&
               likes >= 0 &&
               views >= 0 &&
               episodeCount >= 0
    }
    
    /// Returns validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []
        
        if subscriptionId.isEmpty {
            errors.append("Subscription ID is required")
        }
        
        if userId.isEmpty {
            errors.append("User ID is required")
        }
        
        if title.isEmpty {
            errors.append("Title is required")
        } else if title.count > 200 {
            errors.append("Title must be 200 characters or less")
        }
        
        if feedUrl.isEmpty {
            errors.append("Feed URL is required")
        } else if !isValidURL(feedUrl) {
            errors.append("Feed URL must be a valid URL")
        }
        
        if thumbnailUrl.isEmpty {
            errors.append("Thumbnail URL is required")
        }
        
        if let description = description, description.count > 1000 {
            errors.append("Description must be 1000 characters or less")
        }
        
        if likes < 0 {
            errors.append("Likes cannot be negative")
        }
        
        if views < 0 {
            errors.append("Views cannot be negative")
        }
        
        if episodeCount < 0 {
            errors.append("Episode count cannot be negative")
        }
        
        return errors
    }
    
    /// Creates a sanitized version of the stream with validated data
    func sanitized() -> RSSStream {
        var sanitizedStream = self
        
        // Sanitize title
        sanitizedStream.title = String(title.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Sanitize description
        if let description = description {
            sanitizedStream.description = String(description.prefix(1000)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Ensure metrics are non-negative
        sanitizedStream.likes = max(0, likes)
        sanitizedStream.views = max(0, views)
        sanitizedStream.episodeCount = max(0, episodeCount)
        
        // Set updatedAt timestamp
        sanitizedStream.updatedAt = Timestamp()
        
        return sanitizedStream
    }
    
    // MARK: - Helper Methods
    
    /// Returns the creation date
    var creationDate: Date {
        return createdAt.dateValue()
    }
    
    /// Returns the last update date
    var lastUpdateDate: Date? {
        return updatedAt?.dateValue()
    }
    
    /// Returns the last episode date
    var lastEpisodePublishedDate: Date? {
        return lastEpisodeDate?.dateValue()
    }
    
    /// Check if stream is active
    var isStreamActive: Bool {
        return isActive
    }
    
    // MARK: - Private Helpers
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    // MARK: - Equality & Hashing
    
    static func == (lhs: RSSStream, rhs: RSSStream) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - RSS Stream Creation Helper

extension RSSStream {
    
    /// Creates a new RSS stream from RSS feed data and subscription
    static func create(
        from rssData: RSSFeedData,
        subscription: RSSSubscription,
        userId: String
    ) -> RSSStream {
        return RSSStream(
            subscriptionId: subscription.id ?? "",
            userId: userId,
            title: rssData.channelTitle,
            description: rssData.channelDescription,
            thumbnailUrl: rssData.channelImageURL ?? "",
            episodeCount: 0,
            feedUrl: subscription.feedUrl,
            author: nil,        // RSSFeedData doesn't have author field
            language: nil,      // RSSFeedData doesn't have language field
            category: nil,      // RSSFeedData doesn't have category field
            explicit: false,    // RSSFeedData doesn't have explicit field
            lastEpisodeDate: nil,
            likes: 0,
            views: 0,
            createdAt: Timestamp(),
            updatedAt: Timestamp(),
            isActive: true,
            isPublic: true
        )
    }
}
