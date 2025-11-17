import SwiftUI

/// Custom notification bell view with unread notification badge overlay
struct NotificationBadgeView: View {
    @ObservedObject var notificationBadgeManager = NotificationBadgeManager.shared
    
    var body: some View {
        ZStack {
            // Bell icon
            Image(systemName: "bell")
                .font(.headline)
                .foregroundColor(Color("textColor"))
            
            // Unread notification badge
            if notificationBadgeManager.unreadNotificationCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color("accentColor"))
                        .frame(width: 18, height: 18)
                    
                    if notificationBadgeManager.unreadNotificationCount > 99 {
                        // Show exclamation point for 99+ notifications
                        Text("!")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        // Show count for 1-99 notifications
                        Text("\(notificationBadgeManager.unreadNotificationCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

#Preview {
    NotificationBadgeView()
}
