import SwiftUI

/// Custom message tab view with unread message badge overlay
struct MessageTabBadgeView: View {
    @ObservedObject var messageBadgeManager = MessageBadgeManager.shared
    
    var body: some View {
        ZStack {
            // Message icon
            Image(systemName: "envelope")
                .font(.title2)
                .foregroundColor(Color("textColor"))
            
            // Unread message badge
            if messageBadgeManager.unreadMessageCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 18, height: 18)
                    
                    Text("\(min(messageBadgeManager.unreadMessageCount, 99))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

#Preview {
    MessageTabBadgeView()
}
