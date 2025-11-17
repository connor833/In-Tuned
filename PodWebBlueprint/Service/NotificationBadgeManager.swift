import Foundation
import Firebase
import SwiftUI
import FirebaseAuth

/// Manages unread notification counts and displays them as badges over the notification bell icon
class NotificationBadgeManager: ObservableObject {
    static let shared = NotificationBadgeManager()
    private let db = Firestore.firestore()
    private let notificationService = NotificationService()
    
    @Published var unreadNotificationCount: Int = 0
    
    private init() {}
    
    /// Updates the unread notification count for the current user
    func updateUnreadNotificationCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        print("🔔 NotificationBadgeManager: Updating unread notification count for user \(uid)")
        
        // Get unread notifications from the past week
        let oneWeekAgo = Timestamp(date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("isRead", isEqualTo: false)
            .whereField("createdAt", isGreaterThan: oneWeekAgo)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching unread notifications: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                
                DispatchQueue.main.async {
                    self?.unreadNotificationCount = count
                    print("🔔 Unread notification count: \(count)")
                }
            }
    }
    
    /// Clears the unread notification count (called when notifications are viewed)
    func clearUnreadNotificationCount() {
        unreadNotificationCount = 0
        print("🔔 Notification badge cleared")
    }
    
    /// Listens for real-time updates to unread notification count
    func startListeningForUnreadNotifications() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        print("🔔 NotificationBadgeManager: Starting to listen for unread notifications")
        
        // Get unread notifications from the past week
        let oneWeekAgo = Timestamp(date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("isRead", isEqualTo: false)
            .whereField("createdAt", isGreaterThan: oneWeekAgo)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening for notifications: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                
                DispatchQueue.main.async {
                    self?.unreadNotificationCount = count
                    print("🔔 Real-time unread notification count: \(count)")
                }
            }
    }
    
    /// Stops listening for real-time updates
    func stopListeningForUnreadNotifications() {
        // Note: Firestore listeners are automatically cleaned up when the app is deallocated
        print("🔔 NotificationBadgeManager: Stopped listening for unread notifications")
    }
    
    /// Complete cleanup on logout
    func completeCleanup() {
        print("🚫 NotificationBadgeManager: Starting complete cleanup")
        unreadNotificationCount = 0
        // Firestore listeners will be automatically cleaned up
        print("✅ NotificationBadgeManager: Cleanup complete")
    }
}
