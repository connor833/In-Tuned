//
//  PodRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher
import Firebase

struct PodRowView: View {
    @State private var showingComments = false
    @State private var showingSendView = false
    @StateObject var viewModel: PodViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    let lineLimit = 2

    let pod: Pod
    let onPodSelected: ((Pod) -> Void)?
    
    init(pod: Pod, onPodSelected: ((Pod) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: PodViewModel(pod: pod))
        self.pod = pod
        self.onPodSelected = onPodSelected
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern floating card container
            VStack(spacing: 16) {
                // User info and pod title section
                userInfoSection
                
                // Thumbnail section
                thumbnailSection
                
                // Content section
                contentSection
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
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        HStack(spacing: 12) {
            if !viewModel.hasLoadedUser {
                // Modern loading state
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loading...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Please wait")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            } else {
                // Profile image
                NavigationLink {
                    ProfileView(user: viewModel.pod.user ?? PreviewClass().loadingUser)
                } label: {
                    Group {
                        if let profileImageUrl = viewModel.pod.user?.profileImageUrl, !profileImageUrl.isEmpty {
                            KFImage(URL(string: profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    NavigationLink {
                        ProfileView(user: viewModel.pod.user ?? PreviewClass().loadingUser)
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.pod.user?.fullname ?? "Unknown User")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if viewModel.pod.user?.isVerified ?? false {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(.systemBlue))
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("@\(viewModel.pod.user?.username ?? "unknown")")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Time ago
                Text(getTimeAgo())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
    
    // MARK: - Thumbnail Section
    
    private var thumbnailSection: some View {
        Group {
            if (pod.isDeleted ?? false) == true {
                // Deleted pod placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Text("Pod not available")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    )
            } else {
                // Active pod thumbnail
                Group {
                    if let onPodSelected = onPodSelected {
                        // Use callback for video replacement (PlayerView)
                        Button(action: {
                            onPodSelected(pod)
                        }) {
                            thumbnailContent
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Use NavigationLink for standalone navigation (Feed)
                        NavigationLink {
                            PlayerView(url: URL(string: pod.fileUrl)!, pod: pod)
                                .id(pod.id)
                        } label: {
                            thumbnailContent
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Thumbnail Content
    
    private var thumbnailContent: some View {
        HStack {
            Spacer()
            KFImage(URL(string: pod.thumbnailUrl))
                .resizable()
                .aspectRatio(contentMode: .fit) // Changed from scaledToFill to fit to preserve aspect ratio
                .frame(maxHeight: 200) // Use maxHeight instead of fixed height
                .clipped()
                .cornerRadius(12)
            Spacer()
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(pod.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor((pod.isDeleted ?? false) ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Description
            if !pod.description.isEmpty {
                Text(pod.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor((pod.isDeleted ?? false) ? .secondary : .secondary)
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
            }
            
            // Stats row
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                    
                    Text("\(viewModel.pod.likes) \(viewModel.pod.likes == 1 ? "like" : "likes")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
        }
        .onAppear {
            print("🔍 POD_ROW_VIEW: onAppear for pod: \(pod.id ?? "no-id")")
            print("🔍 POD_ROW_VIEW: pod.title: \(pod.title)")
            print("🔍 POD_ROW_VIEW: pod.userId: \(pod.userId)")
            print("🔍 POD_ROW_VIEW: viewModel.hasLoadedUser: \(viewModel.hasLoadedUser)")
            print("🔍 POD_ROW_VIEW: viewModel.pod.user: \(viewModel.pod.user?.username ?? "nil")")
            print("🔍 POD_ROW_VIEW: viewModel.pod.user?.uid: \(viewModel.pod.user?.uid ?? "nil")")
            
            // User loading is handled in PodViewModel.init, no need to duplicate here
        }
        .sheet(isPresented: $showingComments) {
            if #available(iOS 16.0, *) {
                CommentsView(pod: pod, comment: PreviewClass().previewComment)
                    .presentationDetents([.fraction(0.80)])
                    .presentationDragIndicator(.hidden)
            } else {
                CommentsView(pod: pod, comment: PreviewClass().previewComment)
            }
        }
        .sheet(isPresented: $showingSendView) {
            SendPodView(pod: pod)
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

struct PodRowView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack{
                ForEach(0..<25) { _ in
                    ForEach(ColorScheme.allCases, id: \.self, content: PodRowView(pod: PreviewClass().previewPod, onPodSelected: nil).preferredColorScheme)
                    
                }
            }
        }
    }
}
