import SwiftUI
import Kingfisher

struct NotificationRowView: View {
    @ObservedObject var viewModel: NotificationViewModel
    let notification: Notification
    
    init(notification: Notification, viewModel: NotificationViewModel) {
        self.viewModel = viewModel
        self.notification = notification
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Image with modern styling
            if let sender = notification.sender {
                NavigationLink {
                    ProfileView(user: sender)
                } label: {
                    if sender.profileImageUrl != "" {
                        KFImage(URL(string: sender.profileImageUrl))
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
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Notification Content with modern layout
            VStack(alignment: .leading, spacing: 6) {
                // User name and verification
                HStack(spacing: 6) {
                    if let sender = notification.sender {
                        Text(sender.fullname ?? sender.username)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if sender.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(.systemBlue))
                        }
                    }
                    
                    Spacer()
                    
                    // Timestamp
                    Text(notification.createdAt.dateValue().timeAgoDisplay())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Notification message
                Text(notification.message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Comment preview for comment notifications
                if notification.type == .comment, let commentText = notification.commentText {
                    Text(commentText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            
            // Content Preview (if available) with modern styling
            if let content = notification.content {
                NavigationLink {
                    PlayerView(url: URL(string: content.fileUrl)!, pod: content)
                } label: {
                    KFImage(URL(string: content.thumbnailUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 42) // 4:3 aspect ratio (56/42 = 1.33)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            notification.isRead ? Color.clear : Color("accentColor").opacity(0.3),
                            lineWidth: notification.isRead ? 0 : 1
                        )
                )
                .shadow(
                    color: notification.isRead ? Color.black.opacity(0.04) : Color.black.opacity(0.08),
                    radius: notification.isRead ? 6 : 12,
                    x: 0,
                    y: notification.isRead ? 2 : 4
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// Helper extension for time ago display
extension Date {
    func timeAgoDisplay() -> String {
        let currentTime = Date()
        let timeDiff = currentTime.timeIntervalSince(self)
        
        // Less than 1 minute
        if timeDiff < 60 {
            return "now"
        }
        
        // Minutes (1-59 minutes)
        if timeDiff < 3600 {
            let minutes = Int(timeDiff / 60)
            return "\(minutes)m"
        }
        
        // Hours (1-23 hours)
        if timeDiff < 86400 {
            let hours = Int(timeDiff / 3600)
            return "\(hours)h"
        }
        
        // Days (1-6 days)
        if timeDiff < 604800 { // 7 days in seconds
            let days = Int(timeDiff / 86400)
            return "\(days)d"
        }
        
        // Weeks (1-4 weeks)
        if timeDiff < 2419200 { // 4 weeks in seconds
            let weeks = Int(timeDiff / 604800)
            return "\(weeks)w"
        }
        
        // After 4 weeks, show the actual date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

