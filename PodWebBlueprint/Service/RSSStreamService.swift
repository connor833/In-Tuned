import Foundation
import FirebaseFirestore
import Firebase
import Combine

// MARK: - RSS Stream Service

class RSSStreamService: ObservableObject {
    
    private let db = Firestore.firestore()
    
    // MARK: - Stream Management
    
    /// Gets an RSS stream by ID
    /// - Parameter streamId: The stream document ID
    /// - Returns: The RSS stream
    /// - Throws: RSSSubscriptionError if not found
    func getStream(id streamId: String) async throws -> RSSStream {
        do {
            let document = try await db.collection("rssStreams").document(streamId).getDocument()
            
            guard document.exists else {
                throw RSSSubscriptionError.subscriptionNotFound
            }
            
            let stream = try document.data(as: RSSStream.self)
            return stream
            
        } catch {
            if error is RSSSubscriptionError {
                throw error
            }
            print("❌ Failed to get RSS stream: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Gets all RSS streams for a user
    /// - Parameter userId: The user ID to get streams for
    /// - Returns: Array of RSS streams
    /// - Throws: RSSSubscriptionError if fetch fails
    func getUserStreams(for userId: String) async throws -> [RSSStream] {
        guard !userId.isEmpty else {
            throw RSSSubscriptionError.invalidUserId
        }
        
        do {
            let snapshot = try await db.collection("rssStreams")
                .whereField("userId", isEqualTo: userId)
                .whereField("isActive", isEqualTo: true)
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            let streams = try snapshot.documents.compactMap { document in
                try document.data(as: RSSStream.self)
            }
            
            print("📱 Retrieved \(streams.count) RSS streams for user: \(userId)")
            return streams
            
        } catch {
            print("❌ Failed to get RSS streams: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Gets public RSS streams for discovery
    /// - Parameters:
    ///   - limit: Maximum number of streams to return
    ///   - lastDocument: For pagination
    /// - Returns: Array of public RSS streams
    /// - Throws: RSSSubscriptionError if fetch fails
    func getPublicStreams(limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> [RSSStream] {
        do {
            var query = db.collection("rssStreams")
                .whereField("isActive", isEqualTo: true)
                .whereField("isPublic", isEqualTo: true)
                .order(by: "likes", descending: true)
                .limit(to: limit)
            
            if let lastDocument = lastDocument {
                query = query.start(afterDocument: lastDocument)
            }
            
            let snapshot = try await query.getDocuments()
            
            let streams = try snapshot.documents.compactMap { document in
                try document.data(as: RSSStream.self)
            }
            
            print("🌍 Retrieved \(streams.count) public RSS streams")
            return streams
            
        } catch {
            print("❌ Failed to get public RSS streams: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Episode Management
    
    /// Adds episode (pod) IDs to a stream's episodes subcollection
    /// - Parameters:
    ///   - podIds: Array of pod document IDs to add
    ///   - streamId: The stream document ID
    /// - Throws: RSSSubscriptionError if update fails
    func addEpisodesToStream(_ podIds: [String], to streamId: String) async throws {
        guard !podIds.isEmpty else {
            print("⚠️ [RSSStreamService] No pod IDs provided to add")
            return
        }
        
        print("📡 [RSSStreamService] ===== ADDING EPISODES TO STREAM =====")
        print("📡 [RSSStreamService] Stream ID: \(streamId)")
        print("📡 [RSSStreamService] Number of pods to add: \(podIds.count)")
        print("📡 [RSSStreamService] Pod IDs: \(podIds)")
        
        do {
            let streamRef = db.collection("rssStreams").document(streamId)
            let episodesRef = streamRef.collection("episodes")
            
            print("📡 [RSSStreamService] Creating batch operation...")
            
            // Use batch to add all episodes atomically
            let batch = db.batch()
            
            // Add each pod ID as a document in episodes subcollection
            for (index, podId) in podIds.enumerated() {
                let episodeDoc = episodesRef.document(podId)
                batch.setData([:], forDocument: episodeDoc) // Empty document, ID is the key
                print("📡 [RSSStreamService] Added pod \(index + 1)/\(podIds.count) to batch: \(podId)")
            }
            
            // Update episode count and last episode date
            // Use setData with merge to ensure it works even for new streams
            let updateData: [String: Any] = [
                "episodeCount": FieldValue.increment(Int64(podIds.count)),
                "lastEpisodeDate": Timestamp(),
                "updatedAt": Timestamp()
            ]
            batch.setData(updateData, forDocument: streamRef, merge: true)
            print("📡 [RSSStreamService] Added stream metadata update to batch (merge mode)")
            
            print("📡 [RSSStreamService] Committing batch...")
            try await batch.commit()
            
            print("✅ [RSSStreamService] SUCCESS! Added \(podIds.count) episodes to stream: \(streamId)")
            print("✅ [RSSStreamService] ===== EPISODES ADDED =====")
            
        } catch {
            print("❌ [RSSStreamService] ===== BATCH COMMIT FAILED =====")
            print("❌ [RSSStreamService] Error: \(error.localizedDescription)")
            print("❌ [RSSStreamService] Error details: \(error)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Removes episode (pod) IDs from a stream's episodes subcollection
    /// - Parameters:
    ///   - podIds: Array of pod document IDs to remove
    ///   - streamId: The stream document ID
    /// - Throws: RSSSubscriptionError if update fails
    func removeEpisodesFromStream(_ podIds: [String], from streamId: String) async throws {
        guard !podIds.isEmpty else { return }
        
        print("🗑️ [RSSStreamService] Removing \(podIds.count) episodes from stream: \(streamId)")
        
        do {
            let streamRef = db.collection("rssStreams").document(streamId)
            let episodesRef = streamRef.collection("episodes")
            
            // Use batch to remove all episodes atomically
            let batch = db.batch()
            
            // Remove each pod ID document from episodes subcollection
            for podId in podIds {
                let episodeDoc = episodesRef.document(podId)
                batch.deleteDocument(episodeDoc)
            }
            
            // Update episode count
            batch.updateData([
                "episodeCount": FieldValue.increment(Int64(-podIds.count)),
                "updatedAt": Timestamp()
            ], forDocument: streamRef)
            
            try await batch.commit()
            
            print("✅ [RSSStreamService] Removed \(podIds.count) episodes from stream: \(streamId)")
            
        } catch {
            print("❌ [RSSStreamService] Failed to remove episodes from stream: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Gets all episode (pod) IDs for a stream
    /// - Parameter streamId: The stream document ID
    /// - Returns: Array of pod document IDs
    /// - Throws: RSSSubscriptionError if fetch fails
    func getStreamEpisodeIds(_ streamId: String) async throws -> [String] {
        do {
            let episodesRef = db.collection("rssStreams").document(streamId).collection("episodes")
            let snapshot = try await episodesRef.getDocuments()
            
            let podIds = snapshot.documents.map { $0.documentID }
            
            print("📱 [RSSStreamService] Retrieved \(podIds.count) episode IDs for stream: \(streamId)")
            return podIds
            
        } catch {
            print("❌ [RSSStreamService] Failed to get stream episodes: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Stream Updates
    
    /// Updates stream metadata (likes, views, etc.)
    /// - Parameters:
    ///   - streamId: The stream document ID
    ///   - updates: Dictionary of fields to update
    /// - Throws: RSSSubscriptionError if update fails
    func updateStreamMetadata(_ streamId: String, updates: [String: Any]) async throws {
        guard !updates.isEmpty else { return }
        
        do {
            let streamRef = db.collection("rssStreams").document(streamId)
            var updateData = updates
            updateData["updatedAt"] = Timestamp()
            
            try await streamRef.updateData(updateData)
            
            print("✅ [RSSStreamService] Updated stream metadata: \(streamId)")
            
        } catch {
            print("❌ [RSSStreamService] Failed to update stream metadata: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
    
    /// Updates RSS stream details (title, description, thumbnailUrl)
    /// - Parameters:
    ///   - streamId: The stream document ID
    ///   - title: New title (optional)
    ///   - description: New description (optional)
    ///   - thumbnailUrl: New thumbnail URL (optional)
    /// - Throws: RSSSubscriptionError if update fails
    func updateStreamDetails(_ streamId: String, title: String? = nil, description: String? = nil, thumbnailUrl: String? = nil) async throws {
        var updates: [String: Any] = [:]
        
        if let title = title {
            updates["title"] = title
        }
        if let description = description {
            updates["description"] = description
        }
        if let thumbnailUrl = thumbnailUrl {
            updates["thumbnailUrl"] = thumbnailUrl
        }
        
        guard !updates.isEmpty else {
            print("⚠️ [RSSStreamService] No updates provided for stream details")
            return
        }
        
        try await updateStreamMetadata(streamId, updates: updates)
        print("✅ [RSSStreamService] Updated stream details: \(streamId)")
    }
    
    /// Increments stream likes
    /// - Parameter streamId: The stream document ID
    /// - Throws: RSSSubscriptionError if update fails
    func incrementStreamLikes(_ streamId: String) async throws {
        try await updateStreamMetadata(streamId, updates: [
            "likes": FieldValue.increment(Int64(1))
        ])
    }
    
    /// Increments stream views
    /// - Parameter streamId: The stream document ID
    /// - Throws: RSSSubscriptionError if update fails
    func incrementStreamViews(_ streamId: String) async throws {
        try await updateStreamMetadata(streamId, updates: [
            "views": FieldValue.increment(Int64(1))
        ])
    }
    
    /// Soft deletes a stream (sets isActive to false)
    /// - Parameter streamId: The stream document ID
    /// - Throws: RSSSubscriptionError if update fails
    func deactivateStream(_ streamId: String) async throws {
        try await updateStreamMetadata(streamId, updates: [
            "isActive": false
        ])
        
        print("✅ [RSSStreamService] Deactivated stream: \(streamId)")
    }
    
    /// Reactivates a stream (sets isActive to true)
    /// - Parameter streamId: The stream document ID
    /// - Throws: RSSSubscriptionError if update fails
    func reactivateStream(_ streamId: String) async throws {
        try await updateStreamMetadata(streamId, updates: [
            "isActive": true
        ])
        
        print("✅ [RSSStreamService] Reactivated stream: \(streamId)")
    }
    
    // MARK: - Search and Discovery
    
    /// Searches RSS streams by title
    /// - Parameters:
    ///   - searchTerm: The search term
    ///   - limit: Maximum number of results
    /// - Returns: Array of matching streams
    /// - Throws: RSSSubscriptionError if search fails
    func searchStreams(term searchTerm: String, limit: Int = 20) async throws -> [RSSStream] {
        guard !searchTerm.isEmpty else { return [] }
        
        do {
            // Firestore doesn't support full-text search, so we'll search by title prefix
            let lowercaseSearchTerm = searchTerm.lowercased()
            
            let snapshot = try await db.collection("rssStreams")
                .whereField("isActive", isEqualTo: true)
                .whereField("isPublic", isEqualTo: true)
                .whereField("title", isGreaterThanOrEqualTo: searchTerm)
                .whereField("title", isLessThan: searchTerm + "\u{f8ff}")
                .limit(to: limit)
                .getDocuments()
            
            let streams = try snapshot.documents.compactMap { document in
                try document.data(as: RSSStream.self)
            }
            
            // Filter results that actually contain the search term (case-insensitive)
            let filteredStreams = streams.filter { stream in
                stream.title.lowercased().contains(lowercaseSearchTerm) ||
                (stream.description?.lowercased().contains(lowercaseSearchTerm) ?? false) ||
                (stream.author?.lowercased().contains(lowercaseSearchTerm) ?? false)
            }
            
            print("🔍 [RSSStreamService] Found \(filteredStreams.count) streams for search: \(searchTerm)")
            return filteredStreams
            
        } catch {
            print("❌ [RSSStreamService] Failed to search streams: \(error.localizedDescription)")
            throw RSSSubscriptionError.databaseError(error.localizedDescription)
        }
    }
}
