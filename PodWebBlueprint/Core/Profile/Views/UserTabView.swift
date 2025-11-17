//
//  ProfileView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher
import FirebaseFunctions

struct UserTabView: View {
    @State private var selectedFilter:UserFilterViewModel = .pods
    @Namespace var animation
    @Environment(\.presentationMode) var mode
    let minDragTranslationForSwipe: CGFloat = 50
    @StateObject private var userViewModel: UserViewModel
    @State private var isEditingProfile = false
    @EnvironmentObject var authViewModel: AuthViewModel

    @State var user: User
    @State private var showingProfileImageModal = false
    
    // Search functionality
    @State private var podSearchText = ""
    @State private var isSearchingPods = false
    
    // Bulk selection functionality
    @State private var isInBulkSelectionMode = false
    @State private var selectedPodIds: Set<String> = []
    @State private var showingBulkDeleteAlert = false
    @State private var isBulkDeleting = false
    @State private var bulkDeleteProgress: (completed: Int, total: Int) = (0, 0)
    
    
    init(user: User) {
        self._user = State(initialValue: user)
        _userViewModel = StateObject(wrappedValue: UserViewModel(user: user, authViewModel: AuthViewModel.shared))
    }
    
    // Computed property for filtered pods
    private var filteredPods: [Pod] {
        if podSearchText.isEmpty {
            return userViewModel.pods
        } else {
            return userViewModel.pods.filter { pod in
                pod.title.localizedCaseInsensitiveContains(podSearchText) ||
                pod.description.localizedCaseInsensitiveContains(podSearchText)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                
                headerView
                
                userInfoDetails
                
                actionButtons
                
                // Divider and spacing between action buttons and tab selector
                VStack(spacing: 16) {
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.horizontal)
                    
                    tweetFilterBar
                }
                .padding(.top, 8)
                
                // Add spacing between selector and content
                Spacer()
                    .frame(height: 20)
                
                podsView
            }
        }
        .refreshable {
            if (selectedFilter == .pods) {
                userViewModel.refreshUserPods()
            } else if (selectedFilter == .reposts) {
                userViewModel.refreshUserReposts()
            }
        }
        .navigationBarBackButtonHidden(true)
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    self.handleSwipe(translation: gesture.translation.width)
                }
        )
        .onAppear {
            // Debug log for verification status
            print("🔍 [UserTabView] Viewing own profile for @\(user.username) - Verified: \(user.isVerified ? "✅ YES (Blue check mark will show)" : "❌ NO (No blue check mark)")")
            
            // Only fetch data if not already loaded to prevent unnecessary network calls
            print("📱 UserTabView onAppear - Pods: \(userViewModel.pods.count), Reposts: \(userViewModel.repostsWithPods.count)")
            
            if userViewModel.pods.isEmpty && !userViewModel.isFetchingPods {
                print("📱 Fetching pods...")
                userViewModel.fetchFirstPageOfUserPods()
            } else {
                print("📱 Skipping pods fetch - already have \(userViewModel.pods.count) pods or currently fetching")
            }
            
            if userViewModel.repostsWithPods.isEmpty && !userViewModel.isFetchingReposts {
                print("📱 Fetching reposts...")
                userViewModel.fetchFirstPageOfUserReposts()
            } else {
                print("📱 Skipping reposts fetch - already have \(userViewModel.repostsWithPods.count) reposts or currently fetching")
            }
            
            // Fetch pod count only if needed
            userViewModel.fetchActualPodCount()
        }
        .sheet(isPresented: $showingProfileImageModal) {
            ProfilePhotoSelectorView(userTabview: self)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UploadCompleted"))) { _ in
            // Refresh user pods when an upload completes
            print("📱 Upload completed - refreshing user pods")
            userViewModel.refreshUserPods()
        }
        .alert("Delete Selected Pods", isPresented: $showingBulkDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(selectedPodIds.count) Pods", role: .destructive) {
                performBulkDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedPodIds.count) selected pods? This action cannot be undone.")
        }
        
    }
        
    
    func unfollowDismiss() {
        mode.wrappedValue.dismiss()
    }
    
    // MARK: - Bulk Delete Functions
    
    private func performBulkDelete() {
        guard !selectedPodIds.isEmpty else { return }
        
        isBulkDeleting = true
        let podIdsToDelete = Array(selectedPodIds)
        let totalPods = podIdsToDelete.count
        
        // Initialize progress
        bulkDeleteProgress = (0, totalPods)
        
        // Call bulk delete function with progress callback
        userViewModel.bulkDeletePods(
            podIds: podIdsToDelete,
            progressCallback: { completed, total in
                DispatchQueue.main.async {
                    bulkDeleteProgress = (completed, total)
                }
            }
        ) { success in
            DispatchQueue.main.async {
                isBulkDeleting = false
                
                if success {
                    // Clear selection and exit bulk mode
                    selectedPodIds.removeAll()
                    isInBulkSelectionMode = false
                    bulkDeleteProgress = (0, 0)
                    
                    // Refresh the pod list
                    userViewModel.refreshUserPods()
                } else {
                    // Handle error - could show an error alert here
                    print("❌ Bulk delete failed")
                    bulkDeleteProgress = (0, 0)
                }
            }
        }
    }
    
}

extension UserTabView {
    
    var topBar: some View {
        HStack {
            
            Text("@\(user.username)")
                .font(.headline)
                .fontWeight(.bold)
            
            if user.isVerified {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(.systemBlue))
             }
            
            Spacer()
            
            NavigationLink {
                SettingsScreen()
            } label: {
                ZStack {
                    // Glass morphism background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Settings icon with enhanced styling
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
    
    var headerView: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    NavigationLink(destination: ProfilePhotoSelectorView(userTabview: self)) {
                        if user.profileImageUrl != "" {
                            KFImage(URL(string: user.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.gray)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                    }
                    
                    // Overlay for modal tap gesture
                    if user.profileImageUrl != "" {
                        KFImage(URL(string: user.profileImageUrl))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .onTapGesture {
                                showingProfileImageModal = true
                            }
                            .allowsHitTesting(true)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.gray)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .onTapGesture {
                                showingProfileImageModal = true
                            }
                            .allowsHitTesting(true)
                    }
                }
            }
            
            Spacer()
            
            followingBar
        }
        .padding(.horizontal)
        .frame(height: 120)
    }
    
    var followingBar: some View {
        HStack(spacing: 24) {
            NavigationLink(destination: FollowersView(user: user, userViewModel: userViewModel)) {
                VStack(spacing: 4) {
                    Text("\(user.followers)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Followers")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(Color("textColor"))
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: FollowingView(user: user, userViewModel: userViewModel)) {
                VStack(spacing: 4) {
                    Text("\(user.following)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Following")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(Color("textColor"))
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 4) {
                Text("\(userViewModel.actualPodCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Text("Pods")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .scaledToFit()
    }
    
    var actionButtons: some View {
        HStack(spacing: 12) {
            // Upload Pod button moved to Uploading view per request
            
            NavigationLink {
                UserEditView(user: user, userTabview: self)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Edit Profile")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color("accentColor"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color("accentColor"), lineWidth: 2)
                        )
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal)
        .foregroundColor(Color("textColor"))
    }
    

    
    var userInfoDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full name with modern styling
            if let fullname = user.fullname, !fullname.isEmpty {
                Text(fullname)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            // Bio with modern styling
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            
            // Display clickable link if it exists
            if let link = user.link, !link.isEmpty {
                Button(action: {
                    openLink(link)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 12, weight: .medium))
                        Text(link)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // Helper function to open links
    private func openLink(_ urlString: String) {
        var urlToOpen = urlString
        
        // Add https:// if no scheme is provided
        if !urlToOpen.hasPrefix("http://") && !urlToOpen.hasPrefix("https://") {
            urlToOpen = "https://" + urlToOpen
        }
        
        if let url = URL(string: urlToOpen) {
            UIApplication.shared.open(url)
        }
    }
    
    var tweetFilterBar: some View {
        HStack(spacing: 0) {
            ForEach(UserFilterViewModel.allCasesForCurrentUser(), id: \.rawValue) { item in
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
                        self.selectedFilter = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 16, weight: selectedFilter == item ? .semibold : .medium))
                        .foregroundColor(selectedFilter == item ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            ZStack {
                // Background container
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                
                // Animated selection indicator
                HStack(spacing: 0) {
                    ForEach(UserFilterViewModel.allCasesForCurrentUser(), id: \.rawValue) { item in
                        if selectedFilter == item {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color("accentColor").opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                                .matchedGeometryEffect(id: "selectedTab", in: animation)
                        } else {
                            Color.clear
                        }
                    }
                }
                .padding(4)
            }
        )
        .padding(.horizontal)
    }
    
    var podsView: some View {
        VStack {
            // Playlist and Saved Pods navigation links for current user (only show when on pods tab)
            if selectedFilter == .pods {
                HStack {
                    NavigationLink {
                        UserPlaylistsView(user: user)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Playlists")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color("accentColor"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color("accentColor"), lineWidth: 2)
                                )
                                .shadow(
                                    color: Color.black.opacity(0.1),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink {
                        UserSavedPodsView(user: user)
                            .environmentObject(UserViewModel.shared)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Saved Pods")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color("accentColor"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color("accentColor"), lineWidth: 2)
                                )
                                .shadow(
                                    color: Color.black.opacity(0.1),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Search bar and bulk controls for pods
            if selectedFilter == .pods && !userViewModel.pods.isEmpty && !userViewModel.shouldShowNoPodsMessage {
                VStack(spacing: 12) {
                    SearchBar(text: $podSearchText)
                        .padding(.horizontal)
                        .onChange(of: podSearchText) { newValue in
                            isSearchingPods = !newValue.isEmpty
                        }
                    
                    // Bulk selection controls
                    if authViewModel.userSession?.uid == user.uid {
                        VStack(spacing: 12) {
                            // Selection mode toggle and bulk actions
                            HStack {
                                if !isInBulkSelectionMode {
                                    Button("Select Pods") {
                                        isInBulkSelectionMode = true
                                        selectedPodIds.removeAll()
                                    }
                                    .foregroundColor(Color("accentColor"))
                                    .font(.system(size: 16, weight: .medium))
                                } else {
                                    Button("Cancel") {
                                        isInBulkSelectionMode = false
                                        selectedPodIds.removeAll()
                                    }
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16, weight: .medium))
                                    
                                    Spacer()
                                    
                                    // Simple red delete button with progress counter
                                    if !selectedPodIds.isEmpty {
                                        Button(action: {
                                            showingBulkDeleteAlert = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 8, height: 8)
                                                if isBulkDeleting {
                                                    HStack(spacing: 4) {
                                                        ProgressView()
                                                            .scaleEffect(0.8)
                                                        Text("\(bulkDeleteProgress.completed)/\(bulkDeleteProgress.total)")
                                                            .font(.system(size: 14, weight: .medium))
                                                    }
                                                } else {
                                                    Text("Delete Pods (\(selectedPodIds.count))")
                                                        .font(.system(size: 16, weight: .medium))
                                                }
                                            }
                                            .foregroundColor(.red)
                                        }
                                        .disabled(isBulkDeleting)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Simple select all/deselect all (only in bulk mode)
                            if isInBulkSelectionMode && !filteredPods.isEmpty {
                                HStack {
                                    Button("Select All") {
                                        selectedPodIds = Set(filteredPods.compactMap { $0.id })
                                    }
                                    .foregroundColor(Color("accentColor"))
                                    .font(.system(size: 14, weight: .medium))
                                    .disabled(selectedPodIds.count == filteredPods.count)
                                    
                                    Spacer()
                                    
                                    Button("Deselect All") {
                                        selectedPodIds.removeAll()
                                    }
                                    .foregroundColor(Color("accentColor"))
                                    .font(.system(size: 14, weight: .medium))
                                    .disabled(selectedPodIds.isEmpty)
                                    
                                    Spacer()
                                    
                                    Text("\(selectedPodIds.count) selected")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            
            LazyVStack(spacing: 0) {
                if (selectedFilter == .pods) {
                    if userViewModel.shouldShowNoPodsMessage {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "waveform")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No pods yet")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Upload your first pod to get started")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            NavigationLink {
                                UploadPodView(user: user)
                            } label: {
                                Text("Upload Pod")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color("accentColor"))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ForEach(Array(filteredPods.enumerated()), id: \.element.id) { index, pod in
                            PodRowViewThin(
                                pod: pod,
                                isInSelectionMode: isInBulkSelectionMode,
                                isSelected: selectedPodIds.contains(pod.id ?? ""),
                                onSelectionChanged: { isSelected in
                                    if let podId = pod.id {
                                        if isSelected {
                                            selectedPodIds.insert(podId)
                                        } else {
                                            selectedPodIds.remove(podId)
                                        }
                                    }
                                },
                                onPodDeleted: {
                                    // Refresh the pod list when a pod is deleted
                                    userViewModel.fetchUserPods()
                                }
                            )
                            .padding(.top, index == 0 ? 8 : 0) // Add top padding to first item
                            .onAppear {
                                // Trigger pagination when reaching the last item
                                if pod == filteredPods.last && userViewModel.hasMorePods && !userViewModel.isFetchingPods {
                                    userViewModel.fetchNextPageOfUserPods()
                                }
                            }
                        }
                        
                        // Loading indicator for pagination
                        if userViewModel.isFetchingPods && userViewModel.hasMorePods {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more pods...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        
                        // End of content indicator
                        if !userViewModel.hasMorePods && !userViewModel.pods.isEmpty {
                            Text("No more pods to load")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        }
                        
                        // Show "No pods found" message when searching
                        if isSearchingPods && filteredPods.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("No pods found")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Try searching for a different title")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        }
                    }
                } else if (selectedFilter == .reposts) {
                    if userViewModel.shouldShowNoRepostsMessage {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "arrow.2.squarepath")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No reposts yet")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Repost pods you love to share with your followers")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ForEach(Array(userViewModel.repostsWithPods.enumerated()), id: \.element.repost.id) { index, repostWithPod in
                            if repostWithPod.pod.isDeleted == true {
                                DeletedRepostRowView(repostWithPod: repostWithPod) {
                                    userViewModel.removeOrphanedRepost(podId: repostWithPod.repost.podId)
                                }
                                .padding(.top, index == 0 ? 8 : 0) // Add top padding to first item
                                .onAppear {
                                    // Trigger pagination when reaching the last item
                                    if repostWithPod.repost.id == userViewModel.repostsWithPods.last?.repost.id && userViewModel.hasMoreReposts && !userViewModel.isFetchingReposts {
                                        userViewModel.fetchNextPageOfUserReposts()
                                    }
                                }
                            } else {
                                RepostRowView(repost: repostWithPod.repost)
                                    .padding(.top, index == 0 ? 8 : 0) // Add top padding to first item
                                    .onAppear {
                                        // Trigger pagination when reaching the last item
                                        if repostWithPod.repost.id == userViewModel.repostsWithPods.last?.repost.id && userViewModel.hasMoreReposts && !userViewModel.isFetchingReposts {
                                            userViewModel.fetchNextPageOfUserReposts()
                                        }
                                    }
                            }
                        }
                        
                        // Loading indicator for repost pagination
                        if userViewModel.isFetchingReposts && userViewModel.hasMoreReposts {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more reposts...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        
                        // End of content indicator for reposts
                        if !userViewModel.hasMoreReposts && !userViewModel.repostsWithPods.isEmpty {
                            Text("No more reposts to load")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
            }
            .id(selectedFilter)
            .animation(nil, value: selectedFilter)
        }
    }
    
    private func handleSwipe(translation: CGFloat) {
        if translation > minDragTranslationForSwipe {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
                selectedFilter = .pods
            }
            
        } else if translation < -minDragTranslationForSwipe {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
                if selectedFilter == .pods {
                    selectedFilter = .reposts
                }
            }
        }
    }
    
    // MARK: - Migration Functions (COMPLETED - Keep for future migrations)
    
    /// Migration completed successfully for all users on [DATE]
    /// This function migrated all users from old preferences structure to new UserPreferences structure
    /// 
    /// To use in future:
    /// 1. Update the UserPreferences model if needed
    /// 2. Call this function to migrate all users
    /// 3. Remove button again after completion
    private func migrateUserPreferences() {
        print("🚀 Starting migration for ALL users...")
        
        Task {
            do {
                let userPreferencesService = UserPreferencesService()
                try await userPreferencesService.migrateAllUsers()
                print("✅ All users migrated successfully!")
            } catch {
                print("❌ Migration failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Pod Migration Function (Temporary - Delete after use)
    
    private func migrateAllPods() {
        print("🚀 Starting migration for ALL pods...")
        
        Task {
            do {
                let userPreferencesService = UserPreferencesService()
                try await userPreferencesService.migrateAllPods()
                print("✅ All pods migrated successfully!")
            } catch {
                print("❌ Pod migration failed: \(error.localizedDescription)")
            }
        }
    }
    
}

struct Previews_UserTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light Mode Preview
            UserTabView(user: PreviewClass().previewUser)
                .previewDisplayName("Light Mode")
                .environment(\.colorScheme, .light)

            // Dark Mode Preview
            UserTabView(user: PreviewClass().previewUser)
                .previewDisplayName("Dark Mode")
                .environment(\.colorScheme, .dark)
        }
    }
}




