//
//  BlockService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/1/25.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

class BlockService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Block User
    
    func blockUser(userId: String, reason: String? = nil, completion: @escaping (Bool) -> Void) {
        print("🚫 BLOCK_SERVICE: blockUser called with userId: \(userId), reason: \(reason ?? "none")")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ BLOCK_SERVICE: blockUser failed - no authenticated user")
            completion(false)
            return
        }
        
        print("🚫 BLOCK_SERVICE: Current user UID: \(currentUid)")
        print("🚫 BLOCK_SERVICE: Calling blockUser cloud function...")
        
        // Use cloud function for atomic operations
        let functions = Functions.functions()
        let blockUserFunction = functions.httpsCallable("blockUser")
        
        let data: [String: Any] = [
            "userId": userId,
            "blockType": "user", // Always use "user" since both types do the same thing
            "reason": reason ?? NSNull()
        ]
        
        print("🚫 BLOCK_SERVICE: Cloud function data payload: \(data)")
        
        blockUserFunction.call(data) { result, error in
            if let error = error {
                print("❌ BLOCK_SERVICE: blockUser cloud function error: \(error)")
                print("❌ BLOCK_SERVICE: Error details: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("🚫 BLOCK_SERVICE: Cloud function call successful, processing result...")
            
            if let data = result?.data as? [String: Any] {
                print("🚫 BLOCK_SERVICE: Result data: \(data)")
                
                if let success = data["success"] as? Bool, success {
                    print("✅ BLOCK_SERVICE: User blocked successfully via cloud function")
                    completion(true)
                } else {
                    print("❌ BLOCK_SERVICE: Cloud function returned success: false")
                    completion(false)
                }
            } else {
                print("❌ BLOCK_SERVICE: Failed to parse cloud function result")
                completion(false)
            }
        }
    }
    
    // MARK: - Unblock User
    
    func unblockUser(userId: String, completion: @escaping (Bool) -> Void) {
        print("🔓 BLOCK_SERVICE: unblockUser called with userId: \(userId)")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ BLOCK_SERVICE: unblockUser failed - no authenticated user")
            completion(false)
            return
        }
        
        print("🔓 BLOCK_SERVICE: Current user UID: \(currentUid)")
        print("🔓 BLOCK_SERVICE: Calling unblockUser cloud function...")
        
        let functions = Functions.functions()
        let unblockUserFunction = functions.httpsCallable("unblockUser")
        
        let data = ["userId": userId]
        print("🔓 BLOCK_SERVICE: Cloud function data payload: \(data)")
        
        unblockUserFunction.call(data) { result, error in
            if let error = error {
                print("❌ BLOCK_SERVICE: unblockUser cloud function error: \(error)")
                print("❌ BLOCK_SERVICE: Error details: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("🔓 BLOCK_SERVICE: Cloud function call successful, processing result...")
            
            if let data = result?.data as? [String: Any] {
                print("🔓 BLOCK_SERVICE: Result data: \(data)")
                
                if let success = data["success"] as? Bool, success {
                    print("✅ BLOCK_SERVICE: User unblocked successfully via cloud function")
                    completion(true)
                } else {
                    print("❌ BLOCK_SERVICE: Cloud function returned success: false")
                    completion(false)
                }
            } else {
                print("❌ BLOCK_SERVICE: Failed to parse cloud function result")
                completion(false)
            }
        }
    }
    
    // MARK: - Check Block Status
    
    func checkIfUserIsBlocked(userId: String, completion: @escaping (Bool) -> Void) {
        print("🔍 BLOCK_SERVICE: checkIfUserIsBlocked called with userId: \(userId)")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ BLOCK_SERVICE: checkIfUserIsBlocked failed - no authenticated user")
            completion(false)
            return
        }
        
        print("🔍 BLOCK_SERVICE: Current user UID: \(currentUid)")
        print("🔍 BLOCK_SERVICE: Checking if current user has blocked userId: \(userId)")
        
        let blockRef = db.collection("users")
            .document(currentUid)
            .collection("user-blocks")
            .document(userId)
        
        print("🔍 BLOCK_SERVICE: Querying Firestore path: \(blockRef.path)")
        
        blockRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ BLOCK_SERVICE: Error checking block status: \(error)")
                print("❌ BLOCK_SERVICE: Error details: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            let isBlocked = snapshot?.exists ?? false
            print("🔍 BLOCK_SERVICE: Block status check result - isBlocked: \(isBlocked)")
            print("🔍 BLOCK_SERVICE: Document exists: \(snapshot?.exists ?? false)")
            
            if let data = snapshot?.data() {
                print("🔍 BLOCK_SERVICE: Block document data: \(data)")
            }
            
            completion(isBlocked)
        }
    }
    
    func checkIfCurrentUserIsBlocked(by userId: String, completion: @escaping (Bool) -> Void) {
        print("🔍 BLOCK_SERVICE: checkIfCurrentUserIsBlocked called with userId: \(userId)")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ BLOCK_SERVICE: checkIfCurrentUserIsBlocked failed - no authenticated user")
            completion(false)
            return
        }
        
        print("🔍 BLOCK_SERVICE: Current user UID: \(currentUid)")
        print("🔍 BLOCK_SERVICE: Checking if current user is blocked by userId: \(userId)")
        
        let blockRef = db.collection("users")
            .document(userId)
            .collection("user-blocks")
            .document(currentUid)
        
        print("🔍 BLOCK_SERVICE: Querying Firestore path: \(blockRef.path)")
        
        blockRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ BLOCK_SERVICE: Error checking if current user is blocked: \(error)")
                print("❌ BLOCK_SERVICE: Error details: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            let isBlocked = snapshot?.exists ?? false
            print("🔍 BLOCK_SERVICE: Current user blocked status check result - isBlocked: \(isBlocked)")
            print("🔍 BLOCK_SERVICE: Document exists: \(snapshot?.exists ?? false)")
            
            if let data = snapshot?.data() {
                print("🔍 BLOCK_SERVICE: Block document data: \(data)")
            }
            
            completion(isBlocked)
        }
    }
    
    // MARK: - Quick Array Checks (Fast, for ongoing app usage)
    
    /// Quick check using current user's blockedUsers array (fast, for ongoing app usage)
    func quickCheckIfUserIsBlocked(userId: String, currentUser: User) -> Bool {
        return currentUser.blockedUsers?.contains(userId) == true
    }
    
    /// Quick check using current user's blockedBy array (fast, for ongoing app usage)
    func quickCheckIfCurrentUserIsBlocked(by userId: String, currentUser: User) -> Bool {
        return currentUser.blockedBy?.contains(userId) == true
    }
    
    // MARK: - Accurate Array Checks (for critical operations)
    
    /// Accurate check using current user's blockedBy array (for profile views, conversations)
    /// This fetches the current user's document to get the most up-to-date blockedBy array
    /// Note: We can't read other users' user-blockedBy collections due to Firestore security rules
    func accurateCheckIfCurrentUserIsBlocked(by userId: String, completion: @escaping (Bool) -> Void) {
        print("🔍 BLOCK_SERVICE: accurateCheckIfCurrentUserIsBlocked called with userId: \(userId)")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ BLOCK_SERVICE: accurateCheckIfCurrentUserIsBlocked failed - no authenticated user")
            completion(false)
            return
        }
        
        print("🔍 BLOCK_SERVICE: Current user UID: \(currentUid)")
        print("🔍 BLOCK_SERVICE: Fetching current user document to check blockedBy array")
        
        let userRef = db.collection("users").document(currentUid)
        
        print("🔍 BLOCK_SERVICE: Querying Firestore path: \(userRef.path)")
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ BLOCK_SERVICE: Error fetching current user document: \(error)")
                print("❌ BLOCK_SERVICE: Error details: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let data = snapshot?.data(),
                  let blockedBy = data["blockedBy"] as? [String] else {
                print("🔍 BLOCK_SERVICE: No blockedBy array found in current user document")
                completion(false)
                return
            }
            
            let isBlocked = blockedBy.contains(userId)
            print("🔍 BLOCK_SERVICE: BlockedBy array check result - isBlocked: \(isBlocked)")
            print("🔍 BLOCK_SERVICE: Current user's blockedBy array: \(blockedBy)")
            
            completion(isBlocked)
        }
    }
    
    // MARK: - Fetch Blocked Users
    
    func fetchBlockedUsers(completion: @escaping ([BlockMetadata]) -> Void) {
        print("📋 BLOCK_SERVICE: fetchBlockedUsers called")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ BLOCK_SERVICE: fetchBlockedUsers failed - no authenticated user")
            completion([])
            return
        }
        
        print("🔍 BLOCK_SERVICE: Current user UID: \(currentUid)")
        print("🔍 BLOCK_SERVICE: Fetching blocked users from Firestore...")
        
        let blockedUsersRef = db.collection("users")
            .document(currentUid)
            .collection("user-blocks")
            .order(by: "timestamp", descending: true)
        
        
        blockedUsersRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ BLOCK_SERVICE: Error fetching blocked users: \(error)")
                print("❌ BLOCK_SERVICE: Error details: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("🔍 BLOCK_SERVICE: No documents found in blocked users collection")
                completion([])
                return
            }
            
            print("🔍 BLOCK_SERVICE: Found \(documents.count) blocked user documents")
            
            let blockedUsers = documents.compactMap { document -> BlockMetadata? in
                do {
                    let blockMetadata = try document.data(as: BlockMetadata.self)
                    print("🔍 BLOCK_SERVICE: Successfully parsed block document: \(document.documentID)")
                    return blockMetadata
                } catch {
                    print("❌ BLOCK_SERVICE: Failed to parse block document \(document.documentID): \(error)")
                    print("❌ BLOCK_SERVICE: Raw document data: \(document.data())")
                    return nil
                }
            }
            
            print("🔍 BLOCK_SERVICE: Successfully parsed \(blockedUsers.count) blocked users")
            completion(blockedUsers)
        }
    }
    
    // MARK: - Filter Blocked Content
    
    func filterBlockedUsers<T: Identifiable>(_ items: [T], where getId: @escaping (T) -> String, completion: @escaping ([T]) -> Void) {
        print("🔍 BLOCK_SERVICE: filterBlockedUsers called with \(items.count) items")
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("❌ BLOCK_SERVICE: filterBlockedUsers failed - no authenticated user")
            completion(items)
            return
        }
        
        print("🔍 BLOCK_SERVICE: Current user UID: \(currentUid)")
        print("🔍 BLOCK_SERVICE: Fetching blocked users for filtering...")
        
        // Get all blocked user IDs
        let blockedUsersRef = db.collection("users")
            .document(currentUid)
            .collection("user-blocks")
        
        print("🔍 BLOCK_SERVICE: Querying Firestore path: \(blockedUsersRef.path)")
        
        blockedUsersRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ BLOCK_SERVICE: Error fetching blocked users for filtering: \(error)")
                print("❌ BLOCK_SERVICE: Error details: \(error.localizedDescription)")
                completion(items)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("🔍 BLOCK_SERVICE: No blocked user documents found, returning all items")
                completion(items)
                return
            }
            
            let blockedUserIds = documents.map { $0.documentID }
            print("🔍 BLOCK_SERVICE: Found \(blockedUserIds.count) blocked user IDs: \(blockedUserIds)")
            
            // Filter out blocked users
            let filteredItems = items.filter { item in
                let itemId = getId(item)
                let isBlocked = blockedUserIds.contains(itemId)
                if isBlocked {
                    print("🔍 BLOCK_SERVICE: Filtering out blocked user: \(itemId)")
                }
                return !isBlocked
            }
            
            print("🔍 BLOCK_SERVICE: Filtered \(items.count) items down to \(filteredItems.count) items")
            completion(filteredItems)
        }
    }
}
