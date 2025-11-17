//
//  AnnouncementTestView.swift
//  PodWebBlueprint
//
//  Test helper view for announcements (use in debug builds only)
//

import SwiftUI

struct AnnouncementTestView: View {
    @State private var showPreview = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            Section(header: Text("Test Announcements")) {
                Button("Clear Seen Announcements") {
                    AnnouncementService.shared.clearSeenAnnouncements()
                    alertMessage = "Cleared! Restart the app to see announcements again."
                    showAlert = true
                }
                
                Button("Preview Sample Announcement") {
                    showPreview = true
                }
            }
            
            Section(header: Text("Firestore Setup")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create an 'announcements' collection in Firestore with documents containing:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("""
                    • title (String)
                    • message (String)
                    • createdAt (Timestamp)
                    • expiresAt (Timestamp)
                    • priority (String: low/medium/high/critical)
                    • targetAudience (String: all/new_users/existing_users)
                    • imageURL (String, optional)
                    • actionButtonText (String, optional)
                    • actionButtonURL (String, optional)
                    • minAppVersion (String, optional)
                    • maxAppVersion (String, optional)
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .navigationTitle("Announcements")
        .alert("Success", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showPreview) {
            AnnouncementView(
                announcement: Announcement(
                    id: "preview",
                    title: "What's New in v2.0! 🎉",
                    message: "We've added exciting new features including improved podcast discovery, enhanced audio quality, and a redesigned user interface. Thank you for being part of our community!",
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
                    priority: .high,
                    imageURL: nil,
                    actionButtonText: "Explore New Features",
                    actionButtonURL: "podwebblueprint://explore",
                    targetAudience: .all,
                    minAppVersion: nil,
                    maxAppVersion: nil
                ),
                onDismiss: { showPreview = false }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    NavigationStack {
        AnnouncementTestView()
    }
}

