

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

struct NotificationService {
    private let db = Firestore.firestore()
    
    // MARK: - Fetch Notifications
    
    func fetchNotifications(forUser uid: String, completion: @escaping([Notification]) -> Void) {
        fetchPaginatedNotifications(forUser: uid, limit: 20, lastDocument: nil) { notifications, _ in
            completion(notifications)
        }
    }
    
    /// Fetches paginated notifications for a user
    func fetchPaginatedNotifications(forUser uid: String, limit: Int = 20, lastDocument: DocumentSnapshot? = nil, completion: @escaping([Notification], DocumentSnapshot?) -> Void) {
        print("🔔 [NotificationService] Fetching notifications for user: \(uid), limit: \(limit)")
        
        // Calculate date one month ago for better performance
        let oneMonthAgo = Timestamp(date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date())
        
        var query = db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("createdAt", isGreaterThan: oneMonthAgo)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching notifications: \(error)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("🔔 No notifications found for user: \(uid)")
                completion([], nil)
                return
            }
            
            print("🔔 Found \(documents.count) notifications for user: \(uid)")
            
            var notifications: [Notification] = []
            
            for doc in documents {
                do {
                    let data = doc.data()
                    
                    // Create notification with all required fields including isRead from database
                    let notification = Notification(
                        senderId: data["senderId"] as? String ?? "",
                        recipientId: data["recipientId"] as? String ?? "",
                        createdAt: data["createdAt"] as? Timestamp ?? Timestamp(),
                        type: NotificationType(rawValue: data["type"] as? String ?? "") ?? .system,
                        contentId: data["contentId"] as? String,
                        commentText: data["commentText"] as? String,
                        messageText: data["messageText"] as? String,
                        version: data["version"] as? Int ?? 2,
                        updatedAt: data["updatedAt"] as? Timestamp,
                        category: NotificationCategory(rawValue: data["category"] as? String ?? "social") ?? .social,
                        isRead: data["isRead"] as? Bool ?? false, // Read from database!
                        groupId: data["groupId"] as? String,
                        deepLink: data["deepLink"] as? String
                    )
                    
                    // Set the ID
                    var notificationWithId = notification
                    notificationWithId.id = doc.documentID
                    notifications.append(notificationWithId)
                    
                } catch {
                    print("❌ Error creating notification: \(error)")
                }
            }
            
            // Fetch sender and content details for each notification
            let group = DispatchGroup()
            
            for i in 0..<notifications.count {
                    group.enter()
                    
                    // Fetch sender
                    self.fetchUser(withUid: notifications[i].senderId) { result in
                        switch result {
                        case .success(let user):
                            notifications[i].sender = user
                        case .failure(let error):
                            print("Error fetching sender user: \(error.localizedDescription)")
                        }
                        group.leave()
                    }
                    
                    // Fetch content if available
                    if let contentId = notifications[i].contentId {
                        group.enter()
                        self.fetchPod(withId: contentId) { pod in
                            notifications[i].content = pod
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    let lastDocument = documents.last
                    completion(notifications, lastDocument)
                }
            }
    }
    
    // MARK: - Mark as Read
    
    func markNotificationAsRead(_ notification: Notification, completion: @escaping(Bool) -> Void) {
        guard let id = notification.id else { return }
        
        let currentTime = Timestamp()
        let updateData: [String: Any] = [
            "isRead": true,
            "updatedAt": currentTime
        ]
        
        db.collection("notifications")
            .document(id)
            .updateData(updateData) { error in
                if let error = error {
                    print("❌ Error marking notification as read: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                print("✅ Notification marked as read: \(id)")
                completion(true)
            }
    }
    
    /// Tracks notification open/click analytics
    func trackNotificationOpen(_ notification: Notification, completion: @escaping(Bool) -> Void) {
        guard let id = notification.id else { return }
        
        let currentTime = Timestamp()
        let updateData: [String: Any] = [
            "openCount": FieldValue.increment(Int64(1)),
            "lastOpenedAt": currentTime,
            "updatedAt": currentTime
        ]
        
        db.collection("notifications")
            .document(id)
            .updateData(updateData) { error in
                if let error = error {
                    print("❌ Error tracking notification open: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                print("✅ Notification open tracked: \(id)")
                completion(true)
            }
    }
    
    /// Tracks notification click analytics
    func trackNotificationClick(_ notification: Notification, completion: @escaping(Bool) -> Void) {
        guard let id = notification.id else { return }
        
        let currentTime = Timestamp()
        let updateData: [String: Any] = [
            "clickCount": FieldValue.increment(Int64(1)),
            "lastClickedAt": currentTime,
            "updatedAt": currentTime
        ]
        
        db.collection("notifications")
            .document(id)
            .updateData(updateData) { error in
                if let error = error {
                    print("❌ Error tracking notification click: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                print("✅ Notification click tracked: \(id)")
                completion(true)
            }
    }
    
    func markAllNotificationsAsRead(completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread notifications: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(false)
                    return
                }
                
                let batch = Firestore.firestore().batch()
                
                let currentTime = Timestamp()
                for document in documents {
                    batch.updateData([
                        "isRead": true,
                        "updatedAt": currentTime
                    ], forDocument: document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("Error marking all notifications as read: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    completion(true)
                }
            }
    }
    
    // MARK: - Create Notification
    
    func createNotification(type: NotificationType, senderId: String, recipientId: String, contentId: String? = nil, commentText: String? = nil, completion: @escaping(Bool) -> Void) {
        
        // Don't create notification for self-actions
        guard senderId != recipientId else {
            completion(true)
            return
        }
        
        // Validate input
        do {
            let notification = Notification(senderId: senderId, recipientId: recipientId, type: type, contentId: contentId, commentText: commentText)
            try notification.validate()
        } catch {
            print("❌ Notification validation failed: \(error)")
            completion(false)
            return
        }
        
        // Handle duplicate notification prevention for follow, follow request, follow request accepted, and like notifications
        if type == .follow || type == .followRequest || type == .followRequestAccepted || type == .like {
            print("🔄 [NotificationService] Processing \(type.rawValue) notification with duplicate prevention")
            handleDuplicateNotificationPrevention(type: type, senderId: senderId, recipientId: recipientId, contentId: contentId) {
                print("🔄 [NotificationService] Duplicate prevention completed, creating notification")
                self.createNotificationDocument(type: type, senderId: senderId, recipientId: recipientId, contentId: contentId, commentText: commentText, completion: completion)
            }
        } else {
            // For other notification types (comments, reposts, tags), create directly
            print("🔄 [NotificationService] Processing \(type.rawValue) notification without duplicate prevention")
            createNotificationDocument(type: type, senderId: senderId, recipientId: recipientId, contentId: contentId, commentText: commentText, completion: completion)
        }
    }
    
    // MARK: - Duplicate Notification Prevention
    
    private func handleDuplicateNotificationPrevention(type: NotificationType, senderId: String, recipientId: String, contentId: String?, completion: @escaping() -> Void) {
        print("🔍 Checking for duplicate \(type.rawValue) notification from \(senderId) to \(recipientId)\(contentId != nil ? " for content \(contentId!)" : "")")
        
        // Get all notifications for this recipient and filter in memory to avoid complex queries
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: recipientId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error checking for duplicate \(type.rawValue) notification: \(error.localizedDescription)")
                    completion() // Continue with notification creation
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("✅ No notifications found for recipient \(recipientId), proceeding with creation")
                    completion()
                    return
                }
                
                // Filter for matching notifications
                let matchingDocuments = documents.filter { document in
                    let data = document.data()
                    let typeMatches = data["type"] as? String == type.rawValue
                    let senderMatches = data["senderId"] as? String == senderId
                    
                    if type == .like, let contentId = contentId {
                        let contentMatches = data["contentId"] as? String == contentId
                        return typeMatches && senderMatches && contentMatches
                    } else if type == .follow, let contentId = contentId {
                        // For follow notifications, contentId represents the sender (person being followed)
                        let contentMatches = data["contentId"] as? String == contentId
                        return typeMatches && senderMatches && contentMatches
                    } else if type == .followRequest {
                        // For follow request notifications, we only check type and sender (no contentId needed)
                        return typeMatches && senderMatches
                    } else if type == .followRequestAccepted {
                        // For follow request accepted notifications, we only check type and sender (no contentId needed)
                        return typeMatches && senderMatches
                    } else {
                        return typeMatches && senderMatches
                    }
                }
                
                if matchingDocuments.isEmpty {
                    print("✅ No existing \(type.rawValue) notification found, proceeding with creation")
                    completion()
                    return
                }
                
                print("🗑️ Found \(matchingDocuments.count) existing \(type.rawValue) notification(s), deleting...")
                
                // Delete all matching notifications
                let deleteGroup = DispatchGroup()
                for document in matchingDocuments {
                    deleteGroup.enter()
                    document.reference.delete { error in
                        if let error = error {
                            print("❌ Error deleting existing notification: \(error.localizedDescription)")
                        } else {
                            print("✅ Deleted existing \(type.rawValue) notification")
                        }
                        deleteGroup.leave()
                    }
                }
                
                deleteGroup.notify(queue: .main) {
                    print("✅ Finished deleting \(matchingDocuments.count) existing \(type.rawValue) notification(s)")
                    completion()
                }
            }
    }
    
    private func createNotificationDocument(type: NotificationType, senderId: String, recipientId: String, contentId: String?, commentText: String?, completion: @escaping(Bool) -> Void) {
        let currentTime = Timestamp()
        let data: [String: Any] = [
            "senderId": senderId,
            "recipientId": recipientId,
            "type": type.rawValue,
            "contentId": contentId as Any,
            "commentText": commentText as Any,
            "messageText": NSNull(),
            "version": 2,
            "createdAt": currentTime,
            "updatedAt": currentTime,
            "category": "social",
            "isRead": false,
            "groupId": NSNull(),
            "deepLink": NSNull()
        ]
        
        // Create the notification document - Cloud Function will automatically handle push notification
        db.collection("notifications")
            .addDocument(data: data) { error in
                if let error = error {
                    print("❌ Error creating notification: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                print("✅ Notification created successfully - push notification will be sent by cloud function")
                completion(true)
            }
    }
    
    // MARK: - Advanced Notification Management
    
    /// Deletes a notification (soft delete)
    func deleteNotification(_ notification: Notification, completion: @escaping(Bool) -> Void) {
        guard let id = notification.id else { return }
        
        let currentTime = Timestamp()
        let updateData: [String: Any] = [
            "deletedAt": currentTime,
            "updatedAt": currentTime
        ]
        
        db.collection("notifications")
            .document(id)
            .updateData(updateData) { error in
                if let error = error {
                    print("❌ Error deleting notification: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                print("✅ Notification deleted: \(id)")
                completion(true)
            }
    }
    
    /// Deletes all notifications for a user (soft delete)
    func deleteAllNotifications(forUser uid: String, completion: @escaping(Bool) -> Void) {
        let currentTime = Timestamp()
        
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("deletedAt", isEqualTo: NSNull())
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching notifications for deletion: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(true)
                    return
                }
                
                let batch = Firestore.firestore().batch()
                
                for document in documents {
                    batch.updateData([
                        "deletedAt": currentTime,
                        "updatedAt": currentTime
                    ], forDocument: document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ Error deleting all notifications: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    print("✅ All notifications deleted for user: \(uid)")
                    completion(true)
                }
            }
    }
    
    /// Gets notification analytics for a user
    func getNotificationAnalytics(forUser uid: String, completion: @escaping([String: Any]) -> Void) {
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("deletedAt", isEqualTo: NSNull())
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching notification analytics: \(error.localizedDescription)")
                    completion([:])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([:])
                    return
                }
                
                var analytics: [String: Any] = [:]
                var totalOpenCount = 0
                var totalClickCount = 0
                var unreadCount = 0
                var typeCounts: [String: Int] = [:]
                
                for document in documents {
                    let data = document.data()
                    
                    if let isRead = data["isRead"] as? Bool, !isRead {
                        unreadCount += 1
                    }
                    
                    if let openCount = data["openCount"] as? Int {
                        totalOpenCount += openCount
                    }
                    
                    if let clickCount = data["clickCount"] as? Int {
                        totalClickCount += clickCount
                    }
                    
                    if let type = data["type"] as? String {
                        typeCounts[type, default: 0] += 1
                    }
                }
                
                analytics = [
                    "totalNotifications": documents.count,
                    "unreadCount": unreadCount,
                    "totalOpenCount": totalOpenCount,
                    "totalClickCount": totalClickCount,
                    "openRate": documents.count > 0 ? Double(totalOpenCount) / Double(documents.count) : 0.0,
                    "clickRate": documents.count > 0 ? Double(totalClickCount) / Double(documents.count) : 0.0,
                    "typeCounts": typeCounts
                ]
                
                completion(analytics)
            }
    }
    
    // MARK: - Helper Functions
    
    private func fetchUser(withUid uid: String, completion: @escaping(Result<User, Error>) -> Void) {
        db.collection("users")
            .document(uid)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let snapshot = snapshot, let user = try? snapshot.data(as: User.self) else {
                    let error = NSError(domain: "NotificationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                    completion(.failure(error))
                    return
                }
                completion(.success(user))
            }
    }
    
    private func fetchPod(withId id: String, completion: @escaping(Pod?) -> Void) {
        db.collection("pods")
            .document(id)
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot, let pod = try? snapshot.data(as: Pod.self) else {
                    completion(nil)
                    return
                }
                completion(pod)
            }
    }
    
    // MARK: - Admin Functions
    
    /// Send custom notification (for admin use)
    func sendCustomNotification(to recipientId: String, title: String, body: String, data: [String: String] = [:], completion: @escaping(Bool) -> Void) {
        
        guard let _ = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let functions = Functions.functions()
        let sendNotification = functions.httpsCallable("sendPushNotification")
        
        let notificationData: [String: Any] = [
            "recipientId": recipientId,
            "title": title,
            "body": body,
            "data": data
        ]
        
        sendNotification.call(notificationData) { result, error in
            if let error = error {
                print("Error sending custom notification: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    /// Get unread notification count (only recent notifications - last 7 days)
    func getUnreadNotificationCount(forUser uid: String, completion: @escaping(Int) -> Void) {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let sevenDaysAgoTimestamp = Timestamp(date: sevenDaysAgo)
        
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("isRead", isEqualTo: false)
            .whereField("createdAt", isGreaterThanOrEqualTo: sevenDaysAgoTimestamp)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching unread count: \(error.localizedDescription)")
                    completion(0)
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                print("📱 Unread notification count: \(count) (last 7 days)")
                completion(count)
            }
    }
    
    /// Listen for real-time notification updates
    func listenForNotifications(forUser uid: String, completion: @escaping([Notification]) -> Void) -> ListenerRegistration {
        // Calculate date one week ago
        let oneWeekAgo = Timestamp(date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        
        return db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .whereField("createdAt", isGreaterThan: oneWeekAgo)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for notifications: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                var notifications = documents.compactMap({ try? $0.data(as: Notification.self) })
                
                // Fetch sender and content details for each notification
                let group = DispatchGroup()
                
                for i in 0..<notifications.count {
                    group.enter()
                    
                    // Fetch sender
                    self.fetchUser(withUid: notifications[i].senderId) { result in
                        switch result {
                        case .success(let user):
                            notifications[i].sender = user
                        case .failure(let error):
                            print("Error fetching sender user: \(error.localizedDescription)")
                        }
                        group.leave()
                    }
                    
                    // Fetch content if available
                    if let contentId = notifications[i].contentId {
                        group.enter()
                        self.fetchPod(withId: contentId) { pod in
                            notifications[i].content = pod
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    completion(notifications)
                }
            }
    }
    
    // MARK: - Debug Helpers
    
    /// Test notification creation with FCM verification
    /// - Parameters:
    ///   - recipientId: User ID to send test notification to
    ///   - completion: Success callback
    func testNotificationWithFCMCheck(to recipientId: String, completion: @escaping(Bool) -> Void) {
        guard let senderId = Auth.auth().currentUser?.uid else {
            print("❌ No current user to send test notification")
            completion(false)
            return
        }
        
        print("🧪 Testing notification system for recipient: \(recipientId)")
        
        // First check if recipient has FCM token
        FCMService.shared.getFCMToken(forUser: recipientId) { token in
            if let token = token, !token.isEmpty {
                print("✅ Recipient has FCM token: \(token.prefix(30))...")
                
                // Create test notification
                self.createNotification(
                    type: .like,
                    senderId: senderId,
                    recipientId: recipientId,
                    contentId: "test_content_id"
                ) { success in
                    if success {
                        print("✅ Test notification created successfully!")
                        print("📱 Push notification should be sent automatically by cloud function")
                    } else {
                        print("❌ Failed to create test notification")
                    }
                    completion(success)
                }
            } else {
                print("❌ Recipient has NO FCM token!")
                print("💡 They will NOT receive push notifications")
                print("🔧 Recipient needs to:")
                print("   1. Allow notification permissions")
                print("   2. Log into the app")
                print("   3. Check console for FCM token verification")
                completion(false)
            }
        }
    }
} 
