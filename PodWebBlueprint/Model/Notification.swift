//
//  Notification.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 5/25/25.
//

import Foundation
import FirebaseFirestore
import Firebase

struct Notification: Identifiable, Codable, Hashable, Equatable {
    @DocumentID var id: String?
    let senderId: String
    let recipientId: String
    let createdAt: Timestamp
    let type: NotificationType
    let contentId: String?  // ID of the related content (pod, comment, etc.)
    let commentText: String?  // Text of the comment for comment notifications
    let messageText: String?  // Text of the message for message notifications
    
    // Essential production fields
    let version: Int
    let updatedAt: Timestamp?
    
    // Notification metadata
    let category: NotificationCategory
    let isRead: Bool
    
    // Grouping support
    let groupId: String?  // For grouping similar notifications
    
    // Rich content support
    let deepLink: String?  // Deep link for notification action
    
    // Optional fields for additional context (not stored in Firestore)
    var sender: User?  // The user who triggered the notification
    var content: Pod?  // The related content if it's a pod
    
    // Computed property to get a user-friendly message (excluded from encoding)
    var message: String {
        switch type {
        case .like:
            return NSLocalizedString("liked your pod", comment: "")
        case .comment:
            return NSLocalizedString("commented on your pod", comment: "")
        case .follow:
            return NSLocalizedString("started following you", comment: "")
        case .followRequest:
            return NSLocalizedString("requested to follow you", comment: "")
        case .followRequestAccepted:
            return NSLocalizedString("accepted your follow request", comment: "")
        case .repost:
            return NSLocalizedString("reposted your pod", comment: "")
        case .message:
            return NSLocalizedString("sent you a message", comment: "")
        case .tag:
            return NSLocalizedString("tagged you in a pod", comment: "")
        case .system:
            return NSLocalizedString("system notification", comment: "")
        case .marketing:
            return NSLocalizedString("marketing notification", comment: "")
        case .reminder:
            return NSLocalizedString("reminder notification", comment: "")
        case .achievement:
            return NSLocalizedString("achievement unlocked", comment: "")
        }
    }
    
    // Custom coding keys to exclude computed properties from encoding
    enum CodingKeys: String, CodingKey {
        case id, senderId, recipientId, createdAt, type, contentId, commentText, messageText
        case version, updatedAt
        case category, isRead
        case groupId, deepLink
        // Exclude 'sender', 'content', 'message' as they're computed or not stored
    }
    
    // MARK: - Initializers
    
    init(senderId: String, recipientId: String, type: NotificationType, contentId: String? = nil, commentText: String? = nil, messageText: String? = nil, category: NotificationCategory = .social, groupId: String? = nil, deepLink: String? = nil) {
        self.id = nil
        self.senderId = senderId
        self.recipientId = recipientId
        self.createdAt = Timestamp()
        self.type = type
        self.contentId = contentId
        self.commentText = commentText
        self.messageText = messageText
        self.version = 2
        self.updatedAt = Timestamp()
        self.category = category
        self.isRead = false
        self.groupId = groupId
        self.deepLink = deepLink
        self.sender = nil
        self.content = nil
    }
    
    // Custom initializer for creating a notification with isRead = true
    init(senderId: String, recipientId: String, createdAt: Timestamp, type: NotificationType, contentId: String?, commentText: String?, messageText: String?, version: Int, updatedAt: Timestamp?, category: NotificationCategory, isRead: Bool, groupId: String?, deepLink: String?) {
        self.id = nil
        self.senderId = senderId
        self.recipientId = recipientId
        self.createdAt = createdAt
        self.type = type
        self.contentId = contentId
        self.commentText = commentText
        self.messageText = messageText
        self.version = version
        self.updatedAt = updatedAt
        self.category = category
        self.isRead = isRead
        self.groupId = groupId
        self.deepLink = deepLink
        self.sender = nil
        self.content = nil
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Notification, rhs: Notification) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Validation
    
    /// Validates the notification data
    func validate() throws {
        var errors: [String] = []
        
        if senderId.isEmpty { errors.append("Sender ID is required") }
        if recipientId.isEmpty { errors.append("Recipient ID is required") }
        if senderId == recipientId { errors.append("Cannot send notification to self") }
        
        if let commentText = commentText, commentText.count > 500 {
            errors.append("Comment text must be 500 characters or less")
        }
        
        if let messageText = messageText, messageText.count > 1000 {
            errors.append("Message text must be 1000 characters or less")
        }
        
        if !errors.isEmpty {
            throw NotificationError.validationFailed(errors)
        }
    }
}

// MARK: - Notification Errors

enum NotificationError: Error, LocalizedError {
    case validationFailed([String])
    case invalidInput(String)
    case networkError(Error)
    case notificationNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .notificationNotFound:
            return "Notification not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - Supporting Enums

// Enum to define different types of notifications
enum NotificationType: String, Codable, CaseIterable {
    case like
    case comment
    case follow
    case followRequest
    case followRequestAccepted
    case repost
    case message
    case tag
    case system
    case marketing
    case reminder
    case achievement
}

// Enum for notification categories
enum NotificationCategory: String, Codable, CaseIterable {
    case social
    case system
    case marketing
    case reminder
    case achievement
    case security
}
