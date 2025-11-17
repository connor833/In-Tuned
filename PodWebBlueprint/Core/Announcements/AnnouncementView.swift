//
//  AnnouncementView.swift
//  PodWebBlueprint
//
//  View for displaying announcements to users
//

import SwiftUI

struct AnnouncementView: View {
    let announcement: Announcement
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Priority Badge
                        if announcement.priority == .high || announcement.priority == .critical {
                            HStack {
                                Image(systemName: announcement.priority == .critical ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                    .foregroundColor(announcement.priority == .critical ? .red : .orange)
                                
                                Text(announcement.priority == .critical ? "Important" : "Notice")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(announcement.priority == .critical ? .red : .orange)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background((announcement.priority == .critical ? Color.red : Color.orange).opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Optional Image
                        if let imageURL = announcement.imageURL, let url = URL(string: imageURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipped()
                                        .cornerRadius(12)
                                case .failure(_):
                                    EmptyView()
                                case .empty:
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                        .overlay(ProgressView())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        // Message
                        Text(announcement.message)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                        
                        // Optional Action Button
                        if let buttonText = announcement.actionButtonText,
                           let urlString = announcement.actionButtonURL,
                           let url = URL(string: urlString) {
                            Link(destination: url) {
                                HStack {
                                    Text(buttonText)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Dismiss Button
                Button(action: onDismiss) {
                    Text("Got It")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle(announcement.title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Announcement Modal Manager

struct AnnouncementModalModifier: ViewModifier {
    @State private var announcements: [Announcement] = []
    @State private var currentAnnouncementIndex = 0
    @State private var showAnnouncement = false
    
    func body(content: Content) -> some View {
        content
            .task {
                await loadAnnouncements()
            }
            .sheet(isPresented: $showAnnouncement) {
                if currentAnnouncementIndex < announcements.count {
                    AnnouncementView(
                        announcement: announcements[currentAnnouncementIndex],
                        onDismiss: handleDismiss
                    )
                    .onAppear {
                        let announcement = announcements[currentAnnouncementIndex]
                        print("📢 Showing announcement: \(announcement.title)")
                        print("📢 Message: \(announcement.message)")
                        print("📢 Priority: \(announcement.priority)")
                    }
                } else {
                    Text("No announcement data")
                        .padding()
                }
            }
    }
    
    private func loadAnnouncements() async {
        do {
            announcements = try await AnnouncementService.shared.fetchUnseenAnnouncements()
            if !announcements.isEmpty {
                showAnnouncement = true
            }
        } catch {
            print("⚠️ Failed to load announcements: \(error)")
        }
    }
    
    private func handleDismiss() {
        guard currentAnnouncementIndex < announcements.count else { return }
        
        let announcement = announcements[currentAnnouncementIndex]
        if let id = announcement.id {
            AnnouncementService.shared.markAsSeen(announcementId: id)
        }
        
        // Show next announcement if available
        if currentAnnouncementIndex + 1 < announcements.count {
            currentAnnouncementIndex += 1
            showAnnouncement = true
        } else {
            showAnnouncement = false
        }
    }
}

// MARK: - View Extension

extension View {
    func withAnnouncements() -> some View {
        modifier(AnnouncementModalModifier())
    }
}

