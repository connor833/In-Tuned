//
//  AnnouncementDebugView.swift
//  Attuned
//
//  Debug view for testing announcements
//

import SwiftUI

struct AnnouncementDebugView: View {
    @State private var message = ""
    
    var body: some View {
        List {
            Section("Debug Actions") {
                Button(action: clearSeenAnnouncements) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Seen Announcements")
                        Spacer()
                    }
                }
                
                Button(action: fetchAnnouncements) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Fetch Announcements")
                        Spacer()
                    }
                }
            }
            
            if !message.isEmpty {
                Section("Result") {
                    Text(message)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Announcement Debug")
    }
    
    private func clearSeenAnnouncements() {
        AnnouncementService.shared.clearSeenAnnouncements()
        message = "✅ Cleared all seen announcements. Close and reopen the app to see announcements again."
    }
    
    private func fetchAnnouncements() {
        Task {
            do {
                let announcements = try await AnnouncementService.shared.fetchUnseenAnnouncements()
                await MainActor.run {
                    if announcements.isEmpty {
                        message = "No unseen announcements found. Check console logs for details."
                    } else {
                        message = "Found \(announcements.count) announcement(s):\n" + 
                                 announcements.map { "• \($0.title)" }.joined(separator: "\n")
                    }
                }
            } catch {
                await MainActor.run {
                    message = "❌ Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AnnouncementDebugView()
    }
}

