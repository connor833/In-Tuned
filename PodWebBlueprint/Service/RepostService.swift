//
//  RepostService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

class RepostService {
    private let db = Firestore.firestore()
    private let userService = UserService()
    private let podService = PodService()
    private let notificationService = NotificationService()
    private let functions = Functions.functions()
    
    // MARK: - Error Types
    
    enum RepostServiceError: Error, LocalizedError {
        case invalidInput(String)
        case networkError(Error)
        case permissionDenied
        case repostNotFound
        case duplicateRepost
        case validationFailed([String])
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidInput(let message):
                return "Invalid input: \(message)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .permissionDenied:
                return "Permission denied"
            case .repostNotFound:
                return "Repost not found"
            case .duplicateRepost:
                return "You have already reposted this content"
            case .validationFailed(let errors):
                return "Validation failed: \(errors.joined(separator: ", "))"
            case .unknown(let error):
                return "Unknown error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Retry Configuration
    
    private struct RetryConfig {
        static let maxRetries = 3
        static let baseDelay: TimeInterval = 1.0
        static let maxDelay: TimeInterval = 10.0
    }
    
    // MARK: - Generic Retry Function
    
    private func retryOperation<T>(
        operation: @escaping () async throws -> T,
        maxRetries: Int = RetryConfig.maxRetries,
        baseDelay: TimeInterval = RetryConfig.baseDelay
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on validation errors or permission errors
                if error is RepostServiceError {
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let delay = min(baseDelay * pow(2.0, Double(attempt)), RetryConfig.maxDelay)
                
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? RepostServiceError.unknown(NSError(domain: "RepostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
    }
    
    // MARK: - Validation Helpers
    
    private func validateRepostInput(podId: String, originalUserId: String, caption: String?) throws {
        var errors: [String] = []
        
        if podId.isEmpty { errors.append("Pod ID is required") }
        if originalUserId.isEmpty { errors.append("Original user ID is required") }
        if let caption = caption, caption.count > 500 { errors.append("Caption must be 500 characters or less") }
        
        if !errors.isEmpty {
            throw RepostServiceError.validationFailed(errors)
        }
    }
    
    private func validateRepostId(_ repostId: String) throws {
        if repostId.isEmpty {
            throw RepostServiceError.invalidInput("Repost ID is required")
        }
    }
    
    // MARK: - Repost Operations
    
    /// Creates a repost with comprehensive validation and error handling
    func createRepost(podId: String, originalUserId: String, caption: String?, completion: @escaping (Result<Void, RepostServiceError>) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(.failure(.permissionDenied))
            return
        }
        
        // Validate input
        do {
            try validateRepostInput(podId: podId, originalUserId: originalUserId, caption: caption)
        } catch {
            completion(.failure(error as? RepostServiceError ?? .validationFailed(["Unknown validation error"])))
            return
        }
        
        // Sanitize caption
        let sanitizedCaption = caption.map { InputSanitizer.clean($0, type: .podDescription) }
        
        // Check for duplicate repost
        checkIfUserReposted(podId: podId) { [weak self] hasReposted in
            if hasReposted {
                completion(.failure(.duplicateRepost))
                return
            }
            
            // Create repost data with new model structure
            let currentTime = Timestamp()
            let currentDate = Date()
        let repostData: [String: Any] = [
            "podId": podId,
            "originalUserId": originalUserId,
            "repostUserId": currentUid,
                "caption": sanitizedCaption ?? NSNull(),
                "timestamp": currentDate,
                "version": 1,
                "createdAt": currentTime,
                "updatedAt": currentTime,
                "deletedAt": NSNull(),
                "likes": 0,
                "views": 0,
                "shares": 0,
                "comments": 0,
                "isReported": false,
                "moderationStatus": "approved",
                "contentWarnings": [],
                "isActive": true
            ]
            
            // Create repost in dedicated reposts collection
            let repostId = UUID().uuidString
            let repostRef = self?.db.collection("reposts").document(repostId)
            
            // Add repostId to the data
            var finalRepostData = repostData
            finalRepostData["id"] = repostId
            
            repostRef?.setData(finalRepostData) { error in
                if let error = error {
                        print("❌ Error creating repost: \(error)")
                        completion(.failure(.networkError(error)))
                        return
                    }
                    
                    print("✅ Repost created successfully")
                    
                    // Add reference to user's reposts collection
                    self?.addRepostReferenceToUser(userId: currentUid, repostId: repostId, podId: podId)
                    
                    // Increment repost count on the original pod atomically
                    self?.incrementPodReposts(podId: podId)
                    
                    // Create repost notification for the original pod creator
                    if currentUid != originalUserId {
                        self?.notificationService.createNotification(
                            type: .repost,
                            senderId: currentUid,
                            recipientId: originalUserId,
                            contentId: podId
                        ) { success in
                            if success {
                                print("✅ Repost notification created successfully")
                            } else {
                                print("⚠️ Failed to create repost notification")
                            }
                        }
                    }
                    
                    completion(.success(()))
                }
        }
    }
    
    /// Legacy method for backward compatibility
    func createRepost(podId: String, originalUserId: String, caption: String?, completion: @escaping() -> Void) {
        createRepost(podId: podId, originalUserId: originalUserId, caption: caption) { result in
            completion() // Ignore result for legacy compatibility
        }
    }
    
    // Fetch user's reposts
    func fetchUserReposts(userId: String, completion: @escaping([Repost]) -> Void) {
        print("🔍 [RepostService] Fetching reposts for user: \(userId)")
        
        // Query the main reposts collection directly
        db.collection("reposts")
            .whereField("repostUserId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching user reposts: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("🔍 [RepostService] No reposts found for user: \(userId)")
                    completion([])
                    return
                }
                
                print("🔍 [RepostService] Found \(documents.count) reposts for user: \(userId)")
                
                // Convert documents to Repost objects
                let reposts = documents.compactMap { doc -> Repost? in
                    do {
                        var repost = try doc.data(as: Repost.self)
                        repost.id = doc.documentID
                        return repost
                    } catch {
                        print("❌ Error decoding repost: \(error)")
                        return nil
                    }
                }
                
                print("🔍 [RepostService] Successfully decoded \(reposts.count) reposts")
                completion(reposts)
            }
    }
    
    /// Fetches reposts by their IDs from the main reposts collection
    private func fetchRepostsByIds(repostIds: [String], completion: @escaping([Repost]) -> Void) {
        let group = DispatchGroup()
        var reposts: [Repost] = []
        let repostsQueue = DispatchQueue(label: "reposts.queue", attributes: .concurrent)
        
        for repostId in repostIds {
            group.enter()
            
            db.collection("reposts")
                .document(repostId)
                .getDocument { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error fetching repost \(repostId): \(error)")
                        return
                    }
                    
                    guard let document = snapshot,
                          document.exists,
                          let data = document.data(),
                          data["isActive"] as? Bool == true else {
                        return
                    }
                    
                    do {
                        let repost = try document.data(as: Repost.self)
                        repostsQueue.async(flags: .barrier) {
                        reposts.append(repost)
                        }
                    } catch {
                        print("❌ Error decoding repost \(repostId): \(error)")
                    }
                }
        }
        
        group.notify(queue: .main) {
            // Sort reposts by creation date (newest first)
            let sortedReposts = reposts.sorted { repost1, repost2 in
                let date1 = repost1.creationDate ?? repost1.timestamp
                let date2 = repost2.creationDate ?? repost2.timestamp
                return date1 > date2
            }
            
            print("✅ Fetched \(sortedReposts.count) reposts for user")
            completion(sortedReposts)
            }
    }
    
    // Fetch user's reposts with pod data, handling deleted pods
    func fetchUserRepostsWithPods(userId: String, completion: @escaping([RepostWithPod]) -> Void) {
        db.collection("users")
            .document(userId)
            .collection("user-reposts")
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let group = DispatchGroup()
                var repostsWithPods: [RepostWithPod] = []
                
                for document in documents {
                    group.enter()
                    if var repost = try? document.data(as: Repost.self) {
                        repost.id = document.documentID
                        
                        // Fetch the pod data
                        self.db.collection("pods")
                            .document(repost.podId)
                            .getDocument { podSnapshot, podError in
                                defer { group.leave() }
                                
                                if let podSnapshot = podSnapshot, podSnapshot.exists,
                                   let pod = try? podSnapshot.data(as: Pod.self) {
                                    let repostWithPod = RepostWithPod(repost: repost, pod: pod)
                                    repostsWithPods.append(repostWithPod)
                                                            } else {
                                // Pod was deleted, mark it as deleted
                                var deletedPod = Pod(
                                    title: "Deleted Pod",
                                    timestamp: Timestamp(date: repost.timestamp),
                                    description: "This pod has been deleted",
                                    fileUrl: "",
                                    thumbnailUrl: "",
                                    userId: repost.repostUserId,
                                    likes: 0
                                )
                                deletedPod.id = repost.podId
                                deletedPod.isDeleted = true
                                
                                let repostWithDeletedPod = RepostWithPod(repost: repost, pod: deletedPod)
                                repostsWithPods.append(repostWithDeletedPod)
                            }
                            }
                    } else {
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    // Sort reposts by timestamp (newest first) to maintain chronological order
                    let sortedReposts = repostsWithPods.sorted { $0.repost.timestamp > $1.repost.timestamp }
                    completion(sortedReposts)
                }
            }
    }
    
    // MARK: - Paginated User Reposts
    
    func fetchPaginatedUserRepostsWithPods(
        userId: String,
        limit: Int = 10,
        lastDocument: DocumentSnapshot? = nil,
        completion: @escaping ([RepostWithPod], DocumentSnapshot?) -> Void
    ) {
        print("🔍 [RepostService] Fetching paginated user reposts for UID: \(userId), limit: \(limit), hasLastDoc: \(lastDocument != nil)")
        
        var query = db.collection("reposts")
            .whereField("repostUserId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [RepostService] Error fetching paginated user reposts: \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [RepostService] No repost documents found for user \(userId)")
                completion([], nil)
                return
            }
            
            print("🔍 [RepostService] Found \(documents.count) repost documents for user \(userId)")
            
            let group = DispatchGroup()
            var repostsWithPods: [RepostWithPod] = []
            
            for document in documents {
                group.enter()
                
                // Decode repost directly from document
                guard var repost = try? document.data(as: Repost.self) else {
                    print("❌ Failed to decode repost from document")
                    group.leave()
                    continue
                }
                
                repost.id = document.documentID
                
                // Fetch the pod data
                self.db.collection("pods")
                    .document(repost.podId)
                    .getDocument { podSnapshot, podError in
                        defer { group.leave() }
                        
                        if let podSnapshot = podSnapshot, podSnapshot.exists,
                           let pod = try? podSnapshot.data(as: Pod.self) {
                            let repostWithPod = RepostWithPod(repost: repost, pod: pod)
                            repostsWithPods.append(repostWithPod)
                        } else {
                            // Pod was deleted, mark it as deleted
                            var deletedPod = Pod(
                                title: "Deleted Pod",
                                timestamp: Timestamp(date: repost.timestamp),
                                description: "This pod has been deleted",
                                fileUrl: "",
                                thumbnailUrl: "",
                                userId: repost.repostUserId,
                                likes: 0
                            )
                            deletedPod.id = repost.podId
                            deletedPod.isDeleted = true
                            
                            let repostWithDeletedPod = RepostWithPod(repost: repost, pod: deletedPod)
                            repostsWithPods.append(repostWithDeletedPod)
                        }
                    }
            }
            
            group.notify(queue: .main) {
                // Sort reposts by timestamp (newest first) to maintain chronological order
                let sortedReposts = repostsWithPods.sorted { $0.repost.timestamp > $1.repost.timestamp }
                let lastDocument = documents.last
                
                print("✅ [RepostService] Fetched \(sortedReposts.count) user reposts, hasMore: \(lastDocument != nil)")
                completion(sortedReposts, lastDocument)
            }
        }
    }
    
    // Check if user has reposted a specific pod
    func checkIfUserReposted(podId: String, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("users")
            .document(currentUid)
            .collection("user-reposts")
            .document(podId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ Error checking repost status: \(error)")
                    completion(false)
                    return
                }
                
                guard let data = snapshot?.data() else {
                    completion(false)
                    return
                }
                
                // Check if the reference exists and is active
                let isActive = data["isActive"] as? Bool ?? false
                completion(snapshot?.exists == true && isActive)
            }
    }
    
    /// Deletes a repost with proper error handling and atomic operations
    func deleteRepost(podId: String, completion: @escaping (Result<Void, RepostServiceError>) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(.failure(.permissionDenied))
            return
        }
        
        do {
            try validateRepostId(podId)
        } catch {
            completion(.failure(error as? RepostServiceError ?? .invalidInput("Invalid pod ID")))
            return
        }
        
        // First, get the repost ID from user's reference
        let userRepostRef = db.collection("users")
            .document(currentUid)
            .collection("user-reposts")
            .document(podId)
        
        userRepostRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error getting repost reference: \(error)")
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = snapshot?.data(),
                  let repostId = data["repostId"] as? String else {
                print("❌ Repost reference not found")
                completion(.failure(.repostNotFound))
                return
            }
            
            // Delete the repost from the main reposts collection
            let repostRef = self.db.collection("reposts").document(repostId)
            
            repostRef.delete { [weak self] error in
                if let error = error {
                    print("❌ Error deleting repost: \(error)")
                    completion(.failure(.networkError(error)))
                    return
                }
                
                print("✅ Repost deleted successfully from main collection")
                
                // Remove reference from user's reposts collection
                self?.removeRepostReferenceFromUser(userId: currentUid, podId: podId)
                
                // Decrement repost count on the original pod atomically
                self?.decrementPodReposts(podId: podId)
                
                completion(.success(()))
            }
        }
    }
    
    /// Legacy method for backward compatibility
    func deleteRepost(podId: String, completion: @escaping() -> Void) {
        deleteRepost(podId: podId) { result in
            completion() // Ignore result for legacy compatibility
        }
    }
    
    // MARK: - User Reference Management
    
    /// Adds a repost reference to user's reposts collection
    private func addRepostReferenceToUser(userId: String, repostId: String, podId: String) {
        let userRepostRef = db.collection("users")
            .document(userId)
            .collection("user-reposts")
            .document(podId)
        
        let referenceData: [String: Any] = [
            "repostId": repostId,
            "podId": podId,
            "createdAt": Timestamp(),
            "isActive": true
        ]
        
        userRepostRef.setData(referenceData) { error in
            if let error = error {
                print("❌ Failed to add repost reference to user: \(error)")
            } else {
                print("✅ Repost reference added to user collection")
            }
        }
    }
    
    /// Removes a repost reference from user's reposts collection
    private func removeRepostReferenceFromUser(userId: String, podId: String) {
        let userRepostRef = db.collection("users")
            .document(userId)
            .collection("user-reposts")
            .document(podId)
        
        userRepostRef.delete { error in
            if let error = error {
                print("❌ Failed to remove repost reference from user: \(error)")
            } else {
                print("✅ Repost reference removed from user collection")
            }
        }
    }
    
    // MARK: - Atomic Operations
    
    /// Increments repost count on a pod atomically
    private func incrementPodReposts(podId: String) {
        let data = ["reposts": FieldValue.increment(Int64(1))]
        
        db.collection("pods").document(podId).updateData(data) { error in
            if let error = error {
                print("❌ Failed to increment pod reposts: \(error)")
            } else {
                print("✅ Pod reposts incremented successfully")
            }
        }
    }
    
    /// Decrements repost count on a pod atomically
    private func decrementPodReposts(podId: String) {
        let data = ["reposts": FieldValue.increment(Int64(-1))]
        
        db.collection("pods").document(podId).updateData(data) { error in
            if let error = error {
                print("❌ Failed to decrement pod reposts: \(error)")
            } else {
                print("✅ Pod reposts decremented successfully")
            }
        }
    }
    
    /// Increments repost engagement metrics atomically via Cloud Function
    func incrementRepostEngagement(repostId: String, metric: String, completion: @escaping (Result<Void, RepostServiceError>) -> Void) {
        let functions = Functions.functions()
        let function = functions.httpsCallable("incrementRepostEngagement")
        
        let data: [String: Any] = [
            "repostId": repostId,
            "metric": metric
        ]
        
        function.call(data) { result, error in
            if let error = error {
                print("❌ Failed to increment repost \(metric): \(error)")
                completion(.failure(.networkError(error)))
                return
            }
            
            print("✅ Repost \(metric) incremented successfully")
            completion(.success(()))
        }
    }
    
    /// Decrements repost engagement metrics atomically via Cloud Function
    func decrementRepostEngagement(repostId: String, metric: String, completion: @escaping (Result<Void, RepostServiceError>) -> Void) {
        let functions = Functions.functions()
        let function = functions.httpsCallable("decrementRepostEngagement")
        
        let data: [String: Any] = [
            "repostId": repostId,
            "metric": metric
        ]
        
        function.call(data) { result, error in
            if let error = error {
                print("❌ Failed to decrement repost \(metric): \(error)")
                completion(.failure(.networkError(error)))
                return
            }
            
            print("✅ Repost \(metric) decremented successfully")
            completion(.success(()))
        }
    }
    
    // Function to remove orphaned repost reference (for deleted pods)
    func removeOrphanedRepost(podId: String, completion: @escaping() -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // First, try to get the repost ID from user's reference
        let userRepostRef = db.collection("users")
            .document(currentUid)
            .collection("user-reposts")
            .document(podId)
        
        userRepostRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { 
                completion()
                return 
            }
            
            var repostId: String?
            
            // Try to get repostId from user reference if it exists
            if let data = snapshot?.data(),
               let referenceRepostId = data["repostId"] as? String {
                repostId = referenceRepostId
                print("✅ Found repost ID from user reference: \(referenceRepostId)")
            } else {
                print("⚠️ User repost reference not found, searching main collection directly")
                
                // Fallback: Search for repost directly in main collection
                self.db.collection("reposts")
                    .whereField("repostUserId", isEqualTo: currentUid)
                    .whereField("podId", isEqualTo: podId)
                    .whereField("isActive", isEqualTo: true)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("❌ Error searching for orphaned repost: \(error)")
                            completion()
                            return
                        }
                        
                        guard let documents = snapshot?.documents,
                              let document = documents.first else {
                            print("❌ Orphaned repost not found in main collection either")
                            completion()
                            return
                        }
                        
                        repostId = document.documentID
                        print("✅ Found repost ID from main collection: \(document.documentID)")
                        
                        self.deleteOrphanedRepost(repostId: repostId!, userId: currentUid, podId: podId, completion: completion)
                    }
                return
            }
            
            // If we have a repostId, proceed with deletion
            if let validRepostId = repostId {
                self.deleteOrphanedRepost(repostId: validRepostId, userId: currentUid, podId: podId, completion: completion)
            } else {
                completion()
            }
        }
    }
    
    // Helper method to delete orphaned repost
    private func deleteOrphanedRepost(repostId: String, userId: String, podId: String, completion: @escaping() -> Void) {
        // Delete the repost from the main reposts collection
        let repostRef = db.collection("reposts").document(repostId)
        
        repostRef.delete { [weak self] error in
            if let error = error {
                print("❌ Error deleting orphaned repost from main collection: \(error)")
            } else {
                print("✅ Orphaned repost deleted successfully from main collection")
            }
            
            // Remove reference from user's reposts collection (if it exists)
            self?.db.collection("users")
                .document(userId)
                .collection("user-reposts")
                .document(podId)
                .delete { error in
                    if let error = error {
                        print("⚠️ Error removing orphaned repost reference (may not exist): \(error)")
                    } else {
                        print("✅ Orphaned repost reference removed successfully")
                    }
                    completion()
                }
        }
    }
    
    // MARK: - Follow Feed Reposts
    
    // Fetch reposts from followed users for the follow feed with pagination
    func fetchFollowRepostsPaginated(
        withUserIds userIds: [String], 
        limit: Int = 20,
        lastTimestamp: Timestamp? = nil,
        completion: @escaping([RepostWithPod]) -> Void
    ) {
        guard !userIds.isEmpty else {
            print("🔍 [RepostService] No user IDs provided for paginated repost fetching")
            completion([])
            return
        }
        
        print("🔍 [RepostService] Starting paginated repost fetch for \(userIds.count) users, limit: \(limit), isFirstPage: \(lastTimestamp == nil)")
        
        print("   📦 Processing \(userIds.count) users individually for better control")
        
        let group = DispatchGroup()
        var allReposts: [RepostWithPod] = []
        
        // Process each user individually for better control
        for (index, userId) in userIds.enumerated() {
            group.enter()
            print("   🔄 Processing user \(index + 1)/\(userIds.count): \(userId)")
            
            // Fetch reposts from this user with pagination
            var query = db.collection("users")
                .document(userId)
                .collection("user-reposts")
                .order(by: "timestamp", descending: true)
                .limit(to: limit * 2) // Fetch more to ensure proper sorting
            
                // Apply timestamp-based pagination if we have a last timestamp
                if let lastTimestamp = lastTimestamp {
                    query = query.whereField("timestamp", isLessThan: lastTimestamp)
                }
                
            query.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error fetching paginated reposts for user \(userId): \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    print("⚠️ No documents found for user \(userId)")
                    return 
                }
                
                print("   👤 User \(userId): Found \(documents.count) repost documents")
                
                if documents.isEmpty {
                    return
                }
                
                // Process each repost
                let repostGroup = DispatchGroup()
                var userReposts: [RepostWithPod] = []
                
                for document in documents {
                    repostGroup.enter()
                    
                    if var repost = try? document.data(as: Repost.self) {
                        repost.id = document.documentID
                        
                        // Fetch the pod data
                        self.db.collection("pods")
                            .document(repost.podId)
                            .getDocument { podSnapshot, podError in
                                defer { repostGroup.leave() }
                                
                                if let podSnapshot = podSnapshot, podSnapshot.exists,
                                   let pod = try? podSnapshot.data(as: Pod.self) {
                                    let repostWithPod = RepostWithPod(repost: repost, pod: pod)
                                    userReposts.append(repostWithPod)
                                    print("   ✅ Repost processed: \(repost.id ?? "nil") -> Pod: \(pod.title)")
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
                                    placeholderPod.id = repost.podId
                                    placeholderPod.isDeleted = true
                                    
                                    let repostWithPod = RepostWithPod(repost: repost, pod: placeholderPod)
                                    userReposts.append(repostWithPod)
                                    print("   ⚠️ Repost with deleted pod: \(repost.id ?? "nil")")
                                }
                            }
                    } else {
                        repostGroup.leave()
                        print("❌ Failed to parse repost document for user \(userId)")
                    }
                }
                
                // Wait for all repost processing to complete
                repostGroup.notify(queue: .main) {
                    allReposts.append(contentsOf: userReposts)
                    print("   📝 User \(userId) reposts added: \(userReposts.count)")
                }
            }
        }
        
        group.notify(queue: .main) {
            print("🎯 [RepostService] All users completed. Total reposts: \(allReposts.count)")
            
            // Sort reposts by timestamp (newest first)
            let sortedReposts = allReposts.sorted { $0.repost.timestamp > $1.repost.timestamp }
            
            // Apply limit if needed
            let finalReposts = Array(sortedReposts.prefix(limit))
            
            print("✅ [RepostService] Final result: \(finalReposts.count) reposts (limit: \(limit))")
            
            // Log which users' reposts are included
            let userRepostsCount = Dictionary(grouping: finalReposts) { $0.repost.repostUserId }
            for (userId, reposts) in userRepostsCount {
                print("   👤 User \(userId): \(reposts.count) reposts")
            }
            
            completion(finalReposts)
        }
    }
    
    // Fetch reposts from followed users for the follow feed (legacy method)
    func fetchFollowReposts(withUserIds userIds: [String], completion: @escaping([RepostWithPod]) -> Void) {
        guard !userIds.isEmpty else {
            print("🔍 [RepostService] No user IDs provided for repost fetching")
            completion([])
            return
        }
        
        print("🔍 [RepostService] Starting to fetch reposts for \(userIds.count) users")
        
        // Firestore 'in' queries support max 10 elements, so we need to chunk the user IDs
        let chunkedUserIds = chunkArray(userIds, into: 10)
        print("   📦 Chunked into \(chunkedUserIds.count) groups")
        
        let group = DispatchGroup()
        var allReposts: [RepostWithPod] = []
        
        for (chunkIndex, chunk) in chunkedUserIds.enumerated() {
            group.enter()
            print("   🔄 Processing chunk \(chunkIndex + 1): \(chunk.count) users")
            
            // Fetch reposts from this chunk of users
            let chunkGroup = DispatchGroup()
            var chunkReposts: [RepostWithPod] = []
            
            for userId in chunk {
                chunkGroup.enter()
                
                // Fetch reposts from this user
                db.collection("users")
                    .document(userId)
                    .collection("user-reposts")
                    .order(by: "timestamp", descending: true)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("❌ Error fetching reposts for user \(userId): \(error)")
                            chunkGroup.leave()
                            return
                        }
                        
                        guard let documents = snapshot?.documents else { 
                            print("⚠️ No documents found for user \(userId)")
                            chunkGroup.leave()
                            return 
                        }
                        
                        print("   👤 User \(userId): Found \(documents.count) repost documents")
                        
                        if documents.isEmpty {
                            chunkGroup.leave()
                            return
                        }
                        
                        // Process each repost
                        let repostGroup = DispatchGroup()
                        var userReposts: [RepostWithPod] = []
                        
                        for document in documents {
                            repostGroup.enter()
                            
                            if var repost = try? document.data(as: Repost.self) {
                                repost.id = document.documentID
                                
                                // Fetch the pod data
                                self.db.collection("pods")
                                    .document(repost.podId)
                                    .getDocument { podSnapshot, podError in
                                        defer { repostGroup.leave() }
                                        
                                        if let podSnapshot = podSnapshot, podSnapshot.exists,
                                           let pod = try? podSnapshot.data(as: Pod.self) {
                                            let repostWithPod = RepostWithPod(repost: repost, pod: pod)
                                            userReposts.append(repostWithPod)
                                            print("   ✅ Repost processed: \(repost.id ?? "nil") -> Pod: \(pod.title)")
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
                                            placeholderPod.id = repost.podId
                                            placeholderPod.isDeleted = true
                                            
                                            let repostWithPod = RepostWithPod(repost: repost, pod: placeholderPod)
                                            userReposts.append(repostWithPod)
                                            print("   ⚠️ Repost with deleted pod: \(repost.id ?? "nil")")
                                        }
                                    }
                            } else {
                                repostGroup.leave()
                                print("❌ Failed to parse repost document for user \(userId)")
                            }
                        }
                        
                        // Wait for all repost processing to complete before leaving the chunk group
                        repostGroup.notify(queue: .main) {
                            chunkReposts.append(contentsOf: userReposts)
                            print("   📝 User \(userId) reposts added to chunk: \(userReposts.count)")
                            chunkGroup.leave()
                        }
                    }
            }
            
            chunkGroup.notify(queue: .main) {
                print("   📦 Chunk \(chunkIndex + 1) completed: \(chunkReposts.count) reposts")
                allReposts.append(contentsOf: chunkReposts)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("🎯 [RepostService] All chunks completed. Total reposts: \(allReposts.count)")
            
            // Sort reposts by timestamp (newest first)
            let sortedReposts = allReposts.sorted { $0.repost.timestamp > $1.repost.timestamp }
            completion(sortedReposts)
        }
    }
    
    // Helper function to chunk arrays into smaller arrays
    private func chunkArray<T>(_ array: [T], into size: Int) -> [[T]] {
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
    
    // MARK: - Simplified Repost Fetching
    
    /// Fetches reposts from specific users with pagination
    /// - Parameters:
    ///   - userIds: Array of user IDs to fetch reposts from
    ///   - limit: Number of reposts to fetch per user
    ///   - lastSnapshot: Last document snapshot for pagination
    ///   - completion: Completion handler with RepostWithPod array
    func fetchRepostsFromUsers(
        userIds: [String],
        limit: Int,
        lastSnapshot: DocumentSnapshot?,
        completion: @escaping([RepostWithPod]) -> Void
    ) {
        print("🔍 [RepostService] fetchRepostsFromUsers called with \(userIds.count) users, limit: \(limit)")
        guard !userIds.isEmpty else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var allReposts: [RepostWithPod] = []
        let repostsLock = NSLock()
        
        for userId in userIds {
            group.enter()
            
            var query = db.collection("users")
                .document(userId)
                .collection("user-reposts")
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
            
            if let lastSnapshot = lastSnapshot {
                query = query.start(afterDocument: lastSnapshot)
            }
            
            query.getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ [RepostService] Error fetching reposts for user \(userId): \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // Process each repost document
                let podGroup = DispatchGroup()
                for document in documents {
                    do {
                        var repost = try document.data(as: Repost.self)
                        repost.id = document.documentID
                        
                        // Fetch the associated pod
                        podGroup.enter()
                        self.podService.fetchPod(withPodId: repost.podId, uid: repost.originalUserId) { pod in
                            defer { podGroup.leave() }
                            let repostWithPod = RepostWithPod(repost: repost, pod: pod)
                            repostsLock.lock()
                            allReposts.append(repostWithPod)
                            repostsLock.unlock()
                        }
                    } catch {
                        print("❌ [RepostService] Error decoding repost: \(error)")
                    }
                }
                
                // Wait for all pod fetches to complete for this user
                podGroup.notify(queue: .main) {
                    // All pods for this user have been fetched
                }
            }
        }
        
        group.notify(queue: .main) {
            let uniqueReposts = Array(Set(allReposts)).sorted { $0.repost.timestamp > $1.repost.timestamp }
            completion(Array(uniqueReposts.prefix(limit)))
        }
    }
    
    // MARK: - Random User Selection Methods
    
    /// Fetch recent reposts from specific users (optimized for random user selection)
    func fetchRecentRepostsFromUsers(
        userIds: [String],
        limit: Int,
        since: Timestamp,
        completion: @escaping([RepostWithPod]) -> Void
    ) {
        print("🔍 [RepostService] fetchRecentRepostsFromUsers called with \(userIds.count) users, limit: \(limit)")
        guard !userIds.isEmpty else {
            completion([])
            return
        }
        
        // Single efficient query for recent reposts from these users
        db.collection("reposts")
            .whereField("repostUserId", in: userIds)
            .whereField("isActive", isEqualTo: true)
            .whereField("timestamp", isGreaterThan: since.dateValue())
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [RepostService] Error fetching recent reposts: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📱 [RepostService] No recent reposts found")
                    completion([])
                    return
                }
                
                print("🔍 [RepostService] Found \(documents.count) recent repost documents")
                
                let group = DispatchGroup()
                var repostsWithPods: [RepostWithPod] = []
                
                for document in documents {
                    group.enter()
                    
                    // Decode repost directly from document
                    guard var repost = try? document.data(as: Repost.self) else {
                        print("❌ Failed to decode repost from document")
                        group.leave()
                        continue
                    }
                    
                    repost.id = document.documentID
                    
                    // Fetch the pod data
                    self.db.collection("pods")
                        .document(repost.podId)
                        .getDocument { podSnapshot, podError in
                            defer { group.leave() }
                            
                            if let podSnapshot = podSnapshot, podSnapshot.exists,
                               let pod = try? podSnapshot.data(as: Pod.self) {
                                let repostWithPod = RepostWithPod(repost: repost, pod: pod)
                                repostsWithPods.append(repostWithPod)
                            } else {
                                // Pod was deleted, mark it as deleted
                                var deletedPod = Pod(
                                    title: "Deleted Pod",
                                    timestamp: Timestamp(date: repost.timestamp),
                                    description: "This pod has been deleted",
                                    fileUrl: "",
                                    thumbnailUrl: "",
                                    userId: repost.repostUserId,
                                    likes: 0
                                )
                                deletedPod.id = repost.podId
                                deletedPod.isDeleted = true
                                
                                let repostWithDeletedPod = RepostWithPod(repost: repost, pod: deletedPod)
                                repostsWithPods.append(repostWithDeletedPod)
                            }
                        }
                }
                
                group.notify(queue: .main) {
                    // Sort reposts by timestamp (newest first)
                    let sortedReposts = repostsWithPods.sorted { $0.repost.timestamp > $1.repost.timestamp }
                    print("✅ [RepostService] Fetched \(sortedReposts.count) recent reposts from \(userIds.count) users")
                    completion(sortedReposts)
                }
            }
    }
} 
