//  PodRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher
import Firebase
import FirebaseAuth

struct PodRowViewThin: View {
    @ObservedObject var viewModel: PodViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    let lineLimit = 2

    let pod: Pod
    
    // Delete pod state
    @State private var isDeleting = false
    @State private var showingDeleteAlert = false
    
    // Bulk selection state
    let isInSelectionMode: Bool
    let isSelected: Bool
    let onSelectionChanged: ((Bool) -> Void)?
    
    // Callback for when pod is deleted
    let onPodDeleted: (() -> Void)?
    
    init(
        pod: Pod, 
        isInSelectionMode: Bool = false,
        isSelected: Bool = false,
        onSelectionChanged: ((Bool) -> Void)? = nil,
        onPodDeleted: (() -> Void)? = nil
    ) {
        self.viewModel = PodViewModel(pod: pod)
        self.pod = pod
        self.isInSelectionMode = isInSelectionMode
        self.isSelected = isSelected
        self.onSelectionChanged = onSelectionChanged
        self.onPodDeleted = onPodDeleted
    }
    

    
    var body: some View {
        Group {
            if pod.isDeleted == true {
                // For deleted pods, show content without navigation
                HStack(spacing: 16) {
                    // Thumbnail placeholder with modern styling
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 80, height: 60)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.system(size: 20, weight: .medium))
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Title
                        Text(pod.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Description
                        Text(pod.description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(lineLimit)
                            .truncationMode(.tail)
                        
                        // Deleted indicator with modern styling
                        Text("Pod not available")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.15))
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 8)
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
                .padding(.vertical, 6)
            } else {
                // For normal pods, show with navigation or selection
                if isInSelectionMode {
                    // In selection mode, make the whole row tappable for selection
                    Button(action: {
                        onSelectionChanged?(!isSelected)
                    }) {
                        podContent
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Normal navigation mode
                    NavigationLink {
                        PlayerView(url: URL(string: pod.fileUrl)!, pod: pod)
                            .id(pod.id)
                    } label: {
                        podContent
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Pod Content View
    private var podContent: some View {
        VStack(spacing: 12) {
            // User info section with title starting at same level
            HStack(alignment: .top, spacing: 12) {
                if !viewModel.hasLoadedUser {
                    // Loading state
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        )
                    
                    Text("Loading...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    // Profile image
                    KFImage(URL(string: viewModel.pod.user?.profileImageUrl ?? ""))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(viewModel.pod.user?.fullname ?? "Unknown User")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if viewModel.pod.user?.isVerified ?? false {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(.systemBlue))
                            }
                        }
                        
                        Text("@\(viewModel.pod.user?.username ?? "unknown")")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Title starts at same level as username
                Text(pod.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Main content
            HStack(spacing: 16) {
                // Selection checkbox (only in bulk selection mode)
                if isInSelectionMode {
                    Button(action: {
                        onSelectionChanged?(!isSelected)
                    }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? Color("accentColor") : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Thumbnail that matches regular PodRowView approach
                HStack {
                    Spacer()
                    KFImage(URL(string: pod.thumbnailUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 80) // Only maxHeight, no width constraint
                        .clipped()
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Description
                    Text(pod.description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(lineLimit)
                        .truncationMode(.tail)
                    
                    Spacer() // Push bottom content to bottom
                    
                    // Likes and date in bottom row
                    HStack {
                        // Likes with modern styling
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                            
                            Text("\(viewModel.pod.likes) \(viewModel.pod.likes == 1 ? "like" : "likes")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Date moved next to likes
                        Text(getTimeAgo())
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 80) // Match thumbnail height for consistent alignment
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
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
        .padding(.vertical, 6)
        .contextMenu {
            // Only show delete option if current user owns the pod and not in selection mode
            if isCurrentUserPod && !isInSelectionMode {
                Button(role: .destructive) {
                    deletePod()
                } label: {
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Delete Pod", systemImage: "trash")
                    }
                }
                .disabled(isDeleting)
            }
        }
        .alert("Delete Pod", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performDeletePod()
            }
        } message: {
            Text("Are you sure you want to delete this pod? This action cannot be undone.")
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
    
    // MARK: - Helper Properties and Methods
    
    private var isCurrentUserPod: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return pod.userId == currentUserId
    }
    
    private func deletePod() {
        guard let podId = pod.id else {
            print("No pod ID available")
            return
        }
        
        showingDeleteAlert = true
    }
    
    private func performDeletePod() {
        print("🔍 === DELETE POD FROM ROW VIEW ===")
        
        guard let podId = pod.id else {
            print("❌ No pod ID available")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No current user ID")
            return
        }
        
        // Double-check that the current user owns this pod
        guard pod.userId == currentUserId else {
            print("❌ User does not own this pod")
            return
        }
        
        print("✅ Pod ID: \(podId)")
        print("✅ Current user ID: \(currentUserId)")
        
        isDeleting = true
        
        viewModel.deletePod {
            DispatchQueue.main.async {
                self.isDeleting = false
                print("✅ Pod deleted successfully")
                
                // Call the callback to refresh the pod list
                self.onPodDeleted?()
            }
        }
    }
}

struct PodRowViewThin_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack {
                ForEach(0..<5) { _ in
                    PodRowViewThin(pod: PreviewClass().previewPod)
                    Divider()
                }
            }
        }
    }
}
