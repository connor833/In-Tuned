//
//  MigrationService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import Firebase
//import FirebaseFirestoreSwift
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

enum RepostMigrationStatus: Equatable {
    case notStarted
    case inProgress
    case completed
    case failed(Error)
    
    static func == (lhs: RepostMigrationStatus, rhs: RepostMigrationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted), (.inProgress, .inProgress), (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - MigrationService

struct MigrationService {
    private let db = Firestore.firestore()
    
    // MARK: - Conversation Migration Functions
    
    /// Migrates all conversations to the new model with essential fields
    /// - Parameters:
    ///   - batchSize: Number of conversations to process at once
    ///   - completion: Completion handler with migration results
    func migrateAllConversations(batchSize: Int = 50, completion: @escaping (MigrationResult) -> Void) {
        print("🔄 MigrationService: Starting conversation migration...")
        
        let conversationsRef = db.collection("conversations")
        var lastDocument: DocumentSnapshot?
        var totalProcessed = 0
        var totalMigrated = 0
        var totalErrors = 0
        
        func processBatch() {
            var query = conversationsRef.limit(to: batchSize)
            
            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }
            
            query.getDocuments { snapshot, error in
                if let error = error {
                    print("❌ MigrationService: Error fetching conversations: \(error)")
                    completion(MigrationResult(migrated: totalMigrated, errors: totalErrors, total: totalProcessed))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    // No more documents to process
                    print("✅ MigrationService: Conversation migration completed!")
                    completion(MigrationResult(migrated: totalMigrated, errors: totalErrors, total: totalProcessed))
                    return
                }
                
                print("🔄 MigrationService: Processing batch of \(documents.count) conversations...")
                
                let group = DispatchGroup()
                
                for document in documents {
                    group.enter()
                    self.migrateSingleConversation(document: document) { success in
                        if success {
                            totalMigrated += 1
                        } else {
                            totalErrors += 1
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    totalProcessed += documents.count
                    lastDocument = documents.last
                    print("📊 MigrationService: Processed \(totalProcessed) conversations. Migrated: \(totalMigrated), Errors: \(totalErrors)")
                    
                    // Continue with next batch
                    processBatch()
                }
            }
        }
        
        processBatch()
    }
    
    /// Migrates a single conversation to the new model
    /// - Parameters:
    ///   - document: The conversation document to migrate
    ///   - completion: Completion handler with success status
    private func migrateSingleConversation(document: DocumentSnapshot, completion: @escaping (Bool) -> Void) {
        guard let data = document.data() else {
            print("❌ MigrationService: No data found for conversation \(document.documentID)")
            completion(false)
            return
        }
        
        let conversationId = document.documentID
        let currentTime = Date()
        
        // Check if conversation already has new fields
        if data["version"] != nil {
            print("⏭️ MigrationService: Conversation \(conversationId) already migrated, skipping")
            completion(true)
            return
        }
        
        // Prepare update data with new fields
        var updateData: [String: Any] = [
            "version": 1,
            "maxParticipants": 50,  // Default for all conversations
            "isReported": false,
            "moderationStatus": "approved",
            "contentWarnings": [],
            "isMuted": false,
            "totalMessages": 0,
            "lastMessageAt": currentTime,
            "lastSeenBy": [:]
        ]
        
        // Add group-specific fields if it's a group conversation
        if let type = data["type"] as? String, type == "group" {
            updateData["avatarUrl"] = nil
            if data["name"] == nil {
                updateData["name"] = "Group Chat"
            }
        }
        
        // Update the conversation document
        document.reference.updateData(updateData) { error in
            if let error = error {
                print("❌ MigrationService: Error updating conversation \(conversationId): \(error)")
                completion(false)
            } else {
                print("✅ MigrationService: Successfully migrated conversation \(conversationId)")
                
                // Also update user conversation metadata
                self.updateUserConversationMetadata(conversationId: conversationId, participants: data["participants"] as? [String] ?? []) { success in
                    completion(success)
                }
            }
        }
    }
    
    /// Updates user conversation metadata for all participants
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - participants: Array of participant user IDs
    ///   - completion: Completion handler with success status
    private func updateUserConversationMetadata(conversationId: String, participants: [String], completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var successCount = 0
        let currentTime = Date()
        
        for participantId in participants {
            group.enter()
            
            let userConversationRef = db.collection("users")
                .document(participantId)
                .collection("conversations")
                .document(conversationId)
            
            let metadataUpdate: [String: Any] = [
                "isMuted": false,
                "isPinned": false,
                "notificationSettings": [:]
            ]
            
            userConversationRef.updateData(metadataUpdate) { error in
                if let error = error {
                    print("❌ MigrationService: Error updating metadata for user \(participantId): \(error)")
                } else {
                    successCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let success = successCount == participants.count
            if success {
                print("✅ MigrationService: Updated metadata for all \(participants.count) participants")
            } else {
                print("⚠️ MigrationService: Updated metadata for \(successCount)/\(participants.count) participants")
            }
            completion(success)
        }
    }
    
    // MARK: - User Migration Functions
    
    /// Migrates a user to the latest data model version
    /// - Parameters:
    ///   - userId: The user ID to migrate
    ///   - completion: Completion handler with success status and error
    func migrateUserToLatest(userId: String, completion: @escaping (Bool, Error?) -> Void) {
        print("🔄 MigrationService: Starting migration for user \(userId)")
        
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("❌ MigrationService: Error fetching user document: \(error)")
                completion(false, error)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ MigrationService: User document does not exist")
                completion(false, NSError(domain: "MigrationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }
            
            let userData = document.data()
            let currentVersion = userData?["version"] as? Int ?? 0
            
            print("🔍 MigrationService: Current user version: \(currentVersion)")
            
            // Check if migration is needed
            if currentVersion >= 1 {
                print("✅ MigrationService: User already at latest version")
                completion(true, nil)
                return
            }
            
            // Perform migration to version 1
            self.migrateToVersion1(userRef: userRef, currentData: userData ?? [:]) { success, error in
                if success {
                    print("✅ MigrationService: Successfully migrated user to version 1")
                } else {
                    print("❌ MigrationService: Failed to migrate user: \(error?.localizedDescription ?? "Unknown error")")
                }
                completion(success, error)
            }
        }
    }
    
    /// Migrates user to version 1 (adds essential production fields)
    private func migrateToVersion1(userRef: DocumentReference, currentData: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        print("🔄 MigrationService: Migrating to version 1")
        
        let updateData: [String: Any] = [
            "isActive": true,
            "termsAcceptedAt": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp(),
            "version": 1
        ]
        
        userRef.updateData(updateData) { error in
            if let error = error {
                print("❌ MigrationService: Error updating user to version 1: \(error)")
                completion(false, error)
            } else {
                print("✅ MigrationService: Successfully updated user to version 1")
                completion(true, nil)
            }
        }
    }
    
    /// Migrates all users in a batch (for admin use)
    /// - Parameters:
    ///   - batchSize: Number of users to process at once
    ///   - completion: Completion handler with migration results
    func migrateAllUsers(batchSize: Int = 100, completion: @escaping (MigrationResult) -> Void) {
        print("🔄 MigrationService: Starting batch migration of all users")
        
        var migratedCount = 0
        var errorCount = 0
        var lastDocument: DocumentSnapshot?
        
        func processBatch() {
            var query = db.collection("users")
                .order(by: "createdAt")
                .limit(to: batchSize)
            
            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }
            
            query.getDocuments { snapshot, error in
                if let error = error {
                    print("❌ MigrationService: Error fetching users batch: \(error)")
                    completion(MigrationResult(migrated: migratedCount, errors: errorCount, total: migratedCount + errorCount))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("✅ MigrationService: Batch migration complete")
                    completion(MigrationResult(migrated: migratedCount, errors: errorCount, total: migratedCount + errorCount))
                    return
                }
                
                let group = DispatchGroup()
                
                for document in documents {
                    group.enter()
                    let userId = document.documentID
                    
                    self.migrateUserToLatest(userId: userId) { success, error in
                        if success {
                            migratedCount += 1
                        } else {
                            errorCount += 1
                            print("❌ MigrationService: Failed to migrate user \(userId): \(error?.localizedDescription ?? "Unknown error")")
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    lastDocument = documents.last
                    print("📊 MigrationService: Processed batch - Migrated: \(migratedCount), Errors: \(errorCount)")
                    processBatch() // Continue with next batch
                }
            }
        }
        
        processBatch()
    }
    
    /// Checks if a user needs migration
    /// - Parameters:
    ///   - userId: The user ID to check
    ///   - completion: Completion handler with migration status
    func checkUserMigrationStatus(userId: String, completion: @escaping (MigrationStatus) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("❌ MigrationService: Error checking user migration status: \(error)")
                completion(.error(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.notFound)
                return
            }
            
            let userData = document.data()
            let currentVersion = userData?["version"] as? Int ?? 0
            
            if currentVersion >= 1 {
                completion(.upToDate)
            } else {
                completion(.needsMigration(currentVersion: currentVersion, targetVersion: 1))
            }
        }
    }
    
    /// Migrates current user on app launch (called from AuthViewModel)
    func migrateCurrentUserIfNeeded(completion: @escaping (Bool) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        checkUserMigrationStatus(userId: currentUserId) { status in
            switch status {
            case .upToDate:
                print("✅ MigrationService: Current user is up to date")
                completion(true)
            case .needsMigration:
                print("🔄 MigrationService: Current user needs migration, starting...")
                self.migrateUserToLatest(userId: currentUserId) { success, error in
                    completion(success)
                }
            case .notFound:
                print("❌ MigrationService: Current user document not found")
                completion(false)
            case .error(let error):
                print("❌ MigrationService: Error checking migration status: \(error)")
                completion(false)
            }
        }
    }
    
    // MARK: - Pod Migration Functions
    
    /// Checks the migration status for pods
    func checkPodMigrationStatus(completion: @escaping ([String: Any]) -> Void) {
        Task {
            do {
                let functions = Functions.functions()
                let getStatus = functions.httpsCallable("getPodMigrationStatus")
                let result = try await getStatus.call()
                
                if let data = result.data as? [String: Any] {
                    await MainActor.run {
                        print("📊 Pod Migration Status:")
                        print("Total pods: \(data["totalPods"] ?? 0)")
                        print("Estimated needing migration: \(data["estimatedNeedingMigration"] ?? 0)")
                        print("Sample size: \(data["sampleSize"] ?? 0)")
                        print("Missing fields in sample: \(data["missingFieldsInSample"] ?? 0)")
                        completion(data)
                    }
                }
            } catch {
                print("❌ Error checking pod migration status: \(error.localizedDescription)")
                await MainActor.run {
                    completion([:])
                }
            }
        }
    }
    
    /// Starts migrating pods to include new engagement metrics and metadata fields
    func startPodMigration(batchSize: Int = 100, startAfterDocId: String? = nil, completion: @escaping ([String: Any]) -> Void) {
        Task {
            do {
                let functions = Functions.functions()
                let migratePods = functions.httpsCallable("migratePodsToNewVersion")
                
                var data: [String: Any] = ["batchSize": batchSize]
                if let startAfterDocId = startAfterDocId {
                    data["startAfterDocId"] = startAfterDocId
                }
                
                let result = try await migratePods.call(data)
                
                if let resultData = result.data as? [String: Any] {
                    await MainActor.run {
                        completion(resultData)
                    }
                }
            } catch {
                print("❌ Error migrating pods: \(error.localizedDescription)")
                await MainActor.run {
                    completion(["error": error.localizedDescription])
                }
            }
        }
    }
    
    // MARK: - Repost Migration Functions
    
    /// Checks the status of repost migration
    func checkRepostMigrationStatus(completion: @escaping (RepostMigrationStatus) -> Void) {
        print("🔍 Checking repost migration status...")
        print("🔍 Current user: \(Auth.auth().currentUser?.uid ?? "nil")")
        
        // Refresh the user's token to ensure it's valid
        Auth.auth().currentUser?.getIDToken { token, error in
            if let error = error {
                print("❌ Error getting ID token: \(error)")
                completion(.failed(error))
                return
            }
            
            print("🔍 ID token obtained: \(token != nil ? "success" : "failed")")
            
            let functions = Functions.functions()
            let function = functions.httpsCallable("getRepostMigrationStatus")
            
            function.call([:]) { result, error in
                if let error = error {
                    print("❌ Error checking repost migration status: \(error)")
                    completion(.failed(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let status = data["status"] as? String else {
                    completion(.failed(NSError(domain: "MigrationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                    return
                }
                
                switch status {
                case "not_started":
                    completion(.notStarted)
                case "in_progress":
                    completion(.inProgress)
                case "completed":
                    completion(.completed)
                default:
                    completion(.failed(NSError(domain: "MigrationService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown status: \(status)"])))
                }
            }
        }
    }
    
    /// Starts the repost migration process
    func startRepostMigration(completion: @escaping (RepostMigrationStatus) -> Void) {
        let functions = Functions.functions()
        let function = functions.httpsCallable("migrateRepostsToNewVersion")
        
        function.call([:]) { result, error in
            if let error = error {
                print("❌ Error starting repost migration: \(error)")
                completion(.failed(error))
                return
            }
            
            guard let data = result?.data as? [String: Any],
                  let success = data["success"] as? Bool else {
                completion(.failed(NSError(domain: "MigrationService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            if success {
                completion(.completed)
            } else {
                let errorMessage = data["error"] as? String ?? "Unknown error"
                completion(.failed(NSError(domain: "MigrationService", code: 4, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
        }
    }
    
    /// Migrates reposts from user subcollections to main collection
    func migrateRepostsToMainCollection(completion: @escaping (RepostMigrationStatus) -> Void) {
        let functions = Functions.functions()
        let function = functions.httpsCallable("migrateRepostsToMainCollection")
        
        function.call([:]) { result, error in
            if let error = error {
                print("❌ Error migrating reposts to main collection: \(error)")
                completion(.failed(error))
                return
            }
            
            guard let data = result?.data as? [String: Any],
                  let success = data["success"] as? Bool else {
                completion(.failed(NSError(domain: "MigrationService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            if success {
                completion(.completed)
            } else {
                let errorMessage = data["error"] as? String ?? "Unknown error"
                completion(.failed(NSError(domain: "MigrationService", code: 6, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
        }
    }
}

// MARK: - Pod Migration Service (ObservableObject wrapper)

class PodMigrationService: ObservableObject {
    @Published var isMigrating = false
    @Published var migrationProgress = ""
    @Published var migrationStatus: PodMigrationStatus?
    
    enum PodMigrationStatus: Equatable {
        case notStarted
        case inProgress
        case completed
        case failed(String)
        
        static func == (lhs: PodMigrationStatus, rhs: PodMigrationStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted),
                 (.inProgress, .inProgress),
                 (.completed, .completed):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    private let migrationService = MigrationService()
    
    // MARK: - Migration Status
    
    func checkMigrationStatus() {
        migrationService.checkPodMigrationStatus { data in
            // Status check doesn't change migration state, just logs info
        }
    }
    
    // MARK: - Start Migration
    
    func startMigration(batchSize: Int = 100) {
        guard !isMigrating else { return }
        
        isMigrating = true
        migrationStatus = .inProgress
        migrationProgress = "Starting migration..."
        
        Task {
            await migratePodsBatch(batchSize: batchSize, startAfterDocId: nil)
        }
    }
    
    // MARK: - Migration Process
    
    private func migratePodsBatch(batchSize: Int, startAfterDocId: String?) async {
        migrationService.startPodMigration(batchSize: batchSize, startAfterDocId: startAfterDocId) { result in
            Task { @MainActor in
                let migratedCount = result["migratedCount"] as? Int ?? 0
                let hasMore = result["hasMore"] as? Bool ?? false
                let lastDocId = result["lastDocId"] as? String
                let message = result["message"] as? String ?? ""
                
                self.migrationProgress = message
                print("✅ \(message)")
                
                if hasMore, let lastDocId = lastDocId {
                    // Continue with next batch
                    Task {
                        await self.migratePodsBatch(batchSize: batchSize, startAfterDocId: lastDocId)
                    }
                } else {
                    // Migration complete
                    self.isMigrating = false
                    self.migrationStatus = .completed
                    self.migrationProgress = "Migration completed successfully!"
                    print("🎉 Pod migration completed!")
                }
            }
        }
    }
    
    // MARK: - Reset Migration State
    
    func resetMigrationState() {
        isMigrating = false
        migrationStatus = .notStarted
        migrationProgress = ""
    }
}

// MARK: - Migration Result Types

struct MigrationResult {
    let migrated: Int
    let errors: Int
    let total: Int
    
    var successRate: Double {
        guard total > 0 else { return 0.0 }
        return Double(migrated) / Double(total)
    }
}

enum MigrationStatus {
    case upToDate
    case needsMigration(currentVersion: Int, targetVersion: Int)
    case notFound
    case error(Error)
}

