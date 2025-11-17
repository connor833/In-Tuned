import Foundation
import UIKit
import Firebase
import FirebaseAuth

/// Manages the app icon badge count to show unread notifications
class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    private let notificationService = NotificationService()
    
    private init() {}
    
    /// Updates the app icon badge count based on recent unread notifications
    func updateBadgeCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        print("🔄 BadgeManager: Updating badge count for user \(uid)")
        notificationService.getUnreadNotificationCount(forUser: uid) { [weak self] count in
            DispatchQueue.main.async {
                print("📱 BadgeManager: Received count \(count), setting badge")
                self?.setBadgeCount(count)
            }
        }
    }
    
    /// Force refresh badge count (useful for debugging)
    func forceRefreshBadgeCount() {
        print("🔄 BadgeManager: Force refreshing badge count")
        updateBadgeCount()
    }
    
    /// Sets the app icon badge count
    /// - Parameter count: The number to display on the badge
    func setBadgeCount(_ count: Int) {
        // Cap badge count at 99+ for readability
        let displayCount = count > 99 ? 99 : count
        UIApplication.shared.applicationIconBadgeNumber = displayCount
        print("📱 Badge count updated to: \(displayCount) (actual unread: \(count))")
    }
    
    /// Clears the app icon badge count
    func clearBadgeCount() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        print("📱 Badge count cleared")
    }
}
