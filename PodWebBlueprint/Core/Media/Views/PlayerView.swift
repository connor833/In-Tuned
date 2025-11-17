//
//  PlayerView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/24/23.
//

import SwiftUI
import AVKit
import Kingfisher
import Firebase
import UIKit
import FirebaseAuth

struct PlayerView: View {
    @State private var currentPod: Pod
    @State private var currentUrl: URL
    
    @Environment(\.presentationMode) var mode
    @StateObject var viewModel: PodViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject var userPreferencesViewModel = UserPreferencesViewModel()
    @StateObject private var playerViewModel = PlayerViewModel.shared
    
    @StateObject private var manager = PlayerManager.shared
    
    @State private var hasSetupPlayer = false
    
    // UI State
    @State private var showingSendView = false
    @State private var showingComments = false
    @State private var expanded: Bool = false
    @State private var truncated: Bool = false

    
    @State private var showingProfile = false
    @State private var showingReportView = false
    @State private var podChangeCounter = 0
    @State private var scrollToTop = false
    @State private var isPodSwitching = false
    @State private var isUserBlocked: Bool = false // Add blocking state
    @StateObject private var mediaBarManager = MediaBarManager.shared
    @State private var isAnimating = true
    
    
    private let lineLimit = 1
    private let blockService = BlockService() // Add blocking service
    
    init(url: URL, pod: Pod) {
        _currentPod = State(initialValue: pod)
        _currentUrl = State(initialValue: url)
        self._viewModel = StateObject(wrappedValue: PodViewModel(pod: pod))
    }
    
    private var moreLessText: String {
        if !truncated {
            return ""
        } else {
            return self.expanded ? "read less" : " read more"
        }
    }
    
    var body: some View {
        // Check if pod is active
        if !isPodActive {
            // Pod is inactive - show unavailable message
            podUnavailableView
        } else {
            // Pod is active or no isActive field - show normal player
            normalPlayerView
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the pod is active and can be viewed
    private var isPodActive: Bool {
        // If isActive field exists, use its value
        // If isActive field is nil (legacy pods), assume it's active
        guard let isActive = currentPod.isActive else {
            print("🎬 PlayerView: Pod '\(currentPod.title)' has no isActive field - assuming active (legacy pod)")
            return true
        }
        
        print("🎬 PlayerView: Pod '\(currentPod.title)' isActive status: \(isActive)")
        return isActive
    }
    
    // MARK: - Pod Unavailable View
    
    private var podUnavailableView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            // Title
            Text("Pod Not Available")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Message
            Text("This pod is currently unavailable and cannot be viewed.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Back button
            Button {
                mode.wrappedValue.dismiss()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Go Back")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color("accentColor"))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Normal Player View
    
    private var normalPlayerView: some View {
        VStack {
            // Top Bar - Wrapped in a separate view to ensure touch handling
            VStack(spacing: 0) {
                HStack {
                    // Back button with enhanced touch handling
                    ZStack {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                        
                        Button {
                            // Just dismiss, don't stop the player
                            mode.wrappedValue.dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                                .foregroundColor(Color("textColor"))
                                .imageScale(.large)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Fallback tap gesture
                        mode.wrappedValue.dismiss()
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button {
                            showingReportView = true
                        } label: {
                            Text("Report Pod")
                            Image(systemName: "flag")
                        }
                        
                        if authViewModel.currentUser?.uid == currentPod.userId {
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
                            .font(.title3)
                            .padding(12)
                            .contentShape(Rectangle())
                    }
                    .foregroundColor(Color("textColor"))
                    .frame(width: 44, height: 44) // Ensure touch target is large enough
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
                .background(Color(.systemBackground).opacity(0.9)) // Semi-transparent background
                
                // Add a small spacer to ensure separation from media player
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 1)
            }
            .zIndex(1000) // Ensure navigation buttons are above media player
            
                                // Smart Media Player
                    Group {
                        if isPodSwitching {
                            // Loading state while switching pods or setting up player
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(height: 256)
                                .overlay(
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .scaleEffect(1.5)
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                                        Text("Loading media...")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                )
                                .transition(.opacity)
                                .onAppear {
                                    print("🔄 PlayerView: Loading overlay shown - isPodSwitching: \(isPodSwitching)")
                                }
                        } else {
                            SmartMediaPlayer(player: manager.player, pod: currentPod)
                                .frame(height: 256)
                                .allowsHitTesting(true) // Keep media controls interactive
                                .transition(.opacity)
                                .onAppear {
                                    print("🔄 PlayerView: Media player shown - isPodSwitching: \(isPodSwitching)")
                                }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isPodSwitching)
            
            // Content
            ScrollViewReader { proxy in
                ScrollView {
                    // Title and Stats
                    HStack {
                        Text(currentPod.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("textColor"))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .id("top")
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("\(viewModel.pod.likes) \(viewModel.pod.likes == 1 ? "like" : "likes")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(playerViewModel.getTimeAgo(for: currentPod))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Description
                    HStack {
                        Text(currentPod.description)
                            .font(.body)
                            .foregroundColor(Color("textColor"))
                            .lineLimit(expanded ? nil : lineLimit)
                            .background(
                                Text(currentPod.description).lineLimit(lineLimit)
                                    .background(GeometryReader { visibleTextGeometry in
                                        ZStack {
                                            Text(self.currentPod.description)
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
                    
                    if truncated {
                        HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expanded.toggle()
                                }
                            } label: {
                                Text(moreLessText)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("accentColor"))
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // User Info
                    HStack {
                        Button(action: {
                            showingProfile = true
                        }) {
                            if playerViewModel.isUserDataLoading {
                                // Loading state
                                HStack(spacing: 12) {
                                    // Loading profile image
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                                        )
                                    
                                    // Loading text
                                    VStack(alignment: .leading, spacing: 4) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 80, height: 12)
                                            .cornerRadius(6)
                                        
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 60, height: 10)
                                            .cornerRadius(5)
                                    }
                                }
                            } else {
                                // Loaded state
                                HStack(spacing: 12) {
                                    if let profileImageUrl = viewModel.pod.user?.profileImageUrl, !profileImageUrl.isEmpty {
                                        KFImage(URL(string: profileImageUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.gray.opacity(0.6))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(viewModel.pod.user?.fullname ?? "")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(Color("textColor"))
                                            
                                            if viewModel.pod.user?.isVerified == true {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        Text("@\(viewModel.pod.user?.username ?? "")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                    .sheet(isPresented: $showingProfile) {
                        if #available(iOS 16.0, *) {
                            VStack(spacing: 0) {
                                Divider()
                                    .padding(.top, 8)
                                NavigationView {
                                    ProfileView(user: viewModel.pod.user ?? PreviewClass().loadingUser) { selectedPod in
                                        // Dismiss the profile sheet
                                        showingProfile = false
                                        
                                        // Execute the same logic as recommended pods
                                        print("PlayerView: Profile sheet pod selected - \(selectedPod.title)")
                                        print("PlayerView: Current URL before change: \(self.currentUrl.absoluteString)")
                                        print("PlayerView: New pod URL: \(selectedPod.fileUrl)")
                                        print("PlayerView: Current pod ID: \(self.currentPod.id ?? "nil")")
                                        print("PlayerView: New pod ID: \(selectedPod.id ?? "nil")")
                                        
                                        // Update state to trigger VPlayer URL change (same as initial load)
                                        self.currentPod = selectedPod
                                        self.currentUrl = URL(string: selectedPod.fileUrl)!
                                        self.viewModel.pod = selectedPod
                                        
                                        // Set loading state for user data (same as initial load)
                                        self.playerViewModel.isUserDataLoading = true
                                        
                                        print("PlayerView: Current URL after change: \(self.currentUrl.absoluteString)")
                                        print("PlayerView: Current pod after change: \(self.currentPod.title)")
                                        
                                        // Reset UI state
                                        self.expanded = false
                                        self.truncated = false
                                        
                                        
                                        // Reset recommendation state
                                        self.playerViewModel.hasLoadedPods = false
                                        self.playerViewModel.hasLoadedPreferences = false
                                        self.playerViewModel.recommendedPods = []
                                        
                                        // Loading state will be handled by player item status observer
                                        
                                        // Use the same method as initial load - no loading states, everything in parallel
                                        self.playerViewModel.startAllLoadingInParallel(for: selectedPod, currentUrl: URL(string: selectedPod.fileUrl)!, manager: self.manager, viewModel: self.viewModel)
                                    }
                                }
                            }
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                        } else {
                            VStack(spacing: 0) {
                                Divider()
                                    .padding(.top, 8)
                                NavigationView {
                                    ProfileView(user: viewModel.pod.user ?? PreviewClass().loadingUser) { selectedPod in
                                        // Dismiss the profile sheet
                                        showingProfile = false
                                        
                                        // Execute the same logic as recommended pods
                                        print("PlayerView: Profile sheet pod selected - \(selectedPod.title)")
                                        print("PlayerView: Current URL before change: \(self.currentUrl.absoluteString)")
                                        print("PlayerView: New pod URL: \(selectedPod.fileUrl)")
                                        print("PlayerView: Current pod ID: \(self.currentPod.id ?? "nil")")
                                        print("PlayerView: New pod ID: \(selectedPod.id ?? "nil")")
                                        
                                        // Show loading state immediately
                                        
                                        // Update state to trigger VPlayer URL change
                                        self.currentPod = selectedPod
                                        self.currentUrl = URL(string: selectedPod.fileUrl)!
                                        self.viewModel.pod = selectedPod
                                        
                                        // Set loading state for user data (same as initial load)
                                        self.playerViewModel.isUserDataLoading = true
                                        self.scrollToTop = true
                                        
                                        // Set loading state for user data (same as initial load)
                                        self.playerViewModel.isUserDataLoading = true
                                        
                                        // Tell PlayerManager to play the new URL
                                        self.manager.play(url: URL(string: selectedPod.fileUrl)!, pod: selectedPod, isRecommendedPod: true)
                                        
                                        print("PlayerView: Current URL after change: \(self.currentUrl.absoluteString)")
                                        print("PlayerView: Current pod after change: \(self.currentPod.title)")
                                        
                                        // Reset UI state
                                        self.expanded = false
                                        self.truncated = false
                                        
                                        
                                        // Reset recommendation state
                                        self.playerViewModel.hasLoadedPods = false
                                        self.playerViewModel.hasLoadedPreferences = false
                                        self.playerViewModel.recommendedPods = []
                                        
                                        // Loading state will be handled by player item status observer
                                        
                                        // Use the same method as initial load - no loading states, everything in parallel
                                        self.playerViewModel.startAllLoadingInParallel(for: selectedPod, currentUrl: URL(string: selectedPod.fileUrl)!, manager: self.manager, viewModel: self.viewModel)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 24) {
                        Button {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                viewModel.toggleLike()
                            }
                        } label: {
                            Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                                .font(.title3)
                                .foregroundColor(viewModel.isLiked ? .red : Color("textColor"))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(viewModel.isLiked ? Color.red.opacity(0.1) : Color.gray.opacity(0.05))
                                )
                        }
                        .disabled(viewModel.isLikeActionInProgress)
                        
                        Button {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                            
                            showingComments.toggle()
                        } label: {
                            Image(systemName: "text.bubble")
                                .font(.title3)
                                .foregroundColor(Color("textColor"))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.05))
                                )
                        }
                        .sheet(isPresented: $showingComments) {
                            if #available(iOS 16.0, *) {
                                CommentsView(pod: currentPod, comment: PreviewClass().previewComment, onPodSelected: { selectedPod in
                                    // Dismiss the comments sheet
                                    showingComments = false
                                    
                                    // Execute the same logic as recommended pods
                                    print("PlayerView: Comments sheet pod selected - \(selectedPod.title)")
                                    print("PlayerView: Current URL before change: \(self.currentUrl.absoluteString)")
                                    print("PlayerView: New pod URL: \(selectedPod.fileUrl)")
                                    print("PlayerView: Current pod ID: \(self.currentPod.id ?? "nil")")
                                    print("PlayerView: New pod ID: \(selectedPod.id ?? "nil")")
                                    
                                    // Show loading state immediately
                                    
                                    // Update state to trigger VPlayer URL change
                                    self.currentPod = selectedPod
                                    self.currentUrl = URL(string: selectedPod.fileUrl)!
                                    self.viewModel.pod = selectedPod
                                    
                                    // Set loading state for user data (same as initial load)
                                    self.playerViewModel.isUserDataLoading = true
                                    
                                    // Tell PlayerManager to play the new URL
                                    self.manager.play(url: URL(string: selectedPod.fileUrl)!, pod: selectedPod, isRecommendedPod: true)
                                    
                                    print("PlayerView: Current URL after change: \(self.currentUrl.absoluteString)")
                                    print("PlayerView: Current pod after change: \(self.currentPod.title)")
                                    
                                    // Reset UI state
                                    self.expanded = false
                                    self.truncated = false
                                    
                                    // Reset recommendation state
                                    self.playerViewModel.hasLoadedPods = false
                                    self.playerViewModel.hasLoadedPreferences = false
                                    self.playerViewModel.recommendedPods = []
                                    
                                    // Use the same method as initial load - no loading states, everything in parallel
                                    self.playerViewModel.startAllLoadingInParallel(for: selectedPod, currentUrl: URL(string: selectedPod.fileUrl)!, manager: self.manager, viewModel: self.viewModel)
                                    
                                    // Fetch new recommendations
                                    self.playerViewModel.fetchFirstPageOfRecommendedPods(for: selectedPod)
                                })
                                .presentationDetents([.fraction(0.6)])
                                .presentationDragIndicator(.visible)
                            } else {
                                CommentsView(pod: currentPod, comment: PreviewClass().previewComment, onPodSelected: { selectedPod in
                                    // Dismiss the comments sheet
                                    showingComments = false
                                    
                                    // Execute the same logic as recommended pods
                                    print("PlayerView: Comments sheet pod selected - \(selectedPod.title)")
                                    print("PlayerView: Current URL before change: \(self.currentUrl.absoluteString)")
                                    print("PlayerView: New pod URL: \(selectedPod.fileUrl)")
                                    print("PlayerView: Current pod ID: \(self.currentPod.id ?? "nil")")
                                    print("PlayerView: New pod ID: \(selectedPod.id ?? "nil")")
                                    
                                    // Update state to trigger VPlayer URL change (same as initial load)
                                    self.currentPod = selectedPod
                                    self.currentUrl = URL(string: selectedPod.fileUrl)!
                                    self.viewModel.pod = selectedPod
                                    
                                    // Set loading state for user data (same as initial load)
                                    self.playerViewModel.isUserDataLoading = true
                                    self.scrollToTop = true
                                    
                                    print("PlayerView: Current URL after change: \(self.currentUrl.absoluteString)")
                                    print("PlayerView: Current pod after change: \(self.currentPod.title)")
                                    
                                    // Reset UI state
                                    self.expanded = false
                                    self.truncated = false
                                    
                                    // Reset recommendation state
                                    self.playerViewModel.hasLoadedPods = false
                                    self.playerViewModel.hasLoadedPreferences = false
                                    self.playerViewModel.recommendedPods = []
                                    
                                    // Use the same method as initial load - no loading states, everything in parallel
                                    self.playerViewModel.startAllLoadingInParallel(for: selectedPod, currentUrl: URL(string: selectedPod.fileUrl)!, manager: self.manager, viewModel: self.viewModel)
                                })
                            }
                        }
                        
                        Button {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                viewModel.toggleSave()
                            }
                        } label: {
                            Image(systemName: viewModel.isSaved ? "archivebox.fill" : "archivebox")
                                .font(.title3)
                                .foregroundColor(viewModel.isSaved ? Color("accentColor") : Color("textColor"))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(viewModel.isSaved ? Color("accentColor").opacity(0.1) : Color.gray.opacity(0.05))
                                )
                        }
                        .disabled(viewModel.isSaveActionInProgress)
                        
                        Button {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                            
                            showingSendView.toggle()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.title3)
                                .foregroundColor(Color("textColor"))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.05))
                                )
                        }
                        .sheet(isPresented: $showingSendView) {
                            if #available(iOS 16.0, *) {
                                SendPodView(pod: currentPod)
                                    .presentationDetents([.fraction(0.6)])
                                    .presentationDragIndicator(.visible)
                            } else {
                                SendPodView(pod: currentPod)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    
                    // Recommended Section
                    HStack {
                        Text("Recommended")
                            .font(.subheadline)
                            .fontWeight(.thin)
                        
                        Spacer()
                        
                        Button {
                            // Force refresh recommendations
                            playerViewModel.forceRefreshRecommendedPods(for: currentPod)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // Recommended Pods List
                    LazyVStack {
                        ForEach(playerViewModel.recommendedPods) { pod in
                            Button(action: {
                                print("PlayerView: Recommended pod selected - \(pod.title)")
                                print("PlayerView: Current URL before change: \(self.currentUrl.absoluteString)")
                                print("PlayerView: New pod URL: \(pod.fileUrl)")
                                print("PlayerView: Current pod ID: \(self.currentPod.id ?? "nil")")
                                print("PlayerView: New pod ID: \(pod.id ?? "nil")")
                                
                                // Wrap state modifications in DispatchQueue.main.async to avoid warnings
                                DispatchQueue.main.async {
                                    // Update state to trigger VPlayer URL change (same as initial load)
                                    self.currentPod = pod
                                    self.currentUrl = URL(string: pod.fileUrl)!
                                    self.viewModel.pod = pod
                                    self.scrollToTop = true
                                    
                                    // Set loading state for user data (same as initial load)
                                    self.playerViewModel.isUserDataLoading = true
                                    
                                    print("PlayerView: Current URL after change: \(self.currentUrl.absoluteString)")
                                    print("PlayerView: Current pod after change: \(self.currentPod.title)")
                                    
                                    // Reset UI state
                                    self.expanded = false
                                    self.truncated = false
                                    
                                    // Reset recommendation state
                                    self.playerViewModel.hasLoadedPods = false
                                    self.playerViewModel.hasLoadedPreferences = false
                                    self.playerViewModel.recommendedPods = []
                                    
                                    // Use the same method as initial load - no loading states, everything in parallel
                                    self.playerViewModel.startAllLoadingInParallel(for: pod, currentUrl: URL(string: pod.fileUrl)!, manager: self.manager, viewModel: self.viewModel)
                                }
                            }) {
                                PodRowView(pod: pod) { selectedPod in
                                    // Handle pod selection for video replacement
                                    print("PlayerView: Recommended pod selected - \(selectedPod.title)")
                                    print("PlayerView: Current URL before change: \(self.currentUrl.absoluteString)")
                                    print("PlayerView: New pod URL: \(selectedPod.fileUrl)")
                                    
                                    // Wrap state modifications in DispatchQueue.main.async to avoid warnings
                                    DispatchQueue.main.async {
                                        // Show loading state immediately
                                        
                                        // Update state to trigger VPlayer URL change
                                        self.currentPod = selectedPod
                                        self.currentUrl = URL(string: selectedPod.fileUrl)!
                                        self.viewModel.pod = selectedPod
                                        
                                        // Set loading state for user data (same as initial load)
                                        self.playerViewModel.isUserDataLoading = true
                                        self.scrollToTop = true
                                        
                                        // Tell PlayerManager to play the new URL
                                        self.manager.play(url: URL(string: selectedPod.fileUrl)!, pod: selectedPod, isRecommendedPod: true)
                                    }
                                    
                                    print("PlayerView: Current URL after change: \(self.currentUrl.absoluteString)")
                                    print("PlayerView: Current pod after change: \(self.currentPod.title)")
                                    
                                    // Reset UI state
                                    self.expanded = false
                                    self.truncated = false
                                    
                                    // Reset recommendation state
                                    self.playerViewModel.hasLoadedPods = false
                                    self.playerViewModel.hasLoadedPreferences = false
                                    self.playerViewModel.recommendedPods = []
                                    
                                    // Use the same method as initial load - no loading states, everything in parallel
                                    self.playerViewModel.startAllLoadingInParallel(for: selectedPod, currentUrl: URL(string: selectedPod.fileUrl)!, manager: self.manager, viewModel: self.viewModel)
                                }
                                .foregroundColor(Color("textColor"))
                            }

                        }
                        
                        // Loading indicator for initial fetch
                        if playerViewModel.isFetching {
                            ProgressView()
                            Color.clear
                                .frame(height: 40)
                                .onAppear {
                                    self.playerViewModel.fetchFirstPageOfRecommendedPods(for: currentPod)
                                }
                        }
                        

                    }
                }
                .onChange(of: scrollToTop) { shouldScroll in
                    if shouldScroll {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                        scrollToTop = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showingReportView) {
                if let currentUser = authViewModel.currentUser {
                    ReportPodView(pod: currentPod, user: currentUser)
                }
            }
            // Loading is now handled in startAllLoadingInParallel for better performance
                        .onAppear {
                // Hide MediaBar when PlayerView appears with animation
                mediaBarManager.animateOut()
                
                // Always update now playing info when PlayerView appears
                if let user = currentPod.user {
                    manager.setNowPlayingInfoWithPod(currentPod, user: user)
                }
                
                // View appears immediately - no animation
                
                // Set initial state immediately - no waiting for anything
                playerViewModel.isUserDataLoading = currentPod.user == nil
                
                // Make player view open immediately - don't show loading on initial open
                hasSetupPlayer = true
                
                                // Check if we're already playing this exact pod - if so, don't restart
                let isAlreadyPlayingSamePod = manager.currentPod?.id == currentPod.id
                
                if !isAlreadyPlayingSamePod {
                    // Start everything in parallel immediately - only if not already playing this pod
                    playerViewModel.startAllLoadingInParallel(for: currentPod, currentUrl: currentUrl, manager: manager, viewModel: viewModel)
                    hasSetupPlayer = true
                } else if isAlreadyPlayingSamePod {
                    // We're already playing this pod (playing or paused) - just ensure UI is synced
                    hasSetupPlayer = true
                    self.playerViewModel.isUserDataLoading = false
                    self.viewModel.refreshSaveState()
                    
                    // Always ensure recommended pods are loaded when reopening
                    if !self.playerViewModel.hasLoadedPods && !self.playerViewModel.isFetching {
                        print("🎯 PlayerView: Loading recommended pods on reopen (other case)")
                        self.playerViewModel.fetchFirstPageOfRecommendedPods(for: self.currentPod)
                    } else {
                        print("🎯 PlayerView: Skipping recommended pods load - hasLoadedPods: \(self.playerViewModel.hasLoadedPods), isFetching: \(self.playerViewModel.isFetching)")
                    }
                } else {
                    // If we re-appear (e.g., after fullscreen) and user data is missing, fetch it again
                    if currentPod.user == nil {
                        Task {
                            let user = await self.playerViewModel.fetchUserForPod(self.currentPod)
                            await MainActor.run {
                                self.currentPod.user = user
                                self.viewModel.pod.user = user
                                    self.viewModel.refreshSaveState()
                                    self.playerViewModel.isUserDataLoading = false
                                if let user = user {
                                    self.manager.setNowPlayingInfoWithPod(self.currentPod, user: user)
                                }
                            }
                        }
                    } else {
                        // Ensure UI reflects loaded state
                        self.playerViewModel.isUserDataLoading = false
                        self.viewModel.refreshSaveState()
                    }
                    
                    // Always ensure recommended pods are loaded when reopening
                    if !self.playerViewModel.hasLoadedPods && !self.playerViewModel.isFetching {
                        print("🎯 PlayerView: Loading recommended pods on reopen (already playing same pod)")
                        self.playerViewModel.fetchFirstPageOfRecommendedPods(for: self.currentPod)
                    } else {
                        print("🎯 PlayerView: Skipping recommended pods load - hasLoadedPods: \(self.playerViewModel.hasLoadedPods), isFetching: \(self.playerViewModel.isFetching)")
                    }
                }
                // Check if current user has blocked the pod author
                checkBlockingStatus()
            }
            .onReceive(playerViewModel.objectWillChange) { _ in
                // Force UI refresh when PlayerViewModel changes
                print("🔄 PlayerView: PlayerViewModel changed, refreshing UI")
            }
            .onDisappear {
                // Show MediaBar when PlayerView is dismissed with animation
                mediaBarManager.animateIn()
                mediaBarManager.dismissPlayerView()
                
                // Wrap state modifications in DispatchQueue.main.async to avoid warnings
                DispatchQueue.main.async {
                    // Clean up PlayerManager to ensure proper audio session cleanup
                    // Reset loading state but preserve cache for better performance
                    self.playerViewModel.hasLoadedPods = false
                    self.playerViewModel.hasLoadedPreferences = false
                    self.expanded = false
                    self.truncated = false
                    self.showingSendView = false
                    self.showingComments = false
                    self.showingProfile = false
                }
            }
            .navigationBarBackButtonHidden()
        }
        .scaleEffect(isAnimating ? 1.0 : 0.95)
        .opacity(isAnimating ? 1.0 : 0.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: isAnimating)
        .onAppear {
            // Setup the singleton with user preferences
            playerViewModel.setup(userPreferencesViewModel: userPreferencesViewModel)
            
            // Check if current user has blocked the pod author
            checkBlockingStatus()
        }
        .sheet(isPresented: $showingComments) {
            if #available(iOS 16.0, *) {
                CommentsView(pod: currentPod, comment: PreviewClass().previewComment)
                    .presentationDetents([.fraction(0.6)])
                    .presentationDragIndicator(.visible)
            } else {
                CommentsView(pod: currentPod, comment: PreviewClass().previewComment)
            }
        }
        .sheet(isPresented: $showingSendView) {
            if #available(iOS 16.0, *) {
                SendPodView(pod: currentPod)
                    .presentationDetents([.fraction(0.6)])
                    .presentationDragIndicator(.visible)
            } else {
                SendPodView(pod: currentPod)
            }
        }
        .sheet(isPresented: $showingProfile) {
            if #available(iOS 16.0, *) {
                ProfileView(user: currentPod.user ?? PreviewClass().previewUser) { selectedPod in
                    // Handle pod selection/
                    currentPod = selectedPod
                    // Update the pod within the existing viewModel
                    viewModel.pod = selectedPod
                    // Check blocking status for new pod
                    checkBlockingStatus()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            } else {
                ProfileView(user: currentPod.user ?? PreviewClass().previewUser) { selectedPod in
                    // Handle pod selection
                    currentPod = selectedPod
                    // Update the pod within the existing viewModel
                    viewModel.pod = selectedPod
                    // Check blocking status for new pod
                    checkBlockingStatus()
                }
            }
        }
        .fullScreenCover(isPresented: $showingReportView) {
            if let currentUser = authViewModel.currentUser {
                ReportPodView(pod: currentPod, user: currentUser)
            }
        }
    }
    
    // MARK: - Blocking Methods
    
    private func checkBlockingStatus() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Check if current user has blocked the pod author
        blockService.checkIfUserIsBlocked(userId: currentPod.userId) { isBlocked in
            DispatchQueue.main.async {
                self.isUserBlocked = isBlocked
            }
        }
    }
    

}
