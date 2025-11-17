import Foundation
import Firebase
import FirebaseFirestore

/// Comprehensive rate limiting service to prevent search abuse and API attacks
/// Protects against malicious users overwhelming the system with search requests
class SearchRateLimiter: ObservableObject {
    
    // MARK: - Rate Limiting Configuration
    
    /// Maximum searches per minute per user
    private let maxSearchesPerMinute = 10
    
    /// Maximum searches per hour per user
    private let maxSearchesPerHour = 100
    
    /// Maximum searches per day per user
    private let maxSearchesPerDay = 1000
    
    /// Cooldown period after hitting rate limit (in seconds)
    private let cooldownPeriod: TimeInterval = 60
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var userSearchCounts: [String: UserSearchCount] = [:]
    private var blockedUsers: Set<String> = []
    
    // MARK: - Search Count Tracking
    
    /// Tracks search attempts for a specific user
    struct UserSearchCount {
        let userId: String
        var searchesPerMinute: Int = 0
        var searchesPerHour: Int = 0
        var searchesPerDay: Int = 0
        var lastSearchTime: Date = Date()
        var lastMinuteReset: Date = Date()
        var lastHourReset: Date = Date()
        var lastDayReset: Date = Date()
        var isBlocked: Bool = false
        var blockExpiry: Date?
    }
    
    // MARK: - Rate Limiting Methods
    
    /// Checks if a user can perform a search
    /// - Parameter userId: The user's ID
    /// - Returns: True if search is allowed, false if rate limited
    func canPerformSearch(userId: String) async -> Bool {
        // Check if user is currently blocked
        if blockedUsers.contains(userId) {
            return false
        }
        
        // Get or create user search count
        var userCount = userSearchCounts[userId] ?? UserSearchCount(userId: userId)
        
        // Reset counters if time periods have passed
        userCount = resetCountersIfNeeded(userCount)
        
        // Check rate limits
        if userCount.searchesPerMinute >= maxSearchesPerMinute {
            await blockUser(userId: userId, reason: "Minute rate limit exceeded")
            return false
        }
        
        if userCount.searchesPerHour >= maxSearchesPerHour {
            await blockUser(userId: userId, reason: "Hour rate limit exceeded")
            return false
        }
        
        if userCount.searchesPerDay >= maxSearchesPerDay {
            await blockUser(userId: userId, reason: "Daily rate limit exceeded")
            return false
        }
        
        // Increment search counts
        userCount.searchesPerMinute += 1
        userCount.searchesPerHour += 1
        userCount.searchesPerDay += 1
        userCount.lastSearchTime = Date()
        
        // Update local tracking
        userSearchCounts[userId] = userCount
        
        // Log search attempt to Firestore for monitoring
        await logSearchAttempt(userId: userId, allowed: true)
        
        return true
    }
    
    /// Records a successful search for rate limiting purposes
    /// - Parameter userId: The user's ID
    func recordSearch(userId: String) async {
        // Update local counts
        if var userCount = userSearchCounts[userId] {
            userCount.searchesPerMinute += 1
            userCount.searchesPerHour += 1
            userCount.searchesPerDay += 1
            userCount.lastSearchTime = Date()
            userSearchCounts[userId] = userCount
        }
        
        // Log to Firestore for monitoring
        await logSearchAttempt(userId: userId, allowed: true)
    }
    
    /// Records a blocked search attempt
    /// - Parameter userId: The user's ID
    /// - Parameter reason: Why the search was blocked
    func recordBlockedSearch(userId: String, reason: String) async {
        await logSearchAttempt(userId: userId, allowed: false, reason: reason)
    }
    
    // MARK: - Private Methods
    
    /// Resets counters if time periods have passed
    private func resetCountersIfNeeded(_ userCount: UserSearchCount) -> UserSearchCount {
        var updatedCount = userCount
        let now = Date()
        
        // Reset minute counter
        if now.timeIntervalSince(userCount.lastMinuteReset) >= 60 {
            updatedCount.searchesPerMinute = 0
            updatedCount.lastMinuteReset = now
        }
        
        // Reset hour counter
        if now.timeIntervalSince(userCount.lastHourReset) >= 3600 {
            updatedCount.searchesPerHour = 0
            updatedCount.lastHourReset = now
        }
        
        // Reset day counter
        if now.timeIntervalSince(userCount.lastDayReset) >= 86400 {
            updatedCount.searchesPerDay = 0
            updatedCount.lastDayReset = now
        }
        
        return updatedCount
    }
    
    /// Blocks a user for exceeding rate limits
    private func blockUser(userId: String, reason: String) async {
        print("🚫 SEARCH_RATE_LIMITER: blockUser called for userId: \(userId), reason: \(reason)")
        
        // Check if user is already blocked
        guard !blockedUsers.contains(userId) else {
            print("🚫 SEARCH_RATE_LIMITER: User \(userId) is already blocked, skipping")
            return
        }
        
        // Add to blocked users set
        blockedUsers.insert(userId)
        print("🚫 SEARCH_RATE_LIMITER: Added userId \(userId) to blockedUsers set. Total blocked: \(blockedUsers.count)")
        
        // Update local tracking
        if var userCount = userSearchCounts[userId] {
            userCount.isBlocked = true
            userCount.blockExpiry = Date().addingTimeInterval(cooldownPeriod)
            userSearchCounts[userId] = userCount
            print("🚫 SEARCH_RATE_LIMITER: Updated local tracking for userId \(userId) - isBlocked: true, blockExpiry: \(userCount.blockExpiry?.description ?? "nil")")
        } else {
            print("⚠️ SEARCH_RATE_LIMITER: No userCount found for userId \(userId) in local tracking")
        }
        
        // Log block to Firestore
        print("🚫 SEARCH_RATE_LIMITER: Logging user block to Firestore...")
        await logUserBlock(userId: userId, reason: reason)
        
        // Schedule unblock after cooldown period
        let unblockTime = Date().addingTimeInterval(cooldownPeriod)
        print("🚫 SEARCH_RATE_LIMITER: Scheduling unblock for userId \(userId) at: \(unblockTime)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownPeriod) {
            print("🚫 SEARCH_RATE_LIMITER: Executing scheduled unblock for userId \(userId)")
            self.unblockUser(userId: userId)
        }
        
        print("🚫 SEARCH_RATE_LIMITER: User \(userId) blocked successfully for reason: \(reason)")
    }
    
    /// Unblocks a user after cooldown period
    private func unblockUser(userId: String) {
        print("🔓 SEARCH_RATE_LIMITER: unblockUser called for userId: \(userId)")
        
        // Remove from blocked users set
        let wasBlocked = blockedUsers.contains(userId)
        blockedUsers.remove(userId)
        print("🔓 SEARCH_RATE_LIMITER: Removed userId \(userId) from blockedUsers set. Was blocked: \(wasBlocked), Total blocked: \(blockedUsers.count)")
        
        if var userCount = userSearchCounts[userId] {
            userCount.isBlocked = false
            userCount.blockExpiry = nil
            userSearchCounts[userId] = userCount
            print("🔓 SEARCH_RATE_LIMITER: Updated local tracking for userId \(userId) - isBlocked: false, blockExpiry: nil")
        } else {
            print("⚠️ SEARCH_RATE_LIMITER: No userCount found for userId \(userId) in local tracking during unblock")
        }
        
        print("🔓 SEARCH_RATE_LIMITER: User \(userId) unblocked successfully")
    }
    
    /// Logs search attempts to Firestore for monitoring
    private func logSearchAttempt(userId: String, allowed: Bool, reason: String? = nil) async {
        let logData: [String: Any] = [
            "userId": userId,
            "timestamp": FieldValue.serverTimestamp(),
            "allowed": allowed,
            "reason": reason ?? "",
            "userAgent": getUserAgent(),
            "ipAddress": await getCurrentIPAddress()
        ]
        
        do {
            let logsRef = db.collection("searchLogs")
            try await logsRef.addDocument(data: logData)
        } catch {
            print("Failed to log search attempt: \(error)")
        }
    }
    
    /// Logs user blocks to Firestore for monitoring
    private func logUserBlock(userId: String, reason: String) async {
        let blockData: [String: Any] = [
            "userId": userId,
            "timestamp": FieldValue.serverTimestamp(),
            "reason": reason,
            "blockExpiry": Date().addingTimeInterval(cooldownPeriod),
            "userAgent": getUserAgent(),
            "ipAddress": await getCurrentIPAddress()
        ]
        
        do {
            let blocksRef = db.collection("userBlocks")
            try await blocksRef.addDocument(data: blockData)
        } catch {
            print("Failed to log user block: \(error)")
        }
    }
    
    /// Gets current user agent for logging
    private func getUserAgent() -> String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        return "PodWebBlueprint/\(appVersion) (\(device.systemName) \(device.systemVersion))"
    }
    
    /// Gets current IP address for logging (placeholder)
    private func getCurrentIPAddress() async -> String {
        // This would make an API call to get the current IP
        // For now, return placeholder
        return "unknown"
    }
    
    // MARK: - Monitoring and Analytics
    
    /// Gets search statistics for monitoring
    func getSearchStats() -> [String: Any] {
        let totalUsers = userSearchCounts.count
        let blockedUsersCount = blockedUsers.count
        let totalSearches = userSearchCounts.values.reduce(0) { $0 + $1.searchesPerDay }
        
        return [
            "totalUsers": totalUsers,
            "blockedUsers": blockedUsersCount,
            "totalSearches": totalSearches,
            "timestamp": Date()
        ]
    }
    
    /// Clears old search data (call periodically)
    func cleanupOldData() {
        let cutoffDate = Date().addingTimeInterval(-86400) // 24 hours ago
        
        userSearchCounts = userSearchCounts.filter { _, userCount in
            userCount.lastSearchTime > cutoffDate
        }
    }
}

// MARK: - Singleton Access

extension SearchRateLimiter {
    static let shared = SearchRateLimiter()
}
