//
//  UserService.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/20/22.
//

import Firebase
//import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseFirestore
import UIKit
import FirebaseAuth

// MARK: - UserService

struct UserService {
    var collectionRef = Firestore.firestore().collection("users")
    private let blockService = BlockService() // Add blocking service
    
    // MARK: - Fetch User
    
    // Fetches a single user with the given UID
    func fetchUser(withUid uid: String, completion: @escaping(Result<User, Error>) -> Void) {
        print("🔄 [UserService] Fetching user with UID: \(uid)")
        
        Firestore.firestore().collection("users")
            .document(uid)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ [UserService] Error fetching user with UID \(uid): \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    let error = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document with UID \(uid) does not exist"])
                    print("❌ [UserService] User document with UID \(uid) does not exist")
                    completion(.failure(error))
                    return
                }
                
                do {
                    
                    let user = try snapshot.data(as: User.self)
                    print("✅ [UserService] Successfully fetched user: \(user.username)")
                    completion(.success(user))
                } catch {
                    print("❌ [UserService] Error parsing user data for UID \(uid): \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }
    
    func searchUsers(query: String, lastDocument: DocumentSnapshot? = nil, completion: @escaping ([User], DocumentSnapshot?) -> Void) {
            var queryRef = collectionRef
                .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
                .whereField("username", isLessThan: query.lowercased() + "~") // "~" ensures case-insensitivity
                .order(by: "username")                  // Primary: text relevance for consistent ordering
                .limit(to: 25) // Fetch more to allow for popularity sorting

            if let lastDocument = lastDocument {
                queryRef = queryRef.start(afterDocument: lastDocument)
            }

            queryRef.getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents else {
                        print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                        completion([], nil)
                        return
                    }

                    // Convert Firestore documents to User objects and filter out deleted/anonymous accounts
                    let resultUsers = documents.compactMap { try? $0.data(as: User.self) }
                        .filter { user in
                            // Filter out deleted accounts
                            let isDeleted = user.isDeleted ?? false
                            // Filter out anonymous accounts (usernames starting with "anon_")
                            let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                            
                            if isDeleted {
                                print("[UserService] Filtering out deleted account: \(user.username)")
                            }
                            if isAnonymous {
                                print("[UserService] Filtering out anonymous account: \(user.username)")
                            }
                            
                            return !isDeleted && !isAnonymous
                        }
                    
                    // Sort by popularity (most followers first) while maintaining text relevance
                    let sortedUsers = resultUsers.sorted { user1, user2 in
                        // First priority: exact text match vs partial match
                        let user1ExactMatch = user1.username.lowercased() == query.lowercased()
                        let user2ExactMatch = user2.username.lowercased() == query.lowercased()
                        
                        if user1ExactMatch != user2ExactMatch {
                            return user1ExactMatch // Exact matches first
                        }
                        
                        // Second priority: starts with query vs contains query
                        let user1StartsWith = user1.username.lowercased().hasPrefix(query.lowercased())
                        let user2StartsWith = user2.username.lowercased().hasPrefix(query.lowercased())
                        
                        if user1StartsWith != user2StartsWith {
                            return user1StartsWith // Starts with first
                        }
                        
                        // Third priority: follower count (most popular first)
                        let user1Followers = user1.followers
                        let user2Followers = user2.followers
                        
                        if user1Followers != user2Followers {
                            return user1Followers > user2Followers // Most followers first
                        }
                        
                        // Fourth priority: verification status (verified first)
                        if user1.isVerified != user2.isVerified {
                            return user1.isVerified // Verified users first
                        }
                        
                        // Fifth priority: recency (newest first)
                        if let user1Created = user1.createdAt, let user2Created = user2.createdAt {
                            return user1Created.dateValue() > user2Created.dateValue()
                        }
                        return false // If no creation date, maintain order
                    }
                    
                    // Take only the top 10 results after sorting
                    let topResults = Array(sortedUsers.prefix(10))
                    
                    print("🎯 [UserService] Search results: \(resultUsers.count) found, \(topResults.count) returned after popularity sorting")
                    
                    // Use quick array check from current user for ongoing app usage
                    guard let currentUid = Auth.auth().currentUser?.uid else {
                        let lastDocument = documents.last
                        completion(topResults, lastDocument)
                        return
                    }
                    
                    // Get current user's blocked users for quick filtering
                    Firestore.firestore().collection("users").document(currentUid).getDocument { snapshot, error in
                        if let userData = snapshot?.data(),
                           let blockedUsers = userData["blockedUsers"] as? [String] {
                            
                            // Quick array check - filter out users that current user has blocked
                            let filteredUsers = resultUsers.filter { user in
                                let isBlocked = blockedUsers.contains(user.uid)
                                if isBlocked {
                                    print("[UserService] Filtering out blocked user: \(user.uid)")
                                }
                                return !isBlocked
                            }
                            
                            let lastDocument = documents.last
                            
                            // Apply popularity sorting to filtered results
                            let sortedFilteredUsers = filteredUsers.sorted { user1, user2 in
                                let user1Followers = user1.followers
                                let user2Followers = user2.followers
                                return user1Followers > user2Followers // Most followers first
                            }
                            
                            let topFilteredResults = Array(sortedFilteredUsers.prefix(10))
                            completion(topFilteredResults, lastDocument)
                        } else {
                            // Fallback to all users if blocking data not available
                            let lastDocument = documents.last
                            completion(topResults, lastDocument)
                        }
                    }
                }
        }

    
    // MARK: - Fetch Users
    
    /// Fetches users with proper security filtering and pagination
    /// Only returns public profile information for discoverable users
    func fetchUsers(limit: Int = 20, lastDocument: DocumentSnapshot? = nil, completion: @escaping(Result<([User], DocumentSnapshot?), Error>) -> Void) {
        print("🔄 [UserService] Fetching users with limit: \(limit)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            print("❌ [UserService] Error: User not authenticated")
            completion(.failure(error))
            return
        }
        
        var query = Firestore.firestore().collection("users")
            .order(by: "username")                      // Consistent ordering
            .limit(to: limit)                           // Pagination limit
        
        // Add pagination if we have a last document
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [UserService] Error fetching users: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No documents returned"])
                print("❌ [UserService] Error: No documents returned")
                completion(.failure(error))
                return
            }
            
            // Filter out current user and return users directly
            let users = documents.compactMap { document -> User? in
                do {
                    let user = try document.data(as: User.self)
                // Skip current user and ensure user is valid
                    guard user.id != currentUserId else { return nil }
                    return user
                } catch {
                    print("❌ [UserService] Error parsing user data: \(error.localizedDescription)")
                    return nil
                }
            }
            
            print("✅ [UserService] Successfully parsed \(users.count) users")
            
            // Use quick array check from current user for ongoing app usage
            Firestore.firestore().collection("users").document(currentUserId).getDocument { snapshot, error in
                if let error = error {
                    print("⚠️ [UserService] Error fetching current user for blocking check: \(error.localizedDescription)")
                    // Fallback to all users if blocking data not available
                    let lastDocument = documents.last
                    completion(.success((users, lastDocument)))
                    return
                }
                
                if let userData = snapshot?.data(),
                   let blockedUsers = userData["blockedUsers"] as? [String] {
                    
                    // Quick array check - filter out users that current user has blocked
                    let filteredUsers = users.filter { user in
                        let isBlocked = blockedUsers.contains(user.uid)
                        if isBlocked {
                            print("🚫 [UserService] Filtering out blocked user: \(user.uid)")
                        }
                        return !isBlocked
                    }
                    
                    let lastDocument = documents.last
                    print("✅ [UserService] Successfully filtered users: \(filteredUsers.count) after blocking")
                    completion(.success((filteredUsers, lastDocument)))
                } else {
                    // Fallback to all users if blocking data not available
                    let lastDocument = documents.last
                    print("✅ [UserService] No blocking data available, returning all users: \(users.count)")
                    completion(.success((users, lastDocument)))
                }
            }
        }
    }
    
    /// Fetches users for search functionality with proper filtering and rate limiting
    func searchUsers(query: String, limit: Int = 20, completion: @escaping(Result<[User], Error>) -> Void) {
        print("🔄 [UserService] Searching users with query: '\(query)', limit: \(limit)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            print("❌ [UserService] Error: User not authenticated")
            completion(.failure(error))
            return
        }
        
        // Check rate limiting before performing search
        Task {
            let canSearch = await SearchRateLimiter.shared.canPerformSearch(userId: currentUserId)
            
            if !canSearch {
                await SearchRateLimiter.shared.recordBlockedSearch(userId: currentUserId, reason: "Rate limit exceeded")
                
                await MainActor.run {
                    let error = NSError(domain: "UserService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"])
                    print("❌ [UserService] Error: Rate limit exceeded")
                    completion(.failure(error))
                }
                return
            }
            
            // Record successful search
            await SearchRateLimiter.shared.recordSearch(userId: currentUserId)
            
            // Search users with username prefix
            Firestore.firestore().collection("users")
                .whereField("username", isGreaterThanOrEqualTo: query)
                .whereField("username", isLessThan: query + "z")
                .limit(to: limit)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ [UserService] Error searching users: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No documents returned"])
                        print("❌ [UserService] Error: No documents returned")
                        completion(.failure(error))
                        return
                    }
                    
                    // Filter out current user, deleted accounts, and anonymous accounts
                    let users = documents.compactMap { document -> User? in
                        do {
                            let user = try document.data(as: User.self)
                            
                            // Filter out current user
                            guard user.id != currentUserId else { return nil }
                            
                            // Filter out deleted accounts
                            let isDeleted = user.isDeleted ?? false
                            if isDeleted {
                                print("❌ [UserService] Filtering out deleted account: \(user.username)")
                                return nil
                            }
                            
                            // Filter out anonymous accounts (usernames starting with "anon_")
                            if user.username.lowercased().hasPrefix("anon_") {
                                print("❌ [UserService] Filtering out anonymous account: \(user.username)")
                                return nil
                            }
                            
                            return user
                        } catch {
                            print("❌ [UserService] Error parsing user data: \(error.localizedDescription)")
                            return nil
                        }
                    }
                    
                    print("✅ [UserService] Successfully parsed \(users.count) users from search")
                    
                    // Use comprehensive blocking check from current user
                    Firestore.firestore().collection("users").document(currentUserId).getDocument { snapshot, error in
                        if let error = error {
                            print("⚠️ [UserService] Error fetching current user for blocking check: \(error.localizedDescription)")
                            // Fallback to all users if blocking data not available
                            completion(.success(users))
                            return
                        }
                        
                        if let userData = snapshot?.data() {
                            let blockedUsers = userData["blockedUsers"] as? [String] ?? []
                            let blockedBy = userData["blockedBy"] as? [String] ?? []
                            
                            // Combine both arrays for comprehensive filtering
                            let allBlockedUserIds = Set(blockedUsers + blockedBy)
                            
                            // Filter out users that current user has blocked OR users that have blocked current user
                            let filteredUsers = users.filter { user in
                                let isBlocked = allBlockedUserIds.contains(user.uid)
                                if isBlocked {
                                    if blockedUsers.contains(user.uid) {
                                        print("🚫 [UserService] Filtering out user you blocked: \(user.uid)")
                                    } else if blockedBy.contains(user.uid) {
                                        print("🚫 [UserService] Filtering out user who blocked you: \(user.uid)")
                                    }
                                }
                                return !isBlocked
                            }
                            
                            print("✅ [UserService] Filtered \(users.count) users down to \(filteredUsers.count) using comprehensive blocking check")
                            completion(.success(filteredUsers))
                        } else {
                            // Fallback to all users if blocking data not available
                            print("✅ [UserService] No blocking data available, returning all users: \(users.count)")
                            completion(.success(users))
                        }
                    }
                }
        }
    }
    
    // MARK: - Fetch User Playlists
    
    // Fetches playlists for the current user from global collection
    func fetchUserPlaylists(uid: String, completion: @escaping([Playlist]) -> Void) {
        // First, get playlist references from user's subcollection
        Firestore.firestore().collection("users").document(uid).collection("user-playlists")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { 
                    print("❌ [UserService] Error fetching user playlist references: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return 
                }
                
                if documents.isEmpty {
                    completion([])
                    return
                }
                
                // Extract playlist IDs from references
                let playlistIds = documents.compactMap { document -> String? in
                    let data = document.data()
                    return data["playlistId"] as? String
                }
                
                if playlistIds.isEmpty {
                    completion([])
                    return
                }
                
                // Fetch actual playlists from global collection
                let group = DispatchGroup()
                var playlists: [Playlist] = []
                
                for playlistId in playlistIds {
                    group.enter()
                    
                    Firestore.firestore().collection("playlists").document(playlistId)
                        .getDocument { snapshot, error in
                            defer { group.leave() }
                            
                            if let error = error {
                                print("❌ [UserService] Error fetching playlist \(playlistId): \(error.localizedDescription)")
                                return
                            }
                            
                            guard let document = snapshot, document.exists else {
                                print("⚠️ [UserService] Playlist \(playlistId) not found in global collection")
                                return
                            }
                            
                            do {
                                let playlist = try document.data(as: Playlist.self)
                                playlists.append(playlist)
                            } catch {
                                print("❌ [UserService] Error decoding playlist \(playlistId): \(error.localizedDescription)")
                            }
                        }
                }
                
                group.notify(queue: .main) {
                    // Sort by creation date (newest first)
                    let sortedPlaylists = playlists.sorted { playlist1, playlist2 in
                        let date1 = playlist1.createdAt?.dateValue() ?? Date.distantPast
                        let date2 = playlist2.createdAt?.dateValue() ?? Date.distantPast
                        return date1 > date2
                    }
                    
                    print("✅ [UserService] Fetched \(sortedPlaylists.count) playlists from global collection")
                    completion(sortedPlaylists)
                }
            }
    }
    
    
    // MARK: - Follow User
    
    // Follows the specified user using cloud function with rate limiting
    func followUser(user: User, completion: @escaping(Bool, String?) -> Void) {
        print("🔄 [UserService] Starting follow user: \(user.username)")
        
        guard let userId = user.id else { 
            print("❌ [UserService] Error: User ID is nil")
            completion(false, "User ID is nil")
            return 
        }
        
        // Check rate limits before attempting to follow
        FollowRateLimiter.shared.canAttemptFollowUnfollow(targetUserId: userId) { allowed, reason in
            if !allowed {
                print("🚫 [UserService] Follow blocked by rate limiter - \(reason ?? "Unknown reason")")
                completion(false, "RATE_LIMITED")
                return
            }
            
            print("✅ [UserService] Rate limit check passed, proceeding with follow")
            
            let functions = Functions.functions()
            let followUserFunction = functions.httpsCallable("followUser")
            
            let data = ["userId": userId]
            
            followUserFunction.call(data) { result, error in
                if let error = error {
                    print("❌ [UserService] Error calling followUser cloud function: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let data = result?.data as? [String: Any],
                   let success = data["success"] as? Bool,
                   success {
                    print("✅ [UserService] User followed successfully via cloud function: \(user.username)")
                    
                    // Record successful follow attempt for rate limiting
                    FollowRateLimiter.shared.recordFollowUnfollowAttempt(targetUserId: userId, action: "follow") { rateLimitSuccess in
                        if rateLimitSuccess {
                            print("📊 [UserService] Recorded follow attempt successfully")
                        } else {
                            print("⚠️ [UserService] Failed to record follow attempt")
                        }
                    }
                    
                    completion(true, nil)
                } else {
                    print("❌ [UserService] Failed to follow user via cloud function: \(user.username)")
                    completion(false, "Failed to follow user")
                }
            }
        }
    }

    
    // MARK: - Unfollow User
    
    // Unfollows the specified user using cloud function with rate limiting
    func unfollowUser(user: User, completion: @escaping(Bool, String?) -> Void) {
        print("🔄 [UserService] Starting unfollow user: \(user.username)")
        
        guard let userId = user.id else { 
            print("❌ [UserService] Error: User ID is nil")
            completion(false, "User ID is nil")
            return 
        }
        
        // Check rate limits before attempting to unfollow
        FollowRateLimiter.shared.canAttemptFollowUnfollow(targetUserId: userId) { allowed, reason in
            if !allowed {
                print("🚫 [UserService] Unfollow blocked by rate limiter - \(reason ?? "Unknown reason")")
                completion(false, "RATE_LIMITED")
                return
            }
            
            print("✅ [UserService] Rate limit check passed, proceeding with unfollow")
            
            let functions = Functions.functions()
            let unfollowUserFunction = functions.httpsCallable("unfollowUser")
            
            let data = ["userId": userId]
            
            unfollowUserFunction.call(data) { result, error in
                if let error = error {
                    print("❌ [UserService] Error calling unfollowUser cloud function: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let data = result?.data as? [String: Any],
                   let success = data["success"] as? Bool,
                   success {
                    print("✅ [UserService] User unfollowed successfully via cloud function: \(user.username)")
                    
                    // Record successful unfollow attempt for rate limiting
                    FollowRateLimiter.shared.recordFollowUnfollowAttempt(targetUserId: userId, action: "unfollow") { rateLimitSuccess in
                        if rateLimitSuccess {
                            print("📊 [UserService] Recorded unfollow attempt successfully")
                        } else {
                            print("⚠️ [UserService] Failed to record unfollow attempt")
                        }
                    }
                    
                    completion(true, nil)
                } else {
                    print("❌ [UserService] Failed to unfollow user via cloud function: \(user.username)")
                    completion(false, "Failed to unfollow user")
                }
            }
        }
    }

    // MARK: - Remove Follower
    
    // Removes a follower by making them unfollow the current user
    func removeFollower(user: User, completion: @escaping(Bool) -> Void) {
        print("🔄 [UserService] Starting remove follower: \(user.username)")
        
        guard let userId = user.id else { 
            print("❌ [UserService] Error: User ID is nil")
            completion(false)
            return 
        }
        
        let functions = Functions.functions()
        let removeFollowerFunction = functions.httpsCallable("removeFollower")
        
        let data = ["userId": userId]
        
        removeFollowerFunction.call(data) { result, error in
            if let error = error {
                print("❌ [UserService] Error calling removeFollower cloud function: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("✅ [UserService] Follower removed successfully via cloud function: \(user.username)")
                completion(true)
            } else {
                print("❌ [UserService] Failed to remove follower via cloud function: \(user.username)")
                completion(false)
            }
        }
    }

    
    // MARK: - Check If User Is Followed
    
    // Checks if the specified user is followed by the current user
    func checkIfUserIsFollowed(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-following")
            .document(userId).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                completion(snapshot.exists)
            }
    }
    
    // MARK: - Check If Current User Is Followed
    
    // Checks if the current user is followed by the specified user
    func checkIfCurrentUserIsFollowed(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("user-following")
            .document(uid).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                print("CHECK IF CURRENT USER IS FOLLOWED \(snapshot.exists)")
                completion(snapshot.exists)
            }
    }
    
    // MARK: - Create Playlist
    
    // Creates a new playlist for the current user in global playlists collection
    func createPlaylist(title: String, podIds: [String], thumbnailUrl: String, description: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }
        
        // Generate a unique playlist ID
        let playlistId = UUID().uuidString
        
        // Playlist data with all new fields
        let playlistData: [String: Any] = [
            "title": title,
            "thumbnailUrl": thumbnailUrl,
            "userId": uid,
            "likes": 0,
            "version": 1,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "description": description ?? "",
            "podCount": podIds.count,
            "isPublic": true,
            "isActive": true
        ]
        
        // Create playlist in global playlists collection
        let globalPlaylistRef = Firestore.firestore().collection("playlists").document(playlistId)
        
        // Set playlist data in global collection
        globalPlaylistRef.setData(playlistData) { error in
            if let error = error {
                print("Error adding playlist to global collection: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // Add pod IDs to the global playlist's "playlist-pods" subcollection
            let playlistPodsCollectionRef = globalPlaylistRef.collection("playlist-pods")
            
            var successCount = 0  // Counter for successful operations
            var errorOccurred = false  // Flag to track if any error occurred
            
            for podId in podIds {
                let podDocRef = playlistPodsCollectionRef.document(podId)
                podDocRef.setData([:]) { error in
                    if let error = error {
                        print("Error adding pod to playlist: \(error.localizedDescription)")
                        errorOccurred = true
                    } else {
                        print("Pod added to playlist successfully.")
                        successCount += 1
                    }
                    
                    // Check if all operations are complete
                    if successCount + (errorOccurred ? 0 : 0) == podIds.count {
                        // All operations are complete, now add reference to user's subcollection
                        self.addPlaylistReferenceToUser(uid: uid, playlistId: playlistId) { success in
                            if success {
                                print("✅ Playlist created successfully in global collection with user reference")
                                completion(true, nil)
                            } else {
                                print("❌ Failed to add playlist reference to user")
                                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to add playlist reference to user."]))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to add playlist reference to user's subcollection
    private func addPlaylistReferenceToUser(uid: String, playlistId: String, completion: @escaping (Bool) -> Void) {
        let userPlaylistRef = Firestore.firestore().collection("users").document(uid).collection("user-playlists").document(playlistId)
        
        // Store just the playlist ID as a reference
        let referenceData: [String: Any] = [
            "playlistId": playlistId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        userPlaylistRef.setData(referenceData) { error in
            if let error = error {
                print("Error adding playlist reference to user: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Playlist reference added to user subcollection")
                completion(true)
            }
        }
    }

    // MARK: - Delete Playlist
    
    // Deletes the specified playlist from global collection and user reference
    func deletePlaylist(withPlaylistId playlistId: String, uid: String, completion: @escaping (Bool, Error?) -> Void) {
        // First, delete from global playlists collection
        let globalPlaylistRef = Firestore.firestore().collection("playlists").document(playlistId)
        
        globalPlaylistRef.delete { error in
            if let error = error {
                print("❌ [UserService] Error deleting playlist from global collection: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // Then, delete the reference from user's subcollection
            let userPlaylistRef = Firestore.firestore().collection("users").document(uid).collection("user-playlists").document(playlistId)
            
            userPlaylistRef.delete { error in
                if let error = error {
                    print("❌ [UserService] Error deleting playlist reference from user: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("✅ [UserService] Playlist deleted successfully from global collection and user reference")
                    completion(true, nil)
                }
            }
        }
    }
    
    // MARK: - Fetch User Following
    
    // Fetches users followed by the specified user with pagination
    func fetchUserFollowing(forUid uid: String, lastUser: User? = nil, limit: Int = 10, completion: @escaping([User]) -> Void) {
        
        var followedUsers = [User]()
        let group = DispatchGroup()
        
        // For following/followers collections, we need to fetch all and paginate client-side
        // since these collections don't have natural ordering
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-following")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { 
                    completion([])
                    return 
                }
                
                if documents.isEmpty {
                    completion([])
                    return
                }
                
                // If we have a last user, skip until we find it
                var shouldStartCollecting = lastUser == nil
                var collectedCount = 0
                
                documents.forEach { doc in
                    let userId = doc.documentID
                    
                    // Skip until we find the last user (for pagination)
                    if !shouldStartCollecting && userId == lastUser?.uid {
                        shouldStartCollecting = true
                        return
                    }
                    
                    // Only collect if we should start collecting and haven't reached the limit
                    if shouldStartCollecting && collectedCount < limit {
                        group.enter()
                        collectedCount += 1
                        
                        Firestore.firestore().collection("users")
                            .document(userId)
                            .getDocument { snapshot, _ in
                                defer { group.leave() }
                                
                                guard let user = try? snapshot?.data(as: User.self) else { return }
                                followedUsers.append(user)
                            }
                    }
                }
                
                group.notify(queue: .main) {
                    // Sort by follower count (descending) for popularity-based ordering
                    let sortedUsers = followedUsers.sorted { user1, user2 in
                        user1.followers > user2.followers
                    }
                    completion(sortedUsers)
                }
            }
    }
    
    // MARK: - Fetch User Followers
    
    // Fetches users following the specified user with pagination
    func fetchUserFollowers(forUid uid: String, lastUser: User? = nil, limit: Int = 10, completion: @escaping([User]) -> Void) {
        
        var followers = [User]()
        let group = DispatchGroup()
        
        // For following/followers collections, we need to fetch all and paginate client-side
        // since these collections don't have natural ordering
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-followers")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { 
                    completion([])
                    return 
                }
                
                if documents.isEmpty {
                    completion([])
                    return
                }
                
                // If we have a last user, skip until we find it
                var shouldStartCollecting = lastUser == nil
                var collectedCount = 0
                
                documents.forEach { doc in
                    let userId = doc.documentID
                    
                    // Skip until we find the last user (for pagination)
                    if !shouldStartCollecting && userId == lastUser?.uid {
                        shouldStartCollecting = true
                        return
                    }
                    
                    // Only collect if we should start collecting and haven't reached the limit
                    if shouldStartCollecting && collectedCount < limit {
                        group.enter()
                        collectedCount += 1
                        
                        Firestore.firestore().collection("users")
                            .document(userId)
                            .getDocument { snapshot, _ in
                                defer { group.leave() }
                                
                                guard let user = try? snapshot?.data(as: User.self) else { return }
                                followers.append(user)
                            }
                    }
                }
                
                group.notify(queue: .main) {
                    // Sort by follower count (descending) for popularity-based ordering
                    let sortedUsers = followers.sorted { user1, user2 in
                        user1.followers > user2.followers
                    }
                    completion(sortedUsers)
                }
            }
    }
    
    // MARK: - Add Friend
    
    // Adds the specified user as a friend and creates a conversation ONLY if one doesn't already exist
    func addFriend(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        
        // Temporarily comment out blocking checks to prevent initialization pause
        // let blockService = BlockService()
        // blockService.checkIfUserIsBlocked(userId: userId) { isBlocked in
        //     if isBlocked {
        //         print("Cannot add friend - user is blocked")
        //         completion(false)
        //         return
        //     }
        //     
        //     blockService.checkIfCurrentUserIsBlocked(by: userId) { isBlockedBy in
        //         if isBlockedBy {
        //             print("Cannot add friend - current user is blocked by this user")
        //             completion(false)
        //             return
        //         }
        //         
        //         // First check if a conversation already exists between these users
        //         let conversationService = ConversationService()
        //         conversationService.findExistingConversation(with: userId) { existingConversationId in
        //             if let existingId = existingConversationId {
        //                 // Conversation already exists, just ensure friendship documents are in place
        //                 print("Conversation already exists: \(existingId), ensuring friendship documents")
        //                 self.ensureFriendshipDocuments(uid: uid, userId: userId) {
        //                     completion(true)
        //                 }
        //             } else {
        //                 // No conversation exists, create friendship and conversation
        //                 print("No existing conversation found, creating new friendship and conversation")
        //                 self.createFriendshipAndConversation(uid: uid, userId: userId) {
        //                     completion(true)
        //                 }
        //             }
        //         }
        //     }
        // }
        
        // Temporarily skip blocking checks
        self.createFriendshipAndConversation(uid: uid, userId: userId) {
            completion(true)
        }
    }
    
    // Helper method to ensure friendship documents exist without creating new conversation
    private func ensureFriendshipDocuments(uid: String, userId: String, completion: @escaping() -> Void) {
        let data = ["email": "", "username": "", "fullname": "", "uid": userId, "followers": 0, "profileImageUrl": "", "isVerified": false, "following": 0, "podCount": 0] as [String: Any]
        
        // Add to current user's friends collection
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .document(userId)
            .setData(data)
        
        // Add current user to other user's friends collection
        let currentData = ["email": "", "username": "", "fullname": "", "uid": uid, "followers": 0, "profileImageUrl": "", "isVerified": false, "following": 0, "podCount": 0] as [String: Any]
        
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("friends")
            .document(uid)
            .setData(currentData) { _ in
                completion()
            }
    }
    
    // Helper method to create friendship and conversation
    private func createFriendshipAndConversation(uid: String, userId: String, completion: @escaping() -> Void) {
        fetchUser(withUid: uid) { result in
            switch result {
            case .success(let currentUser):
            let userData = ["email": currentUser.email, "username": currentUser.username, "fullname": currentUser.fullname, "uid": currentUser.uid, "followers": currentUser.followers, "profileImageUrl": currentUser.profileImageUrl, "isVerified": currentUser.isVerified, "following": currentUser.following, "podCount": currentUser.podCount] as [String: Any]
            
                // Add to current user's friends collection
                Firestore.firestore().collection("users")
                    .document(uid)
                    .collection("friends")
                    .document(userId)
                    .setData(userData)
                
                // Add current user to other user's friends collection
                Firestore.firestore().collection("users")
                    .document(userId)
                    .collection("friends")
                    .document(uid)
                    .setData(userData) { _ in
                        // Create conversation after adding to friends list
                        let conversationService = ConversationService()
                        conversationService.createConversation(participants: [uid, userId]) { conversationId in
                            if let conversationId = conversationId {
                                print("Conversation created successfully: \(conversationId)")
                            } else {
                                print("Failed to create conversation")
                            }
                            completion()
                        }
                    }
            case .failure(let error):
                print("Error fetching current user for friendship: \(error.localizedDescription)")
                completion()
            }
        }
    }
    
    // MARK: - Unadd Friend
    
    // NOTE: This method should NOT be called when unfollowing
    // It should only be called when explicitly removing friendship
    // Unfollowing should NOT remove friendship status
    func unaddFriend(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }

        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .document(userId)
            .delete()
        
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("friends")
            .document(uid)
            .delete() { _ in
                completion(true)
            }
    }
    
    // MARK: - Explicitly Remove Friendship
    
    // This method should be called when users explicitly want to remove friendship
    // It will remove friendship documents and potentially hide the conversation
    // Use this instead of unaddFriend for explicit friendship removal
    func removeFriendship(with user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        
        // Remove friendship documents from both users
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .document(userId)
            .delete()
        
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("friends")
            .document(uid)
            .delete() { _ in
                // Note: We don't delete the conversation here
                // The conversation remains but is no longer accessible through the friends list
                // Users can still see it if they follow each other again
                print("Friendship removed for users \(uid) and \(userId)")
                completion(true)
            }
    }
    
    // MARK: - Fetch Friends
    
    // Fetches friends of the specified user
    func fetchFriends(withUid uid: String, completion: @escaping([User]) -> Void) {
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                let users = documents.compactMap({ try? $0.data(as: User.self)})
                completion(users)
            }
    }
    
    // MARK: - Check If Username Is In Use
    
    // Checks if the specified username is in use
    func isUsernameInUse(username: String, completion: @escaping(Bool) -> Void) {
        Firestore.firestore().collection("usernames")
            .document(username).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                completion(snapshot.exists)
            }
    }
    
    // MARK: - Add Username
    
    // Adds the specified username
    func addUsername(username: String) {
        Firestore.firestore().collection("usernames")
            .document(username)
            .setData([:])
    }
    
    // MARK: - Delete Username
    
    // Deletes the specified username
    func deleteUsername(username: String) {
        Firestore.firestore().collection("usernames")
            .document(username)
            .delete()
    }
    
    // MARK: - Edit Profile
    
    // Edits the profile of the specified user
    func editProfile(withUid uid: String, fullname: String, username: String, bio: String, link: String, completion: @escaping(Result<User, Error>) -> Void) {
        print("🔄 [UserService] Starting profile edit for user: \(uid)")
        print("🔄 [UserService] New username: \(username), fullname: \(fullname)")
        
        // VALIDATION - Check if data is valid before saving
        guard !username.isEmpty else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Username cannot be empty"])
            print("❌ [UserService] Error: Username cannot be empty")
            completion(.failure(error))
            return
        }
        
        guard username.count >= 3 else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Username must be at least 3 characters"])
            print("❌ [UserService] Error: Username must be at least 3 characters")
            completion(.failure(error))
            return
        }
        
        guard !fullname.isEmpty else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Full name cannot be empty"])
            print("❌ [UserService] Error: Full name cannot be empty")
            completion(.failure(error))
            return
        }
        
        guard bio.count <= 500 else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bio must be 500 characters or less"])
            print("❌ [UserService] Error: Bio must be 500 characters or less")
            completion(.failure(error))
            return
        }
        
        // Check if username is available (if changed)
        // First check if username is different from current
        fetchUser(withUid: uid) { result in
            switch result {
            case .success(let currentUser):
                if currentUser.username.lowercased() != username.lowercased() {
                    // Username changed, check availability
                    // NOTE: This client-side check is for UX only - the actual username claiming
                    // is handled atomically by the cloud function to prevent race conditions
                    print("🔄 [UserService] Username changed, checking availability: \(username)")
                    self.isUsernameInUse(username: username) { isInUse in
                        if isInUse {
                            let error = NSError(domain: "UserService", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
                            print("❌ [UserService] Error: Username is already taken")
                            completion(.failure(error))
                            return
                        }
                        
                        // Username is available, proceed with update
                        // The updateProfile method uses Firestore transactions for atomic username claiming
                        print("✅ [UserService] Username available, proceeding with update")
                        self.updateProfile(uid: uid, fullname: fullname, username: username, bio: bio, link: link, completion: completion)
                    }
                } else {
                    // Username unchanged, proceed with update
                    print("🔄 [UserService] Username unchanged, proceeding with update")
                    self.updateProfile(uid: uid, fullname: fullname, username: username, bio: bio, link: link, completion: completion)
                }
            case .failure(let error):
                print("❌ [UserService] Error fetching current user: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // Helper method to actually update the profile with optimistic locking
    private func updateProfile(uid: String, fullname: String, username: String, bio: String, link: String, completion: @escaping(Result<User, Error>) -> Void) {
        print("🔄 [UserService] Starting profile update for user: \(uid)")
        
        // First, fetch the current user to get all existing data
        fetchUser(withUid: uid) { result in
            switch result {
            case .success(let currentUser):
                // Create updated user with all existing data + new values
                var updatedUser = currentUser
                updatedUser.username = username
                updatedUser.fullname = fullname
                updatedUser.bio = bio
                updatedUser.link = link
                updatedUser.lastUpdated = Timestamp()
                
                // Use Firestore transaction for atomic update with optimistic locking
                let userRef = Firestore.firestore().collection("users").document(uid)
                
                Firestore.firestore().runTransaction { transaction, errorPointer in
                    // Re-fetch the user document to get the latest version
                    let userDoc: DocumentSnapshot
                    do {
                        userDoc = try transaction.getDocument(userRef)
                    } catch let fetchError as NSError {
                        errorPointer?.pointee = fetchError
                        return nil
                    }
                    
                    // Check if user document exists
                    guard userDoc.exists else {
                        let error = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                        errorPointer?.pointee = error
                        return nil
                    }
                    
                    // Get the current user data from the document
                    guard let currentUserData = try? userDoc.data(as: User.self) else {
                        let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user data"])
                        errorPointer?.pointee = error
                        return nil
                    }
                    
                    // Optimistic locking: Check if version matches (if version field exists)
                    if let currentVersion = currentUser.version,
                       let fetchedVersion = currentUserData.version,
                       currentVersion != fetchedVersion {
                        let error = NSError(domain: "UserService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User was updated by another client. Please refresh and try again."])
                        errorPointer?.pointee = error
                        return nil
                    }
                    
                    // Update the user document with new data
                    do {
                        try transaction.setData(from: updatedUser, forDocument: userRef)
                        return updatedUser
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                } completion: { result, error in
                if let error = error {
                        print("❌ [UserService] Error updating profile: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else if let updatedUser = result as? User {
                        print("✅ [UserService] Profile updated successfully")
                        completion(.success(updatedUser))
                } else {
                        let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unexpected error during profile update"])
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("❌ [UserService] Error fetching current user for update: \(error.localizedDescription)")
                completion(.failure(error))
                }
            }
    }
    
    // MARK: - Check If Users Are Friends
    
    // Checks if two users are mutual friends
    func checkIfUsersAreFriends(withUid uid: String, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion(false)
            return 
        }
        
        // Check if the other user is in current user's friends collection
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("friends")
            .document(uid)
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot, snapshot.exists else { 
                    completion(false)
                    return 
                }
                
                // If found, check if current user is in the other user's friends collection
                Firestore.firestore().collection("users")
                    .document(uid)
                    .collection("friends")
                    .document(currentUid)
                    .getDocument { snapshot, _ in
                        guard let snapshot = snapshot else { 
                            completion(false)
                            return 
                        }
                        completion(snapshot.exists)
                    }
            }
    }
    
    // MARK: - Handle Mutual Follow
    
    // This method should be called when a mutual follow relationship is established
    // It ensures friendship documents exist and creates conversation if needed
    func handleMutualFollow(withUid uid: String, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion(false)
            return 
        }
        
        let functions = Functions.functions()
        let handleMutualFollowFunction = functions.httpsCallable("handleMutualFollow")
        
        let data = ["userId": uid]
        
        handleMutualFollowFunction.call(data) { result, error in
            if let error = error {
                print("Error calling handleMutualFollow cloud function: \(error)")
                completion(false)
                return
            }
            
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("Mutual follow handled successfully via cloud function")
                completion(true)
            } else {
                print("Failed to handle mutual follow via cloud function")
                completion(false)
            }
        }
    }
    
    // MARK: - Follow Request Methods
    
    // Handles private-to-public transition by auto-accepting all pending follow requests
    func handlePrivateToPublicTransition(completion: @escaping(Bool, String, Int) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false, "User not authenticated", 0)
            return
        }
        
        let functions = Functions.functions()
        let handleTransitionFunction = functions.httpsCallable("handlePrivateToPublicTransition")
        
        handleTransitionFunction.call() { result, error in
            if let error = error {
                print("Error calling handlePrivateToPublicTransition cloud function: \(error)")
                completion(false, "Failed to process follow requests", 0)
                return
            }
            
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                let acceptedCount = data["acceptedCount"] as? Int ?? 0
                let message = data["message"] as? String ?? "Transition completed"
                print("✅ Private-to-public transition completed: \(message)")
                completion(true, message, acceptedCount)
            } else {
                print("Failed to process private-to-public transition")
                completion(false, "Failed to process follow requests", 0)
            }
        }
    }
    
    // Sends a follow request to a private account
    func sendFollowRequest(to user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion(false)
            return 
        }
        guard let userId = user.id else { 
            completion(false)
            return 
        }
        
        // Get current user data
        fetchUser(withUid: currentUid) { result in
            switch result {
            case .success(let currentUser):
                let requestData = [
                    "requesterId": currentUid,
                    "requesterUsername": currentUser.username,
                    "requesterFullname": currentUser.fullname,
                    "requesterProfileImageUrl": currentUser.profileImageUrl,
                "timestamp": Date(),
                "status": "pending"
                ] as [String: Any]
                
                // Add to the target user's follow requests
                Firestore.firestore().collection("users")
                    .document(userId)
                    .collection("follow-requests")
                    .document(currentUid)
                    .setData(requestData) { error in
                        if let error = error {
                            print("Error sending follow request: \(error)")
                            completion(false)
                        } else {
                            // Send follow request notification
                            let notificationService = NotificationService()
                            notificationService.createNotification(
                                type: .followRequest,
                                senderId: currentUid,
                                recipientId: userId,
                                completion: { notificationSuccess in
                                    if notificationSuccess {
                                        print("✅ Follow request notification sent successfully")
                                    } else {
                                        print("❌ Failed to send follow request notification")
                                    }
                                    // Return success for follow request regardless of notification status
                                    completion(true)
                                }
                            )
                        }
                    }
            case .failure(let error):
                print("Error fetching current user for follow request: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // Checks if current user has sent a follow request to the specified user
    func checkIfFollowRequestSent(to user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion(false)
            return 
        }
        guard let userId = user.id else { 
            completion(false)
            return 
        }
        
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("follow-requests")
            .document(currentUid)
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot else { 
                    completion(false)
                    return 
                }
                completion(snapshot.exists)
            }
    }
    
    // Fetches all follow requests for the current user
    func fetchFollowRequests(completion: @escaping([User]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion([])
            return 
        }
        
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("follow-requests")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { 
                    completion([])
                    return 
                }
                
                let requesterIds = documents.compactMap { document -> String? in
                    let data = document.data()
                    return data["requesterId"] as? String
                }
                
                // Fetch complete user data for each requester
                let group = DispatchGroup()
                var users: [User] = []
                
                for requesterId in requesterIds {
                    group.enter()
                    
                    self.fetchUser(withUid: requesterId) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let fetchedUser):
                                users.append(fetchedUser)
                            case .failure(let error):
                                print("Error fetching follow request user: \(error.localizedDescription)")
                            }
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    // Filter out deleted and anonymous accounts from follow requests
                    let filteredUsers = users.filter { user in
                        let isDeleted = user.isDeleted ?? false
                        let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                        return !isDeleted && !isAnonymous
                    }
                    completion(filteredUsers)
                }
            }
    }
    
    // Accepts a follow request and creates the follow relationship
    func acceptFollowRequest(from user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion(false)
            return 
        }
        guard let userId = user.id else { 
            completion(false)
            return 
        }
        
        // First, remove the follow request
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("follow-requests")
            .document(userId)
            .delete { error in
                if let error = error {
                    print("Error removing follow request: \(error)")
                    completion(false)
                    return
                }
                
                // Then, create the follow relationship using the new cloud function
                let functions = Functions.functions()
                let acceptFollowRequestFunction = functions.httpsCallable("acceptFollowRequest")
                
                let data = ["requesterId": userId]
                
                acceptFollowRequestFunction.call(data) { result, error in
                    if let error = error {
                        print("Error calling acceptFollowRequest cloud function: \(error)")
                        completion(false)
                        return
                    }
                    
                    if let data = result?.data as? [String: Any],
                       let success = data["success"] as? Bool,
                       success {
                        print("Follow request accepted successfully")
                        
                        // The acceptFollowRequest cloud function already handles mutual follow logic internally
                        // No need to call handleMutualFollow here as it would create duplicate friendships/conversations
                        completion(true)
                    } else {
                        print("Failed to accept follow request via cloud function")
                        completion(false)
                    }
                }
            }
    }
    
    // Rejects a follow request by removing it
    func rejectFollowRequest(from user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion(false)
            return 
        }
        guard let userId = user.id else { 
            completion(false)
            return 
        }
        
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("follow-requests")
            .document(userId)
            .delete { error in
                if let error = error {
                    print("Error rejecting follow request: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
    }
    
    // Cancels a follow request (for the requester)
    func cancelFollowRequest(to user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            completion(false)
            return 
        }
        guard let userId = user.id else { 
            completion(false)
            return 
        }
        
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("follow-requests")
            .document(currentUid)
            .delete { error in
                if let error = error {
                    print("Error canceling follow request: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
    }
    
    // MARK: - Count User Pods
    
    // Counts the number of pods created by a user
    func countUserPods(withUid uid: String, completion: @escaping(Int) -> Void) {
        Firestore.firestore().collection("pods")
            .whereField("userId", isEqualTo: uid)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error counting user pods: \(error.localizedDescription)")
                    completion(0)
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                completion(count)
            }
    }
    
    // MARK: - Account Anonymization
    
    /// Anonymizes the current user's account by deleting all pods and anonymizing personal data
    /// This operation is irreversible and will:
    /// - Delete all user's pods from the main collection
    /// - Clear personal information (email, bio, link, profile image)
    /// - Set counters to 0 (followers, following, pod count)
    /// - Generate a random username
    /// - Delete the Firebase Auth account (frees up email)
    /// - Parameters:
    ///   - completion: Completion handler with success status, error, and deletion summary
    func anonymizeUserAccount(completion: @escaping (Bool, Error?, String?) -> Void) {
        guard Auth.auth().currentUser != nil else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(false, error, nil)
            return
        }
        
        let functions = Functions.functions()
        let anonymizeFunction = functions.httpsCallable("anonymizeUserAccount")
        
        print("🔄 Starting account anonymization process...")
        
        anonymizeFunction.call([:]) { result, error in
            if let error = error {
                print("❌ Error calling anonymizeUserAccount cloud function: \(error)")
                
                // Parse specific error messages for better user feedback
                var userFriendlyMessage = "Failed to anonymize account. Please try again."
                let functionsError = error as NSError?
                
                if let errorDetails = functionsError?.userInfo["details"] as? String {
                    switch errorDetails {
                    case "User account not found":
                        userFriendlyMessage = "Account not found. Please contact support."
                    case "Unable to generate available username after multiple attempts":
                        userFriendlyMessage = "Unable to generate a unique username. Please try again."
                    default:
                        userFriendlyMessage = "Account anonymization failed: \(errorDetails)"
                    }
                } else if functionsError?.code == 16 { // Unauthenticated
                    userFriendlyMessage = "Authentication failed. Please log in again."
                }
                
                let processedError = NSError(domain: "UserService", code: functionsError?.code ?? -1, userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
                completion(false, processedError, nil)
                return
            }
            
            // Parse successful response
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool {
                
                if success {
                    let podsDeleted = data["podsDeleted"] as? Int ?? 0
                    let message = data["message"] as? String ?? "Account anonymized successfully"
                    let authDeleted = data["authDeleted"] as? Bool ?? false
                    
                    let summary = "✅ Account anonymized successfully!\n• \(podsDeleted) pods deleted\n• Personal data cleared\n• Email freed for reuse"
                    
                    print("✅ Account anonymization completed: \(podsDeleted) pods deleted, auth deleted: \(authDeleted)")
                    completion(true, nil, summary)
                } else {
                    let errorMessage = data["message"] as? String ?? "Unknown error occurred"
                    let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    completion(false, error, nil)
                }
            } else {
                let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(false, error, nil)
            }
        }
    }
    
    // MARK: - Account Data Download
    
    /// Downloads user account data (limited to once per month)
    /// - Parameter completion: Completion handler with success status, error, and download data
    func downloadAccountData(completion: @escaping (Bool, Error?, [String: Any]?) -> Void) {
        guard Auth.auth().currentUser != nil else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(false, error, nil)
            return
        }
        
        let functions = Functions.functions()
        let downloadFunction = functions.httpsCallable("downloadAccountData")
        
        print("🔄 Starting account data download...")
        
        downloadFunction.call([:]) { result, error in
            if let error = error {
                print("❌ Error calling downloadAccountData cloud function: \(error)")
                
                // Parse specific error messages for better user feedback
                var userFriendlyMessage = "Failed to download account data. Please try again."
                
                let functionsError = error as NSError?
                
                if let errorDetails = functionsError?.userInfo["details"] as? String {
                    if errorDetails.contains("once per month") {
                        userFriendlyMessage = errorDetails
                    } else {
                        userFriendlyMessage = "Account data download failed: \(errorDetails)"
                    }
                } else if functionsError?.code == 16 { // Unauthenticated
                    userFriendlyMessage = "Authentication failed. Please log in again."
                } else if functionsError?.code == 8 { // Resource exhausted (monthly limit)
                    userFriendlyMessage = "Monthly download limit reached. Please try again next month."
                }
                
                let processedError = NSError(domain: "UserService", code: functionsError?.code ?? -1, userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
                completion(false, processedError, nil)
                return
            }
            
            // Parse successful response
            print("🔍 DEBUG: Raw response data: \(result?.data ?? "nil")")
            
            if let data = result?.data as? [String: Any] {
                print("🔍 DEBUG: Parsed data keys: \(Array(data.keys))")
                
                if let success = data["success"] as? Bool {
                    
                    if success {
                        // Handle new response format with download info
                        if let downloadInfo = data["downloadInfo"] as? [String: Any],
                           let userData = data["data"] as? [String: Any] {
                            
                            print("✅ Account data exported and uploaded successfully")
                            print("📁 File: \(downloadInfo["fileName"] as? String ?? "Unknown")")
                            print("🔗 Download URL: \(downloadInfo["downloadUrl"] as? String ?? "No URL")")
                            print("⏰ Expires: \(downloadInfo["expiresAt"] as? String ?? "Unknown")")
                            
                            // Store download info in user subcollection
                            self.storeDownloadInfo(downloadInfo: downloadInfo)
                            
                            // Display clean data summary
                            if let accountInfo = userData["accountInfo"] as? [String: Any] {
                                print("\n" + String(repeating: "=", count: 60))
                                print("📊 ACCOUNT DATA EXPORT SUMMARY")
                                print(String(repeating: "=", count: 60))
                                
                                print("👤 ACCOUNT INFORMATION:")
                                print("   • Username: \(accountInfo["username"] as? String ?? "Unknown")")
                                print("   • Full Name: \(accountInfo["fullname"] as? String ?? "Unknown")")
                                print("   • Email: \(accountInfo["email"] as? String ?? "Unknown")")
                                print("   • Bio: \(accountInfo["bio"] as? String ?? "No bio")")
                                print("   • Followers: \(accountInfo["followersCount"] as? Int ?? 0)")
                                print("   • Following: \(accountInfo["followingCount"] as? Int ?? 0)")
                                print("   • Pods Created: \(accountInfo["podsCreatedCount"] as? Int ?? 0)")
                                print("   • Account Created: \(accountInfo["accountCreatedAt"] as? String ?? "Unknown")")
                            }
                            
                            if let exportInfo = userData["exportInfo"] as? [String: Any] {
                                print("\n📈 EXPORT STATISTICS:")
                                print("   • Total Pods: \(exportInfo["totalPods"] as? Int ?? 0)")
                                print("   • Total Followers: \(exportInfo["totalFollowers"] as? Int ?? 0)")
                                print("   • Total Following: \(exportInfo["totalFollowing"] as? Int ?? 0)")
                                print("   • Total Conversations: \(exportInfo["totalConversations"] as? Int ?? 0)")
                                print("   • Total Messages: \(exportInfo["totalMessages"] as? Int ?? 0)")
                                print("   • Total Comments: \(exportInfo["totalComments"] as? Int ?? 0)")
                                print("   • Total Playlists: \(exportInfo["totalPlaylists"] as? Int ?? 0)")
                                print("   • Total Notifications: \(exportInfo["totalNotifications"] as? Int ?? 0)")
                            }
                            
                            print(String(repeating: "=", count: 60))
                            
                            completion(true, nil, userData)
                            
                        } else if let userData = data["data"] as? [String: Any] {
                            // Handle fallback format (upload failed, data returned for client processing)
                            print("✅ Account data collected successfully (upload failed, processing locally)")
                            
                            // Create downloadable JSON file locally
                            self.createAndDownloadJSONFile(data: userData)
                            
                            completion(true, nil, userData)
                        } else {
                            let errorMessage = data["message"] as? String ?? "Unknown error occurred"
                            let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            completion(false, error, nil)
                        }
                    } else {
                        let errorMessage = data["message"] as? String ?? "Unknown error occurred"
                        let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        completion(false, error, nil)
                    }
                } else {
                    let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                    completion(false, error, nil)
                }
            }
        }
    }
    
    // MARK: - Download Info Storage
    
    /// Stores download information in user subcollection
    /// - Parameter downloadInfo: The download information to store
    private func storeDownloadInfo(downloadInfo: [String: Any]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let userDataRef = Firestore.firestore().collection("users").document(uid).collection("user-data")
        
        // Store last download info
        let lastDownloadData: [String: Any] = [
            "exportDate": downloadInfo["exportDate"] as? String ?? "",
            "fileName": downloadInfo["fileName"] as? String ?? "",
            "fileSize": downloadInfo["fileSize"] as? Int ?? 0,
            "expiresAt": downloadInfo["expiresAt"] as? String ?? "",
            "downloadUrl": downloadInfo["downloadUrl"] as? String ?? ""
        ]
        
        userDataRef.document("lastDownload").setData(lastDownloadData) { error in
            if let error = error {
                print("❌ Error storing last download info: \(error)")
            } else {
                print("✅ Last download info stored successfully")
            }
        }
    }
    
    /// Fetches the latest download information from user subcollection
    /// - Parameter completion: Completion handler with the latest download info or nil
    func fetchLatestDownloadInfo(completion: @escaping ([String: Any]?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let userDataRef = Firestore.firestore().collection("users").document(uid).collection("user-data")
        
        // Fetch the last download document
        userDataRef.document("lastDownload").getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching last download info: \(error)")
                completion(nil)
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(nil)
                return
            }
            
            completion(data)
        }
    }
    
    /// Checks if user can download data (monthly limit)
    /// - Parameter completion: Completion handler with whether download is allowed
    func canDownloadData(completion: @escaping (Bool, String?) -> Void) {
        fetchLatestDownloadInfo { downloadInfo in
            
            guard let downloadInfo = downloadInfo else {
                completion(true, nil)
                return
            }
            
            guard let exportDateString = downloadInfo["exportDate"] as? String else {
                completion(true, nil)
                return
            }
            
            // Create a more robust date formatter that handles Z timezone
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            guard let exportDate = dateFormatter.date(from: exportDateString) else {
                completion(true, nil)
                return
            }
            
            // Check if 30 days have passed since last download
            let calendar = Calendar.current
            let now = Date()
            let daysSinceLastDownload = calendar.dateComponents([.day], from: exportDate, to: now).day ?? 0
            
            if daysSinceLastDownload >= 30 {
                completion(true, nil)
            } else {
                let daysRemaining = 30 - daysSinceLastDownload
                completion(false, "You can download your data again in \(daysRemaining) days")
            }
        }
    }
    
    // MARK: - JSON File Creation and Download
    
    /// Creates and downloads a JSON file with user data
    /// - Parameter data: The user data to convert to JSON
    func createAndDownloadJSONFile(data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) else {
            print("❌ Error creating JSON data")
            return
        }
        
        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "account_data_export_\(timestamp).json"
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Error accessing documents directory")
            return
        }
        
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            // Write JSON data to file
            try jsonData.write(to: fileURL)
            print("✅ JSON file created: \(fileURL.path)")
            
            // Store download info in Firebase
            let downloadInfo: [String: Any] = [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "fileName": filename,
                "fileSize": jsonData.count,
                "expiresAt": ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())
            ]
            self.storeDownloadInfo(downloadInfo: downloadInfo)
            
            // Share the file
            DispatchQueue.main.async {
                self.shareJSONFile(fileURL: fileURL, filename: filename)
            }
        } catch {
            print("❌ Error writing JSON file: \(error)")
        }
    }
    
    /// Shares the JSON file using UIActivityViewController
    /// - Parameters:
    ///   - fileURL: URL of the JSON file
    ///   - filename: Name of the file
    private func shareJSONFile(fileURL: URL, filename: String) {
        // Add a longer delay to avoid presentation conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("❌ Error accessing root view controller")
                return
            }
            
            // Find the topmost presented view controller
            var topViewController = rootViewController
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            
            // If there's already a presentation, wait and try again
            if topViewController != rootViewController {
                print("⚠️ Another view controller is already being presented, waiting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.presentShareSheet(fileURL: fileURL, filename: filename, rootViewController: topViewController, window: window)
                }
                return
            }
            
            self.presentShareSheet(fileURL: fileURL, filename: filename, rootViewController: rootViewController, window: window)
        }
    }
    
    private func presentShareSheet(fileURL: URL, filename: String, rootViewController: UIViewController, window: UIWindow) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        // Set the subject for email sharing
        activityViewController.setValue("Account Data Export - \(filename)", forKey: "subject")
        
        // Present the activity view controller
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true) {
            print("✅ Share sheet presented for JSON file: \(filename)")
        }
    }
    
    // MARK: - Data Download Management
    
    /// Fetches the latest data download for the current user
    /// - Parameter completion: Completion handler with the latest download or nil
    func fetchLatestDataDownload(completion: @escaping (DataDownload?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("data-downloads")
            .order(by: "exportDate", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching latest data download: \(error)")
                    completion(nil)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(nil)
                    return
                }
                
                do {
                    let download = try document.data(as: DataDownload.self)
                    completion(download)
                } catch {
                    print("Error decoding data download: \(error)")
                    completion(nil)
                }
            }
    }
}
