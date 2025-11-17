import Foundation
import Firebase
import SwiftUI
import FirebaseAuth

/// Manages unread message counts and displays them as badges over the message tab
class MessageBadgeManager: ObservableObject {
    static let shared = MessageBadgeManager()
    private let db = Firestore.firestore()
    
    @Published var unreadMessageCount: Int = 0
    
    private init() {}
    
    /// Updates the unread message count for the current user
    func updateUnreadMessageCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching conversations: \(error.localizedDescription)")
                    return
                }
                
                var totalUnread = 0
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    if let lastMessageTimestamp = data["lastMessageTimestamp"] as? Timestamp,
                       let lastMessageSenderId = data["lastMessageSenderId"] as? String,
                       let lastReadTimestamp = data["lastReadTimestamp"] as? [String: Timestamp],
                       lastMessageSenderId != uid { // Don't count your own messages
                        
                        let userLastRead = lastReadTimestamp[uid] ?? Timestamp(date: Date(timeIntervalSince1970: 0))
                        
                        if lastMessageTimestamp.dateValue() > userLastRead.dateValue() {
                            totalUnread += 1
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self?.unreadMessageCount = totalUnread
                    print("💬 Unread message count: \(totalUnread)")
                }
            }
    }
    
    /// Clears the unread message count (called when messages tab is opened)
    func clearUnreadMessageCount() {
        unreadMessageCount = 0
        print("💬 Message badge cleared")
    }
    
    /// Marks a specific conversation as read
    func markConversationAsRead(conversationId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("conversations").document(conversationId).updateData([
            "lastReadTimestamp.\(uid)": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Error marking conversation as read: \(error.localizedDescription)")
            } else {
                print("✅ Conversation marked as read")
                self.updateUnreadMessageCount()
            }
        }
    }
    
    /// Listens for real-time updates to unread message count
    func startListeningForUnreadMessages() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening for conversations: \(error.localizedDescription)")
                    return
                }
                
                self?.updateUnreadMessageCount()
            }
    }
    
    /// Complete cleanup on logout
    func completeCleanup() {
        print("🚫 MessageBadgeManager: Starting complete cleanup")
        unreadMessageCount = 0
        // Firestore listeners will be automatically cleaned up
        print("✅ MessageBadgeManager: Cleanup complete")
    }
}
