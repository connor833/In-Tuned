//
//  ConversationsRowView.swift
//  CryptChat
//
//  Created by Connor Adams on 8/10/22.
//

import SwiftUI
import Kingfisher
import FirebaseFirestore
import FirebaseAuth
import Firebase

struct ConversationsRowView: View {
    // MARK: - Properties
    
    let conversation: Conversation
    let latestMessage: Message?
    let podCreatorUsername: String?
    let otherUser: User?
    let showLastMessage: Bool
    let showUnreadIndicator: Bool
    
    // Delete conversation state
    @State private var isDeleting = false
    @State private var showingDeleteAlert = false
    
    // Callback for when conversation is deleted
    let onConversationDeleted: (() -> Void)?
    
    // MARK: - Initialization
    
    init(conversation: Conversation, latestMessage: Message?, podCreatorUsername: String? = nil, otherUser: User? = nil, showLastMessage: Bool = true, showUnreadIndicator: Bool = true, onConversationDeleted: (() -> Void)? = nil) {
        self.conversation = conversation
        self.latestMessage = latestMessage
        self.podCreatorUsername = podCreatorUsername
        self.otherUser = otherUser
        self.showLastMessage = showLastMessage
        self.showUnreadIndicator = showUnreadIndicator
        self.onConversationDeleted = onConversationDeleted
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Image with modern styling
            if let otherUser = otherUser, !otherUser.profileImageUrl.isEmpty {
                KFImage(URL(string: otherUser.profileImageUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
            }
            
            // Conversation Content with modern layout
            VStack(alignment: .leading, spacing: 6) {
                // User name and verification
                HStack(spacing: 6) {
                    Text(otherUser?.fullname ?? "User")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let otherUser = otherUser, otherUser.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(.systemBlue))
                    }
                    
                    Spacer()
                    
                    // Timestamp
                    Text(conversation.lastActivity.timeAgoDisplay())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Last message or username
                if showLastMessage {
                    if let message = latestMessage {
                        if message.isPod {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                                
                                if let username = podCreatorUsername {
                                    Text("Pod by \(username)")
                                        .font(.system(size: 14, weight: isLastMessageUnread ? .semibold : .regular))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Pod shared")
                                        .font(.system(size: 14, weight: isLastMessageUnread ? .semibold : .regular))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text(message.text)
                                .font(.system(size: 14, weight: isLastMessageUnread ? .semibold : .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    } else {
                        Text("No messages yet")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    // Show username instead of last message when showLastMessage is false
                    Text("@\(otherUser?.username ?? "username")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(.systemBlue))
                }
            }
            
            // Unread indicator with modern styling
            if showUnreadIndicator && isLastMessageUnread {
                VStack {
                    Circle()
                        .fill(Color("accentColor"))
                        .frame(width: 8, height: 8)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            (showUnreadIndicator && isLastMessageUnread) ? Color("accentColor").opacity(0.2) : Color.clear,
                            lineWidth: (showUnreadIndicator && isLastMessageUnread) ? 1 : 0
                        )
                )
                .shadow(
                    color: (showUnreadIndicator && isLastMessageUnread) ? Color.black.opacity(0.08) : Color.black.opacity(0.04),
                    radius: (showUnreadIndicator && isLastMessageUnread) ? 8 : 4,
                    x: 0,
                    y: (showUnreadIndicator && isLastMessageUnread) ? 3 : 2
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contextMenu {
            Button(role: .destructive) {
                deleteConversation()
            } label: {
                if isDeleting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Label("Delete Conversation", systemImage: "trash")
                }
            }
            .disabled(isDeleting)
        }
        .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performDeleteConversation()
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    
    private var isLastMessageUnread: Bool {
        guard let currentUid = Auth.auth().currentUser?.uid,
              let latestMessage = latestMessage else { return false }
        
        // Message is unread if:
        // 1. Current user is not the sender of the last message
        // 2. Current user is not in the lastMessageReadBy array
        let isFromOtherUser = latestMessage.senderId != currentUid
        let hasNotRead = !(conversation.lastMessageReadBy?.contains(currentUid) ?? false)
        
        return isFromOtherUser && hasNotRead
    }
    
    private func getOtherParticipant() -> String? {
        guard let currentUid = Auth.auth().currentUser?.uid else { return nil }
        return conversation.participants.first { $0 != currentUid }
    }
    
    // MARK: - Delete Conversation Methods
    
    private func deleteConversation() {
        guard let conversationId = conversation.id else {
            print("No conversation ID available")
            return
        }
        
        showingDeleteAlert = true
    }
    
    private func performDeleteConversation() {
        print("🔍 === DELETE CONVERSATION FROM ROW VIEW ===")
        
        guard let conversationId = conversation.id else {
            print("❌ No conversation ID available")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No current user ID")
            return
        }
        
        print("✅ Conversation ID: \(conversationId)")
        print("✅ Current user ID: \(currentUserId)")
        
        isDeleting = true
        
        // Direct Firestore updates to mark conversation as deleted
        let db = Firestore.firestore()
        
        // 1. Update the main conversation document
        let conversationRef = db.collection("conversations").document(conversationId)
        let updateData: [String: Any] = [
            "deletedFor.\(currentUserId)": [
                "deletedAt": FieldValue.serverTimestamp(),
                "isDeleted": true
            ]
        ]
        
        // 2. Update the user's conversation reference
        let userConversationRef = db.collection("users").document(currentUserId)
            .collection("conversations").document(conversationId)
        let userUpdateData: [String: Any] = [
            "isDeleted": true,
            "deletedAt": FieldValue.serverTimestamp()
        ]
        
        // Perform both updates
        conversationRef.updateData(updateData) { error in
            if let error = error {
                print("❌ Error updating main conversation: \(error)")
                DispatchQueue.main.async {
                    self.isDeleting = false
                    // TODO: Show error alert to user
                }
                return
            }
            
            print("✅ Main conversation updated successfully")
            
            // Update user's conversation reference
            userConversationRef.updateData(userUpdateData) { error in
                DispatchQueue.main.async {
                    self.isDeleting = false
                    
                    if let error = error {
                        print("❌ Error updating user conversation reference: \(error)")
                        // TODO: Show error alert to user
                    } else {
                        print("✅ User conversation reference updated successfully")
                        print("✅ Conversation marked as deleted for user \(currentUserId)")
                        
                        // Call the callback to refresh the conversation list
                        self.onConversationDeleted?()
                    }
                }
            }
        }
    }
}

struct ConversationsRowView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationsRowView(
            conversation: Conversation(
                type: .oneOnOne,
                participants: ["user1", "user2"],
                lastMessage: nil,
                lastActivity: Date(),
                name: nil,
                createdAt: Date(),
                createdBy: "user1"
            ),
            latestMessage: nil,
            otherUser: PreviewClass().previewUser
        )
    }
}
