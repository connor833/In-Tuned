//
//  ProfileView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher
import FirebaseAuth

struct ProfileView: View {
    @State private var selectedFilter:UserFilterViewModel = .pods
    @Namespace var animation
    @Environment(\.presentationMode) var mode
    let minDragTranslationForSwipe: CGFloat = 50
    @StateObject private var userViewModel: UserViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    

    var user: User
    
    @State private var showingReportView = false
    @State private var showingProfileImageModal = false
    @State private var showingBlockView = false
    
    // Search functionality
    @State private var podSearchText = ""
    @State private var isSearchingPods = false
    
    
    // New parameter for sheet mode
    var onPodSelected: ((Pod) -> Void)?
    
    init(user: User, onPodSelected: ((Pod) -> Void)? = nil) {
        self.user = user
        self.onPodSelected = onPodSelected
        self._userViewModel = StateObject(wrappedValue: UserViewModel(user: user, authViewModel: AuthViewModel.shared))
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
                if (self.user.uid != Auth.auth().currentUser?.uid) {
                    // Check blocking status first - show loading until blocking check is complete
                    if !userViewModel.isBlockingCheckComplete {
                        loadingView
                    } else if userViewModel.isCurrentUserBlockedByThisUser {
                        // Current user is blocked by this user - show fake profile for security
                        fakeProfileView
                    } else if userViewModel.isUserBlocked {
                        // Current user has blocked this user - show blocked message
                        blockedUserView
                    } else {
                        // Normal profile view - only show after blocking check is complete
                        topBar
                       
                       headerView
                       
                       userInfoDetails
                       
                       actionButtons
                       
                       // Divider and spacing between action buttons and tab selector
                       VStack(spacing: 16) {
                           Divider()
                               .background(Color(.systemGray4))
                               .padding(.horizontal)
                           
                           if userViewModel.isLoadingFriendshipStatus || userViewModel.isLoadingFollowRequestStatus {
                               loadingView
                           } else if user.isPrivate == true && !userViewModel.isFollowing {
                               privateAccountMessage
                           } else {
                               tweetFilterBar
                               podsView
                           }
                       }
                       .padding(.top, 8)
                    }
                } else {
                    // User is viewing their own profile - deep link to main tab profile
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Redirecting to your profile...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                            .scaleEffect(1.2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .onAppear {
                        // Trigger deep link to main tab profile
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("DeepLinkToProfile"),
                                object: nil
                            )
                            
                            // Dismiss this view after triggering deep link
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            if (selectedFilter == .pods) {
                userViewModel.refreshUserPods()
            } else if (selectedFilter == .reposts) {
                userViewModel.refreshUserReposts()
            }
        }
        .padding(.top, onPodSelected != nil ? 20 : 0) // Add top padding when in sheet mode
        .alert("Rate Limited", isPresented: $userViewModel.showRateLimitPopup) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(userViewModel.rateLimitMessage)
        }
        .onAppear {
            if self.user.uid == Auth.auth().currentUser?.uid {
                // Dismiss the view if the user is the current user
                dismiss()
            }
            
            // Debug log for verification status
            print("🔍 [ProfileView] Viewing profile for @\(user.username) - Verified: \(user.isVerified ? "✅ YES (Blue check mark will show)" : "❌ NO (No blue check mark)")")
            
            // Check blocking status first for security
            userViewModel.checkBlockStatus(user: user)
            
            // Also check follow status immediately for better UX
            userViewModel.checkIfUserIsFollowed(user: user)
            userViewModel.checkIfFollowRequestSent(user: user)
            
            // Fetch first page of user data for pagination
            userViewModel.fetchFirstPageOfUserPods()
            userViewModel.fetchFirstPageOfUserReposts()
        }
        .navigationBarBackButtonHidden(true)
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    self.handleSwipe(translation: gesture.translation.width)
                }
        )
        .sheet(isPresented: $showingProfileImageModal) {
            ProfileImageModalView(profileImageUrl: user.profileImageUrl, username: user.username)
        }
        .sheet(isPresented: $showingBlockView) {
            BlockView(user: user)
        }
    }
    
    // MARK: - Blocked User Views
    
    private var blockedUserView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar with back button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("@\(user.username)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(.systemBlue))
                }
                
                Spacer()
                
                // Empty space to balance the back button
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .padding()
            
            // Profile header with photo, name, and bio
            VStack(spacing: 16) {
                // Profile image
                if !user.profileImageUrl.isEmpty {
                    KFImage(URL(string: user.profileImageUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        )
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                
                // Username and verification
                HStack(spacing: 8) {
                    Text(user.username)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemBlue))
                    }
                }
                
                // Full name
                if let fullname = user.fullname, !fullname.isEmpty {
                    Text(fullname)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Bio
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Blocked message
                VStack(spacing: 8) {
                    Image(systemName: "slash.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("User Blocked")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text("You have blocked this user. Their content is not visible to you.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 16)
                
                // Unblock button
                Button(action: {
                    userViewModel.unblockUser { success in
                        if success {
                            // Dismiss the view after successful unblock
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                        Text("Unblock \(user.username)")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding()
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    private var fakeProfileView: some View {
        VStack(spacing: 0) {
            // Fake top bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Profile")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Empty space to balance the back button
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .padding()
            
            // Centered content area
            VStack(spacing: 24) {
                Spacer()
                
                // Placeholder profile image
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
                
                // Fake username
                Text("user_\(String(user.uid.prefix(8)))")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Fake bio
                Text("This profile is not available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Fake stats
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Pods")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Followers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Following")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 16)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }
        
    
    func unfollowDismiss() {
        mode.wrappedValue.dismiss()
    }
    

    
    
}

extension ProfileView {
    
    var topBar: some View {
        HStack {
            Button {
                mode.wrappedValue.dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(Color("accentColor"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
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
            
            HStack(spacing: 4) {
                Text("@\(user.username)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(.systemBlue))
                        .font(.system(size: 16))
                }
            }
            
            Spacer()
            
            Menu {
                Button {
                    showingBlockView = true
                } label: {
                    Text(userViewModel.isUserBlocked ? "Unblock User" : "Block User")
                    Image(systemName: userViewModel.isUserBlocked ? "person.badge.plus" : "person.badge.minus")
                }
                
                Button {
                    showingReportView = true
                } label: {
                    Text(NSLocalizedString("Report User", comment: ""))
                    Image(systemName: "flag")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .foregroundColor(Color("textColor"))
            .frame(width: 44, height: 44)
            .sheet(isPresented: $showingReportView) {
                ReportUserView(user: user)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
    
    var headerView: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                if user.profileImageUrl != ""{
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
            VStack(spacing: 4) {
                Text("\(userViewModel.user?.followers ?? 0)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Text("Followers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(userViewModel.user?.following ?? 0)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Text("Following")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
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
        HStack {
            Button {
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                
                withAnimation {
                    userViewModel.toggleFollow()
                }
            } label: {
                HStack(spacing: 6) {
                    if userViewModel.isFollowActionInProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: buttonTextColor))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(buttonText)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundColor(buttonTextColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(buttonBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(buttonBorderColor, lineWidth: 2)
                        )
                        .shadow(
                            color: buttonShadowColor,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
                .scaleEffect(userViewModel.isFollowActionInProgress ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: userViewModel.isFollowActionInProgress)
            }
            .disabled(userViewModel.isFollowActionInProgress)
            
            Spacer()
        }
        .padding(.horizontal)
        .foregroundColor(Color("textColor"))
    }
    
    private var buttonText: String {
        if user.isPrivate == true {
            if userViewModel.followRequestSent {
                return "Requested"
            } else if userViewModel.isFollowing {
                return "Unfollow"
            } else {
                return "Follow"
            }
        } else {
            return userViewModel.isFollowing ? "Unfollow" : "Follow"
        }
    }
    
    private var buttonIcon: String {
        if user.isPrivate == true {
            if userViewModel.followRequestSent {
                return "clock.fill"
            } else if userViewModel.isFollowing {
                return "person.badge.minus"
            } else {
                return "person.badge.plus"
            }
        } else {
            return userViewModel.isFollowing ? "person.badge.minus" : "person.badge.plus"
        }
    }
    
    private var buttonTextColor: Color {
        if user.isPrivate == true {
            if userViewModel.followRequestSent {
                return .white
            } else if userViewModel.isFollowing {
                return Color("accentColor")
            } else {
                return .white
            }
        } else {
            return userViewModel.isFollowing ? Color("accentColor") : .white
        }
    }
    
    private var buttonBackgroundColor: Color {
        if user.isPrivate == true {
            if userViewModel.followRequestSent {
                return Color("accentColor")
            } else if userViewModel.isFollowing {
                return Color(.systemBackground)
            } else {
                return Color("accentColor")
            }
        } else {
            return userViewModel.isFollowing ? Color(.systemBackground) : Color("accentColor")
        }
    }
    
    private var buttonBorderColor: Color {
        if user.isPrivate == true {
            if userViewModel.followRequestSent {
                return Color("accentColor")
            } else if userViewModel.isFollowing {
                return Color("accentColor")
            } else {
                return Color("accentColor")
            }
        } else {
            return Color("accentColor")
        }
    }
    
    private var buttonShadowColor: Color {
        if user.isPrivate == true {
            if userViewModel.followRequestSent {
                return Color("accentColor").opacity(0.3)
            } else if userViewModel.isFollowing {
                return Color.black.opacity(0.1)
            } else {
                return Color("accentColor").opacity(0.3)
            }
        } else {
            return userViewModel.isFollowing ? Color.black.opacity(0.1) : Color("accentColor").opacity(0.3)
        }
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
            ForEach(UserFilterViewModel.allCasesForOtherUsers(), id: \.rawValue) { item in
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
                    ForEach(UserFilterViewModel.allCasesForOtherUsers(), id: \.rawValue) { item in
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
            // Playlist navigation link for other users (only show when on pods tab)
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
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Search bar for pods
            if selectedFilter == .pods && !userViewModel.pods.isEmpty && !userViewModel.shouldShowNoPodsMessage {
                SearchBar(text: $podSearchText)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .onChange(of: podSearchText) { newValue in
                        isSearchingPods = !newValue.isEmpty
                    }
            }
            
            LazyVStack {
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
                            
                            Text("This user hasn't uploaded any pods yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ForEach(filteredPods) { pod in
                            if let onPodSelected = onPodSelected {
                                // Custom pod row for sheet mode - disables navigation
                                PodRowViewSheet(pod: pod, onPodSelected: onPodSelected)
                                    .onAppear {
                                        // Trigger pagination when reaching the last item
                                        if pod == filteredPods.last && userViewModel.hasMorePods && !userViewModel.isFetchingPods {
                                            userViewModel.fetchNextPageOfUserPods()
                                        }
                                    }
                            } else {
                                PodRowViewThin(pod: pod)
                                    .onAppear {
                                        // Trigger pagination when reaching the last item
                                        if pod == filteredPods.last && userViewModel.hasMorePods && !userViewModel.isFetchingPods {
                                            userViewModel.fetchNextPageOfUserPods()
                                        }
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
                            
                            Text("This user hasn't reposted any pods yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        let _ = print("🎯 [ProfileView] Rendering \(userViewModel.repostsWithPods.count) reposts")
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
                selectedFilter = .reposts
            }
        }
    }
    
    
    
    var privateAccountMessage: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("This Account is Private")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You must follow this user to see their content")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    var blockedUserMessage: some View {
        VStack(spacing: 20) {
            Image(systemName: "slash.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("User Blocked You")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This user has blocked you. You cannot see their content or interact with them.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    
    
    // MARK: - PodRowViewSheet for Sheet Mode
    struct PodRowViewSheet: View {
        let pod: Pod
        let onPodSelected: (Pod) -> Void
        @StateObject private var viewModel: PodViewModel
        
        init(pod: Pod, onPodSelected: @escaping (Pod) -> Void) {
            self.pod = pod
            self.onPodSelected = onPodSelected
            self._viewModel = StateObject(wrappedValue: PodViewModel(pod: pod))
        }
        
        var body: some View {
            Button(action: {
                onPodSelected(pod)
            }) {
                PodRowViewContent(pod: pod, viewModel: viewModel)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - PodRowViewContent (extracted from PodRowView)
    struct PodRowViewContent: View {
        let pod: Pod
        @ObservedObject var viewModel: PodViewModel
        @Environment(\.presentationMode) var mode
        @State private var expanded: Bool = false
        @State private var truncated: Bool = false
        
        private let lineLimit = 1
        
        var body: some View {
            VStack {
                VStack {
                    HStack {
                        // Thumbnail without NavigationLink
                        KFImage(URL(string: pod.thumbnailUrl))
                            .resizable()
                            .aspectRatio(contentMode: .fit) // Changed from scaledToFill to fit to preserve aspect ratio
                            .frame(maxHeight: 200) // Use maxHeight to allow adaptive width
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    HStack {
                        VStack {
                            HStack {
                                // Profile image without NavigationLink
                                if let profileImageUrl = viewModel.pod.user?.profileImageUrl, !profileImageUrl.isEmpty {
                                    KFImage(URL(string: profileImageUrl))
                                        .resizable()
                                        .clipShape(Circle())
                                        .frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .clipShape(Circle())
                                        .frame(width: 28, height: 28)
                                }
                                
                                Text(pod.title)
                                    .font(.title2)
                                
                                Spacer()
                            }
                            
                            // User info without NavigationLink
                            HStack {
                                Text(viewModel.pod.user?.fullname ?? "")
                                    .font(.system(size: 12))
                                
                                Text("@\(viewModel.pod.user?.username ?? "")")
                                    .foregroundColor(Color(.systemBlue))
                                    .font(.system(size: 12))
                                
                                if viewModel.pod.user?.isVerified ?? false {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(Color(.systemBlue))
                                }
                                
                                Spacer()
                            }
                        }
                        
                        Menu {
                            Button {
                                print("report")
                            } label: {
                                Text("Report Pod")
                                Image(systemName: "flag")
                            }
                            
                            if (Auth.auth().currentUser?.uid == pod.userId) {
                                Button {
                                    viewModel.deletePod {
                                        // Dismiss the view after pod deletion
                                        mode.wrappedValue.dismiss()
                                    }
                                } label: {
                                    Text("Delete Pod")
                                    Image(systemName: "trash.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .foregroundColor(Color("textColor"))
                    }
                    .padding(.horizontal)
                }
                
                VStack {
                    HStack {
                        Text("\(viewModel.pod.likes) likes")
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text(pod.description)
                            .lineLimit(expanded ? nil : lineLimit)
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
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .font(.system(size: 14))
                    
                    HStack {
                        if truncated {
                            Button(action: {
                                withAnimation {
                                    expanded.toggle()
                                }
                            }, label: {
                                Text(expanded ? "read less" : "read more")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            })
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text(getTimeAgo())
                            .font(.subheadline)
                            .fontWeight(.thin)
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .foregroundColor(Color("accentColor"))
                        .padding(.horizontal)
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
    
    struct Previews_ProfileView_Previews: PreviewProvider {
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
}




