//
//  RepostRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher

struct RepostRowView: View {
    let repost: Repost
    @State private var pod: Pod?
    @State private var originalUser: User?
    @State private var repostUser: User?
    @State private var isUserDataLoading = true
    
    private let userService = UserService()
    private let podService = PodService()
    private let conversationService = ConversationService()
    
    var body: some View {
        VStack(spacing: 0) {
            if let pod = pod {
                // Enhanced repost header with glass morphism
                VStack(spacing: 16) {
                    // Enhanced repost header section
                    HStack(spacing: 12) {
                        // Enhanced repost icon with glass morphism
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color("accentColor").opacity(0.2),
                                            Color("accentColor").opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "arrow.2.squarepath")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("accentColor"))
                        }
                        
                        // Enhanced repost user info
                        HStack(spacing: 8) {
                            // Enhanced repost user profile photo
                            if isUserDataLoading {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                    )
                            } else if let repostUser = repostUser, !repostUser.profileImageUrl.isEmpty {
                                KFImage(URL(string: repostUser.profileImageUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Enhanced repost user name with verified badge
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(repostUser?.username ?? "Loading...")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    if repostUser?.isVerified == true {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text("reposted")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Enhanced time indicator
                        Text(getTimeAgo())
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.05))
                            )
                    }
                    
                    // Enhanced caption section with glass morphism
                    if let caption = repost.caption, !caption.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                                
                                Text("Caption")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(caption)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.2), Color.clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    
                    // Use PodRowViewThin for consistent styling
                    if isPodDeleted {
                        DeletedPodRowView(pod: pod) {
                            // This will be handled by the parent view that manages reposts
                        }
                    } else {
                        PodRowViewThin(pod: pod)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: Color.black.opacity(0.08),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            loadRepostData()
        }
        .onChange(of: repost.id) { _ in
            loadRepostData()
        }
    }
    
    private func loadRepostData() {
        isUserDataLoading = true
        
        // Load pod data from main collection to get accurate like count
        conversationService.fetchPod(withPodId: repost.podId) { fetchedPod in
            DispatchQueue.main.async {
                self.pod = fetchedPod
            }
        }
        
        // Load user objects (not just usernames)
        let group = DispatchGroup()
        
        group.enter()
        userService.fetchUser(withUid: repost.originalUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.originalUser = user
                case .failure(let error):
                    print("Error fetching original user: \(error.localizedDescription)")
                }
            }
            group.leave()
        }
        
        group.enter()
        userService.fetchUser(withUid: repost.repostUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.repostUser = user
                case .failure(let error):
                    print("Error fetching repost user: \(error.localizedDescription)")
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isUserDataLoading = false
        }
    }
    
    // Check if the pod is deleted and show appropriate UI
    private var isPodDeleted: Bool {
        return pod?.isDeleted == true
    }
    
    // MARK: - Helper Functions
    
    func getTimeAgo() -> String {
        let currentTime = Date()
        let repostTime = repost.timestamp
        let timeDiff = currentTime.timeIntervalSince(repostTime)
        
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        
        if timeDiff < 60 {
            formatter.allowedUnits = [.second]
        } else if timeDiff < 3600 {
            formatter.allowedUnits = [.minute]
        } else if timeDiff < 86400 {
            formatter.allowedUnits = [.hour]
        } else if timeDiff < 2592000 {
            formatter.allowedUnits = [.day]
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .none
            let dateString = dateFormatter.string(from: repostTime)
            return dateString
        }
        
        guard let timeAgoString = formatter.string(from: timeDiff) else {
            return ""
        }
        
        return timeAgoString + " ago"
    }
}

struct RepostRowView_Previews: PreviewProvider {
    static var previews: some View {
        RepostRowView(repost: Repost(
            podId: "test",
            originalUserId: "original",
            repostUserId: "repost",
            caption: "This is amazing!"
        ))
    }
} 
