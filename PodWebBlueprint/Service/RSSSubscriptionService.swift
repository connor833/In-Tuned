import Foundation
import FirebaseFirestore
import Firebase
import Combine

// MARK: - RSS Subscription Service Types

enum SubscriptionResult {
    case created(RSSSubscription)
    case reactivated(RSSSubscription)
}

enum RSSSubscriptionError: LocalizedError {
    case subscriptionLimitReached
    case subscriptionNotFound
    case duplicateSubscription
    case invalidUserId
    case databaseError(String)
    case validationError(String)
    case missingStreamReference
    case orphanedSubscription
    case streamCreationFailed
    case transactionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .subscriptionLimitReached:
            return "Maximum of 3 RSS subscriptions allowed per user"
        case .subscriptionNotFound:
            return "RSS subscription not found"
        case .duplicateSubscription:
            return "You're already subscribed to this RSS feed"
        case .invalidUserId:
            return "Invalid user ID"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .missingStreamReference:
            return "RSS subscription is missing stream reference"
        case .orphanedSubscription:
            return "RSS subscription has invalid stream reference"
        case .streamCreationFailed:
            return "Failed to create RSS stream"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        }
    }
}

// MARK: - RSS Subscription Service

class RSSSubscriptionService: ObservableObject {
    
    private let db = Firestore.firestore()
    private let maxSubscriptionsPerUser = 3
    
    // MARK: - Create Subscription
    
    /// Creates a new RSS subscription for a user
    /// - Parameters:
    ///   - subscription: The RSS subscription to create
    ///   - rssData: The RSS feed data for stream creation
    ///   - userId: The user ID to create the subscription for
    /// - Returns: The created subscription with document ID
    /// - Throws: RSSSubscriptionError if creation fails
    func createSubscription(_ subscription: RSSSubscription, rssData: RSSFeedData, for userId: String) async throws -> RSSSubscription {
        let result = try await createOrReactivateSubscription(subscription, rssData: rssData, for: userId)
        switch result {
        case .created(let subscription), .reactivated(let subscription):
            return subscription
        }
    }
    
    /// Creates a new RSS subscription with RSS stream or reactivates an existing one
    /// - Parameters:
    ///   - subscription: The RSS subscription to create
    ///   - rssData: The RSS feed data for stream creation
    ///   - userId: The user ID to create the subscription for
    /// - Returns: SubscriptionResult indicating if it was created or reactivated
    /// - Throws: RSSSubscriptionError if creation fails
    func createOrReactivateSubscription(_ subscription: RSSSubscription, rssData: RSSFeedData, for userId: String) async throws -> SubscriptionResult {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        // Validate subscription data
        let sanitizedSubscription = subscription.sanitized()
        guard sanitizedSubscription.isValid else {
            throw RSSSubscriptionError.validationError(sanitizedSubscription.validationErrors.joined(separator: ", "))
        }
        
        // Check subscription limit
        let currentCount = try await getActiveSubscriptionCount(for: userId)
        guard currentCount < maxSubscriptionsPerUser else {
            throw RSSSubscriptionError.subscriptionLimitReached
        }
        
        // Check for existing subscription (both active and inactive)
        if let existingSubscription = try await findExistingSubscription(feedUrl: sanitizedSubscription.feedUrl, for: userId) {
            if existingSubscription.isActive {
                // Already have an active subscription for this feed
                throw RSSSubscriptionError.duplicateSubscription
            } else {
                // Reactivate the inactive subscription instead of creating a new one
                let reactivatedSubscription = try await reactivateSubscriptionWithStream(existingSubscription, rssData: rssData, for: userId)
                return .reactivated(reactivatedSubscription)
            }
        }
        
        // Create subscription + stream atomically using transaction
        do {
            let (createdSubscription, streamId) = try await createSubscriptionWithStreamTransaction(sanitizedSubscription, rssData: rssData, userId: userId)
            
            print("✅ Created RSS subscription and stream: \(sanitizedSubscription.feedTitle) for user: \(userId)")
            print("✅ Stream ID: \(streamId)")
            return .created(createdSubscription)
            
        } catch {
            print("❌ Failed to create RSS subscription with stream: \(error.localizedDescription)")
            if error is RSSSubscriptionError {
                throw error
            }
            throw RSSSubscriptionError.transactionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Get Subscriptions
    
    /// Gets all active RSS subscriptions for a user
    /// - Parameter userId: The user ID to get subscriptions for
    /// - Returns: Array of active RSS subscriptions
    /// - Throws: RSSSubscriptionError if fetch fails
    func getActiveSubscriptions(for userId: String) async throws -> [RSSSubscription] {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        do {
            let snapshot = try await db.collection("users").document(userId).collection("rssSubscriptions")
                .whereField("isActive", isEqualTo: true)
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            let subscriptions = try snapshot.documents.compactMap { document in
                try document.data(as: RSSSubscription.self)
            }
            
            print("📱 Retrieved \(subscriptions.count) active RSS subscriptions for user: \(userId)")
            return subscriptions
            
        } catch {
            print("❌ Failed to get RSS subscriptions: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Gets count of active RSS subscriptions for a user
    /// - Parameter userId: The user ID to count subscriptions for
    /// - Returns: Number of active subscriptions
    /// - Throws: RSSSubscriptionError if fetch fails
    func getActiveSubscriptionCount(for userId: String) async throws -> Int {
        let subscriptions = try await getActiveSubscriptions(for: userId)
        return subscriptions.count
    }
    
    /// Gets a specific RSS subscription by ID
    /// - Parameters:
    ///   - subscriptionId: The subscription document ID
    ///   - userId: The user ID who owns the subscription
    /// - Returns: The RSS subscription
    /// - Throws: RSSSubscriptionError if not found
    func getSubscription(id subscriptionId: String, for userId: String) async throws -> RSSSubscription {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        do {
            let document = try await db.collection("users").document(userId).collection("rssSubscriptions").document(subscriptionId).getDocument()
            
            guard document.exists else {
                throw RSSSubscriptionError.subscriptionNotFound
            }
            
            let subscription = try document.data(as: RSSSubscription.self)
            return subscription
            
        } catch {
            if error is RSSSubscriptionError {
                throw error
            }
            print("❌ Failed to get RSS subscription: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Update Subscription
    
    /// Adds imported episode GUIDs to the subscription's subcollection
    /// - Parameters:
    ///   - newGuids: New episode GUIDs to add
    ///   - subscriptionId: The subscription document ID
    ///   - userId: The user ID who owns the subscription
    /// - Throws: RSSSubscriptionError if update fails
    func addImportedEpisodeGuids(_ newGuids: [String], to subscriptionId: String, for userId: String) async throws {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        guard !newGuids.isEmpty else { return }
        
        do {
            let subscriptionRef = db.collection("users").document(userId)
                .collection("rssSubscriptions").document(subscriptionId)
            
            // Use batch writes for efficiency (up to 500 at a time)
            let batch = db.batch()
            
            for guid in newGuids {
                // Sanitize GUID for use as document ID (Firestore doesn't allow slashes)
                let sanitizedGuid = sanitizeGuidForDocumentId(guid)
                let episodeRef = subscriptionRef.collection("importedEpisodes").document(sanitizedGuid)
                batch.setData([
                    "importedAt": FieldValue.serverTimestamp(),
                    "guid": guid, // Store original GUID in the document
                    "sanitizedGuid": sanitizedGuid
                ], forDocument: episodeRef, merge: true) // merge: true prevents overwriting if exists
            }
            
            // Update subscription's updatedAt timestamp
            batch.updateData([
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: subscriptionRef)
            
            try await batch.commit()
            
            print("✅ Added \(newGuids.count) episode GUIDs to subscription subcollection: \(subscriptionId)")
            
        } catch {
            if error is RSSSubscriptionError {
                throw error
            }
            print("❌ Failed to add episode GUIDs to subcollection: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Updates the last checked timestamp for a subscription
    /// - Parameters:
    ///   - subscriptionId: The subscription document ID
    ///   - userId: The user ID who owns the subscription
    /// - Throws: RSSSubscriptionError if update fails
    func updateLastChecked(for subscriptionId: String, userId: String) async throws {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        do {
            let subscriptionRef = db.collection("users").document(userId).collection("rssSubscriptions").document(subscriptionId)
            
            try await subscriptionRef.updateData([
                "lastChecked": Timestamp(),
                "updatedAt": Timestamp()
            ])
            
            print("✅ Updated last checked for subscription: \(subscriptionId)")
            
        } catch {
            print("❌ Failed to update last checked: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Delete Subscription
    
    /// Deletes (deactivates) an RSS subscription and its associated stream
    /// - Parameters:
    ///   - subscriptionId: The subscription document ID
    ///   - userId: The user ID who owns the subscription
    /// - Throws: RSSSubscriptionError if deletion fails
    func deleteSubscription(id subscriptionId: String, for userId: String) async throws {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        do {
            // Get subscription to find associated stream
            let subscription = try await getSubscription(id: subscriptionId, for: userId)
            
            // Use transaction to deactivate both subscription and stream atomically
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                
                let subscriptionRef = self.db.collection("users").document(userId).collection("rssSubscriptions").document(subscriptionId)
                
                // Deactivate subscription
                transaction.updateData([
                    "isActive": false,
                    "updatedAt": Timestamp()
                ], forDocument: subscriptionRef)
                
                // Deactivate associated stream if it exists
                if let streamId = subscription.streamId {
                    let streamRef = self.db.collection("rssStreams").document(streamId)
                    transaction.updateData([
                        "isActive": false,
                        "updatedAt": Timestamp()
                    ], forDocument: streamRef)
                }
                
                return nil
            }
            
            print("✅ Deleted (deactivated) RSS subscription and stream: \(subscriptionId)")
            
        } catch {
            if error is RSSSubscriptionError {
                throw error
            }
            print("❌ Failed to delete RSS subscription: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Feed Matching
    
    /// Finds existing subscription that matches the given feed data
    /// - Parameters:
    ///   - feedTitle: The feed title to match
    ///   - feedDescription: The feed description to match
    ///   - userId: The user ID to search within
    /// - Returns: Matching subscription if found
    /// - Throws: RSSSubscriptionError if search fails
    func findMatchingSubscription(feedTitle: String, feedDescription: String?, for userId: String) async throws -> RSSSubscription? {
        let subscriptions = try await getActiveSubscriptions(for: userId)
        
        return subscriptions.first { subscription in
            subscription.matchesFeed(title: feedTitle, description: feedDescription)
        }
    }
    
    /// Removes episode GUIDs from subscription tracking subcollection (when episodes are deleted)
    /// - Parameters:
    ///   - guidsToRemove: Episode GUIDs to remove from tracking
    ///   - subscriptionId: The subscription document ID
    ///   - userId: The user ID who owns the subscription
    /// - Throws: RSSSubscriptionError if update fails
    func removeImportedEpisodeGuids(_ guidsToRemove: [String], from subscriptionId: String, for userId: String) async throws {
        print("🗑️ [RSSSubscriptionService] ===== GUID REMOVAL START =====")
        print("🗑️ [RSSSubscriptionService] Subscription ID: \(subscriptionId)")
        print("🗑️ [RSSSubscriptionService] GUIDs to remove: \(guidsToRemove)")
        
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        guard !guidsToRemove.isEmpty else { return }
        
        do {
            let subscriptionRef = db.collection("users").document(userId)
                .collection("rssSubscriptions").document(subscriptionId)
            
            // Use batch deletes for efficiency (up to 500 at a time)
            let batch = db.batch()
            
            for guid in guidsToRemove {
                // Sanitize GUID for document ID lookup
                let sanitizedGuid = sanitizeGuidForDocumentId(guid)
                let episodeRef = subscriptionRef.collection("importedEpisodes").document(sanitizedGuid)
                batch.deleteDocument(episodeRef)
                print("🗑️ [RSSSubscriptionService] Removing GUID from subcollection: \(guid)")
            }
            
            // Update subscription's updatedAt timestamp
            batch.updateData([
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: subscriptionRef)
            
            try await batch.commit()
            
            print("✅ [RSSSubscriptionService] SUCCESS: Removed \(guidsToRemove.count) episode GUIDs from subcollection")
            print("🗑️ [RSSSubscriptionService] ===== GUID REMOVAL COMPLETE =====")
            
        } catch {
            print("❌ [RSSSubscriptionService] GUID REMOVAL FAILED: \(error.localizedDescription)")
            print("🗑️ [RSSSubscriptionService] ===== GUID REMOVAL FAILED =====")
            if error is RSSSubscriptionError {
                throw error
            }
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Finds subscription that contains a specific episode GUID in its subcollection
    /// - Parameters:
    ///   - episodeGuid: The episode GUID to search for
    ///   - userId: The user ID to search within
    /// - Returns: Subscription ID if found
    /// - Throws: RSSSubscriptionError if search fails
    func findSubscriptionContaining(episodeGuid: String, for userId: String) async throws -> String? {
        let subscriptions = try await getActiveSubscriptions(for: userId)
        
        for subscription in subscriptions {
            guard let subscriptionId = subscription.id else { continue }
            
            // Check if episode exists in subcollection
            let isImported = try await isEpisodeImported(guid: episodeGuid, subscriptionId: subscriptionId, userId: userId)
            if isImported {
                return subscriptionId
            }
        }
        
        return nil
    }
    
    /// Checks if an episode GUID is imported in a subscription's subcollection
    /// - Parameters:
    ///   - guid: The episode GUID to check
    ///   - subscriptionId: The subscription document ID
    ///   - userId: The user ID who owns the subscription
    /// - Returns: True if the episode is imported, false otherwise
    /// - Throws: Error if Firestore query fails
    func isEpisodeImported(guid: String, subscriptionId: String, userId: String) async throws -> Bool {
        // Sanitize GUID for document ID lookup
        let sanitizedGuid = sanitizeGuidForDocumentId(guid)
        let episodeRef = db.collection("users").document(userId)
            .collection("rssSubscriptions").document(subscriptionId)
            .collection("importedEpisodes").document(sanitizedGuid)
        
        let doc = try await episodeRef.getDocument()
        return doc.exists
    }
    
    /// Fetches all imported episode GUIDs from a subscription's subcollection
    /// - Parameters:
    ///   - subscriptionId: The subscription document ID
    ///   - userId: The user ID who owns the subscription
    /// - Returns: Set of imported episode GUIDs
    /// - Throws: RSSSubscriptionError if fetch fails
    func getImportedEpisodeGuids(for subscriptionId: String, userId: String) async throws -> Set<String> {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("rssSubscriptions").document(subscriptionId)
                .collection("importedEpisodes")
                .getDocuments()
            
            let guids = Set(snapshot.documents.map { $0.documentID })
            print("📱 Retrieved \(guids.count) imported episode GUIDs from subcollection for subscription: \(subscriptionId)")
            return guids
            
        } catch {
            print("❌ Failed to get imported episode GUIDs: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Finds an existing subscription (active or inactive) by feed URL
    func findExistingSubscription(feedUrl: String, for userId: String) async throws -> RSSSubscription? {
        let query = db.collection("users").document(userId).collection("rssSubscriptions")
            .whereField("feedUrl", isEqualTo: feedUrl)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        do {
            return try document.data(as: RSSSubscription.self)
        } catch {
            print("❌ [RSSSubscriptionService] Failed to decode existing subscription: \(error)")
            return nil
        }
    }
    
    /// Creates subscription and stream atomically using Firestore transaction
    private func createSubscriptionWithStreamTransaction(_ subscription: RSSSubscription, rssData: RSSFeedData, userId: String) async throws -> (RSSSubscription, String) {
        
        let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            
            // 1. Create subscription document reference
            let subscriptionRef = self.db.collection("users").document(userId).collection("rssSubscriptions").document()
            
            // 2. Create stream document reference  
            let streamRef = self.db.collection("rssStreams").document()
            
            // 3. Create user stream reference
            let userStreamRef = self.db.collection("users").document(userId).collection("user-rss-streams").document(streamRef.documentID)
            
            // 4. Prepare subscription data with stream reference
            var subscriptionToSave = subscription
            subscriptionToSave.id = subscriptionRef.documentID
            subscriptionToSave.streamId = streamRef.documentID
            
            // 5. Prepare stream data
            let streamData = self.createStreamData(from: subscription, rssData: rssData, userId: userId, subscriptionId: subscriptionRef.documentID, streamId: streamRef.documentID)
            
            // 6. Prepare user stream reference data
            let userStreamData: [String: Any] = [
                "streamId": streamRef.documentID,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            // 7. Execute all writes atomically
            do {
                try transaction.setData(from: subscriptionToSave, forDocument: subscriptionRef)
                try transaction.setData(streamData, forDocument: streamRef)
                transaction.setData(userStreamData, forDocument: userStreamRef)
            } catch let transactionError as NSError {
                errorPointer?.pointee = transactionError
                return (subscriptionToSave, "")
            }
            
            return (subscriptionToSave, streamRef.documentID)
        }
        
        return result as! (RSSSubscription, String)
    }
    
    /// Creates stream data dictionary for Firestore
    private func createStreamData(from subscription: RSSSubscription, rssData: RSSFeedData, userId: String, subscriptionId: String, streamId: String) -> [String: Any] {
        return [
            "subscriptionId": subscriptionId,
            "userId": userId,
            "title": rssData.channelTitle,
            "description": rssData.channelDescription,
            "thumbnailUrl": rssData.channelImageURL ?? "",
            "episodeCount": 0,
            "feedUrl": subscription.feedUrl,
            "author": rssData.channelAuthor ?? NSNull(),
            "language": rssData.channelLanguage ?? NSNull(),
            "category": rssData.channelCategory ?? NSNull(),
            "explicit": false,    // RSSFeedData doesn't have explicit field
            "lastEpisodeDate": NSNull(),
            "likes": 0,
            "views": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isActive": true,
            "isPublic": true,
            "version": 1
        ]
    }
    
    /// Reactivates an inactive subscription and its associated stream
    func reactivateSubscriptionWithStream(_ subscription: RSSSubscription, rssData: RSSFeedData, for userId: String) async throws -> RSSSubscription {
        guard let subscriptionId = subscription.id else {
            throw RSSSubscriptionError.subscriptionNotFound
        }
        
        print("🔄 [RSSSubscriptionService] Reactivating subscription with stream: \(subscription.feedTitle)")
        
        // Check if stream exists, create if missing
        var streamId = subscription.streamId
        if let existingStreamId = streamId {
            let streamExists = try await checkStreamExists(existingStreamId)
            if !streamExists {
                print("🔄 [RSSSubscriptionService] Stream missing, creating new stream for reactivation")
                streamId = try await createStreamForSubscription(subscription, rssData: rssData, userId: userId)
            }
        } else {
            print("🔄 [RSSSubscriptionService] No streamId found, creating new stream for reactivation")
            streamId = try await createStreamForSubscription(subscription, rssData: rssData, userId: userId)
        }
        
        // Use transaction to reactivate both
        let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            
            let subscriptionRef = self.db.collection("users").document(userId).collection("rssSubscriptions").document(subscriptionId)
            
            // Update subscription
            let subscriptionUpdateData: [String: Any] = [
                "isActive": true,
                "streamId": streamId!,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            transaction.updateData(subscriptionUpdateData, forDocument: subscriptionRef)
            
            // Update stream if it exists
            if let streamId = streamId {
                let streamRef = self.db.collection("rssStreams").document(streamId)
                let streamUpdateData: [String: Any] = [
                    "isActive": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                transaction.updateData(streamUpdateData, forDocument: streamRef)
            }
            
            // Return updated subscription
            var reactivatedSubscription = subscription
            reactivatedSubscription.isActive = true
            reactivatedSubscription.streamId = streamId
            reactivatedSubscription.updatedAt = Timestamp()
            
            return reactivatedSubscription
        }
        
        return result as! RSSSubscription
    }
    
    /// Creates a stream for an existing subscription
    private func createStreamForSubscription(_ subscription: RSSSubscription, rssData: RSSFeedData, userId: String) async throws -> String {
        let streamRef = db.collection("rssStreams").document()
        let streamData = createStreamData(from: subscription, rssData: rssData, userId: userId, subscriptionId: subscription.id!, streamId: streamRef.documentID)
        
        try await streamRef.setData(streamData)
        return streamRef.documentID
    }
    
    /// Checks if a stream exists
    private func checkStreamExists(_ streamId: String) async throws -> Bool {
        let streamRef = db.collection("rssStreams").document(streamId)
        let document = try await streamRef.getDocument()
        return document.exists
    }
    
    // MARK: - Validation and Cleanup
    
    /// Validates subscription integrity and checks for orphaned data
    /// - Parameters:
    ///   - subscription: The subscription to validate
    ///   - userId: The user ID
    /// - Throws: RSSSubscriptionError if validation fails
    func validateSubscriptionIntegrity(_ subscription: RSSSubscription, userId: String) async throws {
        guard let streamId = subscription.streamId else {
            throw RSSSubscriptionError.missingStreamReference
        }
        
        // Check if stream actually exists
        let streamExists = try await checkStreamExists(streamId)
        if !streamExists {
            throw RSSSubscriptionError.orphanedSubscription
        }
    }
    
    /// Finds subscriptions without valid stream references
    /// - Parameter userId: The user ID to check
    /// - Returns: Array of orphaned subscriptions
    /// - Throws: RSSSubscriptionError if check fails
    func findOrphanedSubscriptions(for userId: String) async throws -> [RSSSubscription] {
        let subscriptions = try await getActiveSubscriptions(for: userId)
        var orphanedSubscriptions: [RSSSubscription] = []
        
        for subscription in subscriptions {
            if let streamId = subscription.streamId {
                if !(try await checkStreamExists(streamId)) {
                    orphanedSubscriptions.append(subscription)
                }
            } else {
                // Subscription missing streamId entirely
                orphanedSubscriptions.append(subscription)
            }
        }
        
        print("🔍 [RSSSubscriptionService] Found \(orphanedSubscriptions.count) orphaned subscriptions for user: \(userId)")
        return orphanedSubscriptions
    }
    
    /// Repairs orphaned subscription by creating missing stream
    /// - Parameters:
    ///   - subscription: The orphaned subscription
    ///   - rssData: RSS feed data for stream creation
    ///   - userId: The user ID
    /// - Returns: Updated subscription with stream reference
    /// - Throws: RSSSubscriptionError if repair fails
    func repairOrphanedSubscription(_ subscription: RSSSubscription, rssData: RSSFeedData, userId: String) async throws -> RSSSubscription {
        guard let subscriptionId = subscription.id else {
            throw RSSSubscriptionError.subscriptionNotFound
        }
        
        print("🔧 [RSSSubscriptionService] Repairing orphaned subscription: \(subscription.feedTitle)")
        
        // Create new stream for subscription
        let streamId = try await createStreamForSubscription(subscription, rssData: rssData, userId: userId)
        
        // Update subscription with stream reference
        let subscriptionRef = db.collection("users").document(userId).collection("rssSubscriptions").document(subscriptionId)
        try await subscriptionRef.updateData([
            "streamId": streamId,
            "updatedAt": Timestamp()
        ])
        
        // Return updated subscription
        var repairedSubscription = subscription
        repairedSubscription.streamId = streamId
        repairedSubscription.updatedAt = Timestamp()
        
        print("✅ [RSSSubscriptionService] Successfully repaired orphaned subscription: \(subscription.feedTitle)")
        return repairedSubscription
    }
    
    // MARK: - Health Monitoring (for future use)
    
    /// Gets all subscriptions that haven't been checked recently (for background health monitoring)
    /// - Parameter daysThreshold: Number of days since last check
    /// - Returns: Array of subscriptions needing health check
    func getSubscriptionsNeedingHealthCheck(daysThreshold: Int = 7) async throws -> [(subscription: RSSSubscription, userId: String)] {
        // This would be used for background health monitoring
        // For now, return empty array as health monitoring is not implemented
        return []
    }
    
    // MARK: - Helper Methods
    
    /// Sanitizes a GUID string to be safe for use as a Firestore document ID
    /// - Parameter guid: The original GUID string
    /// - Returns: A sanitized GUID safe for Firestore document IDs
    private func sanitizeGuidForDocumentId(_ guid: String) -> String {
        // Firestore document IDs cannot contain forward slashes or backslashes
        return guid
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }
}
