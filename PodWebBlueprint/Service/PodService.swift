//
//  PodServer.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/14/23.
//

import Firebase
//import FirebaseFirestoreSwift
import FirebaseStorage
import FirebaseFunctions
import FirebaseFirestore
import FirebaseAuth

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

class PodService {
    private let db = Firestore.firestore()
    var collectionRef = Firestore.firestore().collection("pods")
    private let blockService = BlockService() // Add blocking service
    
    // MARK: - Error Types
    
    enum PodServiceError: LocalizedError {
        case invalidPod(String)
        case networkError(Error)
        case permissionDenied
        case podNotFound
        case validationFailed([String])
        case retryLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .invalidPod(let message):
                return "Invalid pod: \(message)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .permissionDenied:
                return "Permission denied"
            case .podNotFound:
                return "Pod not found"
            case .validationFailed(let errors):
                return "Validation failed: \(errors.joined(separator: ", "))"
            case .retryLimitExceeded:
                return "Retry limit exceeded"
            }
        }
    }
    
    // MARK: - Retry Configuration
    
    private struct RetryConfig {
        static let maxRetries = 3
        static let baseDelay: TimeInterval = 1.0
        static let maxDelay: TimeInterval = 10.0
    }
    
    // MARK: - Retry Logic
    
    private func retryOperation<T>(
        operation: @escaping () async throws -> T,
        retryCount: Int = 0
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            if retryCount < RetryConfig.maxRetries {
                let delay = min(RetryConfig.baseDelay * pow(2.0, Double(retryCount)), RetryConfig.maxDelay)
                print("⚠️ Operation failed, retrying in \(delay)s (attempt \(retryCount + 1)/\(RetryConfig.maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await retryOperation(operation: operation, retryCount: retryCount + 1)
            } else {
                throw PodServiceError.retryLimitExceeded
            }
        }
    }
    
    // MARK: - Validation Helpers
    
    private func validatePod(_ pod: Pod) throws {
        guard pod.isValid else {
            throw PodServiceError.validationFailed(pod.validationErrors)
        }
    }
    
    private func validatePodId(_ podId: String?) throws -> String {
        guard let podId = podId, !podId.isEmpty else {
            throw PodServiceError.invalidPod("Pod ID is required")
        }
        return podId
    }
    
    // MARK: - Engagement Metrics
    
    private func incrementPodSaves(podId: String) {
        guard !podId.isEmpty else { return }
        
        Task {
            do {
                try await retryOperation {
                    let functions = Functions.functions()
                    let incrementSaves = functions.httpsCallable("incrementPodSaves")
                    let result = try await incrementSaves.call(["podId": podId])
                    print("✅ Successfully incremented saves for pod: \(podId)")
                    return result
                }
            } catch {
                print("❌ Error incrementing pod saves: \(error.localizedDescription)")
            }
        }
    }
    
    private func decrementPodSaves(podId: String) {
        guard !podId.isEmpty else { return }
        
        Task {
            do {
                try await retryOperation {
                    let functions = Functions.functions()
                    let decrementSaves = functions.httpsCallable("decrementPodSaves")
                    let result = try await decrementSaves.call(["podId": podId])
                    print("✅ Successfully decremented saves for pod: \(podId)")
                    return result
                }
            } catch {
                print("❌ Error decrementing pod saves: \(error.localizedDescription)")
            }
        }
    }
    
    
    // MARK: - Data Consistency Helpers
    
    
    /// Ensures engagement metrics are non-negative
    private func sanitizeEngagementMetrics(_ pod: inout Pod) {
        pod.views = max(0, pod.views)
        pod.shares = max(0, pod.shares)
        pod.comments = max(0, pod.comments)
        pod.saves = max(0, pod.saves)
        pod.likes = max(0, pod.likes)
    }
    
    // MARK: - Real-time Listeners
    private var followPodsListeners: [String: ListenerRegistration] = [:]
    
    // MARK: - Fetch Functions
    
    
    /*
    // Function to fetch pods for a specific user
     //this code is for if there is an extra instance of pods within the user data instead of just fetching the pods from whole bucket
    func fetchPods(withUid uid: String, completion: @escaping([Pod]) -> Void) {
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("pods")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                let pods = documents.compactMap({ try? $0.data(as: Pod.self) })
                completion(pods)
            }
    }
     */
    
    func fetchPods(withUid uid: String, completion: @escaping([Pod]) -> Void) {
        Firestore.firestore().collection("pods")
            .whereField("userId", isEqualTo: uid)
            .getDocuments { snapshot, _ in
            guard let documents = snapshot?.documents else { return }
            let pods = documents.compactMap({ try? $0.data(as: Pod.self) })
                completion(pods.sorted(by: {$0.timestamp.dateValue() > $1.timestamp.dateValue() }))
        }
    }
    
    // MARK: - Paginated User Pods
    
    func fetchPaginatedUserPods(
        forUid uid: String,
        limit: Int = 10,
        lastDocument: DocumentSnapshot? = nil,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        print("🔍 [PodService] Fetching paginated user pods for UID: \(uid), limit: \(limit), hasLastDoc: \(lastDocument != nil)")
        
        var query = Firestore.firestore()
            .collection("pods")
            .whereField("userId", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [PodService] Error fetching paginated user pods: \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [PodService] No documents found for user pods")
                completion([], nil)
                return
            }
            
            let pods = documents.compactMap { try? $0.data(as: Pod.self) }
            let lastDocument = documents.last
            
            print("✅ [PodService] Fetched \(pods.count) user pods, hasMore: \(lastDocument != nil)")
            completion(pods, lastDocument)
        }
    }
    
    func fetchPaginatedPods(limit: Int, lastSnapshot: DocumentSnapshot? = nil, completion: @escaping ([Pod], DocumentSnapshot?) -> Void) {
        var query = Firestore.firestore().collection("pods").limit(to: limit)

        if let lastSnapshot = lastSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }

        query.getDocuments { snapshot, error in
            guard let snapshot = snapshot else {
                print("Error fetching pods: \(error?.localizedDescription ?? "Unknown error")")
                completion([], nil)
                return
            }

            let pods = snapshot.documents.compactMap { try? $0.data(as: Pod.self) }
            
            // Use quick array check from current user for ongoing app usage
            guard let currentUid = Auth.auth().currentUser?.uid else {
                completion(pods, snapshot.documents.last)
                return
            }
            
            // Get current user's blocked users for quick filtering
            Firestore.firestore().collection("users").document(currentUid).getDocument { userSnapshot, userError in
                
                if let userError = userError {
                    print("Error fetching user for blocking: \(userError)")
                    completion(pods, snapshot.documents.last)
                    return
                }
                
                guard let userData = userSnapshot?.data(),
                      let blockedUsers = userData["blockedUsers"] as? [String],
                      let blockedBy = userData["blockedBy"] as? [String] else {
                    completion(pods, snapshot.documents.last)
                    return
                }
                
                let blockedUserIds = Set(blockedUsers)
                let blockedByUserIds = Set(blockedBy)
                
                let filteredPods = pods.filter { pod in
                    !blockedUserIds.contains(pod.userId) && !blockedByUserIds.contains(pod.userId)
                }
                
                completion(filteredPods, snapshot.documents.last)
            }
        }
    }

    
    
    // Legacy function for backward compatibility
    func fetchFollowPods(withUsers users: [User], completion: @escaping([Pod]) -> Void) {
        fetchFollowFeed(withUsers: users, limit: 50) { feedItems, _ in
            // Extract just the pods from FeedItems for backward compatibility
            let pods = feedItems.compactMap { feedItem -> Pod? in
                switch feedItem {
                case .pod(let pod):
                    return pod
                case .repost(let repostWithPod):
                    return repostWithPod.pod
                }
            }
            completion(pods)
        }
    }
    
    // MARK: - Simplified Follow Feed Fetching
    
    /// Fetches both pods and reposts from followed users in a single, simple method
    /// - Parameters:
    ///   - users: Array of followed users
    ///   - limit: Number of items per page (default: 10)
    ///   - lastSnapshot: Last document snapshot for pagination
    ///   - completion: Completion handler with FeedItems and pagination info
    func fetchFollowFeed(
        withUsers users: [User],
        limit: Int = 10,
        lastSnapshot: DocumentSnapshot? = nil,
        completion: @escaping([FeedItem], DocumentSnapshot?) -> Void
    ) {
        print("🚀 [PodService] fetchFollowFeed called with \(users.count) users, limit: \(limit)")
        guard !users.isEmpty else {
            print("🔍 [PodService] No users provided")
            completion([], nil)
            return
        }
        
        // Use random selection of 10 users for variety and fairness
        let randomUsers = Array(users.shuffled().prefix(10))
        let userIds = randomUsers.map { $0.uid }
        print("🎲 [PodService] Using random 10 users: \(userIds.prefix(3).joined(separator: ", "))\(userIds.count > 3 ? "..." : "")")
        
        // Use standard time window (90 days) for consistent results
        let ninetyDaysAgo = Timestamp(date: Date().addingTimeInterval(-90 * 24 * 60 * 60))
        print("🕒 [PodService] Fetching content since: \(ninetyDaysAgo.dateValue())")
        
        // Fetch both pods and reposts, then merge them
        let dispatchGroup = DispatchGroup()
        var allPods: [Pod] = []
        var allReposts: [RepostWithPod] = []
        
        // Fetch pods
        dispatchGroup.enter()
        var query = db.collection("pods")
            .whereField("userId", in: userIds)
            .whereField("timestamp", isGreaterThan: ninetyDaysAgo)
            .order(by: "timestamp", descending: true)
            .limit(to: limit * 2) // Fetch more since we're merging with reposts
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [PodService] Error fetching pods: \(error.localizedDescription)")
            } else if let documents = snapshot?.documents {
                allPods = documents.compactMap { document -> Pod? in
                    guard var pod = try? document.data(as: Pod.self) else { return nil }
                    pod.id = document.documentID
                    return pod
                }
                print("📄 [PodService] Found \(allPods.count) pods from followed users")
            }
            dispatchGroup.leave()
        }
        
        // Fetch reposts
        dispatchGroup.enter()
        let repostService = RepostService()
        let lastTimestamp: Timestamp? = nil
        repostService.fetchFollowRepostsPaginated(
            withUserIds: userIds,
            limit: limit * 2,
            lastTimestamp: lastTimestamp
        ) { reposts in
            allReposts = reposts
            print("📄 [PodService] Found \(allReposts.count) reposts from followed users")
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            // Convert to FeedItems
            let podItems = allPods.map { FeedItem.pod($0) }
            let repostItems = allReposts.map { FeedItem.repost($0) }
            
            // Merge and sort by timestamp
            var allItems = podItems + repostItems
            allItems.sort { (item1: FeedItem, item2: FeedItem) -> Bool in
                let date1 = item1.isRepost ? item1.repostData!.timestamp : item1.pod.timestamp.dateValue()
                let date2 = item2.isRepost ? item2.repostData!.timestamp : item2.pod.timestamp.dateValue()
                return date1 > date2
            }
            
            // Take only the requested limit
            let finalItems = Array(allItems.prefix(limit))
            
            print("✅ [PodService] Returning \(finalItems.count) items (\(podItems.count) pods + \(repostItems.count) reposts, merged and sorted)")
            
            // Note: Pagination cursor is not available when merging two collections
            // For simplicity, we'll return nil and handle pagination differently if needed
            completion(finalItems, nil)
        }
    }
    
    /// Fetch recent pods from specific users (optimized for random user selection)
    private func fetchRecentPodsFromUsers(
        userIds: [String],
        limit: Int,
        since: Timestamp,
        completion: @escaping([Pod]) -> Void
    ) {
        // Single efficient query for recent posts from these users
        print("🔍 [PodService] Querying pods for userIds: \(userIds), limit: \(limit), since: \(since.dateValue())")
        db.collection("pods")
            .whereField("userId", in: userIds)
            .whereField("timestamp", isGreaterThan: since)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [PodService] Error fetching recent pods: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📱 [PodService] No recent pods found")
                    completion([])
                    return
                }
                
                print("📄 [PodService] Found \(documents.count) pod documents")
                
                let pods = documents.compactMap { document -> Pod? in
                    guard var pod = try? document.data(as: Pod.self) else {
                        print("❌ Failed to decode pod")
                        return nil
                    }
                    pod.id = document.documentID
                    return pod
                }
                
                print("✅ [PodService] Fetched \(pods.count) recent pods from \(userIds.count) users")
                completion(pods)
            }
    }

    /// Helper method to fetch pods from specific users with chunking (legacy)
    private func fetchPodsFromUsers(
        userIds: [String],
        limit: Int,
        lastSnapshot: DocumentSnapshot?,
        completion: @escaping([Pod]) -> Void
    ) {
        let userIdChunks = userIds.chunked(into: 10)
        let group = DispatchGroup()
        var allPods: [Pod] = []
        let podsLock = NSLock()
        
        for userIdChunk in userIdChunks {
            group.enter()
            
            var query = Firestore.firestore().collection("pods")
                .whereField("userId", in: userIdChunk)
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
            
            if let lastSnapshot = lastSnapshot {
                query = query.start(afterDocument: lastSnapshot)
            }
            
            query.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ [PodService] Error fetching pods: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                let chunkPods = documents.compactMap { try? $0.data(as: Pod.self) }
                
                podsLock.lock()
                allPods.append(contentsOf: chunkPods)
                podsLock.unlock()
            }
        }
        
        group.notify(queue: .main) {
            let uniquePods = Array(Set(allPods)).sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
            completion(Array(uniquePods.prefix(limit)))
        }
    }
    
    
    // MARK: - Real-time Updates
    
    func startFollowPodsListener(
        for userIds: [String],
        completion: @escaping([FeedItem]) -> Void
    ) -> String {
        let listenerId = UUID().uuidString
        
        // Remove existing listeners for these users
        stopFollowPodsListener(for: userIds)
        
        // Create new listeners for each user
        for userId in userIds {
            let listener = Firestore.firestore().collection("pods")
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error listening to follow pods for user \(userId): \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    let newPods = documents.compactMap { try? $0.data(as: Pod.self) }
                    
                    // Convert pods to FeedItems
                    let podItems = newPods.map { FeedItem.pod($0) }
                    
                    // Return the new items directly (no caching in simplified version)
                    completion(podItems)
                }
            
            followPodsListeners[userId] = listener
        }
        
        return listenerId
    }
    
    func stopFollowPodsListener(for userIds: [String]) {
        for userId in userIds {
            followPodsListeners[userId]?.remove()
            followPodsListeners.removeValue(forKey: userId)
        }
    }
    
    func stopAllFollowPodsListeners() {
        for (_, listener) in followPodsListeners {
            listener.remove()
        }
        followPodsListeners.removeAll()
    }
    
    // MARK: - Cache Management (Simplified)
    
    func clearFollowPodsCache() {
        // No-op for simplified version
    }
    
    func clearFollowPodsCache(for userIds: [String]) {
        // No-op for simplified version
    }
    
    // Helper function to chunk arrays into smaller arrays
    private func chunkArray<T>(_ array: [T], into size: Int) -> [[T]] {
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
    
    // Function to fetch all pods
    func fetchPods(completion: @escaping([Pod]) -> Void) {
        Firestore.firestore().collection("pods")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                let pods = documents.compactMap({ try? $0.data(as: Pod.self) })
                completion(pods)
            }
    }
    
    func fetchPagPods(lastSnapshot: DocumentSnapshot? = nil, limit: Int = 5, completion: @escaping ([Pod], DocumentSnapshot?) -> Void) {
        print("fetch pag pods")
        var query = Firestore.firestore().collection("pods").limit(to: limit)
        
        // If lastSnapshot is provided, start after it
        if let lastSnapshot = lastSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }
        
        query.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching documents: \(error ?? NSError())")
                completion([], nil)
                return
            }
            
            let pods = documents.compactMap({ try? $0.data(as: Pod.self) })
            let lastDocumentSnapshot = documents.last // Get the last document snapshot
            
            completion(pods, lastDocumentSnapshot)
        }
    }

    // MARK: - Search Functions
    
    func searchPods(query: String, lastDocument: DocumentSnapshot? = nil, completion: @escaping ([Pod], DocumentSnapshot?) -> Void) {
        var queryRef = collectionRef
            .whereField("titleLowercased", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("titleLowercased", isLessThan: query.lowercased() + "~") // "~" ensures case-insensitivity
            .order(by: "titleLowercased")           // Primary: text relevance for consistent ordering
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

                // Convert Firestore documents to Pod objects
                let resultPods = documents.compactMap { try? $0.data(as: Pod.self) }
                
                // Sort by popularity (most likes first) while maintaining text relevance
                let sortedPods = resultPods.sorted { pod1, pod2 in
                    // First priority: exact text match vs partial match
                    let pod1ExactMatch = pod1.title.lowercased() == query.lowercased()
                    let pod2ExactMatch = pod2.title.lowercased() == query.lowercased()
                    
                    if pod1ExactMatch != pod2ExactMatch {
                        return pod1ExactMatch // Exact matches first
                    }
                    
                    // Second priority: starts with query vs contains query
                    let pod1StartsWith = pod1.title.lowercased().hasPrefix(query.lowercased())
                    let pod2StartsWith = pod2.title.lowercased().hasPrefix(query.lowercased())
                    
                    if pod1StartsWith != pod2StartsWith {
                        return pod1StartsWith // Starts with first
                    }
                    
                    // Third priority: like count (most popular first)
                    let pod1Likes = pod1.likes
                    let pod2Likes = pod2.likes
                    
                    if pod1Likes != pod2Likes {
                        return pod1Likes > pod2Likes // Most likes first
                    }
                    
                    // Fourth priority: recency (newest first)
                    return pod1.timestamp.dateValue() > pod2.timestamp.dateValue()
                }
                
                // Take only the top 10 results after sorting
                let topResults = Array(sortedPods.prefix(10))
                
                print("🎯 [PodService] Search results: \(resultPods.count) found, \(topResults.count) returned after popularity sorting")
                
                // Use quick array check from current user for ongoing app usage
                guard let currentUid = Auth.auth().currentUser?.uid else {
                    let lastDocument = documents.last
                    completion(topResults, lastDocument)
                    return
                }
                
                // Get current user's blocking data for comprehensive filtering
                Firestore.firestore().collection("users").document(currentUid).getDocument { snapshot, error in
                    if let userData = snapshot?.data() {
                        let blockedUsers = userData["blockedUsers"] as? [String] ?? []
                        let blockedBy = userData["blockedBy"] as? [String] ?? []
                        
                        // Combine both arrays for comprehensive filtering
                        let allBlockedUserIds = Set(blockedUsers + blockedBy)
                        
                        // Filter out pods from users that current user has blocked OR users that have blocked current user
                        let filteredPods = resultPods.filter { pod in
                            let isBlocked = allBlockedUserIds.contains(pod.userId)
                            if isBlocked {
                                if blockedUsers.contains(pod.userId) {
                                    print("[PodService] Filtering out pod from user you blocked: \(pod.userId)")
                                } else if blockedBy.contains(pod.userId) {
                                    print("[PodService] Filtering out pod from user who blocked you: \(pod.userId)")
                                }
                            }
                            return !isBlocked
                        }
                        
                        print("[PodService] Filtered \(resultPods.count) pods down to \(filteredPods.count) using comprehensive blocking check")
                        
                        // Apply popularity sorting to filtered results
                        let sortedFilteredPods = filteredPods.sorted { pod1, pod2 in
                            let pod1Likes = pod1.likes
                            let pod2Likes = pod2.likes
                            return pod1Likes > pod2Likes // Most likes first
                        }
                        
                        let topFilteredResults = Array(sortedFilteredPods.prefix(10))
                        let lastDocument = documents.last
                        completion(topFilteredResults, lastDocument)
                    } else {
                        // Fallback to all pods if blocking data not available
                        let lastDocument = documents.last
                        completion(topResults, lastDocument)
                    }
                }
        }
    }

    
    // Function to fetch saved pods for a user
    func fetchSavedPods(withUid uid: String, completion: @escaping([Pod]) -> Void) {
        print("🔍 [PodService] Fetching saved pods for user: \(uid)")
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("saved-pods")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [PodService] Error fetching saved pods: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    print("🔍 [PodService] No saved pods found for user: \(uid)")
                    completion([])
                    return 
                }
                
                print("🔍 [PodService] Found \(documents.count) saved pod references for user: \(uid)")
                
                let group = DispatchGroup()
                var savedPods: [Pod] = []
                
                for document in documents {
                    group.enter()
                    let podId = document.documentID
                    print("🔍 [PodService] Fetching full pod data for ID: \(podId)")
                    
                    // Fetch the full pod data from the main pods collection
                    Firestore.firestore().collection("pods")
                        .document(podId)
                        .getDocument { podSnapshot, error in
                            defer { group.leave() }
                            
                            if let error = error {
                                print("❌ [PodService] Error fetching pod \(podId): \(error)")
                                return
                            }
                            
                            if let podSnapshot = podSnapshot, podSnapshot.exists,
                               let pod = try? podSnapshot.data(as: Pod.self) {
                                var podWithId = pod
                                podWithId.id = podId
                                savedPods.append(podWithId)
                                print("✅ [PodService] Successfully fetched pod: \(pod.title)")
                            } else {
                                // Pod doesn't exist, create a placeholder pod
                                var placeholderPod = Pod(
                                    title: "Pod not available",
                                    timestamp: Timestamp(date: Date()),
                                    description: "This pod has been deleted or is no longer accessible.",
                                    fileUrl: "",
                                    thumbnailUrl: "",
                                    userId: "",
                                    likes: 0
                                )
                                placeholderPod.id = podId
                                placeholderPod.didSave = true
                                placeholderPod.isDeleted = true // Custom property to mark as deleted
                                savedPods.append(placeholderPod)
                                print("⚠️ [PodService] Pod \(podId) not found, created placeholder")
                            }
                        }
                }
                
                group.notify(queue: .main) {
                    print("🔍 [PodService] Completed fetching saved pods. Total: \(savedPods.count)")
                    completion(savedPods)
                }
            }
    }
    
    // MARK: - Paginated Saved Pods
    
    func fetchPaginatedSavedPods(
        forUid uid: String,
        limit: Int = 10,
        lastDocument: DocumentSnapshot? = nil,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        print("🔍 [PodService] Fetching paginated saved pods for UID: \(uid), limit: \(limit), hasLastDoc: \(lastDocument != nil)")
        
        var query = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("saved-pods")
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [PodService] Error fetching paginated saved pods: \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [PodService] No saved pod documents found for user")
                completion([], nil)
                return
            }
            
            print("🔍 [PodService] Found \(documents.count) saved pod references for user: \(uid)")
            
            let group = DispatchGroup()
            var savedPods: [Pod] = []
            
            for document in documents {
                group.enter()
                let podId = document.documentID
                print("🔍 [PodService] Fetching full pod data for ID: \(podId)")
                
                // Fetch the full pod data from the main pods collection
                Firestore.firestore().collection("pods")
                    .document(podId)
                    .getDocument { podSnapshot, error in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("❌ [PodService] Error fetching pod \(podId): \(error)")
                            return
                        }
                        
                        if let podSnapshot = podSnapshot, podSnapshot.exists,
                           let pod = try? podSnapshot.data(as: Pod.self) {
                            var podWithId = pod
                            podWithId.id = podId
                            savedPods.append(podWithId)
                            print("✅ [PodService] Successfully fetched pod: \(pod.title)")
                        } else {
                            // Pod doesn't exist, create a placeholder pod
                            var placeholderPod = Pod(
                                title: "Pod not available",
                                timestamp: Timestamp(date: Date()),
                                description: "This pod has been deleted or is no longer accessible.",
                                fileUrl: "",
                                thumbnailUrl: "",
                                userId: "",
                                likes: 0
                            )
                            placeholderPod.id = podId
                            placeholderPod.didSave = true
                            placeholderPod.isDeleted = true // Custom property to mark as deleted
                            savedPods.append(placeholderPod)
                            print("⚠️ [PodService] Pod \(podId) not found, created placeholder")
                        }
                    }
            }
            
            group.notify(queue: .main) {
                // Sort saved pods by timestamp (newest first) to maintain chronological order
                let sortedPods = savedPods.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                let lastDocument = documents.last
                
                print("✅ [PodService] Fetched \(sortedPods.count) saved pods, hasMore: \(lastDocument != nil)")
                completion(sortedPods, lastDocument)
            }
        }
    }
    
    // MARK: - Like/Unlike Functions
    
    // Function to like a pod using cloud function
    func likePod(_ pod: Pod, completion: @escaping() -> Void) {
        guard let podId = pod.id else { return }
        
        let functions = Functions.functions()
        let likePodFunction = functions.httpsCallable("likePod")
        
        let data = ["podId": podId]
        
        likePodFunction.call(data) { result, error in
            if let error = error {
                print("Error calling likePod cloud function: \(error)")
                completion()
                return
            }
            
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("Pod liked successfully via cloud function")
            } else {
                print("Failed to like pod via cloud function")
            }
            completion()
        }
    }

    func unlikePod(_ pod: Pod, completion: @escaping() -> Void) {
        guard let podId = pod.id else { return }
        
        let functions = Functions.functions()
        let unlikePodFunction = functions.httpsCallable("unlikePod")
        
        let data = ["podId": podId]
        
        unlikePodFunction.call(data) { result, error in
            if let error = error {
                print("Error calling unlikePod cloud function: \(error)")
                completion()
                return
            }
            
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("Pod unliked successfully via cloud function")
            } else {
                print("Failed to unlike pod via cloud function")
            }
            completion()
        }
    }

    
    // MARK: - Check Functions
    
    // Function to check if a user liked a pod
    func checkIfUserLikedPod(_ pod: Pod, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let podId = pod.id else { return }
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-likes")
            .document(podId).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                completion(snapshot.exists)
            }
    }
    
    // Function to check if a user saved a pod
    func checkIfUserSavedPod(_ pod: Pod, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let podId = pod.id else { return }
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("saved-pods")
            .document(podId).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                completion(snapshot.exists)
            }
    }
    
    // MARK: - Save/Unsave Functions
    
    // Function to save a pod
    func savePod(_ pod: Pod, completion: @escaping(Result<Void, PodServiceError>) -> Void) {
        do {
            // Only validate pod ID, not content validation for saving existing pods
            let podId = try validatePodId(pod.id)
            guard let uid = Auth.auth().currentUser?.uid else {
                completion(.failure(.permissionDenied))
                return
            }
            
            let data = [
                "title": pod.title,
                "description": pod.description,
                "timestamp": pod.timestamp,
                "thumbnailUrl": pod.thumbnailUrl,
                "fileUrl": pod.fileUrl,
                "likes": pod.likes,
                "userId": pod.userId,
                "savedAt": Timestamp()
            ] as [String: Any]
            
            Firestore.firestore().collection("users")
                .document(uid)
                .collection("saved-pods")
                .document(podId)
                .setData(data) { error in
                    if let error = error {
                        print("❌ Error saving pod: \(error.localizedDescription)")
                        completion(.failure(.networkError(error)))
                    } else {
                        // Increment saves count for the pod
                        self.incrementPodSaves(podId: podId)
                        completion(.success(()))
                    }
                }
        } catch let error as PodServiceError {
            completion(.failure(error))
        } catch {
            completion(.failure(.networkError(error)))
        }
    }
    
    // Function to unsave a pod
    func unsavePod(_ pod: Pod, completion: @escaping(Result<Void, PodServiceError>) -> Void) {
        do {
            let podId = try validatePodId(pod.id)
            guard let uid = Auth.auth().currentUser?.uid else {
                completion(.failure(.permissionDenied))
                return
            }
            
            Firestore.firestore().collection("users")
                .document(uid)
                .collection("saved-pods")
                .document(podId)
                .delete { error in
                    if let error = error {
                        print("❌ Error unsaving pod: \(error.localizedDescription)")
                        completion(.failure(.networkError(error)))
                    } else {
                        // Decrement saves count for the pod
                        self.decrementPodSaves(podId: podId)
                        completion(.success(()))
                    }
                }
        } catch let error as PodServiceError {
            completion(.failure(error))
        } catch {
            completion(.failure(.networkError(error)))
        }
    }
    
    // Function to remove orphaned saved pod reference (for deleted pods)
    func removeOrphanedSavedPod(podId: String, completion: @escaping() -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("saved-pods")
            .document(podId)
            .delete { error in
                if let error = error {
                    print("Error removing orphaned saved pod: \(error)")
                } else {
                    print("Orphaned saved pod removed successfully")
                }
                completion()
            }
    }
    
    // MARK: - Delete Function
    
    // Function to delete a pod (database only, keeps storage files)
    func deletePod(pod: Pod, completion: @escaping() -> Void) {
        guard let podId = pod.id else { 
            completion()
            return 
        }
        print("🗑️ [PodService] Deleting pod: \(podId)")
        
        Task {
            // Step 1: Delete pod from database FIRST
            let deletionSuccess = await performDatabaseDeletionAsync(pod: pod)
            
            if deletionSuccess {
                // Step 2: THEN remove from RSS subscription tracking (if applicable)
                // This ensures we never have a deleted pod with GUID still tracked
                await removeFromRSSSubscriptionIfNeeded(pod: pod)
            } else {
                print("❌ [PodService] Pod deletion failed, skipping RSS cleanup")
            }
            
            await MainActor.run {
                completion()
            }
        }
    }
    
    /// Performs the actual database deletion operations asynchronously
    /// Returns true if deletion was successful, false otherwise
    private func performDatabaseDeletionAsync(pod: Pod) async -> Bool {
        guard let podId = pod.id else {
            print("❌ [PodService] No pod ID, cannot delete")
            return false
        }
        
        var allSuccessful = true
        
        // Delete from main pods collection
        do {
            try await Firestore.firestore().collection("pods")
                .document(podId)
                .delete()
            print("✅ [PodService] Deleted from main pods collection")
        } catch {
            print("❌ [PodService] Error deleting from main collection: \(error.localizedDescription)")
            allSuccessful = false
        }
        
        // Delete from user's pods collection
        do {
            try await Firestore.firestore().collection("users")
                .document(pod.userId)
                .collection("pods")
                .document(podId)
                .delete()
            print("✅ [PodService] Deleted from user pods collection")
        } catch {
            print("❌ [PodService] Error deleting from user collection: \(error.localizedDescription)")
            allSuccessful = false
        }
        
        // Update user's pod count
        if let user = pod.user {
            do {
                try await Firestore.firestore().collection("users").document(user.uid)
                    .updateData(["podCount": user.podCount - 1])
                print("✅ [PodService] Pod count updated successfully")
            } catch {
                print("❌ [PodService] Error updating pod count: \(error.localizedDescription)")
                // Don't fail the whole operation for pod count update
            }
        }
        
        if allSuccessful {
            print("✅ [PodService] Pod deleted from database successfully (storage file preserved)")
        } else {
            print("⚠️ [PodService] Pod deletion completed with some errors")
        }
        
        return allSuccessful
    }
    
    /// Performs the actual database deletion operations (legacy callback version)
    private func performDatabaseDeletion(pod: Pod, completion: @escaping() -> Void) {
        Task {
            _ = await performDatabaseDeletionAsync(pod: pod)
            await MainActor.run {
                completion()
            }
        }
    }
    
    /// Removes pod from RSS subscription tracking if it was imported from RSS
    /// This runs AFTER pod deletion to ensure consistency
    private func removeFromRSSSubscriptionIfNeeded(pod: Pod) async {
        print("🗑️ [PodService] =====================================")
        print("🗑️ [PodService] RSS GUID CLEANUP for pod: '\(pod.title)'")
        print("🗑️ [PodService] NOTE: Pod already deleted from database")
        print("🗑️ [PodService] Now removing GUID from subscription tracking...")
        print("🗑️ [PodService] Pod ID: \(pod.id ?? "no-id")")
        print("🗑️ [PodService] Pod fileUrl: \(pod.fileUrl)")
        print("🗑️ [PodService] Pod userId: \(pod.userId)")
        print("🗑️ [PodService] Pod timestamp: \(pod.timestamp.dateValue())")
        print("🗑️ [PodService] Pod createdAt: \(pod.createdAt?.dateValue().description ?? "nil")")
        
        do {
            let rssService = RSSSubscriptionService()
            
            // For RSS-imported pods, we need to search by multiple potential GUIDs
            var guidsToSearch: [String] = []
            
            // 1. PRIORITY: Use stored rssGuid if available (works even if title was edited)
            if let rssGuid = pod.rssGuid {
                guidsToSearch.append(rssGuid)
                print("🔍 [PodService] Added stored RSS GUID: \(rssGuid)")
            }
            
            // 2. FALLBACK: Try current title + date combo (for older pods without rssGuid field)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = pod.createdAt?.dateValue() ?? pod.timestamp.dateValue()
            let dateString = dateFormatter.string(from: date)
            let titleDateGuid = "\(pod.title)_\(dateString)"
            guidsToSearch.append(titleDateGuid)
            print("🔍 [PodService] Added title+date GUID (fallback): \(titleDateGuid)")
            
            // 3. LAST RESORT: Try the fileUrl (might match for very old pods)
            if !pod.fileUrl.isEmpty {
                guidsToSearch.append(pod.fileUrl)
                print("🔍 [PodService] Added fileUrl GUID (last resort): \(pod.fileUrl)")
            }
            
            print("🔍 [PodService] Final GUIDs to search (in priority order): \(guidsToSearch)")
            
            // Search all user's subscriptions for any of these GUIDs
            let subscriptions = try await rssService.getActiveSubscriptions(for: pod.userId)
            print("🔍 [PodService] Found \(subscriptions.count) active subscriptions to check")
            
            var foundMatch = false
            var totalGuidsRemoved = 0
            
            // Search ALL subscriptions (don't break early)
            for (index, subscription) in subscriptions.enumerated() {
                guard let subscriptionId = subscription.id else { 
                    print("⚠️ [PodService] Subscription \(index + 1) has no ID, skipping")
                    continue 
                }
                
                print("🔍 [PodService] Checking subscription \(index + 1): '\(subscription.feedTitle)'")
                
                // Fetch GUIDs from subcollection (not the deprecated array)
                let importedGuids = try await rssService.getImportedEpisodeGuids(for: subscriptionId, userId: pod.userId)
                print("🔍 [PodService] Subscription has \(importedGuids.count) imported GUIDs in subcollection")
                
                // Check if any of our potential GUIDs exist in this subscription's subcollection
                let matchingGuids = guidsToSearch.filter { guid in
                    let exists = importedGuids.contains(guid)
                    print("🔍 [PodService] GUID '\(guid)' exists in subscription: \(exists)")
                    return exists
                }
                
                if !matchingGuids.isEmpty {
                    print("🎯 [PodService] FOUND \(matchingGuids.count) matching GUIDs in subscription '\(subscription.feedTitle)':")
                    for guid in matchingGuids {
                        print("🎯 [PodService]   - \(guid)")
                    }
                    
                    // Remove all matching GUIDs from this subscription
                    try await rssService.removeImportedEpisodeGuids(matchingGuids, from: subscriptionId, for: pod.userId)
                    print("✅ [PodService] SUCCESSFULLY removed \(matchingGuids.count) GUIDs from subscription '\(subscription.feedTitle)'")
                    
                    // Also remove from RSS stream if subscription has one
                    if let streamId = subscription.streamId, let podId = pod.id {
                        let rssStreamService = RSSStreamService()
                        try await rssStreamService.removeEpisodesFromStream([podId], from: streamId)
                        print("✅ [PodService] SUCCESSFULLY removed pod from RSS stream: \(streamId)")
                    }
                    
                    foundMatch = true
                    totalGuidsRemoved += matchingGuids.count
                    // DON'T break here - continue searching other subscriptions
                } else {
                    print("ℹ️ [PodService] No matching GUIDs in subscription '\(subscription.feedTitle)'")
                }
            }
            
            if foundMatch {
                print("✅ [PodService] RSS GUID CLEANUP COMPLETE: Total \(totalGuidsRemoved) GUIDs removed")
                print("✅ [PodService] Pod deletion and GUID cleanup both successful")
            } else {
                print("ℹ️ [PodService] RSS GUID CLEANUP: No GUIDs found to remove")
                print("ℹ️ [PodService] This could mean:")
                print("ℹ️ [PodService]   1. Pod was not imported from RSS")
                print("ℹ️ [PodService]   2. GUID format doesn't match")
                print("ℹ️ [PodService]   3. Already removed from tracking")
                print("ℹ️ [PodService] Pod deletion was still successful")
            }
            print("🗑️ [PodService] =====================================")
            
        } catch {
            print("❌ [PodService] RSS GUID CLEANUP FAILED: \(error.localizedDescription)")
            print("⚠️ [PodService] WARNING: Pod was deleted but GUID may still be tracked")
            print("⚠️ [PodService] User may be able to re-import this episode")
            print("🗑️ [PodService] =====================================")
            // Don't fail the deletion - pod is already deleted, this is just cleanup
        }
    }
    
    /// Creates episode GUID from pod data (matches RSS import logic)
    private func createEpisodeGuidFromPod(_ pod: Pod) -> String {
        // Use fileUrl as primary identifier (most likely to be unique)
        if !pod.fileUrl.isEmpty {
            return pod.fileUrl
        }
        
        // Fallback to title + creation date combo
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Use createdAt if available, otherwise fall back to timestamp
        let date = pod.createdAt?.dateValue() ?? pod.timestamp.dateValue()
        let dateString = dateFormatter.string(from: date)
        return "\(pod.title)_\(dateString)"
    }
    
    // MARK: - File Download Function
    
    // Function to download a file from iCloud
    func downloadFile(from icloudFileUrl: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            // iCloud is not available, handle the error
            return
        }
        
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localUrl = documentDirectory.appendingPathComponent(icloudFileUrl.lastPathComponent)
        
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: icloudFileUrl)
        } catch {
            // Handle the error
            completion(.failure(error))
            return
        }
        
        DispatchQueue.main.async {
            do {
                try FileManager.default.copyItem(at: icloudFileUrl, to: localUrl)
                completion(.success(localUrl))
            } catch {
                // Handle the error
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Playlist Functions
    
    // Function to fetch pod IDs for a playlist from global collection
    func fetchPlaylistPodIds(withPlaylistId playlistId: String, uid: String, completion: @escaping([String]) -> Void) {
        Firestore.firestore().collection("playlists")
            .document(playlistId)
            .collection("playlist-pods")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [PodService] Error fetching playlist pod IDs: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📝 [PodService] No playlist pods found for playlist: \(playlistId)")
                    completion([])
                    return
                }

                let podIds = documents.map { $0.documentID }
                print("✅ [PodService] Fetched \(podIds.count) pod IDs for playlist: \(playlistId)")
                completion(podIds)
            }
    }
    
    // Function to fetch complete playlist data with all new fields from global collection
    func fetchPlaylist(withPlaylistId playlistId: String, uid: String, completion: @escaping(Playlist?) -> Void) {
        Firestore.firestore().collection("playlists")
            .document(playlistId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ [PodService] Error fetching playlist: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    print("❌ [PodService] Playlist not found: \(playlistId)")
                    completion(nil)
                    return
                }
                
                do {
                    let playlist = try document.data(as: Playlist.self)
                    print("✅ [PodService] Successfully fetched playlist: \(playlist.title)")
                    completion(playlist)
                } catch {
                    print("❌ [PodService] Error decoding playlist: \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }
    
    // Function to fetch pod IDs for a user
    func fetchUserPodIds(withUid uid: String, completion: @escaping([String]) -> Void) {
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("pods")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else {
                               return
                           }

                let podIds = documents.map { $0.documentID }
                completion(podIds)
            }
    }
    
    // MARK: - Paginated User Pod Search
    
    /// Fetches paginated user pods with search functionality for playlist creation/management
    /// - Parameters:
    ///   - uid: User ID to fetch pods for
    ///   - searchText: Optional search text to filter pods by title
    ///   - limit: Number of pods to fetch per page (default: 10)
    ///   - lastDocument: Last document snapshot for pagination
    ///   - completion: Completion handler with fetched pods and last document snapshot
    func fetchPaginatedUserPodsForPlaylist(
        uid: String,
        searchText: String? = nil,
        limit: Int = 10,
        lastDocument: DocumentSnapshot? = nil,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        let db = Firestore.firestore()
        var query = db.collection("pods")
            .whereField("userId", isEqualTo: uid)
        
        // Apply search filter if provided
        if let searchText = searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // For search, fetch more pods to filter from since we're doing client-side filtering
            query = query.order(by: "timestamp", descending: true).limit(to: limit * 3) // Fetch 3x more for better search results
        } else {
            // No search - order by timestamp for chronological order
            query = query.order(by: "timestamp", descending: true).limit(to: limit)
        }
        
        // Apply pagination
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [PodService] Error fetching user pods for playlist: \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("📝 [PodService] No user pods found")
                completion([], nil)
                return
            }
            
            let allPods = documents.compactMap { document -> Pod? in
                do {
                    return try document.data(as: Pod.self)
                } catch {
                    print("❌ [PodService] Error decoding pod: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // Apply client-side filtering for search
            var filteredPods = allPods
            if let searchText = searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let searchLower = searchText.lowercased()
                filteredPods = allPods.filter { pod in
                    pod.title.lowercased().contains(searchLower)
                }
                print("🔍 [PodService] Client-side filtering: \(allPods.count) pods -> \(filteredPods.count) pods (search: '\(searchText)')")
            }
            
            // Apply the original limit to the filtered results
            let finalPods = Array(filteredPods.prefix(limit))
            let lastDocumentSnapshot = documents.last
            
            print("✅ [PodService] Fetched \(finalPods.count) user pods for playlist (search: '\(searchText ?? "")')")
            completion(finalPods, lastDocumentSnapshot)
        }
    }
    
    // Function to fetch a pod with a specific pod ID
    func fetchPod(withPodId podId: String, uid: String, completion: @escaping(Pod) -> Void) {
        Firestore.firestore().collection("pods")
            .document(podId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ [PodService] Error fetching pod \(podId): \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    print("❌ [PodService] Pod \(podId) not found")
                    return
                }
                
                do {
                    let pod = try snapshot.data(as: Pod.self)
                    completion(pod)
                } catch {
                    print("❌ [PodService] Error decoding pod \(podId): \(error.localizedDescription)")
                }
            }
    }
    
    // Function to add pods to a playlist in global collection
    func addPodsToPlaylist(uid: String, playlistId: String, podIds: [String], completion: @escaping (Bool, Error?) -> Void) {
        
        let globalPlaylistRef = Firestore.firestore().collection("playlists").document(playlistId)
        
        // First, get current pod count to calculate new count
        globalPlaylistRef.getDocument { (document, error) in
            if let error = error {
                print("❌ [PodService] Error fetching playlist: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ [PodService] Playlist not found: \(playlistId)")
                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Playlist not found."]))
                return
            }
            
            let currentPodCount = document.data()?["podCount"] as? Int ?? 0
            let newPodCount = currentPodCount + podIds.count
            
            // Update playlist document with new pod count and updated timestamp
            globalPlaylistRef.updateData([
                "podCount": newPodCount,
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("❌ [PodService] Error updating playlist pod count: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                // Add pod IDs to the global playlist's "playlist-pods" subcollection
                let playlistPodsCollectionRef = globalPlaylistRef.collection("playlist-pods")
                
                // Use a dispatch group to wait for all async operations to finish
                let dispatchGroup = DispatchGroup()
                
                for podId in podIds {
                    dispatchGroup.enter()
                    
                    let podDocRef = playlistPodsCollectionRef.document(podId)
                    podDocRef.setData([:]) { error in
                        if let error = error {
                            print("❌ [PodService] Error adding pod to playlist: \(error.localizedDescription)")
                            completion(false, error)
                        } else {
                            print("✅ [PodService] Pod added to playlist successfully.")
                            dispatchGroup.leave()
                        }
                    }
                }
                
                // Notify completion when all operations are finished
                dispatchGroup.notify(queue: .main) {
                    print("✅ [PodService] All pods added to playlist successfully")
                    completion(true, nil)
                }
            }
        }
    }

    // Function to change the name of a playlist in global collection
    func changePlaylistName(playlistId: String, newTitle: String, uid: String, completion: @escaping([Bool]) -> Void) {
        let globalPlaylistRef = Firestore.firestore().collection("playlists").document(playlistId)
        
        globalPlaylistRef.updateData([
            "title": newTitle,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("❌ [PodService] Error updating playlist title: \(error.localizedDescription)")
                completion([false])
            } else {
                print("✅ [PodService] Playlist title updated successfully.")
                completion([true])
            }
        }
    }

    // Function to remove a pod from a playlist in global collection
    func removePodFromPlaylist(playlistId: String, uid: String, podId: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }
        
        let globalPlaylistRef = Firestore.firestore().collection("playlists").document(playlistId)
        
        // First, get current pod count to calculate new count
        globalPlaylistRef.getDocument { (document, error) in
            if let error = error {
                print("❌ [PodService] Error fetching playlist: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ [PodService] Playlist not found: \(playlistId)")
                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Playlist not found."]))
                return
            }
            
            let currentPodCount = document.data()?["podCount"] as? Int ?? 0
            let newPodCount = max(0, currentPodCount - 1) // Ensure count doesn't go below 0
            
            // Delete the pod with the given podId from global collection
            globalPlaylistRef.collection("playlist-pods").document(podId).delete { error in
                if let error = error {
                    print("❌ [PodService] Error removing pod from playlist: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    // Update playlist document with new pod count and updated timestamp
                    globalPlaylistRef.updateData([
                        "podCount": newPodCount,
                        "updatedAt": FieldValue.serverTimestamp()
                    ]) { updateError in
                        if let updateError = updateError {
                            print("❌ [PodService] Error updating playlist pod count: \(updateError.localizedDescription)")
                            completion(false, updateError)
                        } else {
                            print("✅ [PodService] Pod removed from playlist successfully.")
                            completion(true, nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Simplified For You Feed Fetching
    
    /// Fetches recommended pods based on user preferences in a simple, unified way
    /// - Parameters:
    ///   - preferences: User preferences containing categories and keywords
    ///   - limit: Number of pods to fetch per page (default: 10)
    ///   - lastSnapshot: Last document snapshot for pagination
    ///   - completion: Completion handler with fetched pods and pagination info
    func fetchForYouFeed(
        preferences: UserPreferences,
        limit: Int = 10,
        lastSnapshot: DocumentSnapshot? = nil,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        print("🎯 [PodService] ===== FOR YOU FEED FETCH =====")
        print("🎯 [PodService] Categories count: \(preferences.selectedCategories.count)")
        print("🎯 [PodService] Requested limit: \(limit)")
        print("🎯 [PodService] Has lastSnapshot: \(lastSnapshot != nil)")
        
        // Use top 10 categories to avoid chunking issues for now
        let categoriesToQuery = preferences.selectedCategories
            .sorted(by: { $0.weight > $1.weight })
            .prefix(10)
            .map { $0.category }
        
        guard !categoriesToQuery.isEmpty else {
            print("⚠️ [PodService] No categories available")
            completion([], nil)
            return
        }
        
        print("🎯 [PodService] Top categories: \(categoriesToQuery)")
        
        // Handle chunking if needed
        if categoriesToQuery.count <= 10 {
            fetchPodsByCategories(categories: categoriesToQuery, limit: limit, lastSnapshot: lastSnapshot, completion: completion)
        } else {
            fetchPodsByCategoriesChunked(categories: categoriesToQuery, limit: limit, lastSnapshot: lastSnapshot, completion: completion)
        }
    }
    
    /// Helper method to fetch pods by categories (≤10 categories)
    private func fetchPodsByCategories(
        categories: [String],
        limit: Int,
        lastSnapshot: DocumentSnapshot?,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        // Fetch more pods to allow for popularity sorting and diversification
        let fetchLimit = min(limit * 3, 50) // Fetch 3x more for better sorting options
        
        print("🎯 [PodService] fetchPodsByCategories - fetchLimit: \(fetchLimit)")
        print("🎯 [PodService] Categories: \(categories)")
        
        var query = Firestore.firestore().collection("pods")
            .whereField("category", in: categories as [Any])
            .limit(to: fetchLimit)
        
        // Note: Removed timestamp ordering to allow popularity-based sorting
        
        if let lastSnapshot = lastSnapshot {
            query = query.start(afterDocument: lastSnapshot)
            print("🎯 [PodService] Using pagination cursor from: \(lastSnapshot.documentID)")
        }
        
        // Force server fetch for fresh data (especially for engagement metrics like likes)
        query.getDocuments(source: lastSnapshot == nil ? .server : .default) { snapshot, error in
            if let error = error {
                print("❌ [PodService] Error fetching pods: \(error)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [PodService] No documents in snapshot")
                completion([], nil)
                return
            }
            
            print("🎯 [PodService] Firestore returned \(documents.count) documents")
            
            var pods = documents.compactMap { try? $0.data(as: Pod.self) }
            
            print("🎯 [PodService] Decoded \(pods.count) pods successfully")
            print("🎯 [PodService] Raw fetch: \(pods.count) pods")
            
            // Apply popularity-based sorting instead of timestamp
            pods = self.sortPodsByPopularity(pods)
            print("🎯 [PodService] After popularity sort: \(pods.count) pods")
            
            // Apply diversification for For You feed
            pods = self.diversifyForYouFeed(pods)
            print("🎯 [PodService] After diversification: \(pods.count) pods")
            
            // Take only the requested limit after sorting and diversification
            let finalPods = Array(pods.prefix(limit))
            
            // Check if there are more pods available (either more documents than shown, or hit fetch limit)
            let hasMore = (pods.count > limit) || (documents.count == fetchLimit)
            
            print("🎯 [PodService] Final result: \(finalPods.count) pods")
            print("🎯 [PodService] Available after processing: \(pods.count) pods")
            print("🎯 [PodService] More pods available: \(pods.count > limit) OR hit fetch limit: \(documents.count == fetchLimit)")
            print("🎯 [PodService] hasMore: \(hasMore)")
            
            // Use last document from the sorted/diversified pods if we have more
            let lastDoc = hasMore ? documents.last : nil
            completion(finalPods, lastDoc)
        }
    }
    
    /// Helper method to fetch pods by categories (>10 categories)
    private func fetchPodsByCategoriesChunked(
        categories: [String],
        limit: Int,
        lastSnapshot: DocumentSnapshot?,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        // For >10 categories, we need to fetch from all chunks and combine
        // This approach fetches more data and sorts it properly
        let chunkedCategories = categories.chunked(into: 10)
        let group = DispatchGroup()
        var allPods: [Pod] = []
        let podsLock = NSLock()
        
        // Fetch more pods per chunk to ensure we have enough after deduplication
        let podsPerChunk = max(limit * 3, 30)
        
        for (index, chunk) in chunkedCategories.enumerated() {
            group.enter()
            
            var query = Firestore.firestore().collection("pods")
                .whereField("category", in: chunk as [Any])
                .order(by: "timestamp", descending: true)
                .limit(to: podsPerChunk)
            
            // Apply pagination only to the first chunk to maintain consistency
            if index == 0, let lastSnapshot = lastSnapshot {
                query = query.start(afterDocument: lastSnapshot)
            }
            
            // Force server fetch for first page to get fresh engagement metrics
            query.getDocuments(source: (index == 0 && lastSnapshot == nil) ? .server : .default) { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ [PodService] Error fetching chunk \(index): \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                let chunkPods = documents.compactMap { try? $0.data(as: Pod.self) }
                
                podsLock.lock()
                allPods.append(contentsOf: chunkPods)
                podsLock.unlock()
            }
        }
        
        group.notify(queue: .main) {
            // Remove duplicates and sort by timestamp
            let uniquePods = Array(Set(allPods)).sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
            
            // For pagination, we need to skip pods we've already seen
            let finalPods: [Pod]
            if let lastSnapshot = lastSnapshot {
                // Skip the first pod since it's the same as our lastSnapshot
                finalPods = Array(uniquePods.dropFirst().prefix(limit))
            } else {
                finalPods = Array(uniquePods.prefix(limit))
            }
            
            let hasMore = finalPods.count == limit && !finalPods.isEmpty
            
            print("✅ [PodService] Fetched \(finalPods.count) pods from chunks (hasMore: \(hasMore))")
            completion(finalPods, hasMore ? lastSnapshot : nil)
        }
    }
    
    // MARK: - Single Category Query (≤10 categories)
    
    private func executeSingleCategoryQuery(
        categories: [String],
        limit: Int,
        lastSnapshot: DocumentSnapshot?,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        let db = Firestore.firestore()
        let podsCollection = db.collection("pods")
        
        var query = podsCollection
            .whereField("category", in: categories as [Any])
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        if let lastSnapshot = lastSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }
        
        // Force server fetch for first page to get fresh engagement metrics
        query.getDocuments(source: lastSnapshot == nil ? .server : .default) { snapshot, error in
            if let error = error {
                print("❌ [PodService] Error in single category query: \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [PodService] No documents found in single category query")
                completion([], nil)
                return
            }
            
            let pods = documents.compactMap { try? $0.data(as: Pod.self) }
            let lastSnapshot = documents.last
            
            print("✅ [PodService] Single query: \(pods.count) pods from \(categories.count) categories")
            print("✅ [PodService] Has more results: \(lastSnapshot != nil)")
            
            // Remove duplicates while preserving order
            var seenIds = Set<String>()
            let uniquePods = pods.filter { pod in
                guard let id = pod.id else { return false }
                if seenIds.contains(id) {
                    return false
                }
                seenIds.insert(id)
                return true
            }
            
            completion(uniquePods, lastSnapshot)
        }
    }
    
    // MARK: - Chunked Category Query (>10 categories)
    
    private func executeChunkedCategoryQuery(
        categories: [String],
        limit: Int,
        lastSnapshot: DocumentSnapshot?,
        completion: @escaping ([Pod], DocumentSnapshot?) -> Void
    ) {
        let db = Firestore.firestore()
        let podsCollection = db.collection("pods")
        
        // Chunk categories into groups of 10 (Firestore limit)
        let chunkedCategories = chunkArray(categories, into: 10)
        
        print("🔀 [PodService] Chunking \(categories.count) categories into \(chunkedCategories.count) chunks")
        
        let group = DispatchGroup()
        var allPods: [Pod] = []
        var lastSnapshotFromChunks: DocumentSnapshot?
        
        for (index, chunk) in chunkedCategories.enumerated() {
            group.enter()
            
            var query = podsCollection
                .whereField("category", in: chunk as [Any])
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
            
            // Apply pagination to the first chunk only to maintain consistency
            if index == 0, let lastSnapshot = lastSnapshot {
                query = query.start(afterDocument: lastSnapshot)
            }
            
            query.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ [PodService] Error in chunk \(index): \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    return 
                }
                
                let chunkPods = documents.compactMap { try? $0.data(as: Pod.self) }
                allPods.append(contentsOf: chunkPods)
                
                // Store the last snapshot from the first chunk for pagination
                if index == 0 {
                    lastSnapshotFromChunks = documents.last
                }
            }
        }
        
        group.notify(queue: .main) {
            // Remove duplicates first
            var seenIds = Set<String>()
            let uniquePods = allPods.filter { pod in
                guard let id = pod.id else { return false }
                if seenIds.contains(id) {
                    return false
                }
                seenIds.insert(id)
                return true
            }
            
            if RecommendationConfig.enableRecommendationDebugging {
                print("🎯 [PodService] Chunked query raw: \(uniquePods.count) unique pods from \(categories.count) categories")
            }
            
            // Apply popularity-based sorting instead of timestamp
            var sortedPods = self.sortPodsByPopularity(uniquePods)
            
            // Apply diversification for For You feed
            sortedPods = self.diversifyForYouFeed(sortedPods)
            
            // Take only the requested limit after sorting and diversification
            let finalPods = Array(sortedPods.prefix(limit))
            
            if RecommendationConfig.enableRecommendationDebugging {
                print("✅ [PodService] Chunked query final: \(finalPods.count) pods after popularity sorting & diversification")
            }
            
            completion(finalPods, lastSnapshotFromChunks)
        }
    }
    
    // MARK: - Popularity & Diversification Algorithms
    
    /// Sort pods by popularity score with randomness to prevent repetitive feeds
    private func sortPodsByPopularity(_ pods: [Pod]) -> [Pod] {
        if RecommendationConfig.Diversification.enablePopularityTierShuffling {
            return sortPodsByPopularityTiers(pods)
        } else {
            return sortPodsByPopularityWithRandomness(pods)
        }
    }
    
    /// Sort pods by popularity but add randomness to prevent same content every time
    private func sortPodsByPopularityWithRandomness(_ pods: [Pod]) -> [Pod] {
        let randomnessFactor = RecommendationConfig.Diversification.popularityRandomnessFactor
        
        return pods.sorted { pod1, pod2 in
            let score1 = RecommendationConfig.calculatePopularityScore(
                likes: pod1.likes,
                views: pod1.views,
                shares: pod1.shares,
                saves: pod1.saves,
                comments: pod1.comments,
                createdAt: pod1.createdAt?.dateValue()
            )
            
            let score2 = RecommendationConfig.calculatePopularityScore(
                likes: pod2.likes,
                views: pod2.views,
                shares: pod2.shares,
                saves: pod2.saves,
                comments: pod2.comments,
                createdAt: pod2.createdAt?.dateValue()
            )
            
            // Add randomness to popularity scores to create variety
            let randomBonus1 = Double.random(in: 0...score1) * randomnessFactor
            let randomBonus2 = Double.random(in: 0...score2) * randomnessFactor
            
            let finalScore1 = score1 + randomBonus1
            let finalScore2 = score2 + randomBonus2
            
            // Higher final score (popularity + randomness) first
            if finalScore1 != finalScore2 {
                return finalScore1 > finalScore2
            }
            
            // If same final score, fall back to timestamp (newer first)
            return pod1.timestamp.dateValue() > pod2.timestamp.dateValue()
        }
    }
    
    /// Sort pods by popularity tiers with randomization within each tier
    private func sortPodsByPopularityTiers(_ pods: [Pod]) -> [Pod] {
        // Calculate popularity scores for all pods
        let podsWithScores = pods.map { pod in
            let score = RecommendationConfig.calculatePopularityScore(
                likes: pod.likes,
                views: pod.views,
                shares: pod.shares,
                saves: pod.saves,
                comments: pod.comments,
                createdAt: pod.createdAt?.dateValue()
            )
            return (pod: pod, score: score)
        }
        
        // Group into popularity tiers (high, medium, low)
        let allScores = podsWithScores.map { $0.score }.sorted(by: >)
        guard !allScores.isEmpty else { return pods }
        
        let maxScore = allScores.first ?? 0
        let minScore = allScores.last ?? 0
        let scoreRange = maxScore - minScore
        
        // Define tier boundaries
        let highTierThreshold = maxScore - (scoreRange * 0.33)
        let mediumTierThreshold = maxScore - (scoreRange * 0.67)
        
        var highTierPods: [Pod] = []
        var mediumTierPods: [Pod] = []
        var lowTierPods: [Pod] = []
        
        for (pod, score) in podsWithScores {
            if score >= highTierThreshold {
                highTierPods.append(pod)
            } else if score >= mediumTierThreshold {
                mediumTierPods.append(pod)
            } else {
                lowTierPods.append(pod)
            }
        }
        
        if RecommendationConfig.enableRecommendationDebugging {
            print("🎯 [PodService] Popularity tiers - High: \(highTierPods.count), Medium: \(mediumTierPods.count), Low: \(lowTierPods.count)")
        }
        
        // Randomize within each tier to create variety
        let shuffledHighTier = highTierPods.shuffled()
        let shuffledMediumTier = mediumTierPods.shuffled()
        let shuffledLowTier = lowTierPods.shuffled()
        
        // Combine tiers (high first, then medium, then low)
        return shuffledHighTier + shuffledMediumTier + shuffledLowTier
    }
    
    /// Apply diversification to For You feed to prevent monotonous content
    private func diversifyForYouFeed(_ pods: [Pod]) -> [Pod] {
        guard pods.count > RecommendationConfig.ForYouFeed.diversificationInterval else {
            return pods
        }
        
        var diversifiedPods: [Pod] = []
        var userPreferencePods: [Pod] = []
        var randomPods: [Pod] = []
        
        // Separate pods into preference-based and random pools
        let userPrefWeight = RecommendationConfig.ForYouFeed.userPreferenceWeight
        let splitIndex = Int(Double(pods.count) * userPrefWeight)
        
        userPreferencePods = Array(pods.prefix(splitIndex))
        randomPods = Array(pods.suffix(pods.count - splitIndex)).shuffled()
        
        if RecommendationConfig.enableRecommendationDebugging {
            print("🎲 [PodService] Diversification: \(userPreferencePods.count) preference-based, \(randomPods.count) random")
        }
        
        // Interleave preference-based pods with random ones
        let interval = RecommendationConfig.ForYouFeed.diversificationInterval
        var userPrefIndex = 0
        var randomIndex = 0
        
        for i in 0..<pods.count {
            if i % interval == (interval - 1) && randomIndex < randomPods.count {
                // Every Nth pod should be random for variety
                diversifiedPods.append(randomPods[randomIndex])
                randomIndex += 1
            } else if userPrefIndex < userPreferencePods.count {
                // Regular preference-based pod
                diversifiedPods.append(userPreferencePods[userPrefIndex])
                userPrefIndex += 1
            } else if randomIndex < randomPods.count {
                // Fill remaining with random if we run out of preference pods
                diversifiedPods.append(randomPods[randomIndex])
                randomIndex += 1
            }
        }
        
        // Apply smart diversification to prevent consecutive similar content
        let smartDiversifiedPods = applySmartDiversification(diversifiedPods)
        
        // Apply category balancing to prevent any single category from dominating
        return applyCategoryBalancing(smartDiversifiedPods)
    }
    
    /// Apply smart diversification to prevent consecutive similar content
    private func applySmartDiversification(_ pods: [Pod]) -> [Pod] {
        guard RecommendationConfig.Diversification.enableSmartShuffling else {
            return pods
        }
        
        var optimizedPods = pods
        let maxSameCategory = RecommendationConfig.Diversification.maxConsecutiveSameCategory
        let maxSameUser = RecommendationConfig.Diversification.maxConsecutiveSameUser
        
        // Track consecutive counts
        var lastCategory: String? = nil
        var lastUserId: String? = nil
        var consecutiveCategoryCount = 0
        var consecutiveUserCount = 0
        
        var i = 0
        while i < optimizedPods.count - 1 {
            let currentPod = optimizedPods[i]
            let currentCategory = currentPod.category
            let currentUserId = currentPod.userId
            
            // Update consecutive counts
            if currentCategory == lastCategory {
                consecutiveCategoryCount += 1
            } else {
                consecutiveCategoryCount = 1
                lastCategory = currentCategory
            }
            
            if currentUserId == lastUserId {
                consecutiveUserCount += 1
            } else {
                consecutiveUserCount = 1
                lastUserId = currentUserId
            }
            
            // Check if we need to swap to break monotony
            if consecutiveCategoryCount > maxSameCategory || consecutiveUserCount > maxSameUser {
                // Find a suitable pod to swap with later in the array
                if let swapIndex = findDiversePod(
                    in: optimizedPods,
                    startingFrom: i + 1,
                    avoidingCategory: currentCategory,
                    avoidingUser: currentUserId
                ) {
                    optimizedPods.swapAt(i + 1, swapIndex)
                    
                    if RecommendationConfig.enableRecommendationDebugging {
                        print("🔄 [PodService] Swapped pods at \(i+1) and \(swapIndex) for diversification")
                    }
                    
                    // Reset counts after swap
                    consecutiveCategoryCount = 1
                    consecutiveUserCount = 1
                }
            }
            
            i += 1
        }
        
        return optimizedPods
    }
    
    /// Find a pod that's different from the specified category and user
    private func findDiversePod(
        in pods: [Pod],
        startingFrom index: Int,
        avoidingCategory: String?,
        avoidingUser: String
    ) -> Int? {
        for i in index..<pods.count {
            let pod = pods[i]
            if pod.category != avoidingCategory && pod.userId != avoidingUser {
                return i
            }
        }
        return nil
    }
    
    /// Apply category balancing to prevent any single category from dominating the feed
    private func applyCategoryBalancing(_ pods: [Pod]) -> [Pod] {
        let maxPercentage = RecommendationConfig.Diversification.maxSameCategoryPercentage
        let maxPodsPerCategory = Int(Double(pods.count) * maxPercentage)
        
        // Count pods per category
        var categoryCount: [String: Int] = [:]
        var categoryPods: [String: [Pod]] = [:]
        
        for pod in pods {
            let category = pod.category ?? "Unknown"
            categoryCount[category, default: 0] += 1
            categoryPods[category, default: []].append(pod)
        }
        
        // Check if any category exceeds the limit
        var balancedPods: [Pod] = []
        var excessPods: [Pod] = []
        
        for (category, pods) in categoryPods {
            let count = pods.count
            if count > maxPodsPerCategory {
                // Take only the allowed number (keep the first ones which are highest popularity)
                let allowedPods = Array(pods.prefix(maxPodsPerCategory))
                let excess = Array(pods.suffix(count - maxPodsPerCategory))
                
                balancedPods.append(contentsOf: allowedPods)
                excessPods.append(contentsOf: excess)
                
                if RecommendationConfig.enableRecommendationDebugging {
                    print("⚖️ [PodService] Category '\(category)' had \(count) pods, limited to \(maxPodsPerCategory). Moved \(excess.count) to end.")
                }
            } else {
                balancedPods.append(contentsOf: pods)
            }
        }
        
        // Maintain original order for non-excess pods, add excess pods at the end (shuffled for variety)
        let finalPods = balancedPods + excessPods.shuffled()
        
        if RecommendationConfig.enableRecommendationDebugging && !excessPods.isEmpty {
            print("⚖️ [PodService] Category balancing: moved \(excessPods.count) excess pods to create variety")
        }
        
        return finalPods
    }
}
