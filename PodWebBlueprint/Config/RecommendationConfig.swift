//
//  RecommendationConfig.swift
//  PodWebBlueprint
//
//  Centralized configuration for all recommendation algorithms
//

import Foundation

struct RecommendationConfig {
    
    // MARK: - For You Feed Configuration
    
    /// For You feed diversification settings
    struct ForYouFeed {
        /// Percentage of results that should be based on user preferences
        static let userPreferenceWeight: Double = 0.75        // 75% user preferences
        /// Percentage of results that should be random for diversity
        static let randomDiversityWeight: Double = 0.25       // 25% random diversity
        /// How often to inject random pods (every N pods)
        static let diversificationInterval: Int = 3           // Every 3rd pod is random
        /// Number of categories to query from user preferences
        static let maxUserCategories: Int = 10
    }
    
    // MARK: - Player View Recommendations Configuration
    
    /// Player view recommendation mixing weights
    struct PlayerRecommendations {
        /// Weight for similarity to current pod (category + keywords matching)
        static let currentPodSimilarityWeight: Double = 0.50  // 50% similar content
        /// Weight for user preference categories
        static let userPreferenceWeight: Double = 0.35        // 35% user preferences  
        /// Weight for random variety
        static let randomVarietyWeight: Double = 0.15         // 15% random variety
        
        /// Number of pods to fetch for recommendations
        static let pageSize: Int = 10
        /// Cache expiration time (in seconds)
        static let cacheExpirationTime: TimeInterval = 120    // 2 minutes
    }
    
    // MARK: - Popularity Scoring Configuration
    
    /// Popularity scoring weights for different engagement metrics
    struct PopularityScoring {
        /// Weight for likes in popularity calculation
        static let likesWeight: Double = 2.0
        /// Weight for views in popularity calculation  
        static let viewsWeight: Double = 0.1
        /// Weight for shares in popularity calculation
        static let sharesWeight: Double = 3.0
        /// Weight for saves in popularity calculation
        static let savesWeight: Double = 1.5
        /// Weight for comments in popularity calculation
        static let commentsWeight: Double = 1.0
        
        /// Minimum engagement threshold to be considered for recommendations
        static let minEngagementThreshold: Int = 1
        /// Boost factor for recently engaged content (last 7 days)
        static let recentEngagementBoost: Double = 1.2
    }
    
    // MARK: - Diversification Configuration
    
    /// Settings for content diversification to prevent filter bubbles
    struct Diversification {
        /// Maximum number of pods from same category in a row
        static let maxConsecutiveSameCategory: Int = 2
        /// Maximum number of pods from same user in a row  
        static let maxConsecutiveSameUser: Int = 1
        /// Minimum variety score required (0.0 to 1.0)
        static let minVarietyScore: Double = 0.3
        /// Enable smart shuffling to spread out similar content
        static let enableSmartShuffling: Bool = true
        
        /// Maximum percentage of results that can be from the same category (prevents dominance)
        static let maxSameCategoryPercentage: Double = 0.4    // Max 40% from any single category
        /// Randomness factor in popularity sorting (0.0 = pure popularity, 1.0 = pure random)
        static let popularityRandomnessFactor: Double = 0.3   // 30% randomness mixed with popularity
        /// Enable popularity tier shuffling (groups by popularity, randomizes within tiers)
        static let enablePopularityTierShuffling: Bool = true
    }
    
    // MARK: - User Learning Configuration (existing)
    
    /// Settings for how user interactions affect preferences
    struct UserLearning {
        /// Weight boost per interaction
        static let clickBoost: Double = 0.1
        /// Maximum weight for any category/keyword
        static let maxWeight: Double = 1.0
        /// Minimum weight for any category/keyword
        static let minWeight: Double = 0.1
        /// Decay factor applied to other categories when one is boosted
        static let decayFactor: Double = 0.95
        /// Maximum number of keywords to track per user
        static let maxKeywords: Int = 5
    }
    
    // MARK: - Debug Configuration
    
    /// Enable detailed logging for recommendation algorithms
    static let enableRecommendationDebugging: Bool = true
    
    // MARK: - Utility Functions
    
    /// Calculate popularity score for a pod
    static func calculatePopularityScore(
        likes: Int,
        views: Int, 
        shares: Int,
        saves: Int,
        comments: Int,
        createdAt: Date? = nil
    ) -> Double {
        let baseScore = Double(likes) * PopularityScoring.likesWeight +
                       Double(views) * PopularityScoring.viewsWeight +
                       Double(shares) * PopularityScoring.sharesWeight +
                       Double(saves) * PopularityScoring.savesWeight +
                       Double(comments) * PopularityScoring.commentsWeight
        
        // Apply recent engagement boost if created within last 7 days
        if let createdAt = createdAt,
           Date().timeIntervalSince(createdAt) < (7 * 24 * 60 * 60) {
            return baseScore * PopularityScoring.recentEngagementBoost
        }
        
        return baseScore
    }
    
    /// Check if a pod meets minimum engagement threshold
    static func meetsEngagementThreshold(
        likes: Int,
        views: Int,
        shares: Int,
        saves: Int,
        comments: Int
    ) -> Bool {
        let totalEngagement = likes + views + shares + saves + comments
        return totalEngagement >= PopularityScoring.minEngagementThreshold
    }
}
