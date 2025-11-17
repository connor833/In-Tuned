//
//  ConversationService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/23.
//

import Foundation
import Firebase
import FirebaseFirestore
//import FirebaseFirestoreSwift
import FirebaseFunctions
import SwiftUI
import FirebaseAuth

class ConversationService: ObservableObject {
    private let db = Firestore.firestore()
    private let blockService = BlockService() // Add blocking service
    
    // MARK: - Caching Properties
    private var blockingCache: [String: (result: Bool, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // MARK: - Engagement Metrics
    
    private func incrementPodShares(podId: String) {
        guard !podId.isEmpty else { return }
        
        Task {
            do {
                let functions = Functions.functions()
                let incrementShares = functions.httpsCallable("incrementPodShares")
                let result = try await incrementShares.call(["podId": podId, "shareType": "direct"])
                print("✅ Successfully incremented shares for pod: \(podId)")
            } catch {
                print("❌ Error incrementing pod shares: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Create Conversation
    
    func createConversation(participants: [String], completion: @escaping (String?) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        // Check if any participants are blocked
        checkForBlockedUsers(participants: participants) { hasBlockedUsers in
            if hasBlockedUsers {
                print("Cannot create conversation - blocked users detected")
                completion(nil)
                return
            }
            
            self.createConversationInternal(participants: participants, completion: completion)
        }
    }
    
    
    private func createConversationInternal(participants: [String], completion: @escaping (String?) -> Void) {
        createConversationInternal(participants: participants, type: .oneOnOne, name: nil, description: nil, completion: completion)
    }
    
    private func createConversationInternal(participants: [String], type: ConversationType, name: String?, description: String?, completion: @escaping (String?) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let conversationId = UUID().uuidString
        let currentTime = Date()
        
        // Determine conversation type and set appropriate fields
        let isGroup = type == .group
        let maxParticipants = isGroup ? 50 : 2
        
        var conversationData: [String: Any] = [
            "type": type.rawValue,
            "participants": participants,
            "lastActivity": currentTime,
            "createdAt": currentTime,
            "createdBy": currentUid,
            
            // Essential production fields
            "version": 1,
            
            // Group-specific fields
            "maxParticipants": maxParticipants,
            
            // Content moderation
            "isReported": false,
            "moderationStatus": "approved",
            "contentWarnings": [],
            "isMuted": false,
            
            // Analytics
            "totalMessages": 0,
            "lastMessageAt": currentTime,
            "lastSeenBy": [:]
        ]
        
        // Add group-specific fields if it's a group
        if isGroup {
            conversationData["name"] = name ?? "Group Chat"
        } else {
            // One-on-one conversation
            conversationData["name"] = name
        }
        
        // Create conversation
        db.collection("conversations")
            .document(conversationId)
            .setData(conversationData) { error in
                if let error = error {
                    print("Error creating conversation: \(error)")
                    completion(nil)
                    return
                }
                
                // Add conversation reference to each participant
                let batch = self.db.batch()
                let currentTime = Date()
                
                for participantId in participants {
                    let userConversationRef = self.db.collection("users")
                        .document(participantId)
                        .collection("conversations")
                        .document(conversationId)
                    
                    // Use the same data as the main conversation document for consistency
                    var userConversationData = conversationData
                    userConversationData["unreadCount"] = 0
                    userConversationData["lastReadTimestamp"] = currentTime
                    userConversationData["conversationRef"] = "conversations/\(conversationId)"
                    userConversationData["joinedAt"] = currentTime
                    
                    // Add user-specific metadata fields
                    userConversationData["isMuted"] = false
                    userConversationData["isPinned"] = false
                    userConversationData["notificationSettings"] = [:]
                    
                    print("🔍 [ConversationService] Setting user conversation data for \(participantId):")
                    print("   - lastActivity: \(conversationData["lastActivity"] ?? "MISSING")")
                    print("   - createdAt: \(conversationData["createdAt"] ?? "MISSING")")
                    print("   - conversationRef: conversations/\(conversationId)")
                    print("   - unreadCount: 0")
                    print("   - joinedAt: \(currentTime)")
                    batch.setData(userConversationData, forDocument: userConversationRef)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ [ConversationService] Error adding conversation to users: \(error)")
                        completion(nil)
                        return
                    }
                    
                    print("✅ [ConversationService] Conversation created successfully: \(conversationId)")
                    print("✅ [ConversationService] User conversation references created with lastActivity: \(currentTime)")
                    
                    // Verify the data was written correctly by reading it back
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.verifyUserConversationData(conversationId: conversationId, participants: participants)
                    }
                    
                    completion(conversationId)
                }
            }
    }
    
    // MARK: - Send Message
    
    func sendMessage(text: String, conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Check if conversation exists and get participants
        db.collection("conversations")
            .document(conversationId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching conversation: \(error)")
                    completion(false)
                    return
                }
                
                guard let conversationData = snapshot?.data(),
                      let participants = conversationData["participants"] as? [String] else {
                    print("Conversation not found or invalid")
                    completion(false)
                    return
                }
                
                // Check if any participants are blocked
                self.checkForBlockedUsers(participants: participants) { hasBlockedUsers in
                    if hasBlockedUsers {
                        print("Cannot send message - blocked users in conversation")
                        completion(false)
                        return
                    }
                    
                    self.sendMessageInternal(text: text, conversationId: conversationId, completion: completion)
                }
            }
    }
    
    private func sendMessageInternal(text: String, conversationId: String, completion: @escaping (Bool) -> Void) {
        let messageId = UUID().uuidString
        let currentTime = Date()
        let currentUid = Auth.auth().currentUser?.uid ?? ""
        
        let messageData: [String: Any] = [
            "text": text,
            "senderId": currentUid,
            "timestamp": currentTime,
            "isPod": false,
            "podId": NSNull(),
            "isRead": false,
            
            // Essential production fields
            "version": 1,
            
            // Message content
            "conversationId": conversationId,
            
            // Content moderation
            "isReported": false,
            
            // Read status (isRead for one-on-one, readBy for group chats)
            "readBy": [:],
            
            // Analytics
            "reactions": [:]
        ]
        
        // Add message to conversation
        db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
            .setData(messageData) { error in
                if let error = error {
                    print("Error sending message: \(error)")
                    completion(false)
                    return
                }
                
                // Check if sender has deleted this conversation and restore it if needed
                self.checkAndRestoreDeletedConversation(conversationId: conversationId, userId: Auth.auth().currentUser?.uid ?? "")
                
                // Update conversation's last message and activity
                let currentTime = Date()
                self.db.collection("conversations")
                    .document(conversationId)
                    .updateData([
                        "lastMessage": messageData,
                        "lastActivity": currentTime,
                        "lastMessageReadBy": [Auth.auth().currentUser?.uid ?? ""] // Only sender has read the new message
                    ]) { error in
                        if let error = error {
                            print("Error updating conversation: \(error)")
                        } else {
                            // Also update user conversation metadata with lastActivity for proper sorting
                            self.updateUserConversationMetadata(conversationId: conversationId, lastActivity: currentTime)
                        }
                        completion(true)
                    }
            }
    }
    
    // MARK: - Send Pod Message
    
    func sendPodMessage(podId: String, conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Check if conversation exists and get participants
        db.collection("conversations")
            .document(conversationId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching conversation: \(error)")
                    completion(false)
                    return
                }
                
                guard let conversationData = snapshot?.data(),
                      let participants = conversationData["participants"] as? [String] else {
                    print("Conversation not found or invalid")
                    completion(false)
                    return
                }
                
                // Check if any participants are blocked
                self.checkForBlockedUsers(participants: participants) { hasBlockedUsers in
                    if hasBlockedUsers {
                        print("Cannot send pod message - blocked users in conversation")
                        completion(false)
                        return
                    }
                    
                    self.sendPodMessageInternal(podId: podId, conversationId: conversationId, completion: completion)
                }
            }
    }
    
    private func sendPodMessageInternal(podId: String, conversationId: String, completion: @escaping (Bool) -> Void) {
        let messageId = UUID().uuidString
        let currentTime = Date()
        let currentUid = Auth.auth().currentUser?.uid ?? ""
        
        let messageData: [String: Any] = [
            "text": "",
            "senderId": currentUid,
            "timestamp": currentTime,
            "isPod": true,
            "podId": podId,
            "isRead": false,
            
            // Essential production fields
            "version": 1,
            
            // Message content
            "conversationId": conversationId,
            
            // Content moderation
            "isReported": false,
            
            // Read status (isRead for one-on-one, readBy for group chats)
            "readBy": [:],
            
            // Analytics
            "reactions": [:]
        ]
        
        // Add message to conversation
        db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
            .setData(messageData) { error in
                if let error = error {
                    print("Error sending pod message: \(error)")
                    completion(false)
                    return
                }
                
                // Check if sender has deleted this conversation and restore it if needed
                self.checkAndRestoreDeletedConversation(conversationId: conversationId, userId: Auth.auth().currentUser?.uid ?? "")
                
                // Increment shares count for the pod
                self.incrementPodShares(podId: podId)
                
                // Update conversation's last message and activity
                let currentTime = Date()
                self.db.collection("conversations")
                    .document(conversationId)
                    .updateData([
                        "lastMessage": messageData,
                        "lastActivity": currentTime,
                        "lastMessageReadBy": [Auth.auth().currentUser?.uid ?? ""] // Only sender has read the new message
                    ]) { error in
                        if let error = error {
                            print("Error updating conversation: \(error)")
                        } else {
                            // Also update user conversation metadata with lastActivity for proper sorting
                            self.updateUserConversationMetadata(conversationId: conversationId, lastActivity: currentTime)
                        }
                        completion(true)
                    }
            }
    }
    
    // MARK: - Fetch Messages
    
    func fetchMessages(conversationId: String, limit: Int = 20, completion: @escaping ([Message]) -> Void) {
        // Check if conversation has blocked users before fetching messages
        db.collection("conversations")
            .document(conversationId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching conversation: \(error)")
                    completion([])
                    return
                }
                
                guard let conversationData = snapshot?.data(),
                      let participants = conversationData["participants"] as? [String] else {
                    print("Conversation not found or invalid")
                    completion([])
                    return
                }
                
                // Check if any participants are blocked
                self.checkForBlockedUsers(participants: participants) { hasBlockedUsers in
                    if hasBlockedUsers {
                        print("Cannot fetch messages - blocked users in conversation")
                        completion([])
                        return
                    }
                    
                    self.fetchMessagesInternal(conversationId: conversationId, limit: limit, completion: completion)
                }
            }
    }
    
    private func fetchMessagesInternal(conversationId: String, limit: Int = 20, completion: @escaping ([Message]) -> Void) {
        // First check if current user has deleted this conversation
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        print("🔍 [ConversationService] Fetching messages for conversation: \(conversationId)")
        
        // Check user's deletion status
        db.collection("users")
            .document(currentUid)
            .collection("conversations")
            .document(conversationId)
            .getDocument { [weak self] userDoc, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [ConversationService] Error reading user conversation doc: \(error)")
                    completion([])
                    return
                }
                
                let userData = userDoc?.data() ?? [:]
                let isDeleted = userData["isDeleted"] as? Bool ?? false
                let deletedAt = userData["deletedAt"] as? Timestamp
                
                print("🔍 [ConversationService] User conversation data: \(userData)")
                print("🔍 [ConversationService] User deletion status - isDeleted: \(isDeleted), deletedAt: \(deletedAt?.dateValue() ?? Date())")
                
                // If we don't have deletedAt from user metadata, check the main conversation document
                if deletedAt == nil {
                    self.db.collection("conversations").document(conversationId).getDocument { convDoc, convError in
                        if let convError = convError {
                            print("❌ [ConversationService] Error reading main conversation doc: \(convError)")
                            self.executeMessageQuery(conversationId: conversationId, isDeleted: isDeleted, deletedAt: deletedAt, limit: limit, completion: completion)
                            return
                        }
                        
                        let convData = convDoc?.data() ?? [:]
                        let deletedFor = convData["deletedFor"] as? [String: [String: Any]] ?? [:]
                        let userDeletedFor = deletedFor[currentUid]
                        let mainDeletedAt = userDeletedFor?["deletedAt"] as? Timestamp
                        
                        print("🔍 [ConversationService] Main conversation deletedFor data: \(deletedFor)")
                        print("🔍 [ConversationService] Main conversation deletedAt for user: \(mainDeletedAt?.dateValue() ?? Date())")
                        
                        // Use the main conversation's deletedAt if user metadata doesn't have it
                        let finalDeletedAt = deletedAt ?? mainDeletedAt
                        self.executeMessageQuery(conversationId: conversationId, isDeleted: isDeleted, deletedAt: finalDeletedAt, limit: limit, completion: completion)
                    }
                } else {
                    self.executeMessageQuery(conversationId: conversationId, isDeleted: isDeleted, deletedAt: deletedAt, limit: limit, completion: completion)
                }
            }
    }
    
    // MARK: - Helper Methods
    
    /// Verify that user conversation data was written correctly
    private func verifyUserConversationData(conversationId: String, participants: [String]) {
        print("🔍 [ConversationService] Verifying user conversation data for conversation: \(conversationId)")
        
        for participantId in participants {
            let userConversationRef = db.collection("users")
                .document(participantId)
                .collection("conversations")
                .document(conversationId)
            
            userConversationRef.getDocument { snapshot, error in
                if let error = error {
                    print("❌ [ConversationService] Error verifying user conversation data for \(participantId): \(error)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("❌ [ConversationService] No data found for user \(participantId) conversation \(conversationId)")
                    return
                }
                
                print("🔍 [ConversationService] Verification for user \(participantId):")
                print("   - lastActivity: \(data["lastActivity"] ?? "MISSING")")
                print("   - conversationRef: \(data["conversationRef"] ?? "MISSING")")
                print("   - unreadCount: \(data["unreadCount"] ?? "MISSING")")
                print("   - joinedAt: \(data["joinedAt"] ?? "MISSING")")
                print("   - isDeleted: \(data["isDeleted"] ?? "MISSING")")
            }
        }
    }
    
    /// Update user conversation metadata with lastActivity for proper sorting
    private func updateUserConversationMetadata(conversationId: String, lastActivity: Date) {
        // Get conversation participants first
        db.collection("conversations")
            .document(conversationId)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching conversation for metadata update: \(error)")
                    return
                }
                
                guard let conversationData = snapshot?.data(),
                      let participants = conversationData["participants"] as? [String] else {
                    print("Conversation not found or invalid for metadata update")
                    return
                }
                
                // Update lastActivity for all participants
                let batch = self.db.batch()
                for participantId in participants {
                    let userConversationRef = self.db.collection("users")
                        .document(participantId)
                        .collection("conversations")
                        .document(conversationId)
                    
                    batch.updateData([
                        "lastActivity": lastActivity
                    ], forDocument: userConversationRef)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("Error updating user conversation metadata: \(error)")
                    } else {
                        print("✅ Updated lastActivity for all participants in conversation \(conversationId)")
                    }
                }
            }
    }
    
    private func executeMessageQuery(conversationId: String, isDeleted: Bool, deletedAt: Timestamp?, limit: Int, completion: @escaping ([Message]) -> Void) {
        var query: Query
        
        if isDeleted, let deletedAt = deletedAt {
            print("🔍 [ConversationService] Applying deletion filter - only messages AFTER: \(deletedAt.dateValue())")
            query = self.db.collection("conversations").document(conversationId).collection("messages").whereField("timestamp", isGreaterThan: deletedAt).order(by: "timestamp", descending: true).limit(to: limit)
        } else if let deletedAt = deletedAt {
            print("🔍 [ConversationService] Applying deletedAt filter (conversation restored) - only messages AFTER: \(deletedAt.dateValue())")
            query = self.db.collection("conversations").document(conversationId).collection("messages").whereField("timestamp", isGreaterThan: deletedAt).order(by: "timestamp", descending: true).limit(to: limit)
        } else {
            print("🔍 [ConversationService] No deletion filter - fetching all messages")
            query = self.db.collection("conversations").document(conversationId).collection("messages").order(by: "timestamp", descending: true).limit(to: limit)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [ConversationService] Error fetching messages: \(error)")
                completion([])
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [ConversationService] No snapshot received")
                completion([])
                return
            }
            
            let documents = snapshot.documents
            let messages = documents.compactMap { try? $0.data(as: Message.self) }
            print("🔍 [ConversationService] Fetched \(messages.count) messages")

            // Apply in-memory filtering as a safety net
            let filteredMessages: [Message]
            if let deletedAt = deletedAt {
                filteredMessages = messages.filter { $0.timestamp > deletedAt.dateValue() }
                print("🔍 [ConversationService] In-memory filtering: \(messages.count) messages filtered down to \(filteredMessages.count) messages (AFTER \(deletedAt.dateValue()))")
                
                // DEBUG: Show which messages were filtered out
                if messages.count != filteredMessages.count {
                    let filteredOut = messages.filter { $0.timestamp <= deletedAt.dateValue() }
                    print("🔍 [ConversationService] DEBUG: Filtered out \(filteredOut.count) messages:")
                    for msg in filteredOut {
                        print("🔍 [ConversationService] DEBUG: Filtered out message at \(msg.timestamp) (deletedAt: \(deletedAt.dateValue()))")
                    }
                }
            } else {
                filteredMessages = messages
                print("🔍 [ConversationService] No in-memory filtering needed")
            }
            
            // DEBUG: Show all message timestamps vs deletedAt
            if let deletedAt = deletedAt {
                print("🔍 [ConversationService] DEBUG: deletedAt timestamp: \(deletedAt.dateValue())")
                print("🔍 [ConversationService] DEBUG: All message timestamps:")
                for (index, msg) in messages.enumerated() {
                    let isAfter = msg.timestamp > deletedAt.dateValue()
                    print("🔍 [ConversationService] DEBUG: Message \(index): \(msg.timestamp) - After deletedAt: \(isAfter)")
                }
            }

            // Sort ascending for display
            let sortedMessages = filteredMessages.sorted { $0.timestamp < $1.timestamp }
            completion(sortedMessages)
        }
    }
    
    // MARK: - Fetch Messages with Pagination
    
    func fetchMessagesPaginated(conversationId: String, lastMessage: Message?, limit: Int = 20, completion: @escaping ([Message]) -> Void) {
        // Check if conversation has blocked users before fetching messages
        db.collection("conversations")
            .document(conversationId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching conversation: \(error)")
                    completion([])
                    return
                }
                
                guard let conversationData = snapshot?.data(),
                      let participants = conversationData["participants"] as? [String] else {
                    print("Conversation not found or invalid")
                    completion([])
                    return
                }
                
                // Check if any participants are blocked
                self.checkForBlockedUsers(participants: participants) { hasBlockedUsers in
                    if hasBlockedUsers {
                        print("Cannot fetch messages - blocked users in conversation")
                        completion([])
                        return
                    }
                    
                    self.fetchMessagesPaginatedInternal(conversationId: conversationId, lastMessage: lastMessage, limit: limit, completion: completion)
                }
            }
    }
    
    private func fetchMessagesPaginatedInternal(conversationId: String, lastMessage: Message?, limit: Int = 20, completion: @escaping ([Message]) -> Void) {
        // First check if current user has deleted this conversation
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        print("🔍 [ConversationService] Fetching paginated messages for conversation: \(conversationId)")
        
        // Check user's deletion status
        db.collection("users")
            .document(currentUid)
            .collection("conversations")
            .document(conversationId)
            .getDocument { [weak self] userDoc, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [ConversationService] Error reading user conversation doc: \(error)")
                    completion([])
                    return
                }
                
                let userData = userDoc?.data() ?? [:]
                let isDeleted = userData["isDeleted"] as? Bool ?? false
                let deletedAt = userData["deletedAt"] as? Timestamp
                
                print("🔍 [ConversationService] User conversation data: \(userData)")
                print("🔍 [ConversationService] Paginated - User deletion status - isDeleted: \(isDeleted), deletedAt: \(deletedAt?.dateValue() ?? Date())")
                
                // If we don't have deletedAt from user metadata, check the main conversation document
                if deletedAt == nil {
                    self.db.collection("conversations").document(conversationId).getDocument { convDoc, convError in
                        if let convError = convError {
                            print("❌ [ConversationService] Error reading main conversation doc: \(convError)")
                            self.executePaginatedMessageQuery(conversationId: conversationId, isDeleted: isDeleted, deletedAt: deletedAt, lastMessage: lastMessage, limit: limit, completion: completion)
                            return
                        }
                        
                        let convData = convDoc?.data() ?? [:]
                        let deletedFor = convData["deletedFor"] as? [String: [String: Any]] ?? [:]
                        let userDeletedFor = deletedFor[currentUid]
                        let mainDeletedAt = userDeletedFor?["deletedAt"] as? Timestamp
                        
                        print("🔍 [ConversationService] Paginated - Main conversation deletedFor data: \(deletedFor)")
                        print("🔍 [ConversationService] Paginated - Main conversation deletedAt for user: \(mainDeletedAt?.dateValue() ?? Date())")
                        
                        // Use the main conversation's deletedAt if user metadata doesn't have it
                        let finalDeletedAt = deletedAt ?? mainDeletedAt
                        self.executePaginatedMessageQuery(conversationId: conversationId, isDeleted: isDeleted, deletedAt: finalDeletedAt, lastMessage: lastMessage, limit: limit, completion: completion)
                    }
                } else {
                    self.executePaginatedMessageQuery(conversationId: conversationId, isDeleted: isDeleted, deletedAt: deletedAt, lastMessage: lastMessage, limit: limit, completion: completion)
                }
            }
    }
    
    private func executePaginatedMessageQuery(conversationId: String, isDeleted: Bool, deletedAt: Timestamp?, lastMessage: Message?, limit: Int, completion: @escaping ([Message]) -> Void) {
        var query: Query
        
        if isDeleted, let deletedAt = deletedAt {
            print("🔍 [ConversationService] Paginated - Applying deletion filter - only messages AFTER: \(deletedAt.dateValue())")
            query = self.db.collection("conversations").document(conversationId).collection("messages").whereField("timestamp", isGreaterThan: deletedAt).order(by: "timestamp", descending: true).limit(to: limit)
        } else if let deletedAt = deletedAt {
            print("🔍 [ConversationService] Paginated - Applying deletedAt filter (conversation restored) - only messages AFTER: \(deletedAt.dateValue())")
            query = self.db.collection("conversations").document(conversationId).collection("messages").whereField("timestamp", isGreaterThan: deletedAt).order(by: "timestamp", descending: true).limit(to: limit)
        } else {
            print("🔍 [ConversationService] Paginated - No deletion filter - fetching all messages")
            query = self.db.collection("conversations").document(conversationId).collection("messages").order(by: "timestamp", descending: true).limit(to: limit)
        }
        
        if let lastMessage = lastMessage, let messageId = lastMessage.id {
            // For pagination, we need to create a DocumentSnapshot or use start(after:)
            // Since we have the message data, we can use start(after:) with the timestamp
            query = query.start(after: [lastMessage.timestamp])
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [ConversationService] Paginated - Error fetching messages: \(error)")
                completion([])
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [ConversationService] Paginated - No snapshot received")
                completion([])
                return
            }
            
            let documents = snapshot.documents
            let messages = documents.compactMap { try? $0.data(as: Message.self) }
            print("🔍 [ConversationService] Paginated - Fetched \(messages.count) messages")

            // Apply in-memory filtering as a safety net
            let filteredMessages: [Message]
            if let deletedAt = deletedAt {
                filteredMessages = messages.filter { $0.timestamp > deletedAt.dateValue() }
                print("🔍 [ConversationService] Paginated - In-memory filtering: \(messages.count) messages filtered down to \(filteredMessages.count) messages (AFTER \(deletedAt.dateValue()))")
                
                // DEBUG: Show which messages were filtered out
                if messages.count != filteredMessages.count {
                    let filteredOut = messages.filter { $0.timestamp <= deletedAt.dateValue() }
                    print("🔍 [ConversationService] Paginated - DEBUG: Filtered out \(filteredOut.count) messages:")
                    for msg in filteredOut {
                        print("🔍 [ConversationService] Paginated - DEBUG: Filtered out message at \(msg.timestamp) (deletedAt: \(deletedAt.dateValue()))")
                    }
                }
            } else {
                filteredMessages = messages
                print("🔍 [ConversationService] Paginated - No in-memory filtering needed")
            }
            
            // DEBUG: Show all message timestamps vs deletedAt
            if let deletedAt = deletedAt {
                print("🔍 [ConversationService] Paginated - DEBUG: deletedAt timestamp: \(deletedAt.dateValue())")
                print("🔍 [ConversationService] DEBUG: All message timestamps:")
                for (index, msg) in messages.enumerated() {
                    let isAfter = msg.timestamp > deletedAt.dateValue()
                    print("🔍 [ConversationService] Paginated - DEBUG: Message \(index): \(msg.timestamp) - After deletedAt: \(isAfter)")
                }
            }

            let sortedMessages = filteredMessages.sorted { $0.timestamp < $1.timestamp }
            completion(sortedMessages)
        }
    }
    
    // MARK: - Setup Message Listener
    
    func setupMessageListener(conversationId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        // Set up the message listener directly without blocking checks
        return setupMessageListenerInternal(conversationId: conversationId, completion: completion)
    }
    
    private func setupMessageListenerInternal(conversationId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        // First check if current user has deleted this conversation
        guard let currentUid = Auth.auth().currentUser?.uid else {
            // Return empty listener if no current user
            return db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .addSnapshotListener { _, _ in }
        }
        
        // Set up message listener with deletion filter
        return db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                let messages = documents.compactMap { try? $0.data(as: Message.self) }
                
                // Check user's deletion status and filter messages
                self.db.collection("users")
                    .document(currentUid)
                    .collection("conversations")
                    .document(conversationId)
                    .getDocument { userDoc, error in
                        let userData = userDoc?.data() ?? [:]
                        let isDeleted = userData["isDeleted"] as? Bool ?? false
                        let deletedAt = userData["deletedAt"] as? Timestamp
                        
                        print("🔍 [ConversationService] Message Listener - User deletion status - isDeleted: \(isDeleted), deletedAt: \(deletedAt?.dateValue() ?? Date())")
                        
                        // If we don't have deletedAt from user metadata, check the main conversation document
                        if deletedAt == nil {
                            self.db.collection("conversations").document(conversationId).getDocument { convDoc, convError in
                                if let convError = convError {
                                    print("❌ [ConversationService] Message Listener - Error reading main conversation doc: \(convError)")
                                    self.filterAndCompleteMessages(messages: messages, isDeleted: isDeleted, deletedAt: deletedAt, completion: completion)
                                    return
                                }
                                
                                let convData = convDoc?.data() ?? [:]
                                let deletedFor = convData["deletedFor"] as? [String: [String: Any]] ?? [:]
                                let userDeletedFor = deletedFor[currentUid]
                                let mainDeletedAt = userDeletedFor?["deletedAt"] as? Timestamp
                                
                                print("🔍 [ConversationService] Message Listener - Main conversation deletedFor data: \(deletedFor)")
                                print("🔍 [ConversationService] Message Listener - Main conversation deletedAt for user: \(mainDeletedAt?.dateValue() ?? Date())")
                                
                                // Use the main conversation's deletedAt if user metadata doesn't have it
                                let finalDeletedAt = deletedAt ?? mainDeletedAt
                                self.filterAndCompleteMessages(messages: messages, isDeleted: isDeleted, deletedAt: finalDeletedAt, completion: completion)
                            }
                        } else {
                            self.filterAndCompleteMessages(messages: messages, isDeleted: isDeleted, deletedAt: deletedAt, completion: completion)
                        }
                    }
            }
    }
    
    private func filterAndCompleteMessages(messages: [Message], isDeleted: Bool, deletedAt: Timestamp?, completion: @escaping ([Message]) -> Void) {
        let filteredMessages: [Message]
        if isDeleted, let deletedAt = deletedAt {
            print("🔍 [ConversationService] Message Listener - Applying deletion filter - only messages AFTER: \(deletedAt.dateValue())")
            filteredMessages = messages.filter { $0.timestamp > deletedAt.dateValue() }
            print("🔍 [ConversationService] Message Listener - Filtered \(messages.count) messages down to \(filteredMessages.count) messages")
            
            // DEBUG: Show which messages were filtered out
            if messages.count != filteredMessages.count {
                let filteredOut = messages.filter { $0.timestamp <= deletedAt.dateValue() }
                print("🔍 [ConversationService] DEBUG: Filtered out \(filteredOut.count) messages:")
                for msg in filteredOut {
                    print("🔍 [ConversationService] DEBUG: Filtered out message at \(msg.timestamp) (deletedAt: \(deletedAt.dateValue()))")
                }
            }
        } else if let deletedAt = deletedAt {
            print("🔍 [ConversationService] Message Listener - Applying deletedAt filter (conversation restored) - only messages AFTER: \(deletedAt.dateValue())")
            filteredMessages = messages.filter { $0.timestamp > deletedAt.dateValue() }
            print("🔍 [ConversationService] Message Listener - Filtered \(messages.count) messages down to \(filteredMessages.count) messages")
            
            // DEBUG: Show which messages were filtered out
            if messages.count != filteredMessages.count {
                let filteredOut = messages.filter { $0.timestamp <= deletedAt.dateValue() }
                print("🔍 [ConversationService] DEBUG: Filtered out \(filteredOut.count) messages:")
                for msg in filteredOut {
                    print("🔍 [ConversationService] DEBUG: Filtered out message at \(msg.timestamp) (deletedAt: \(deletedAt.dateValue()))")
                }
            }
        } else {
            print("🔍 [ConversationService] Message Listener - No deletion filter - using all messages")
            filteredMessages = messages
            print("🔍 [ConversationService] Message Listener - Filtered \(messages.count) messages down to \(filteredMessages.count) messages")
        }
        
        // DEBUG: Show all message timestamps vs deletedAt
        if let deletedAt = deletedAt {
            print("🔍 [ConversationService] DEBUG: deletedAt timestamp: \(deletedAt.dateValue())")
            print("🔍 [ConversationService] DEBUG: All message timestamps:")
            for (index, msg) in messages.enumerated() {
                let isAfter = msg.timestamp > deletedAt.dateValue()
                print("🔍 [ConversationService] DEBUG: Message \(index): \(msg.timestamp) - After deletedAt: \(isAfter)")
            }
        }
        
        completion(filteredMessages)
    }
    
    // MARK: - Fetch Conversations
    
    func fetchConversations(for userId: String, completion: @escaping ([Conversation]) -> Void) {
        print("🔍 [ConversationService] Fetching conversations for user: \(userId)")
        
        // Query user's conversation metadata
        db.collection("users")
            .document(userId)
            .collection("conversations")
            .order(by: "lastActivity", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [ConversationService] Error fetching conversations: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [ConversationService] No conversation documents found for user: \(userId)")
                    completion([])
                    return
                }
                
                print("🔍 [ConversationService] Found \(documents.count) user conversation references")
                
                // Debug: Print the user conversation data
                for (index, doc) in documents.enumerated() {
                    let data = doc.data()
                    print("🔍 [ConversationService] User conv \(index): \(doc.documentID)")
                    print("   - lastActivity: \(data["lastActivity"] ?? "MISSING")")
                    print("   - conversationRef: \(data["conversationRef"] ?? "MISSING")")
                    print("   - isDeleted: \(data["isDeleted"] ?? "MISSING")")
                }
                
                let group = DispatchGroup()
                var conversations: [Conversation] = []
                
                for document in documents {
                    group.enter()
                    
                    let conversationRef = document.data()["conversationRef"] as? String ?? ""
                    
                    self.db.document(conversationRef).getDocument { conversationDoc, error in
                        if let conversationDoc = conversationDoc,
                           let conversation = try? conversationDoc.data(as: Conversation.self) {
                            // Double-check that the conversation isn't marked as deleted in the main document
                            let deletedFor = conversationDoc.data()?["deletedFor"] as? [String: [String: Any]] ?? [:]
                            let isDeletedInMain = deletedFor[userId]?["isDeleted"] as? Bool ?? false
                            
                            if !isDeletedInMain {
                                // Check if conversation has blocked users
                                self.checkForBlockedUsers(participants: conversation.participants) { hasBlockedUsers in
                                    if !hasBlockedUsers {
                                        conversations.append(conversation)
                                    } else {
                                        print("Skipping conversation \(conversation.id ?? "unknown") - blocked users detected")
                                    }
                                    group.leave()
                                }
                            } else {
                                print("Skipping conversation \(conversation.id ?? "unknown") - marked as deleted in main document for user \(userId)")
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    // Sort by lastActivity from the main conversation document to ensure correct order
                    let sortedConversations = conversations.sorted { $0.lastActivity > $1.lastActivity }
                    completion(sortedConversations)
                }
            }
    }
    
    /// Fetch conversations with server-side search and pagination
    func fetchConversationsWithSearch(
        for userId: String,
        searchQuery: String = "",
        lastConversation: Conversation? = nil,
        limit: Int = 10,
        completion: @escaping ([Conversation]) -> Void
    ) {
        print("🔍 [ConversationService] Fetching conversations with search: '\(searchQuery)', limit: \(limit)")
        
        var query = db.collection("users")
            .document(userId)
            .collection("conversations")
            .order(by: "lastActivity", descending: true)
            .limit(to: limit)
        
        // Add pagination cursor using lastActivity
        if let lastConversation = lastConversation {
            query = query.start(after: [lastConversation.lastActivity])
            print("🔍 [ConversationService] Using pagination cursor: \(lastConversation.lastActivity)")
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ [ConversationService] Error fetching conversations: \(error)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [ConversationService] No conversation documents found for user: \(userId)")
                completion([])
                return
            }
            
            print("🔍 [ConversationService] Found \(documents.count) user conversation references")
            
            // Debug: Print the user conversation data
            for (index, doc) in documents.enumerated() {
                let data = doc.data()
                print("🔍 [ConversationService] User conv \(index): \(doc.documentID)")
                print("   - lastActivity: \(data["lastActivity"] ?? "MISSING")")
                print("   - conversationRef: \(data["conversationRef"] ?? "MISSING")")
                print("   - isDeleted: \(data["isDeleted"] ?? "MISSING")")
            }
            
            let group = DispatchGroup()
            var conversations: [Conversation] = []
            
            for document in documents {
                group.enter()
                
                let conversationRef = document.data()["conversationRef"] as? String ?? ""
                
                self.db.document(conversationRef).getDocument { conversationDoc, error in
                    if let conversationDoc = conversationDoc,
                       let conversation = try? conversationDoc.data(as: Conversation.self) {
                        // Check if conversation isn't deleted
                        let deletedFor = conversationDoc.data()?["deletedFor"] as? [String: [String: Any]] ?? [:]
                        let isDeletedInMain = deletedFor[userId]?["isDeleted"] as? Bool ?? false
                        
                        if !isDeletedInMain {
                            // Check for blocked users
                            self.checkForBlockedUsers(participants: conversation.participants) { hasBlockedUsers in
                                if !hasBlockedUsers {
                                    // Apply search filter if query exists
                                    if searchQuery.isEmpty || self.conversationMatchesSearch(conversation, searchQuery: searchQuery) {
                                        conversations.append(conversation)
                                    }
                                }
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                // Sort by lastActivity from the main conversation document to ensure correct order
                let sortedConversations = conversations.sorted { $0.lastActivity > $1.lastActivity }
                print("✅ [ConversationService] Found \(sortedConversations.count) conversations matching search")
                completion(sortedConversations)
            }
        }
    }
    
    /// Check if conversation matches search query
    private func conversationMatchesSearch(_ conversation: Conversation, searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        
        // For now, we'll do basic search on conversation data
        // In a production app, you'd want to store searchable fields in the conversation document
        // or create a separate search index
        
        // Check if any participant ID contains the query (basic fallback)
        for participantId in conversation.participants {
            if participantId.lowercased().contains(query) {
                return true
            }
        }
        
        return false
    }
    
    /// Fetch ALL conversations for a user (including deleted ones) for the New Message view
    /// This method shows full conversation history but still applies blocking filters for security
    /// Returns both conversations and a set of deleted conversation IDs
    func fetchAllConversationsIncludingDeleted(for userId: String, completion: @escaping ([Conversation], Set<String>) -> Void) {
        print("🔄 CONVERSATION_SERVICE: Fetching ALL conversations including deleted for user: \(userId)")
        
        // Query user's conversation metadata (including deleted ones) with limit
        db.collection("users")
            .document(userId)
            .collection("conversations")
            .order(by: "lastActivity", descending: true)
            .limit(to: 50) // Limit to prevent fetching too many conversations
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ CONVERSATION_SERVICE: Error fetching all conversations: \(error)")
                    completion([], [])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([], [])
                    return
                }
                
                let group = DispatchGroup()
                var conversations: [Conversation] = []
                var deletedConversationIds: Set<String> = []
                
                for document in documents {
                    group.enter()
                    
                    // Include ALL conversations, even deleted ones
                    let isDeleted = document.data()["isDeleted"] as? Bool ?? false
                    let conversationRef = document.data()["conversationRef"] as? String ?? ""
                    
                    if isDeleted {
                        print("📝 CONVERSATION_SERVICE: Including deleted conversation: \(document.documentID)")
                    }
                    
                    // Fetch full conversation data
                    self.db.document(conversationRef).getDocument { conversationDoc, error in
                        if let conversationDoc = conversationDoc,
                           let conversation = try? conversationDoc.data(as: Conversation.self) {
                            
                            // Check if conversation has blocked users (still apply blocking filter for security)
                            self.checkForBlockedUsers(participants: conversation.participants) { hasBlockedUsers in
                                if !hasBlockedUsers {
                                    conversations.append(conversation)
                                    if isDeleted {
                                        deletedConversationIds.insert(conversation.id ?? "")
                                        print("✅ CONVERSATION_SERVICE: Added deleted conversation (no blocking): \(conversation.id ?? "unknown")")
                                    }
                                } else {
                                    print("🚫 CONVERSATION_SERVICE: Skipping conversation (blocked users): \(conversation.id ?? "unknown")")
                                }
                                group.leave()
                            }
                        } else {
                            print("⚠️ CONVERSATION_SERVICE: Could not parse conversation: \(conversationRef)")
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("✅ CONVERSATION_SERVICE: Fetched \(conversations.count) total conversations (including deleted)")
                    print("📝 CONVERSATION_SERVICE: Found \(deletedConversationIds.count) deleted conversations")
                    completion(conversations, deletedConversationIds)
                }
            }
    }
    
    // MARK: - Find Existing Conversation
    
    func findExistingConversation(with userId: String, completion: @escaping (String?) -> Void) {
        findExistingConversation(with: userId, includeDeleted: false, completion: completion)
    }
    
    // MARK: - Find Existing Conversation (including deleted ones)
    
    func findExistingConversation(with userId: String, includeDeleted: Bool = false, completion: @escaping (String?) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        // Check if conversation already exists
        db.collection("users")
            .document(currentUid)
            .collection("conversations")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking existing conversations: \(error)")
                    completion(nil)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    // No conversations exist
                    completion(nil)
                    return
                }
                
                // Check if conversation with this user already exists
                let group = DispatchGroup()
                var foundConversationId: String?
                
                for document in documents {
                    group.enter()
                    
                    // Check if this conversation is marked as deleted for the user
                    let isDeleted = document.data()["isDeleted"] as? Bool ?? false
                    
                    // Skip deleted conversations unless explicitly requested
                    if isDeleted && !includeDeleted {
                        print("Skipping deleted conversation when finding existing: \(document.documentID)")
                        group.leave()
                        continue
                    }
                    
                    let conversationRef = document.data()["conversationRef"] as? String ?? ""
                    
                    self.db.document(conversationRef).getDocument { conversationDoc, error in
                        defer { group.leave() }
                        
                        if let conversationDoc = conversationDoc,
                           let conversation = try? conversationDoc.data(as: Conversation.self) {
                            // Double-check that the conversation isn't marked as deleted in the main document
                            let deletedFor = conversationDoc.data()?["deletedFor"] as? [String: [String: Any]] ?? [:]
                            let currentUserId = Auth.auth().currentUser?.uid ?? ""
                            let isDeletedInMain = deletedFor[currentUserId]?["isDeleted"] as? Bool ?? false
                            
                            // If including deleted conversations, don't check main document deletion status
                            if (includeDeleted || !isDeletedInMain) && conversation.participants.contains(userId) {
                                foundConversationId = conversation.id
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    completion(foundConversationId)
                }
            }
    }
    
    // MARK: - Get or Create Conversation
    
    func getOrCreateConversation(with userId: String, completion: @escaping (String?) -> Void) {
        // Check if users are blocked before proceeding
        checkForBlockedUsers(participants: [Auth.auth().currentUser?.uid ?? "", userId]) { hasBlockedUsers in
            if hasBlockedUsers {
                print("Cannot create conversation - blocked users detected")
                completion(nil)
                return
            }
            
            // First try to find existing conversation
            self.findExistingConversation(with: userId) { existingConversationId in
                if let existingId = existingConversationId {
                    // Found existing conversation
                    completion(existingId)
                } else {
                    // No existing conversation found, create new one
                    self.createConversation(participants: [Auth.auth().currentUser?.uid ?? "", userId]) { conversationId in
                        completion(conversationId)
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch Pod
    
    func fetchPod(withPodId podId: String, completion: @escaping(Pod?) -> Void) {
        guard !podId.isEmpty else {
            completion(nil)
            return
        }
        
        db.collection("pods")
            .document(podId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching pod: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(nil)
                    return
                }
                
                do {
                    let pod = try snapshot.data(as: Pod.self)
                    completion(pod)
                } catch {
                    print("Error decoding pod: \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }
    
    // MARK: - Fetch User Details
    
    func fetchUserDetails(userId: String, completion: @escaping(User?) -> Void) {
        db.collection("users")
            .document(userId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching user details: \(error)")
                    completion(nil)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(nil)
                    return
                }
                
                do {
                    let user = try snapshot.data(as: User.self)
                    completion(user)
                } catch {
                    print("Error decoding user: \(error)")
                    completion(nil)
                }
            }
    }
    
    // MARK: - Check and Restore Deleted Conversation
    
    private func checkAndRestoreDeletedConversation(conversationId: String, userId: String) {
        // First check the main conversation document to see who has it marked as deleted
        let conversationRef = db.collection("conversations").document(conversationId)
        
        conversationRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error checking main conversation document: \(error)")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                print("Conversation document doesn't exist")
                return
            }
            
            let deletedFor = snapshot.data()?["deletedFor"] as? [String: [String: Any]] ?? [:]
            
            // If no one has it marked as deleted, nothing to restore
            if deletedFor.isEmpty {
                return
            }
            
            print("🔄 Found \(deletedFor.count) users with deleted conversation \(conversationId), restoring for all...")
            
            // Restore conversation for all users who have it marked as deleted
            let group = DispatchGroup()
            
            for (deletedUserId, deletedData) in deletedFor {
                let isDeleted = deletedData["isDeleted"] as? Bool ?? false
                
                if isDeleted {
                    group.enter()
                    print("🔄 Restoring conversation for user: \(deletedUserId)")
                    
                    // Update the user's conversation reference to mark as not deleted
                    let userConversationRef = self.db.collection("users")
                        .document(deletedUserId)
                        .collection("conversations")
                        .document(conversationId)
                    
                    let userUpdateData: [String: Any] = [
                        "isDeleted": false
                        // Keep deletedAt timestamp for message filtering
                    ]
                    
                    userConversationRef.updateData(userUpdateData) { error in
                        if let error = error {
                            print("❌ Error restoring user conversation reference for \(deletedUserId): \(error)")
                        } else {
                            print("✅ User conversation reference restored successfully for \(deletedUserId)")
                        }
                        group.leave()
                    }
                }
            }
            
            // After restoring all user references, remove the deletedFor entries from main document
            group.notify(queue: .main) {
                let conversationUpdateData: [String: Any] = [
                    "deletedFor": FieldValue.delete() // Remove the entire deletedFor field
                ]
                
                conversationRef.updateData(conversationUpdateData) { error in
                    if let error = error {
                        print("❌ Error updating main conversation document: \(error)")
                    } else {
                        print("✅ Main conversation document updated successfully - removed all deletedFor entries")
                    }
                }
            }
        }
    }
    
    // MARK: - Mark Last Message as Read
    
    func markLastMessageAsRead(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Add current user to the lastMessageReadBy array
        db.collection("conversations")
            .document(conversationId)
            .updateData([
                "lastMessageReadBy": FieldValue.arrayUnion([currentUid])
            ]) { error in
                if let error = error {
                    print("Error marking last message as read: \(error)")
                    completion(false)
                } else {
                    print("Successfully marked last message as read for user: \(currentUid)")
                    completion(true)
                }
            }
    }
    
    // MARK: - Restore Conversation When Sending Message
    
    func restoreConversationForNewMessage(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Update user's conversation reference to mark as not deleted
        let userConversationRef = db.collection("users")
            .document(currentUid)
            .collection("conversations")
            .document(conversationId)
        
        let userUpdateData: [String: Any] = [
            "isDeleted": false
            // Keep deletedAt timestamp for message filtering
        ]
        
        userConversationRef.updateData(userUpdateData) { error in
            if let error = error {
                print("❌ Error restoring conversation for new message: \(error)")
                completion(false)
            } else {
                print("✅ Conversation restored for new message (kept deletedAt)")
                completion(true)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Simple check: is current user blocked by a specific user?
    /// Uses the same approach as ProfileView - reads from current user's blockedBy array
    func isCurrentUserBlockedBy(userId: String, completion: @escaping (Bool) -> Void) {
        // Guard against empty user IDs that would cause Firestore crashes
        guard !userId.isEmpty else {
            print("⚠️ CONVERSATION_SERVICE: Empty userId provided, skipping blocking check")
            completion(false)
            return
        }
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Use the EXACT same approach as ProfileView - read current user's blockedBy array
        // This reads from users/{currentUid} and checks the blockedBy array field
        let userRef = db.collection("users").document(currentUid)
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ CONVERSATION_SERVICE: Error checking if blocked by user: \(error)")
                completion(false)
                return
            }
            
            if let userData = snapshot?.data(),
               let blockedBy = userData["blockedBy"] as? [String] {
                let isBlocked = blockedBy.contains(userId)
                print("🔍 CONVERSATION_SERVICE: Current user blocked by \(userId): \(isBlocked)")
                print("🔍 CONVERSATION_SERVICE: Current user's blockedBy array: \(blockedBy)")
                completion(isBlocked)
            } else {
                print("🔍 CONVERSATION_SERVICE: No blockedBy array found, assuming not blocked")
                completion(false)
            }
        }
    }
    
    /// Simple check: has current user blocked a specific user?
    /// Reads from current user's blockedUsers array
    func hasCurrentUserBlocked(userId: String, completion: @escaping (Bool) -> Void) {
        // Guard against empty user IDs that would cause Firestore crashes
        guard !userId.isEmpty else {
            print("⚠️ CONVERSATION_SERVICE: Empty userId provided, skipping blocking check")
            completion(false)
            return
        }
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        // Read from current user's blockedUsers array
        let userRef = db.collection("users").document(currentUid)
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ CONVERSATION_SERVICE: Error checking if current user blocked: \(error)")
                completion(false)
                return
            }
            
            if let userData = snapshot?.data(),
               let blockedUsers = userData["blockedUsers"] as? [String] {
                let hasBlocked = blockedUsers.contains(userId)
                print("🔍 CONVERSATION_SERVICE: Current user has blocked \(userId): \(hasBlocked)")
                print("🔍 CONVERSATION_SERVICE: Current user's blockedUsers array: \(blockedUsers)")
                completion(hasBlocked)
            } else {
                print("🔍 CONVERSATION_SERVICE: No blockedUsers array found, assuming not blocked")
                completion(false)
            }
        }
    }
    
    private func checkForBlockedUsers(participants: [String], completion: @escaping (Bool) -> Void) {
        print("🔍 CONVERSATION_SERVICE: checkForBlockedUsers called with participants: \(participants)")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ CONVERSATION_SERVICE: checkForBlockedUsers failed - no authenticated user")
            completion(false)
            return
        }
        
        // Create cache key from sorted participants
        let cacheKey = participants.sorted().joined(separator: ",")
        
        // Check cache first
        if let cached = blockingCache[cacheKey] {
            let timeSinceCache = Date().timeIntervalSince(cached.timestamp)
            if timeSinceCache < cacheTimeout {
                print("🔍 CONVERSATION_SERVICE: Using cached blocking result: \(cached.result) (cached \(Int(timeSinceCache))s ago)")
                completion(cached.result)
                return
            } else {
                print("🔍 CONVERSATION_SERVICE: Cache expired (\(Int(timeSinceCache))s ago), fetching fresh data")
                blockingCache.removeValue(forKey: cacheKey)
            }
        }
        
        print("🔍 CONVERSATION_SERVICE: Current user UID: \(currentUid)")
        print("🔍 CONVERSATION_SERVICE: Checking for any blocking relationships...")
        
        // Check both directions: if current user is blocked by someone OR if current user has blocked someone
        let group = DispatchGroup()
        var hasBlockedUsers = false
        
        for participantId in participants {
            if participantId != currentUid { // Skip checking self
                group.enter()
                
                // Check if current user is blocked by this participant
                isCurrentUserBlockedBy(userId: participantId) { isBlockedByThem in
                    if isBlockedByThem {
                        print("🔍 CONVERSATION_SERVICE: Current user is blocked by participant: \(participantId)")
                        hasBlockedUsers = true
                        group.leave()
                    } else {
                        // Check if current user has blocked this participant
                        self.hasCurrentUserBlocked(userId: participantId) { hasBlockedThem in
                            if hasBlockedThem {
                                print("🔍 CONVERSATION_SERVICE: Current user has blocked participant: \(participantId)")
                                hasBlockedUsers = true
                            }
                            group.leave()
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            // Cache the result
            self.blockingCache[cacheKey] = (result: hasBlockedUsers, timestamp: Date())
            
            if hasBlockedUsers {
                print("🔍 CONVERSATION_SERVICE: Blocking detected - conversation will be filtered out")
            } else {
                print("🔍 CONVERSATION_SERVICE: No blocking detected - conversation will be shown")
            }
            completion(hasBlockedUsers)
        }
    }
    
    /// Server-side search for conversations by participant usernames
    /// This method searches through all conversations, not just loaded ones
    func searchConversationsByUsername(
        for userId: String,
        searchQuery: String,
        lastConversation: Conversation? = nil,
        limit: Int = 10,
        completion: @escaping ([Conversation]) -> Void
    ) {
        print("🔍 [ConversationService] Server-side search for username: '\(searchQuery)' for user: \(userId)")
        
        // First, find users whose usernames match the search query
        let usernameQuery = searchQuery.lowercased()
        print("🔍 [ConversationService] Searching for usernames containing: '\(usernameQuery)'")
        
        // Search in users collection for matching usernames
        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: usernameQuery)
            .whereField("username", isLessThan: usernameQuery + "\u{f8ff}")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [ConversationService] Error searching users: \(error)")
                    completion([])
                    return
                }
                
                guard let userDocs = snapshot?.documents else {
                    print("⚠️ [ConversationService] No user documents found")
                    completion([])
                    return
                }
                
                print("🔍 [ConversationService] Found \(userDocs.count) potential user documents")
                
                let matchingUserIds = userDocs.compactMap { doc -> String? in
                    let userData = doc.data()
                    let username = userData["username"] as? String ?? ""
                    let isDeleted = userData["isDeleted"] as? Bool ?? false
                    
                    print("🔍 [ConversationService] Checking user: \(username) (ID: \(doc.documentID))")
                    
                    // Filter out deleted accounts
                    if isDeleted {
                        print("❌ [ConversationService] Filtering out deleted account: \(username)")
                        return nil
                    }
                    
                    // Filter out anonymous accounts (usernames starting with "anon_")
                    if username.lowercased().hasPrefix("anon_") {
                        print("❌ [ConversationService] Filtering out anonymous account: \(username)")
                        return nil
                    }
                    
                    // Double-check the username actually contains our query
                    if username.lowercased().contains(usernameQuery) {
                        print("✅ [ConversationService] User matches: \(username)")
                        return doc.documentID
                    }
                    return nil
                }
                
                print("🔍 [ConversationService] Found \(matchingUserIds.count) users matching '\(searchQuery)': \(matchingUserIds)")
                
                if matchingUserIds.isEmpty {
                    print("⚠️ [ConversationService] No matching users found, returning empty results")
                    completion([])
                    return
                }
                
                // Now find conversations that include any of these users
                self?.findConversationsWithUsers(
                    userId: userId,
                    targetUserIds: matchingUserIds,
                    lastConversation: lastConversation,
                    limit: limit,
                    completion: completion
                )
            }
    }
    
    /// Find conversations that include specific users
    private func findConversationsWithUsers(
        userId: String,
        targetUserIds: [String],
        lastConversation: Conversation? = nil,
        limit: Int = 10,
        completion: @escaping ([Conversation]) -> Void
    ) {
        print("🔍 [ConversationService] Finding conversations with users: \(targetUserIds)")
        
        // Search through ALL conversations globally to find ones with target users
        // This is more efficient than checking every user's conversation collection
        var query = db.collection("conversations")
            .order(by: "lastActivity", descending: true)
            .limit(to: limit * 3) // Fetch more to account for filtering
        
        // Add pagination cursor
        if let lastConversation = lastConversation {
            query = query.start(after: [lastConversation.lastActivity])
            print("🔍 [ConversationService] Using pagination cursor: \(lastConversation.lastActivity)")
        }
        
        query.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ [ConversationService] Error fetching conversations: \(error)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [ConversationService] No conversation documents found")
                completion([])
                return
            }
            
            print("🔍 [ConversationService] Found \(documents.count) potential conversations to check")
            
            let group = DispatchGroup()
            var conversations: [Conversation] = []
            
            for document in documents {
                group.enter()
                
                // Parse conversation directly from document
                if let conversation = try? document.data(as: Conversation.self) {
                    
                    // Check if this conversation includes any of our target users
                    let hasTargetUser = conversation.participants.contains { participantId in
                        targetUserIds.contains(participantId)
                    }
                    
                    if hasTargetUser {
                        // Check if current user is also a participant (they need to be in the conversation)
                        let hasCurrentUser = conversation.participants.contains { participantId in
                            participantId == userId
                        }
                        
                        if hasCurrentUser {
                            // Check for blocked users
                            self?.checkForBlockedUsers(participants: conversation.participants) { hasBlockedUsers in
                                if !hasBlockedUsers {
                                    conversations.append(conversation)
                                    print("✅ [ConversationService] Found matching conversation: \(conversation.id ?? "nil") with participants: \(conversation.participants)")
                                } else {
                                    print("🚫 [ConversationService] Skipping blocked conversation: \(conversation.id ?? "nil")")
                                }
                                group.leave()
                            }
                        } else {
                            print("⚠️ [ConversationService] Conversation \(conversation.id ?? "nil") has target user but not current user")
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                } else {
                    print("⚠️ [ConversationService] Could not parse conversation: \(document.documentID)")
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Sort by last activity and limit results
                let sortedConversations = conversations
                    .sorted { $0.lastActivity > $1.lastActivity }
                    .prefix(limit)
                    .map { $0 }
                
                print("✅ [ConversationService] Server search found \(sortedConversations.count) conversations")
                completion(Array(sortedConversations))
            }
        }
    }
} 
