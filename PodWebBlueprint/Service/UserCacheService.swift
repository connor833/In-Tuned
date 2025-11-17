//
//  UserCacheService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/25/25.
//

import Foundation
import SwiftUI
import Firebase

/// A shared service for caching user data to prevent redundant backend calls
class UserCacheService: ObservableObject {
    static let shared = UserCacheService()
    
    // MARK: - Published Properties
    @Published var cachedUsers: [String: User] = [:]
    
    // MARK: - Private Properties
    private let userService = UserService()
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [String: Date] = [:]
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get user data from cache or fetch if not available/expired
    /// - Parameters:
    ///   - userId: The user ID to fetch
    ///   - completion: Completion handler with the user data
    func getUser(userId: String, completion: @escaping (User?) -> Void) {
        // Check if we have cached data
        if let cachedUser = cachedUsers[userId],
           let timestamp = cacheTimestamps[userId],
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            print("🔍 UserCacheService: Using cached user: \(cachedUser.username) (cached \(Int(Date().timeIntervalSince(timestamp)))s ago)")
            completion(cachedUser)
            return
        }
        
        // Check if cache is expired
        if let timestamp = cacheTimestamps[userId],
           Date().timeIntervalSince(timestamp) >= cacheTimeout {
            print("🔍 UserCacheService: Cache expired for user \(userId), fetching fresh data")
            cachedUsers.removeValue(forKey: userId)
            cacheTimestamps.removeValue(forKey: userId)
        }
        
        // Fetch fresh data
        print("🔍 UserCacheService: Fetching user data for: \(userId)")
        userService.fetchUser(withUid: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.cachedUsers[userId] = user
                    self?.cacheTimestamps[userId] = Date()
                    print("✅ UserCacheService: Cached user: \(user.username)")
                    completion(user)
                case .failure(let error):
                    print("❌ UserCacheService: Failed to fetch user \(userId): \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
    
    /// Preload multiple users at once
    /// - Parameters:
    ///   - userIds: Array of user IDs to preload
    ///   - completion: Completion handler when all users are loaded
    func preloadUsers(userIds: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        for userId in userIds {
            group.enter()
            getUser(userId: userId) { _ in
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
    
    /// Clear cache for a specific user
    /// - Parameter userId: The user ID to clear from cache
    func clearUserCache(userId: String) {
        cachedUsers.removeValue(forKey: userId)
        cacheTimestamps.removeValue(forKey: userId)
        print("🧹 UserCacheService: Cleared cache for user: \(userId)")
    }
    
    /// Clear all cached data
    func clearAllCache() {
        cachedUsers.removeAll()
        cacheTimestamps.removeAll()
        print("🧹 UserCacheService: Cleared all user cache")
    }
    
    /// Check if a user is cached and fresh
    /// - Parameter userId: The user ID to check
    /// - Returns: True if user is cached and not expired
    func isUserCached(userId: String) -> Bool {
        guard let timestamp = cacheTimestamps[userId] else { return false }
        return Date().timeIntervalSince(timestamp) < cacheTimeout
    }
}
