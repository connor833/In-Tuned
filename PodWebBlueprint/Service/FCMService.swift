//
//  FCMService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 5/25/25.
//

import Foundation
import UIKit
import Firebase
import FirebaseMessaging
import FirebaseFunctions
import UserNotifications
import FirebaseAuth

class FCMService {
    static let shared = FCMService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Token Management
    
    /// Update FCM token for current user
    func updateFCMToken() {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ FCM: No authenticated user found")
            return 
        }
        
        print("🔄 FCM: Starting token update for user: \(uid)")
        
        // First check notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 Notification Permission Status: \(settings.authorizationStatus.rawValue)")
            
            if settings.authorizationStatus == .denied {
                print("❌ FCM: Notifications DENIED - FCM token won't work")
                return
            }
            
            // Check APNS token status
            let apnsToken = Messaging.messaging().apnsToken
            print("🔑 APNS Token Status: \(apnsToken != nil ? "Available ✅" : "NOT AVAILABLE ⚠️")")
            
            // Check if APNS token is available
            if Messaging.messaging().apnsToken == nil {
                print("⚠️  APNS token not ready yet - will retry when APNSTokenReady notification fires")
                print("💡 This should only happen if called before APNS registration completes")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                return
            }
            
            // APNS is ready, get FCM token
            self.attemptFCMTokenGeneration(for: uid)
        }
    }
    
    /// Helper function to attempt FCM token generation
    private func attemptFCMTokenGeneration(for uid: String) {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ FCM: Error fetching token - \(error.localizedDescription)")
                
                // If still no APNS token, this is likely the issue
                if Messaging.messaging().apnsToken == nil {
                    print("💡 Root cause: No APNS token available")
                    print("🔧 Try closing and reopening the app")
                }
                return
            }
            
            guard let token = token else { 
                print("❌ FCM: Token is nil - check Firebase configuration")
                return 
            }
            
            print("✅ FCM: Token generated successfully")
            print("🔑 FCM Token: \(token)")
            
            // Store the token in Firestore
            self?.db.collection("users")
                .document(uid)
                .updateData(["fcmToken": token]) { error in
                    if let error = error {
                        print("❌ FCM: Error saving to Firestore - \(error.localizedDescription)")
                    } else {
                        print("✅ FCM: Token successfully saved to Firestore")
                    }
                }
        }
    }
    
    /// Get FCM token for a specific user
    func getFCMToken(forUser uid: String, completion: @escaping(String?) -> Void) {
        db.collection("users")
            .document(uid)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching FCM token: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                let token = snapshot?.data()?["fcmToken"] as? String
                completion(token)
            }
    }
    
    /// Remove FCM token for current user (on logout)
    func removeFCMToken() {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ FCM: No authenticated user found for token removal")
            return 
        }
        
        print("🚫 FCM: Starting complete FCM cleanup for user: \(uid)")
        
        // 1. Remove token from Firestore
        db.collection("users")
            .document(uid)
            .updateData(["fcmToken": FieldValue.delete()]) { error in
                if let error = error {
                    print("❌ FCM: Error removing token from Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ FCM: Token removed from Firestore successfully")
                }
            }
        
        // 2. Delete the local FCM token
        Messaging.messaging().deleteToken { error in
            if let error = error {
                print("❌ FCM: Error deleting local FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM: Local FCM token deleted successfully")
            }
        }
        
        // 3. Clear any cached tokens
        Messaging.messaging().isAutoInitEnabled = false
        print("✅ FCM: Auto-init disabled")
    }
    
    /// Complete FCM cleanup (called on logout)
    func completeFCMCleanup() {
        print("🚫 FCM: Starting complete FCM cleanup")
        
        // Disable auto-init to prevent new tokens
        Messaging.messaging().isAutoInitEnabled = false
        
        // Delete any existing token
        Messaging.messaging().deleteToken { error in
            if let error = error {
                print("❌ FCM: Error deleting FCM token during cleanup: \(error.localizedDescription)")
            } else {
                print("✅ FCM: FCM token deleted during cleanup")
            }
        }
        
        // Re-enable auto-init for future logins
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Messaging.messaging().isAutoInitEnabled = true
            print("✅ FCM: Auto-init re-enabled for future logins")
        }
    }
    
    // MARK: - Debug Methods (Development Only)
    
    /// Tests FCM token generation and validation
    func testFCMTokenGeneration() {
        // Test FCM token generation
        Messaging.messaging().token { token, error in
            if let error = error {
                // FCM token error
            } else if let token = token {
                // FCM token generated successfully
            }
        }
    }
    
    // MARK: - Legacy Methods (kept for backward compatibility)
    
    @available(*, deprecated, message: "Push notifications are now handled automatically by cloud functions")
    func sendPushNotification(to recipientId: String, title: String, body: String, data: [String: String], completion: @escaping(Bool) -> Void) {
        print("Warning: sendPushNotification is deprecated. Push notifications are now handled automatically by cloud functions.")
        completion(false)
    }
    
    // MARK: - Utility Methods
    
    /// Check if user has valid FCM token
    func hasValidFCMToken(completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        getFCMToken(forUser: uid) { token in
            completion(token != nil && !token!.isEmpty)
        }
    }
    
    /// Request new FCM token
    func refreshFCMToken() {
        Messaging.messaging().deleteToken { [weak self] error in
            if let error = error {
                print("Error deleting FCM token: \(error.localizedDescription)")
            }
            
            // Request new token
            self?.updateFCMToken()
        }
    }
    
    /// Debug function to check current FCM token status
    func debugFCMTokenStatus() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ FCM Debug: No authenticated user")
            return
        }
        
        print("🔍 === FCM TOKEN DEBUG STATUS ===")
        print("👤 User ID: \(uid)")
        
        // Check notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("📱 Notification Permission: \(settings.authorizationStatus.rawValue)")
                
                // Check APNS token
                let apnsToken = Messaging.messaging().apnsToken
                print("🔑 APNS Token: \(apnsToken != nil ? "Available" : "NOT AVAILABLE")")
                
                // Try to get FCM token
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("❌ FCM Token Error: \(error.localizedDescription)")
                    } else if let token = token {
                        print("✅ FCM Token: \(token.prefix(50))...")
                        print("📏 Token Length: \(token.count)")
                    } else {
                        print("❌ FCM Token: nil")
                    }
                }
            }
        }
    }
}
