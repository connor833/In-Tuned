//
//  PodRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher
import Firebase
import FirebaseAuth

struct PodGridView: View {
    @ObservedObject var viewModel: PodViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var expanded: Bool = false
    @State private var truncated: Bool = false
    @State private var cachedUser: User? // Cache user data to prevent re-fetching
    @State private var isUserBlocked: Bool = false // Add blocking state
    let lineLimit = 2
    
    var pod: Pod
    private let blockService = BlockService() // Add blocking service
    
    init(pod: Pod, viewModel: PodViewModel) {
        self.pod = pod
        self.viewModel = viewModel
    }
    
    private var moreLessText: String {
            if !truncated {
                return ""
            } else {
                return self.expanded ? "read less" : " read more"
            }
        }
    
    // Use cached user or fallback to viewModel.pod.user
    private var displayUser: User? {
        if let cached = cachedUser {
            return cached
        }
        return viewModel.pod.user
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail section with modern styling
            NavigationLink {
                PlayerView(url: (URL(string: pod.fileUrl))!, pod: pod)
            } label: {
                KFImage(URL(string: pod.thumbnailUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fit) // Changed from fill to fit to preserve aspect ratio
                    .frame(maxHeight: 100) // Use maxHeight instead of fixed height
                    .clipped()
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 6) {
                // Title
                Text(pod.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // User info section
                NavigationLink {
                    ProfileView(user: displayUser ?? PreviewClass().loadingUser)
                } label: {
                    HStack(spacing: 4) {
                        // Profile image
                        if let profileImageUrl = displayUser?.profileImageUrl, !profileImageUrl.isEmpty {
                            KFImage(URL(string: profileImageUrl))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // Username
                        Text("@\(displayUser?.username ?? "")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // Verification badge
                        if (displayUser?.isVerified ?? false) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(.systemBlue))
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Description
                if !pod.description.isEmpty {
                    Text(pod.description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(expanded ? nil : lineLimit)
                        .multilineTextAlignment(.leading)
                        .background(
                            Text(pod.description).lineLimit(lineLimit)
                                .background(GeometryReader { visibleTextGeometry in
                                    ZStack {
                                        Text(self.pod.description)
                                            .background(GeometryReader { fullTextGeometry in
                                                Color.clear.onAppear {
                                                    self.truncated = fullTextGeometry.size.height > visibleTextGeometry.size.height
                                                }
                                            })
                                    }
                                    .frame(height: .greatestFiniteMagnitude)
                                })
                                .hidden()
                        )
                }
                
                // Read more/less button
                if truncated {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            expanded.toggle()
                        }
                    }) {
                        Text(moreLessText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color("accentColor"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Stats row
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                        
                        Text("\(viewModel.pod.likes)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.04),
                    radius: 4,
                    x: 0,
                    y: 1
                )
        )
        .onAppear {
            // Cache user data to prevent re-fetching on re-renders
            if cachedUser == nil && viewModel.pod.user != nil {
                cachedUser = viewModel.pod.user
            }
            // Check if current user has blocked the pod author
            checkBlockingStatus()
        }
    }
    
    // MARK: - Blocking Methods
    
    private func checkBlockingStatus() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Check if current user has blocked the pod author
        blockService.checkIfUserIsBlocked(userId: pod.userId) { isBlocked in
            DispatchQueue.main.async {
                self.isUserBlocked = isBlocked
            }
        }
    }
    
    func getTimeAgo() -> String {
        let currentTime = Date()
        let postedTime = pod.timestamp.dateValue()
        let timeDiff = currentTime.timeIntervalSince(postedTime)
        
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
            let dateString = dateFormatter.string(from: postedTime)
            return dateString
        }
        
        guard let timeAgoString = formatter.string(from: timeDiff) else {
            return ""
        }
        
        return timeAgoString + " ago"
    }
    
}

struct PodGridView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 16) {
                ForEach(0..<25) { _ in
                    ForEach(ColorScheme.allCases, id: \.self, content: PodGridView(pod: PreviewClass().previewPod, viewModel: PodViewModel(pod: PreviewClass().previewPod)).preferredColorScheme)
                }
            }
        }
    }
}
