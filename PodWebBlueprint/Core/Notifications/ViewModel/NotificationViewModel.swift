import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

class NotificationViewModel: ObservableObject {
    @Published var notifications = [Notification]()
    @Published var isLoading = false
    private let service = NotificationService()
    private let badgeManager = BadgeManager.shared
    
    init() {
        fetchNotifications()
    }
    
    func fetchNotifications() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        service.fetchNotifications(forUser: uid) { [weak self] notifications in
            DispatchQueue.main.async {
                self?.notifications = notifications
                self?.isLoading = false
                
                // Update badge count after fetching notifications
                BadgeManager.shared.updateBadgeCount()
            }
        }
    }
    
    func refreshNotifications() {
        fetchNotifications()
    }
    
    func markAllAsRead() {
        service.markAllNotificationsAsRead { [weak self] (success: Bool) in
            if success {
                DispatchQueue.main.async {
                    // Create a new array with updated notifications
                    self?.notifications = self?.notifications.map { notification in
                        // Create a new notification with isRead = true using the custom initializer
                        let updatedNotification = Notification(
                            senderId: notification.senderId,
                            recipientId: notification.recipientId,
                            createdAt: notification.createdAt,
                            type: notification.type,
                            contentId: notification.contentId,
                            commentText: notification.commentText,
                            messageText: notification.messageText,
                            version: notification.version,
                            updatedAt: notification.updatedAt,
                            category: notification.category,
                            isRead: true, // Set to true
                            groupId: notification.groupId,
                            deepLink: notification.deepLink
                        )
                        var result = updatedNotification
                        result.id = notification.id
                        result.sender = notification.sender
                        result.content = notification.content
                        return result
                    } ?? []
                    
                    // Update badge count after marking all as read
                    BadgeManager.shared.updateBadgeCount()
                    
                    // Clear notification badge
                    NotificationBadgeManager.shared.clearUnreadNotificationCount()
                }
            }
        }
    }
    
    func markAsRead(_ notification: Notification) {
        guard !notification.isRead else { return }
        service.markNotificationAsRead(notification) { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    // Update the specific notification in the array
                    if let index = self?.notifications.firstIndex(where: { $0.id == notification.id }) {
                        // Create a new notification with isRead = true using the custom initializer
                        let updatedNotification = Notification(
                            senderId: notification.senderId,
                            recipientId: notification.recipientId,
                            createdAt: notification.createdAt,
                            type: notification.type,
                            contentId: notification.contentId,
                            commentText: notification.commentText,
                            messageText: notification.messageText,
                            version: notification.version,
                            updatedAt: notification.updatedAt,
                            category: notification.category,
                            isRead: true, // Set to true
                            groupId: notification.groupId,
                            deepLink: notification.deepLink
                        )
                        var result = updatedNotification
                        result.id = notification.id
                        result.sender = notification.sender
                        result.content = notification.content
                        self?.notifications[index] = result
                    }
                    
                    // Update badge count after marking notification as read
                    BadgeManager.shared.updateBadgeCount()
                    NotificationBadgeManager.shared.updateUnreadNotificationCount()
                }
            }
        }
    }
    
    // Function to handle notification tap based on type
    func handleNotificationTap(_ notification: Notification) {
        switch notification.type {
        case .like, .comment, .tag:
            // These types already have navigation in the view
            break
        case .follow:
            // Handle follow notification tap
            if let sender = notification.sender {
                // Navigate to profile
                break
            }
        case .followRequest:
            // Handle follow request notification tap
            if let sender = notification.sender {
                // Navigate to follow requests view
                break
            }
        case .followRequestAccepted:
            // Handle follow request accepted notification tap
            if let sender = notification.sender {
                // Navigate to notifications view
                break
            }
        case .repost:
            // Handle repost notification tap
            if let content = notification.content {
                // Navigate to the reposted content
                break
            }
        case .message:
            // Handle message notification tap
            // Navigate to messages/conversation
            break
        case .system:
            // Handle system notification tap
            // Navigate to system settings or show system message
            break
        case .marketing:
            // Handle marketing notification tap
            // Navigate to marketing content or app features
            break
        case .reminder:
            // Handle reminder notification tap
            // Navigate to reminder details or create new reminder
            break
        case .achievement:
            // Handle achievement notification tap
            // Navigate to achievements or profile
            break
        }
    }
}
