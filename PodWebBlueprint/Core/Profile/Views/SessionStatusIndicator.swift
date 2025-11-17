import SwiftUI

/// Simple session status indicator for displaying in the main app
struct SessionStatusIndicator: View {
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var showSessionExpiringAlert = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Session status dot
            Circle()
                .fill(sessionManager.isSessionValid ? .green : .red)
                .frame(width: 8, height: 8)
            
            // Session status text
            Text(sessionManager.isSessionValid ? "Session Active" : "Session Inactive")
                .font(.caption2)
                .foregroundColor(sessionManager.isSessionValid ? .green : .red)
            
            // Session expiry warning
            if let expiresAt = sessionManager.sessionExpiresAt {
                let timeRemaining = expiresAt.timeIntervalSinceNow
                if timeRemaining < 24 * 60 * 60 && timeRemaining > 0 { // Less than 1 day
                    Button {
                        showSessionExpiringAlert = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption2)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpiringSoon)) { _ in
            showSessionExpiringAlert = true
        }
        .alert("Session Expiring Soon", isPresented: $showSessionExpiringAlert) {
            Button("OK") { }
            Button("Extend Session") {
                Task {
                    try? await sessionManager.refreshSession()
                }
            }
        } message: {
            Text("Your session will expire soon. You can extend it or let it expire naturally.")
        }
    }
}

// MARK: - Preview

struct SessionStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        SessionStatusIndicator()
    }
}
