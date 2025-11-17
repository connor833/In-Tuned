//
//  RSSUploadView.swift
//  Attuned
//
//  Created by Connor Adams on 9/27/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Foundation
import AVFoundation
import CommonCrypto

struct RSSUploadView: View {
    let user: User
    
    @State private var rssURL = ""
    @State private var isLoading = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showPartialSuccessAlert = false
    @State private var failedEpisodeDetails: [(title: String, error: String)] = []
    @State private var uploadedEpisodeCount = 0
    
    // Episode preview and selection
    @State private var rssData: RSSFeedData?
    @State private var selectedEpisodes: Set<String> = []
    @State private var showEpisodePreview = false
    @State private var editedEpisodes: [String: EditedEpisode] = [:]
    @State private var showingEditSheet = false
    @State private var editingEpisodeIndex: Int?
    @State private var matchingSubscription: RSSSubscription? // For checking upload status in RSS browser
    @State private var matchingSubscriptionImportedGuids: Set<String> = [] // Cached GUIDs for sync checking
    
    // Custom image replacement
    @State private var showImagePicker = false
    @State private var customThumbnailImage: UIImage?
    @State private var customThumbnailUrl: String?
    @State private var isUploadingCustomImage = false
    
    // RSS Subscription Management
    @State private var userSubscriptions: [RSSSubscription] = []
    @State private var isLoadingSubscriptions = false
    @State private var showSubscriptionChoice = false
    @State private var subscriptionChoiceData: RSSFeedData?
    @State private var isCheckingForNew = false
    @State private var newEpisodesFound: [RSSEpisode] = []
    @State private var newEpisodesWithSource: [(episode: RSSEpisode, subscription: RSSSubscription)] = []
    @State private var showNewEpisodePreview = false
    @State private var selectedRSSFilter: String? = nil // nil = all, subscription.id = specific feed
    @State private var subscriptionToRemove: RSSSubscription?
    @State private var showRemoveConfirmation = false
    
    // Individual subscription browsing
    @State private var showingIndividualFeed = false
    @State private var selectedSubscription: RSSSubscription?
    @State private var individualFeedData: RSSFeedData?
    @State private var individualFeedSelectedEpisodes: Set<String> = []
    @State private var isUploadingFromIndividualFeed = false
    @State private var selectedSubscriptionImportedGuids: Set<String> = [] // Cached GUIDs for individual feed
    
    // RSS Verification
    @State private var showVerification = false
    @State private var pendingVerificationData: RSSFeedData?
    @State private var isCheckingVerification = false
    
    // View control
    @State private var showImportForm = false
    
    @Environment(\.presentationMode) var presentationMode
    
    // Services
    private let rssSubscriptionService = RSSSubscriptionService()
    private let rssStreamService = RSSStreamService()
    
    // AI Processing - same as regular uploads
    private let aiProcessor = AIProcessor()
    private let openAIProcessor = OpenAIProcessor(apiKey: AIConfig.openAIAPIKey)
    
    var body: some View {
        baseNavigationView
            .alert("Upload Successful", isPresented: $showSuccessAlert) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Successfully uploaded \(uploadedEpisodeCount) episodes from the RSS feed!")
            }
            .alert("Import Failed", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Partial Upload Success", isPresented: $showPartialSuccessAlert) {
                Button("OK") {
                    failedEpisodeDetails.removeAll()
                }
                Button("Retry Failed") {
                    retryFailedEpisodes()
                }
            } message: {
                let successCount = uploadedEpisodeCount
                let failedCount = failedEpisodeDetails.count
                let failedTitles = failedEpisodeDetails.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
                let moreText = failedCount > 3 ? "\n...and \(failedCount - 3) more" : ""
                
                Text("✅ Successfully uploaded \(successCount) episodes\n\n❌ Failed to upload \(failedCount) episodes:\n\n\(failedTitles)\(moreText)")
            }
            .alert("Remove RSS Subscription", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) { 
                    subscriptionToRemove = nil
                }
                Button("Remove", role: .destructive) {
                    if let subscription = subscriptionToRemove {
                        Task {
                            await removeSubscription(subscription)
                        }
                    }
                }
            } message: {
                if let subscription = subscriptionToRemove {
                    Text("Remove '\(subscription.feedTitle)' from your subscriptions? This won't delete uploaded episodes.")
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                editSheetContent
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $customThumbnailImage)
            }
            .fullScreenCover(isPresented: $showingIndividualFeed) {
                individualFeedBrowsingView
            }
            .fullScreenCover(isPresented: $showNewEpisodePreview) {
                newEpisodePreviewFullScreen
            }
            .fullScreenCover(isPresented: $showEpisodePreview) {
                episodePreviewFullScreen
            }
            .sheet(isPresented: $showVerification) {
                if let feedData = pendingVerificationData {
                    RSSVerificationView(
                        feedData: feedData,
                        feedUrl: rssURL,
                        onVerificationSuccess: {
                            // After successful verification, proceed with showing episodes
                            Task {
                                await proceedAfterVerification()
                            }
                        }
                    )
                }
            }
            .onChange(of: showingEditSheet) { isShowing in
                if isShowing {
                    print("🎬 SHEET_OPEN: showingEditSheet=\(isShowing)")
                    print("🎬 SHEET_OPEN: editingEpisodeIndex=\(editingEpisodeIndex?.description ?? "nil")")
                    print("🎬 SHEET_OPEN: rssData episodes count=\(rssData?.episodes.count ?? 0)")
                } else {
                    // Reset editing index when sheet is dismissed
                    editingEpisodeIndex = nil
                }
            }
            .onChange(of: customThumbnailImage) { image in
                if let image = image {
                    Task {
                        await uploadCustomImage(image)
                    }
                }
            }
    }
    
    private var baseNavigationView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    mainContentView
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("RSS Import")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            loadUserSubscriptions()
        }
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        if showSubscriptionChoice {
            subscriptionChoiceSection
        } else {
            initialRSSInputView
        }
    }
    
    @ViewBuilder
    private var initialRSSInputView: some View {
        if userSubscriptions.isEmpty && !isLoadingSubscriptions {
            // Show full RSS import view for new users
            fullRSSImportView
        } else if showImportForm {
            // Show import form when user clicks "Import New RSS Feed"
            fullRSSImportView
        } else {
            // Show subscription management for existing users
            subscriptionManagementSection
        }
    }
    
    @ViewBuilder
    private var fullRSSImportView: some View {
        VStack(spacing: 24) {
                    // Back button if user has subscriptions
                    if !userSubscriptions.isEmpty {
                        HStack {
                            Button(action: {
                                showImportForm = false
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                    Text("Back to Subscriptions")
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("accentColor"))
                            }
                            Spacer()
                        }
                        .padding(.bottom, 8)
                    }
            
                    headerSection
            
                    urlInputSection
            
                        loadButton
                        
                        if isLoading {
                            loadingSection
                        }
                        
                    infoSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Subscription Management Section
    
    private var subscriptionManagementSection: some View {
        Group {
            if isLoadingSubscriptions {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                    Text("Loading your RSS subscriptions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
            } else if !userSubscriptions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your RSS Subscriptions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("(\(userSubscriptions.count)/3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(userSubscriptions) { subscription in
                            subscriptionRowView(subscription)
                        }
                        
                        Button(action: checkAllFeedsForNewEpisodes) {
                            HStack {
                                Image(systemName: isCheckingForNew ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .rotationEffect(isCheckingForNew ? .degrees(360) : .degrees(0))
                                    .animation(isCheckingForNew ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isCheckingForNew)
                                
                                Text(isCheckingForNew ? "Checking for New Episodes..." : "Check All Feeds for New Episodes")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("accentColor"))
                                    .shadow(color: Color("accentColor").opacity(0.25), radius: 8, x: 0, y: 4)
                            )
                        }
                        .disabled(isCheckingForNew || isLoading)
                        .opacity(isCheckingForNew || isLoading ? 0.6 : 1.0)
                        
                        // Import New RSS Feed button
                        if userSubscriptions.count < 3 {
                            Button(action: {
                                // Clear any existing data and show import form
                                rssURL = ""
                                selectedEpisodes.removeAll()
                                rssData = nil
                                customThumbnailImage = nil
                                customThumbnailUrl = nil
                                showImportForm = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Text("Import New RSS Feed")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color("accentColor"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color("accentColor").opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color("accentColor"), lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(isLoading)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color("accentColor").opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func subscriptionRowView(_ subscription: RSSSubscription) -> some View {
        Button(action: {
            selectedSubscription = subscription
            loadIndividualFeed(subscription)
        }) {
            HStack(spacing: 16) {
                // RSS Feed Image
                AsyncImage(url: URL(string: subscription.feedImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray4))
                        .overlay(
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Feed Title
                    Text(subscription.feedTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Feed Description
                    if let description = subscription.feedDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Status and Browse hint
                    HStack(spacing: 8) {
                        // Last checked status
                        HStack(spacing: 4) {
                            Image(systemName: lastCheckedIcon(for: subscription))
                                .font(.system(size: 10))
                                .foregroundColor(lastCheckedColor(for: subscription))
                            
                            if let lastChecked = subscription.lastChecked {
                                Text(formatRelativeDate(lastChecked.dateValue()))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(lastCheckedColor(for: subscription))
                    } else {
                                Text("Never checked")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        // Browse hint
                        HStack(spacing: 4) {
                            Text("Browse")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("accentColor"))
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color("accentColor"))
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(subscriptionRowBackground)
            .overlay(subscriptionRowBorder)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            // Remove button in top-right corner
            Button(action: {
                subscriptionToRemove = subscription
                showRemoveConfirmation = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 20, height: 20)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: 8, y: -8),
            alignment: .topTrailing
        )
    }
    
    @ViewBuilder
    private var subscriptionRowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    @ViewBuilder
    private var subscriptionRowBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color("accentColor").opacity(0.2),
                        Color("accentColor").opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    // Helper functions for status indicators
    private func lastCheckedIcon(for subscription: RSSSubscription) -> String {
        guard let lastChecked = subscription.lastChecked else { return "exclamationmark.triangle" }
        
        let daysSinceCheck = Calendar.current.dateComponents([.day], from: lastChecked.dateValue(), to: Date()).day ?? 0
        
        if daysSinceCheck == 0 {
            return "checkmark.circle.fill"
        } else if daysSinceCheck <= 1 {
            return "clock.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func lastCheckedColor(for subscription: RSSSubscription) -> Color {
        guard let lastChecked = subscription.lastChecked else { return .orange }
        
        let daysSinceCheck = Calendar.current.dateComponents([.day], from: lastChecked.dateValue(), to: Date()).day ?? 0
        
        if daysSinceCheck == 0 {
            return .green
        } else if daysSinceCheck <= 1 {
            return .blue
        } else {
            return .orange
        }
    }
    
    // Helper functions for episode selection
    private func getSelectionIcon(for index: Int, isNew: Bool) -> String {
        let indexString = String(index)
        
        if !isNew {
            return "checkmark.circle.fill" // Already uploaded - show as "done"
        } else if individualFeedSelectedEpisodes.contains(indexString) {
            return "checkmark.circle.fill" // Selected for upload
        } else {
            return "circle" // Available for selection
        }
    }
    
    private func getSelectionColor(for index: Int, isNew: Bool) -> Color {
        let indexString = String(index)
        
        if !isNew {
            return .gray // Already uploaded - grayed out
        } else if individualFeedSelectedEpisodes.contains(indexString) {
            return Color("accentColor") // Selected for upload
        } else {
            return .gray // Available for selection
        }
    }
    
    private func getRowBackgroundColor(for index: Int, isNew: Bool) -> Color {
        let indexString = String(index)
        
        if !isNew {
            return Color(.systemGray6) // Muted background for uploaded episodes
        } else if individualFeedSelectedEpisodes.contains(indexString) {
            return Color("accentColor").opacity(0.1) // Highlighted for selected episodes
        } else {
            return Color(.systemBackground) // Normal background for available episodes
        }
    }
    
    // MARK: - Subscription Choice Section
    
    private var subscriptionChoiceSection: some View {
        VStack(spacing: 20) {
            // Back button
            HStack {
                Button("← Back") {
                    showSubscriptionChoice = false
                    subscriptionChoiceData = nil
                    rssURL = ""
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("accentColor"))
                
                Spacer()
            }
            
            if let rssData = subscriptionChoiceData {
                VStack(spacing: 16) {
                    // RSS Feed Info
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("RSS Feed Found!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 6) {
                            Text(rssData.channelTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("\(rssData.episodes.count) episodes found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Subscribe button
                    VStack(spacing: 16) {
                        Button(action: {
                            subscribeAndViewEpisodes()
                        }) {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Subscribe & Browse Episodes")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                
                                Text("Save this RSS feed and browse episodes to upload")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color("accentColor"))
                                    .shadow(color: Color("accentColor").opacity(0.25), radius: 10, x: 0, y: 6)
                            )
                        }
                        .disabled(userSubscriptions.count >= 3)
                        
                        if userSubscriptions.count >= 3 {
                            Text("⚠️ Maximum 3 RSS subscriptions reached. Remove a subscription to add a new one.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color("accentColor").opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - New Episode Preview Section
    
    @ViewBuilder
    private var newEpisodePreviewFullScreen: some View {
        NavigationView {
            if isCheckingForNew {
                // Enhanced loading state for checking feeds
                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                    
                    VStack(spacing: 8) {
                        Text("Checking RSS Feeds...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Scanning \(userSubscriptions.count) subscription\(userSubscriptions.count == 1 ? "" : "s") for new episodes")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("This may take a moment...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationTitle("New Episodes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            showNewEpisodePreview = false
                            newEpisodesFound.removeAll()
                            selectedEpisodes.removeAll()
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                    // Episode count, filtering, selection, and upload
                    VStack(spacing: 16) {
                        HStack {
                            Text("Found \(filteredNewEpisodes.count) New Episodes")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        // RSS Feed Filter
                        if userSubscriptions.count > 1 && !newEpisodesWithSource.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // All Feeds filter
                                    Button(action: {
                                        selectedRSSFilter = nil
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "list.bullet")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("All Feeds")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedRSSFilter == nil ? Color("accentColor") : Color(.systemGray5))
                                        )
                                        .foregroundColor(selectedRSSFilter == nil ? .white : .primary)
                                    }
                                    
                                    // Individual feed filters
                                    ForEach(uniqueSubscriptionsWithNewEpisodes, id: \.id) { subscription in
                                        Button(action: {
                                            selectedRSSFilter = subscription.id
                                        }) {
                                            HStack(spacing: 6) {
                                                Text(subscription.feedTitle)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .lineLimit(1)
                                                
                                                Text("(\(episodeCountForSubscription(subscription)))")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(selectedRSSFilter == subscription.id ? Color("accentColor") : Color(.systemGray5))
                                            )
                                            .foregroundColor(selectedRSSFilter == subscription.id ? .white : .primary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        HStack {
                            Button(action: {
                                selectedEpisodes = Set(filteredNewEpisodes.indices.map { String($0) })
                            }) {
                                Text("Select All")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                            }
                            
                            Spacer()
                            
                            if !selectedEpisodes.isEmpty {
                                Button(action: {
                                    selectedEpisodes.removeAll()
                                }) {
                                    Text("Deselect All")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(selectedEpisodes.count) selected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Upload button at the top
                        if !selectedEpisodes.isEmpty {
                            Button(action: {
                                uploadSelectedNewEpisodes()
                            }) {
                                HStack {
                                    if isUploading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                        Text("Uploading...")
            } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Upload \(selectedEpisodes.count) Episodes")
                                    }
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("accentColor"))
                                        .shadow(color: Color("accentColor").opacity(0.25), radius: 8, x: 0, y: 4)
                                )
                            }
                            .disabled(isUploading || isLoading)
                        }
                        
                        // Progress bar when uploading
                        if isUploading {
                            VStack(spacing: 12) {
                                Text("Uploading Episodes...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                ProgressView(value: uploadProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: Color("accentColor")))
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                                
                                Text("\(Int(uploadProgress * 100))% Complete")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Episodes list
                    VStack(spacing: 12) {
                        ForEach(Array(filteredNewEpisodes.enumerated()), id: \.element.audioURL) { index, episode in
                            filteredNewEpisodeRowView(episode: episode, index: index)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
                .navigationTitle("New Episodes")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            showNewEpisodePreview = false
                            newEpisodesFound.removeAll()
                            selectedEpisodes.removeAll()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var episodePreviewFullScreen: some View {
        NavigationView {
            if isLoading {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                    
                    Text("Loading RSS Feed...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("RSS Episodes")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            showEpisodePreview = false
                            rssData = nil
                            selectedEpisodes.removeAll()
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if let rssData = rssData {
                        // Feed info header with image
                VStack(spacing: 16) {
                            // RSS Feed Image
                            AsyncImage(url: URL(string: rssData.channelImageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray4))
                                    .overlay(
                                        Image(systemName: "waveform.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            VStack(spacing: 8) {
                                Text(rssData.channelTitle)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                if !rssData.channelDescription.isEmpty {
                                    Text(rssData.channelDescription)
                                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                
                                Text("Total Episodes: \(rssData.episodes.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                        .padding(.horizontal, 20)
                        
                        // Selection controls and Upload button
                        VStack(spacing: 16) {
                            HStack {
                                Button(action: {
                                    // Select only new episodes (not already uploaded)
                                    selectedEpisodes = Set(rssData.episodes.indices.compactMap { index in
                                        let episode = rssData.episodes[index]
                                        let isNew = isEpisodeNew(episode, cachedGuids: matchingSubscriptionImportedGuids)
                                        return isNew ? String(index) : nil
                                    })
                                }) {
                                    Text("Select All")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("accentColor"))
                                }
                                
                                Spacer()
                                
                                if !selectedEpisodes.isEmpty {
                                    Button(action: {
                                        selectedEpisodes.removeAll()
                                    }) {
                                        Text("Deselect All")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(selectedEpisodes.count) selected")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Upload button at the top
                            if !selectedEpisodes.isEmpty {
                                Button(action: {
                                    uploadSelectedEpisodes()
                                }) {
                                    HStack {
                                        if isUploading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .foregroundColor(.white)
                                            Text("Uploading...")
                                        } else {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Upload \(selectedEpisodes.count) Episodes")
                                        }
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color("accentColor"))
                                            .shadow(color: Color("accentColor").opacity(0.25), radius: 8, x: 0, y: 4)
                                    )
                                }
                                .disabled(isUploading || isLoading)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Episodes list
                        LazyVStack(spacing: 12) {
                            ForEach(rssData.episodes.indices, id: \.self) { index in
                                rssEpisodeRow(episode: rssData.episodes[index], index: index)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
                .navigationTitle("RSS Episodes")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                            showEpisodePreview = false
                            rssData = nil
                            selectedEpisodes.removeAll()
                        }
                    }
                }
            }
        }
    }
    
    private var newEpisodePreviewSection: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button("← Back") {
                    showNewEpisodePreview = false
                    newEpisodesFound.removeAll()
                    selectedEpisodes.removeAll()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("accentColor"))
                
                Spacer()
            }
            
            // Episode count and selection
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("New Episodes Found")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(newEpisodesFound.count) new episodes since your last check")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !newEpisodesFound.isEmpty {
                    HStack {
                        Button(action: {
                            if selectedEpisodes.count == newEpisodesFound.count {
                                selectedEpisodes.removeAll()
                            } else {
                                selectedEpisodes = Set(newEpisodesFound.indices.map { String($0) })
                            }
                        }) {
                            Text(selectedEpisodes.count == newEpisodesFound.count ? "Deselect All" : "Select All")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("accentColor"))
                        }
                        
                        Spacer()
                        
                        if selectedEpisodes.count > 0 {
                            Button(action: {
                                uploadSelectedNewEpisodes()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Upload \(selectedEpisodes.count) Episode\(selectedEpisodes.count == 1 ? "" : "s")")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color("accentColor"))
                                )
                            }
                            .disabled(isUploading)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Episodes list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(newEpisodesFound.enumerated()), id: \.offset) { index, episode in
                                newEpisodeRowView(episode: episode, index: index)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 400)
            } else {
                VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("All Caught Up!")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("No new episodes found since your last check.")
                            .font(.subheadline)
                        .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                }
            }
            
            if isUploading {
                uploadProgressSection
            }
            
            Spacer()
        }
    }
    
    private func filteredNewEpisodeRowView(episode: RSSEpisode, index: Int) -> some View {
        let subscription = newEpisodesWithSource.first { $0.episode.audioURL == episode.audioURL }?.subscription
        
        return HStack(spacing: 12) {
            // Selection checkbox
            Button(action: {
                if selectedEpisodes.contains(String(index)) {
                    selectedEpisodes.remove(String(index))
                } else {
                    selectedEpisodes.insert(String(index))
                }
            }) {
                Image(systemName: selectedEpisodes.contains(String(index)) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedEpisodes.contains(String(index)) ? Color("accentColor") : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // RSS Feed source indicator
                if let subscription = subscription {
                    Text(subscription.feedTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("accentColor"))
                        .lineLimit(1)
                }
                
                // Episode title
                Text(episode.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Episode description
                if !episode.description.isEmpty {
                    Text(episode.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                // Publication date
                Text(formatDate(episode.pubDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Edit button
            Button(action: {
                editingEpisodeIndex = index
                showingEditSheet = true
            }) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color("accentColor"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedEpisodes.contains(String(index)) ? Color("accentColor").opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedEpisodes.contains(String(index)) ? Color("accentColor") : Color.clear, lineWidth: 2)
                )
        )
    }
    
    private func newEpisodeRowView(episode: RSSEpisode, index: Int) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                let indexString = String(index)
                if selectedEpisodes.contains(indexString) {
                    selectedEpisodes.remove(indexString)
                } else {
                    selectedEpisodes.insert(indexString)
                }
            }) {
                Image(systemName: selectedEpisodes.contains(String(index)) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(selectedEpisodes.contains(String(index)) ? Color("accentColor") : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(episode.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if episode.hasWarnings {
                        Button(action: {
                            // Show warning details
                        }) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Edit button for new episodes
                    Button(action: {
                        editingEpisodeIndex = index
                        showingEditSheet = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color("accentColor"))
                    }
                }
                
                // Show warnings if any
                if episode.hasWarnings {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(episode.validationWarnings, id: \.self) { warning in
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text(warning)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if episode.title.count > 200 {
                            Text("✂️ Will be truncated to: \(episode.truncatedTitle)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Text(formatDate(episode.pubDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !episode.description.isEmpty {
                    Text(episode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            selectedEpisodes.contains(String(index)) ? Color("accentColor") : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .onTapGesture {
            let indexString = String(index)
            if selectedEpisodes.contains(indexString) {
                selectedEpisodes.remove(indexString)
            } else {
                selectedEpisodes.insert(indexString)
                    }
        }
    }
    
    // MARK: - Header Section
    // MARK: - Computed Properties for RSS Filtering
    
    // Filtered episodes based on selected RSS feed
    private var filteredNewEpisodes: [RSSEpisode] {
        guard let filterSubscriptionId = selectedRSSFilter else {
            return newEpisodesFound // Show all if no filter selected
        }
        
        return newEpisodesWithSource
            .filter { $0.subscription.id == filterSubscriptionId }
            .map { $0.episode }
    }
    
    // Get unique subscriptions that have new episodes
    private var uniqueSubscriptionsWithNewEpisodes: [RSSSubscription] {
        let subscriptions = newEpisodesWithSource.map { $0.subscription }
        var uniqueSubscriptions: [RSSSubscription] = []
        var seenIds: Set<String> = []
        
        for subscription in subscriptions {
            if let id = subscription.id, !seenIds.contains(id) {
                uniqueSubscriptions.append(subscription)
                seenIds.insert(id)
            }
        }
        
        return uniqueSubscriptions
    }
    
    // Count episodes for a specific subscription
    private func episodeCountForSubscription(_ subscription: RSSSubscription) -> Int {
        return newEpisodesWithSource.filter { $0.subscription.id == subscription.id }.count
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color("accentColor"))
            
            VStack(spacing: 8) {
                Text("Import RSS Feed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Paste your podcast RSS feed URL to preview and select episodes to upload")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - URL Input Section
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RSS Feed URL")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("https://rss.art19.com/your-podcast", text: $rssURL)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("accentColor").opacity(0.3), lineWidth: 1)
                        )
                )
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .disabled(isLoading || isUploading)
            
            Text("Enter the RSS feed URL for your podcast. This is usually provided by your hosting platform.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Load Button
    private var loadButton: some View {
        Button(action: loadRSSFeed) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(isLoading ? "Loading..." : "Load Episodes")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.85)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color("accentColor").opacity(0.25), radius: 10, x: 0, y: 6)
            )
        }
        .disabled(rssURL.isEmpty || isLoading || !isValidURL(rssURL))
        .opacity(rssURL.isEmpty || isLoading || !isValidURL(rssURL) ? 0.6 : 1.0)
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 12) {
            Text("Loading Episodes...")
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
            
            Text("Parsing RSS feed...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Upload Progress Section
    private var uploadProgressSection: some View {
        VStack(spacing: 12) {
            Text("Uploading Episodes...")
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView(value: uploadProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color("accentColor")))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text("\(Int(uploadProgress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How RSS Import Works")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                StepRow(icon: "1.circle.fill", text: "Paste your RSS feed URL")
                StepRow(icon: "2.circle.fill", text: "Preview all available episodes")
                StepRow(icon: "3.circle.fill", text: "Select episodes you want to upload")
                StepRow(icon: "4.circle.fill", text: "Upload selected episodes to your profile")
            }
            
            Text("Note: Audio files remain hosted on your original platform. We only import the metadata and streaming links.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Episode Preview Section
    private var episodePreviewSection: some View {
        VStack(spacing: 20) {
            // Header with podcast info
            if let rssData = rssData {
                VStack(spacing: 12) {
                    HStack {
                        Button("← Back") {
                            showEpisodePreview = false
                            self.rssData = nil
                            selectedEpisodes.removeAll()
                        }
                        .foregroundColor(Color("accentColor"))
                        
                        Spacer()
                    }
                    
                    Text(rssData.channelTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Podcast thumbnail with custom replacement option
                    VStack(spacing: 12) {
                        // Show custom image if selected, otherwise RSS image
                        Group {
                            if let customImage = customThumbnailImage {
                                Image(uiImage: customImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if let imageURL = rssData.channelImageURL {
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray5))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.title2)
                                        )
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                            .font(.title2)
                                    )
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        // Replace Image button
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack(spacing: 6) {
                                if isUploadingCustomImage {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                } else {
                                    Image(systemName: customThumbnailImage != nil ? "checkmark.circle.fill" : "photo.badge.plus")
                                        .font(.system(size: 14))
                                }
                                Text(customThumbnailImage != nil ? "Custom Image" : "Replace Image")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(customThumbnailImage != nil ? .green : Color("accentColor"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill((customThumbnailImage != nil ? Color.green : Color("accentColor")).opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(customThumbnailImage != nil ? .green : Color("accentColor"), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(isUploadingCustomImage)
                    }
                    
                    Text("\(rssData.episodes.count) episodes found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Selection controls
                HStack(spacing: 16) {
                    Button("Select All") {
                        // Select only new episodes (not already uploaded)
                        selectedEpisodes = Set(rssData.episodes.indices.compactMap { index in
                            let episode = rssData.episodes[index]
                            let isNew = isEpisodeNew(episode, cachedGuids: matchingSubscriptionImportedGuids)
                            return isNew ? String(index) : nil
                        })
                    }
                    .foregroundColor(Color("accentColor"))
                    
                    Button("Deselect All") {
                        selectedEpisodes.removeAll()
                    }
                    .foregroundColor(Color("accentColor"))
                    
                    Spacer()
                    
                    Text("\(selectedEpisodes.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Upload button
                if !selectedEpisodes.isEmpty {
                    if isUploading {
                        uploadProgressSection
                    } else {
                        Button("Upload Selected Episodes (\(selectedEpisodes.count))") {
                            uploadSelectedEpisodes()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.85)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color("accentColor").opacity(0.25), radius: 10, x: 0, y: 6)
                        )
                    }
                }
                
                // Episodes list
                LazyVStack(spacing: 12) {
                    ForEach(rssData.episodes.indices, id: \.self) { index in
                        rssEpisodeRow(episode: rssData.episodes[index], index: index)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func retryFailedEpisodes() {
        // Get the failed episode titles for retry
        guard let rssData = rssData else { return }
        let failedTitles = failedEpisodeDetails.map { $0.title }
        
        // Clear the failure details for fresh retry
        failedEpisodeDetails.removeAll()
        
        // Re-select only the failed episodes for retry
        selectedEpisodes.removeAll()
        
        for (index, episode) in rssData.episodes.enumerated() {
            let episodeId = String(index)
            // Check if this episode was in the failed list
            if failedTitles.contains(episode.title) {
                selectedEpisodes.insert(episodeId)
            }
        }
        
        // Clear the alert and start upload again
        showPartialSuccessAlert = false
        
        print("🔄 Retrying \(selectedEpisodes.count) failed episodes")
        
        // Start the upload process for the failed episodes
        Task {
            await uploadSelectedEpisodes()
        }
    }
    
    @MainActor
    private func uploadCustomImage(_ image: UIImage) async {
        guard let rssData = rssData else { return }
        
        isUploadingCustomImage = true
        
        do {
            // Compress and upload the custom image
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw RSSImportError.invalidPodData("Failed to compress custom image")
            }
            
            // Upload to Firebase Storage using existing thumbnails folder
            let storage = Storage.storage()
            let storageRef = storage.reference()
            let filename = "\(UUID().uuidString)_custom_rss.jpg"
            let imageRef = storageRef.child("thumbnails/\(filename)")
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            
            customThumbnailUrl = downloadURL.absoluteString
            
            print("🖼️ Custom RSS artwork uploaded successfully: \(downloadURL.absoluteString)")
            
        } catch {
            print("❌ Failed to upload custom RSS artwork: \(error)")
            errorMessage = "Failed to upload custom image: \(error.localizedDescription)"
            showErrorAlert = true
            customThumbnailImage = nil
        }
        
        isUploadingCustomImage = false
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme?.hasPrefix("http") == true
    }
    
    // MARK: - RSS Verification
    
    /// Check if the feed is already verified for this user
    private func isRSSFeedVerified(feedUrl: String) async -> Bool {
        let db = Firestore.firestore()
        // Hash the URL to create a valid Firestore document ID (SHA-256 to match server)
        let feedUrlHash = sha256(feedUrl)
        let verifiedFeedRef = db.collection("users").document(user.uid)
            .collection("verifiedRSSFeeds").document(feedUrlHash)
        
        do {
            let doc = try await verifiedFeedRef.getDocument()
            return doc.exists
        } catch {
            print("❌ Failed to check RSS verification status: \(error)")
            return false
        }
    }
    
    /// SHA-256 hash function to match server-side hashing
    private func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Proceed after successful verification
    private func proceedAfterVerification() async {
        // The RSS feed data is already loaded in pendingVerificationData
        // After verification, create the subscription and load the feed browser
        guard let feedData = pendingVerificationData else { return }
        
        do {
            let subscription = RSSSubscription.create(
                from: feedData,
                feedUrl: rssURL,
                userId: user.uid
            )
            
            let result = try await rssSubscriptionService.createOrReactivateSubscription(subscription, rssData: feedData, for: user.uid)
            
            await MainActor.run {
                self.pendingVerificationData = nil
                // First dismiss the verification sheet
                self.showVerification = false
                
                // Small delay to allow sheet dismissal animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loadUserSubscriptions()
                    
                    switch result {
                    case .created(let createdSubscription):
                        self.selectedSubscription = createdSubscription
                        self.loadIndividualFeed(createdSubscription)
                    case .reactivated(let reactivatedSubscription):
                        self.selectedSubscription = reactivatedSubscription
                        self.loadIndividualFeed(reactivatedSubscription)
                    }
                    
                    print("✅ RSS feed verified! Loading feed browser...")
                }
            }
        } catch {
            await MainActor.run {
                self.pendingVerificationData = nil
                self.showVerification = false
                showError("Failed to create subscription after verification: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadRSSFeed() {
        guard let url = URL(string: rssURL) else {
            showError("Invalid RSS URL format")
            return
        }
        
        isLoading = true
        
        Task {
            // First check if user already has this RSS feed
            do {
                if let existingSubscription = try await rssSubscriptionService.findExistingSubscription(feedUrl: rssURL, for: user.uid) {
                    if existingSubscription.isActive {
                        // Active subscription - block loading
                        await MainActor.run {
                            isLoading = false
                            showError("You're already subscribed to this RSS feed! Check your subscriptions above.")
                        }
                        return
                    } else {
                        // Inactive subscription - load RSS data first then reactivate
                        print("🔄 Found inactive subscription, loading RSS data for reactivation")
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let parser = RSSParser()
                        let parsedRSSData = try parser.parse(data: data)
                        
                        let reactivatedSubscription = try await rssSubscriptionService.reactivateSubscriptionWithStream(existingSubscription, rssData: parsedRSSData, for: user.uid)
                        
                        await MainActor.run {
                            isLoading = false
                            // Update local subscriptions list
                            loadUserSubscriptions()
                            // Go directly to individual feed browser with NEW/UPLOADED indicators
                            selectedSubscription = reactivatedSubscription
                            loadIndividualFeed(reactivatedSubscription)
                        }
                        return
                    }
                }
            } catch {
                print("❌ Failed to check existing subscriptions: \(error)")
                // Continue with loading if check fails
            }
            
            // No existing subscription - load feed and check for verification
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let parser = RSSParser()
                let feedData = try parser.parse(data: data)
                
                print("📧 [RSS Main] Feed email found: \(feedData.channelEmail ?? "NONE")")
                
                // Check if RSS feed is already verified
                let isVerified = await isRSSFeedVerified(feedUrl: rssURL)
                print("🔐 [RSS Main] Feed verified status: \(isVerified)")
                
                if isVerified || feedData.channelEmail == nil {
                    // Already verified OR no email in feed - create subscription immediately
                    print("✅ [RSS Main] Creating subscription without verification (verified=\(isVerified), hasEmail=\(feedData.channelEmail != nil))")
                    let subscription = RSSSubscription.create(
                        from: feedData,
                        feedUrl: rssURL,
                        userId: user.uid
                    )
                    
                    let result = try await rssSubscriptionService.createOrReactivateSubscription(subscription, rssData: feedData, for: user.uid)
                    
                    await MainActor.run {
                        isLoading = false
                        loadUserSubscriptions()
                        
                        switch result {
                        case .created(let createdSubscription):
                            selectedSubscription = createdSubscription
                            loadIndividualFeed(createdSubscription)
                        case .reactivated(let reactivatedSubscription):
                            selectedSubscription = reactivatedSubscription
                            loadIndividualFeed(reactivatedSubscription)
                        }
                    }
                } else {
                    // Not verified and has email - show verification screen
                    print("🔐 [RSS Main] Showing verification screen for email: \(feedData.channelEmail ?? "unknown")")
                    await MainActor.run {
                        isLoading = false
                        pendingVerificationData = feedData
                        showVerification = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError("Failed to load RSS feed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Removed old performRSSLoad - now using ImportNewRSSFeedView sheet only
    
    private func validateAndFilterEpisodes(_ rssData: RSSFeedData) async -> RSSFeedData {
        var validEpisodes: [RSSEpisode] = []
        var invalidCount = 0
        
        for episode in rssData.episodes {
            // Basic validation first
            if episode.isValid {
                // Check audio URL accessibility
                if await isAudioURLAccessible(episode.audioURL) {
                    validEpisodes.append(episode)
                } else {
                    invalidCount += 1
                    print("⚠️ Episode '\(episode.title)' has inaccessible audio URL: \(episode.audioURL)")
                }
            } else {
                invalidCount += 1
                print("⚠️ Episode '\(episode.title)' failed validation: \(episode.validationErrors.joined(separator: ", "))")
            }
        }
        
        if invalidCount > 0 {
            print("⚠️ Filtered out \(invalidCount) invalid episodes from RSS feed")
        }
        
        return RSSFeedData(
            channelTitle: rssData.channelTitle,
            channelDescription: rssData.channelDescription,
            channelImageURL: rssData.channelImageURL,
            channelAuthor: rssData.channelAuthor,
            channelCategory: rssData.channelCategory,
            channelLanguage: rssData.channelLanguage,
            channelEmail: rssData.channelEmail,
            episodes: validEpisodes
        )
    }
    
    private func isAudioURLAccessible(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
                
                // Check for successful status and audio content type
                let isSuccessStatus = (200...299).contains(statusCode)
                let isAudioContent = contentType.contains("audio") || 
                                   contentType.contains("mpeg") || 
                                   contentType.contains("mp3") ||
                                   contentType.contains("mp4") ||
                                   contentType.contains("wav")
                
                return isSuccessStatus && (isAudioContent || contentType.isEmpty)
            }
            
            return false
        } catch {
            print("❌ Audio URL accessibility check failed for \(urlString): \(error.localizedDescription)")
            // Return true for network errors to be permissive (user might be offline)
            return true
        }
    }
    
    private func uploadSelectedEpisodes() {
        guard let rssData = rssData else { return }
        
        isUploading = true
        uploadProgress = 0.0
        
        Task {
            await performSelectedUpload(rssData: rssData)
        }
    }
    
    private func performSelectedUpload(rssData: RSSFeedData) async {
        let selectedIndices = selectedEpisodes.compactMap { Int($0) }.sorted()
        let selectedRSSEpisodes = selectedIndices.map { rssData.episodes[$0] }
        
        var successfulUploads = 0
        var failedEpisodes: [(episode: RSSEpisode, error: String)] = []
        
        do {
            // Upload artwork (use custom if available, otherwise RSS artwork)
            await MainActor.run { uploadProgress = 0.1 }
            let thumbnailUrl: String
            if let customUrl = customThumbnailUrl {
                // Custom image already uploaded, use its URL
                thumbnailUrl = customUrl
                print("🖼️ Using custom thumbnail: \(customUrl)")
            } else {
                // Upload RSS artwork
                thumbnailUrl = try await uploadPodcastArtwork(from: rssData.channelImageURL)
                print("🖼️ Using RSS thumbnail: \(thumbnailUrl)")
            }
            
            // Check if this feed has a subscription with a stream (for linking pods)
            let matchingSubscription = await findSubscriptionForFeed(rssData)
            let streamId = matchingSubscription?.streamId
            
            // Process selected episodes with individual error handling
            var uploadedPods: [Pod] = []
            var uploadedGuids: [String] = []
            
            for (processedIndex, episode) in selectedRSSEpisodes.enumerated() {
                do {
                    // Find the original index in the full episodes array
                    let originalIndex = selectedIndices[processedIndex]
                    // Use custom thumbnail URL if available, otherwise use RSS thumbnail
                    let finalThumbnailUrl = customThumbnailUrl ?? thumbnailUrl
                    let pod = try await createPodFromRSSEpisode(episode, thumbnailUrl: finalThumbnailUrl, episodeIndex: originalIndex, streamId: streamId)
                    uploadedPods.append(pod)
                    successfulUploads += 1
                    
                    // Track GUID for subscription deduplication (if this came from a subscription)
                    let episodeGuid = createEpisodeGuid(from: episode)
                    uploadedGuids.append(episodeGuid)
                    
                } catch {
                    failedEpisodes.append((episode: episode, error: error.localizedDescription))
                    failedEpisodeDetails.append((title: episode.title, error: error.localizedDescription))
                    print("❌ Failed to process episode '\(episode.title)': \(error.localizedDescription)")
                }
                
                // Update progress
                let progress = 0.1 + (0.7 * Double(processedIndex + 1) / Double(selectedRSSEpisodes.count))
                await MainActor.run { uploadProgress = progress }
            }
            
            // Only proceed if we have valid pods to upload
            guard !uploadedPods.isEmpty else {
            await MainActor.run {
                    isUploading = false
                    showError("All selected episodes failed validation. Please check episode data and try again.")
                }
                return
            }
            
            // Save to Firebase with retry logic
            await MainActor.run { uploadProgress = 0.8 }
            try await savePodsToFirebaseWithRetry(&uploadedPods)
            
            // Update subscription tracking if this was from a subscription
            if let matchingSubscription = matchingSubscription {
                try await rssSubscriptionService.addImportedEpisodeGuids(uploadedGuids, to: matchingSubscription.id!, for: user.uid)
                
                // Also add episodes to RSS stream
                if let streamId = matchingSubscription.streamId {
                    let podIds = uploadedPods.compactMap { $0.id }
                    print("🔵 [Upload] After save - Pod IDs: \(podIds)")
                    try await rssStreamService.addEpisodesToStream(podIds, to: streamId)
                }
            }
            
            // Complete
            await MainActor.run {
                uploadProgress = 1.0
                uploadedEpisodeCount = successfulUploads
                isUploading = false
                
                if failedEpisodes.isEmpty {
                    // Complete success
                showSuccessAlert = true
                } else if successfulUploads > 0 {
                    // Partial success - show detailed failure info
                    showPartialSuccessAlert = true
                } else {
                    // Complete failure
                    showError("All episodes failed to upload. Please check your RSS feed and try again.")
                }
            }
            
        } catch {
            await MainActor.run {
                isUploading = false
                if successfulUploads > 0 {
                    showError("Uploaded \(successfulUploads) episodes successfully, but failed to complete: \(error.localizedDescription)")
                } else {
                    showError("Failed to upload episodes: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func savePodsToFirebaseWithRetry(_ pods: inout [Pod]) async throws {
        let db = Firestore.firestore()
        let maxRetries = 3
        
        for (index, pod) in pods.enumerated() {
            var success = false
            var lastError: Error?
            var savedPodId: String?
            
            for attempt in 1...maxRetries {
                do {
                    let sanitizedPod = pod.sanitized()
                    let docRef = try await db.collection("pods").addDocument(from: sanitizedPod)
                    
                    // Also save to user's personal pods collection (like regular uploads)
                    try await db.collection("users").document(user.uid).collection("pods").document(docRef.documentID).setData(from: sanitizedPod)
                    
                    savedPodId = docRef.documentID
                    success = true
                    break
                } catch {
                    lastError = error
                    print("❌ Attempt \(attempt) failed for episode '\(pod.title)': \(error.localizedDescription)")
                    
                    if attempt < maxRetries {
                        // Wait before retrying (exponential backoff)
                        let delay = Double(attempt) * 2.0
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }
            
            if !success {
                throw lastError ?? RSSImportError.uploadFailed
            }
            
            // Update the pod with its ID
            if let podId = savedPodId {
                pods[index].id = podId
                print("✅ Saved pod '\(pod.title)' with ID: \(podId)")
            }
            
            // Update progress for individual pod uploads
            let progress = 0.8 + (0.2 * Double(index + 1) / Double(pods.count))
            await MainActor.run { uploadProgress = progress }
        }
        
        // Increment user's pod count for all uploaded episodes
        await incrementUserPodCount(by: pods.count)
        
        // Send notification to refresh user profile (like regular uploads)
        await MainActor.run {
            NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil)
        }
    }
    
    private func incrementUserPodCount(by count: Int) async {
        let userRef = Firestore.firestore().collection("users").document(user.uid)
        
        do {
            try await userRef.updateData([
                "podCount": FieldValue.increment(Int64(count))
            ])
            print("✅ User pod count incremented by \(count) for RSS upload")
        } catch {
            print("❌ Failed to increment user pod count: \(error)")
        }
    }
    
    private func createPodFromRSSEpisode(_ episode: RSSEpisode, thumbnailUrl: String, episodeIndex: Int? = nil, originalGuid: String? = nil, streamId: String? = nil) async throws -> Pod {
        // Validate episode before processing
        guard episode.isValid else {
            throw RSSImportError.invalidEpisodeData(episode.validationErrors.joined(separator: ", "))
        }
        
        // Use edited values if available, otherwise use original episode data
        var finalTitle = episode.sanitizedTitle
        // Provide fallback description if RSS episode doesn't have one
        var finalDescription = episode.description.isEmpty ? 
            "Episode from \(episode.title)" : episode.sanitizedDescription
        var finalKeywords = episode.keywords ?? []
        
        if let index = episodeIndex,
           let editedEpisode = editedEpisodes[String(index)] {
            print("🎬 Processing edited episode \(index)")
            print("🎬 Original title: '\(editedEpisode.title)'")
            print("🎬 Original description: '\(editedEpisode.description)'")
            
            // Handle edited title with fallback for empty
            let editedTitle = editedEpisode.title.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🎬 Trimmed title: '\(editedTitle)'")
            
            if editedTitle.isEmpty {
                finalTitle = episode.sanitizedTitle
                print("🎬 Using fallback title: '\(finalTitle)'")
            } else {
                finalTitle = InputSanitizer.clean(editedTitle, type: .podTitle)
                print("🎬 Sanitized title: '\(finalTitle)'")
            }
            
            // Handle edited description with fallback
            let editedDesc = editedEpisode.description.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🎬 Trimmed description: '\(editedDesc)'")
            
            if editedDesc.isEmpty {
                finalDescription = "Episode from \(finalTitle)"
                print("🎬 Using fallback description: '\(finalDescription)'")
            } else {
                let sanitizedDesc = InputSanitizer.clean(editedDesc, type: .podDescription)
                print("🎬 Sanitized description: '\(sanitizedDesc)'")
                print("🎬 Sanitized description length: \(sanitizedDesc.count)")
                
                // Check if sanitization resulted in empty string (failed validation)
                if sanitizedDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalDescription = "Episode from \(finalTitle)"
                    print("🎬 Sanitization failed, using fallback: '\(finalDescription)'")
                } else {
                    // Ensure description is within Pod model limits (5000 chars)
                    if sanitizedDesc.count > 5000 {
                        finalDescription = String(sanitizedDesc.prefix(4997)) + "..."
                        print("🎬 Description truncated to 5000 chars: '\(finalDescription)'")
                    } else {
                        finalDescription = sanitizedDesc
                        print("🎬 Using sanitized description: '\(finalDescription)'")
                    }
                }
            }
            finalKeywords = editedEpisode.keywords
            
            print("🎬 Final title: '\(finalTitle)'")
            print("🎬 Final description: '\(finalDescription)'")
        }
        
            // Use the same AI processing as regular uploads
            let processedPod = await openAIProcessor.processPodWithFallback(
            title: finalTitle,
            description: finalDescription,
            userTags: finalKeywords, // Use edited or original keywords as user tags
                originalProcessor: aiProcessor
            )
            
        // Smart keyword combination: RSS keywords take priority, then AI fills remaining slots
        var combinedKeywords: [String] = []
        
        // Start with RSS keywords (from XML) - these are creator-selected and most relevant
        let cleanedRSSKeywords = finalKeywords.compactMap { keyword -> String? in
            let cleaned = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        combinedKeywords.append(contentsOf: cleanedRSSKeywords)
        
        print("🏷️ Starting with \(cleanedRSSKeywords.count) RSS keywords: \(cleanedRSSKeywords)")
        
        // Fill remaining slots with AI keywords if we have space (max 10 total)
        let remainingSlots = max(0, 10 - combinedKeywords.count)
        if remainingSlots > 0 && !processedPod.keywords.isEmpty {
            let lowercaseRSSKeywords = combinedKeywords.map { $0.lowercased() }
            let uniqueAIKeywords = processedPod.keywords.compactMap { aiKeyword -> String? in
                let cleaned = aiKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
                // Only add if not empty and not already in RSS keywords (case-insensitive)
                if !cleaned.isEmpty && !lowercaseRSSKeywords.contains(cleaned.lowercased()) {
                    return cleaned
                } else {
                    return nil
                }
            }
            
            // Add up to remaining slots
            let aiKeywordsToAdd = Array(uniqueAIKeywords.prefix(remainingSlots))
            combinedKeywords.append(contentsOf: aiKeywordsToAdd)
            
            print("🏷️ Added \(aiKeywordsToAdd.count) AI keywords: \(aiKeywordsToAdd)")
        }
        
        // Ensure we don't exceed 10 keywords total
        combinedKeywords = Array(combinedKeywords.prefix(10))
        
        print("🏷️ Final keywords for '\(finalTitle)': \(combinedKeywords.count)/10 total")
        print("🏷️ Keywords: \(combinedKeywords)")
        
        // Use the provided original GUID, or create one from the episode
        // (originalGuid should be from the original episode BEFORE any edits)
        let rssGuid = originalGuid ?? createEpisodeGuid(from: episode)
        
        // Create Pod with final processed data
            let pod = Pod(
                id: nil,
            title: finalTitle,
                timestamp: Timestamp(date: episode.pubDate),
            description: finalDescription,
                fileUrl: episode.audioURL,
                thumbnailUrl: thumbnailUrl,
                userId: user.uid,
                likes: 0,
                views: 0,
                shares: 0,
                comments: 0,
                saves: 0,
            category: processedPod.category ?? "Miscellaneous", // AI-generated category with fallback
            keywords: combinedKeywords, // Combined RSS + AI keywords
                duration: episode.duration,
                fileSize: episode.fileSize,
            mimeType: episode.mimeType ?? "audio/mpeg", // Default MIME type
            rssGuid: rssGuid, // Store original RSS GUID for deletion tracking
            rssStreamId: streamId, // Store RSS stream ID for linking pods to their stream
            titleLowercased: finalTitle.lowercased(),
                user: nil,
                didLike: false,
                didSave: false,
                isDeleted: false,
                isActive: true,
                createdAt: Timestamp(date: episode.pubDate),
                updatedAt: Timestamp(),
                deletedAt: nil,
                version: 1,
                isReported: false,
                moderationStatus: .approved,
                contentWarnings: []
            )
            
        // Validate Pod before returning
        guard pod.isValid else {
            throw RSSImportError.invalidPodData(pod.validationErrors.joined(separator: ", "))
        }
        
        return pod.sanitized()
    }
    
    private func uploadPodcastArtwork(from imageURL: String?) async throws -> String {
        guard let imageURL = imageURL,
              let url = URL(string: imageURL) else {
            throw RSSImportError.missingArtwork
        }
        
        // Download image
        let (imageData, _) = try await URLSession.shared.data(from: url)
        
        // Upload to Firebase Storage using existing thumbnails folder
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageRef = storageRef.child("thumbnails/\(UUID().uuidString).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await imageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}

// MARK: - Step Row Component
struct StepRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("accentColor"))
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - RSS Data Models
struct RSSFeedData {
    let channelTitle: String
    let channelDescription: String
    let channelImageURL: String?
    let channelAuthor: String?
    let channelCategory: String?
    let channelLanguage: String?
    let channelEmail: String? // For ownership verification
    let episodes: [RSSEpisode]
}

struct EditedEpisode {
    var title: String
    var description: String
    var keywords: [String]
    
    init(from episode: RSSEpisode) {
        self.title = episode.title
        // Provide fallback description if RSS episode doesn't have one
        self.description = episode.description.isEmpty ? 
            "Episode from \(episode.title)" : episode.description
        self.keywords = episode.keywords ?? []
    }
}

struct RSSEpisode {
    let title: String
    let description: String
    let audioURL: String
    let pubDate: Date
    let duration: TimeInterval?
    let fileSize: Int64?
    let mimeType: String?
    let keywords: [String]?
    
    // Validation properties
    var isValid: Bool {
        return !sanitizedTitle.isEmpty &&
               !audioURL.isEmpty &&
               isValidAudioURL &&
               sanitizedTitle.count <= 200 &&
               (description.isEmpty || sanitizedDescription.count <= 5000) // Allow empty description for RSS
    }
    
    var sanitizedTitle: String {
        return InputSanitizer.clean(title, type: .podTitle)
    }
    
    var sanitizedDescription: String {
        let cleaned = InputSanitizer.clean(description, type: .podDescription)
        // Truncate to 5000 characters if longer
        return String(cleaned.prefix(5000))
    }
    
    var isValidAudioURL: Bool {
        guard let url = URL(string: audioURL) else { return false }
        return url.scheme?.hasPrefix("http") == true
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if title.isEmpty {
            errors.append("Episode title is required")
        } else if sanitizedTitle.isEmpty {
            errors.append("Episode title contains only invalid characters")
        } else if sanitizedTitle.count > 200 {
            errors.append("Episode title too long (max 200 characters)")
        }
        
        if description.isEmpty {
            // For RSS episodes, we'll provide a fallback instead of requiring description
            // This is handled in createPodFromRSSEpisode
        } else if sanitizedDescription.isEmpty {
            errors.append("Episode description contains only invalid characters")
        // Note: We auto-truncate descriptions now, so this check is informational only
        } else if description.count > 5000 {
            print("ℹ️ Episode description will be truncated from \(description.count) to 5000 characters")
        }
        
        if audioURL.isEmpty {
            errors.append("Audio URL is required")
        } else if !isValidAudioURL {
            errors.append("Invalid audio URL format")
        }
        
        return errors
    }
    
    var validationWarnings: [String] {
        var warnings: [String] = []
        
        if title.count > 200 {
            warnings.append("Title will be truncated to 200 characters")
        } else if title.count > 150 {
            warnings.append("Title is quite long (\(title.count)/200 characters)")
        }
        
        if description.count > 5000 {
            warnings.append("Description will be truncated to 5000 characters")
        } else if description.count > 4500 {
            warnings.append("Description is quite long (\(description.count)/5000 characters)")
        }
        
        return warnings
    }
    
    var hasWarnings: Bool {
        return !validationWarnings.isEmpty
    }
    
    var truncatedTitle: String {
        return String(title.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - RSS Parser
class RSSParser: NSObject, XMLParserDelegate {
    private var rssData: RSSFeedData?
    private var episodes: [RSSEpisode] = []
    private var currentEpisode: RSSEpisode?
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentAudioURL = ""
    private var currentPubDate = ""
    private var currentDuration = ""
    private var currentKeywords = ""
    private var currentSummary = "" // iTunes summary (preferred over description)
    
    private var channelTitle = ""
    private var channelDescription = ""
    private var channelSummary = "" // iTunes summary (preferred over description)
    private var channelImageURL = ""
    private var channelAuthor = ""
    private var channelCategory = ""
    private var channelLanguage = ""
    private var channelEmail = "" // For ownership verification
    
    private var isInItem = false
    private var isInChannel = true
    
    // Flags to prevent duplicate data
    private var channelTitleCaptured = false
    private var channelDescriptionCaptured = false
    private var channelAuthorCaptured = false
    
    // Format validation
    private var hasItunesNamespace = false
    private var isRSS2Format = false
    private var rootElementFound = false
    
    func parse(data: Data) throws -> RSSFeedData {
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            throw RSSImportError.parseError
        }
        
        // Validate format requirements
        guard rootElementFound && isRSS2Format else {
            throw RSSImportError.unsupportedFormat
        }
        
        guard hasItunesNamespace else {
            throw RSSImportError.unsupportedFormat
        }
        
        guard let rssData = rssData else {
            throw RSSImportError.noData
        }
        
        return rssData
    }
    
    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        // Check for RSS 2.0 root element
        if elementName == "rss" && !rootElementFound {
            rootElementFound = true
            let version = attributeDict["version"] ?? ""
            isRSS2Format = version.hasPrefix("2.")
        }
        
        // Check for iTunes namespace elements
        if elementName.hasPrefix("itunes:") {
            hasItunesNamespace = true
        }
        
        if elementName == "item" {
            isInItem = true
            isInChannel = false
            // Reset episode data
            currentTitle = ""
            currentDescription = ""
            currentSummary = ""
            currentAudioURL = ""
            currentPubDate = ""
            currentDuration = ""
            currentKeywords = ""
        } else if elementName == "channel" {
            // Reset channel data when entering channel element
            isInChannel = true
            isInItem = false
        } else if elementName == "enclosure" && isInItem {
            currentAudioURL = attributeDict["url"] ?? ""
        } else if elementName == "itunes:image" && !isInItem {
            channelImageURL = attributeDict["href"] ?? ""
        } else if (elementName == "itunes:category" || elementName == "category") && !isInItem && isInChannel && channelCategory.isEmpty {
            // iTunes category is stored in the "text" attribute
            channelCategory = attributeDict["text"] ?? ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty else { return } // Skip empty strings
        
        switch currentElement {
        case "title":
            // Only use standard <title> tag, not <itunes:title>
            if isInItem {
                currentTitle += trimmedString
            } else if isInChannel && !channelTitleCaptured {
                print("📝 [Parser] Adding to channel title: '\(trimmedString)'")
                print("📝 [Parser] Channel title before: '\(channelTitle)'")
                channelTitle += trimmedString
                print("📝 [Parser] Channel title after: '\(channelTitle)'")
            }
        case "itunes:title":
            // Ignore itunes:title to prevent duplication (we use standard <title> tag)
            break
        case "itunes:summary":
            // Prioritize iTunes summary (clean, concise) for both episodes and channel
            if isInItem {
                currentSummary += trimmedString
            } else if isInChannel && !channelDescriptionCaptured {
                channelSummary += trimmedString
            }
        case "description":
            // Only use <description> if we don't have iTunes summary
            if isInItem && currentSummary.isEmpty {
                currentDescription += trimmedString
            } else if isInChannel && !channelDescriptionCaptured && channelSummary.isEmpty {
                channelDescription += trimmedString
            }
        case "itunes:author", "author":
            if !isInItem && isInChannel && !channelAuthorCaptured {
                channelAuthor += trimmedString
            }
        case "itunes:email", "managingEditor", "webMaster":
            if !isInItem && isInChannel && channelEmail.isEmpty {
                // Extract email from format "email@domain.com (Name)" or just "email@domain.com"
                let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                if let regex = try? NSRegularExpression(pattern: emailPattern),
                   let match = regex.firstMatch(in: trimmedString, range: NSRange(trimmedString.startIndex..., in: trimmedString)) {
                    if let range = Range(match.range, in: trimmedString) {
                        channelEmail = String(trimmedString[range])
                    }
                } else {
                    channelEmail += trimmedString
                }
            }
        case "language":
            if !isInItem && isInChannel && channelLanguage.isEmpty {
                channelLanguage += trimmedString
            }
        case "category":
            // Fallback for non-iTunes category tags that use text content
            if !isInItem && isInChannel && channelCategory.isEmpty {
                channelCategory += trimmedString
            }
        case "pubDate":
            if isInItem {
                currentPubDate += trimmedString
            }
        case "itunes:duration":
            if isInItem {
                currentDuration += trimmedString
            }
        case "itunes:keywords":
            if isInItem {
                currentKeywords += trimmedString
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Mark channel-level elements as captured when we exit them
        if !isInItem && isInChannel {
            if elementName == "title" && !channelTitle.isEmpty {
                print("🔒 [Parser] Locking channel title: '\(channelTitle)'")
                channelTitleCaptured = true
            } else if (elementName == "description" || elementName == "itunes:summary") && (!channelDescription.isEmpty || !channelSummary.isEmpty) {
                channelDescriptionCaptured = true
            } else if (elementName == "itunes:author" || elementName == "author") && !channelAuthor.isEmpty {
                channelAuthorCaptured = true
            }
        }
        
        // Clear currentElement when we exit an element to prevent duplicate appends
        if elementName == currentElement {
            currentElement = ""
        }
        
        if elementName == "item" {
            // Create episode from current data
            let episode = createEpisode()
            episodes.append(episode)
            isInItem = false
            isInChannel = true
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        // Prioritize iTunes summary (clean, concise) over full description (HTML with promotional content)
        let channelDescriptionToUse = !channelSummary.isEmpty ? channelSummary : channelDescription
        
        // Clean HTML tags from channel description (same as episode descriptions)
        let cleanChannelDescription = stripHTMLTags(from: channelDescriptionToUse)
        
        print("✅ [Parser] Parsing complete!")
        print("✅ [Parser] Final channel title: '\(channelTitle)'")
        print("✅ [Parser] Channel title length: \(channelTitle.count)")
        print("✅ [Parser] Channel language: '\(channelLanguage)'")
        print("✅ [Parser] Using iTunes summary for channel: \(!channelSummary.isEmpty)")
        
        rssData = RSSFeedData(
            channelTitle: channelTitle,
            channelDescription: cleanChannelDescription,
            channelImageURL: channelImageURL.isEmpty ? nil : channelImageURL,
            channelAuthor: channelAuthor.isEmpty ? nil : channelAuthor,
            channelCategory: channelCategory.isEmpty ? nil : channelCategory,
            channelLanguage: channelLanguage.isEmpty ? nil : channelLanguage,
            channelEmail: channelEmail.isEmpty ? nil : channelEmail,
            episodes: episodes
        )
    }
    
    private func createEpisode() -> RSSEpisode {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let pubDate = dateFormatter.date(from: currentPubDate) ?? Date()
        
        let duration = parseDuration(currentDuration)
        let keywords = currentKeywords.isEmpty ? nil : currentKeywords.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Prioritize iTunes summary (clean, concise) over full description (HTML with promotional content)
        let descriptionToUse = !currentSummary.isEmpty ? currentSummary : currentDescription
        
        // Clean HTML tags from description and trim whitespace
        let cleanDescription = stripHTMLTags(from: descriptionToUse)
        let cleanTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return RSSEpisode(
            title: cleanTitle,
            description: cleanDescription,
            audioURL: currentAudioURL.trimmingCharacters(in: .whitespacesAndNewlines),
            pubDate: pubDate,
            duration: duration,
            fileSize: nil,
            mimeType: "audio/mpeg",
            keywords: keywords
        )
    }
    
    private func stripHTMLTags(from string: String) -> String {
        var cleaned = string
        
        // First, replace block-level tags with newlines to preserve paragraph breaks
        let blockTags = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", 
                        "</li>", "</tr>", "</blockquote>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            cleaned = cleaned.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        
        // Replace list start tags with newlines and bullets/numbers
        cleaned = cleaned.replacingOccurrences(of: "<li>", with: "\n• ", options: [.caseInsensitive, .regularExpression])
        
        // Strip all remaining HTML tags
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode common HTML entities
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#8217;": "'",
            "&#8220;": "\"",
            "&#8221;": "\"",
            "&#8211;": "-",
            "&#8212;": "—"
        ]
        for (entity, replacement) in entities {
            cleaned = cleaned.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        
        // Clean up excessive newlines and spaces
        cleaned = cleaned.replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        // Remove leading/trailing whitespace and dots that are just separators
        cleaned = cleaned.replacingOccurrences(of: "\n\\.\n", with: "\n", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^\\.\n", with: "", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseDuration(_ durationString: String) -> TimeInterval? {
        let components = durationString.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        let minutes = Double(components[components.count - 2]) ?? 0
        let seconds = Double(components[components.count - 1]) ?? 0
        
        if components.count == 3 {
            let hours = Double(components[0]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        } else {
            return minutes * 60 + seconds
        }
    }
}

// MARK: - Sheet Content

extension RSSUploadView {
    
    @ViewBuilder
    private var editSheetContent: some View {
        if let editingIndex = editingEpisodeIndex {
            let episodeData = getEpisodeData(for: editingIndex)
            let episode = episodeData.episode
            let episodeSource = episodeData.source
            
            if let validEpisode = episode {
                let editedEpisode = editedEpisodes[String(editingIndex)] ?? EditedEpisode(from: validEpisode)
                NavigationView {
                    EpisodeEditView(
                        episode: validEpisode,
                        editedEpisode: editedEpisode
                    ) { savedEpisode in
                        editedEpisodes[String(editingIndex)] = savedEpisode
                        showingEditSheet = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingEditSheet = false
                            }
                        }
                    }
                }
                .onAppear {
                    print("🎬 SHEET_SUCCESS: Loading edit view for episode \(editingIndex) from \(episodeSource)")
                }
            } else {
                VStack(spacing: 16) {
                    Text("Error: Could not load episode for editing")
                        .foregroundColor(.red)
                    Text("COPY_THIS: editingIndex=\(editingIndex), source=\(episodeSource), newEpisodesCount=\(newEpisodesFound.count), rssDataCount=\(rssData?.episodes.count ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    Button("Close") {
                        showingEditSheet = false
                        editingEpisodeIndex = nil
                    }
                }
                .padding()
                .onAppear {
                    print("🎬 SHEET_ERROR: Failed to load episode")
                    print("🎬 SHEET_ERROR: editingIndex=\(editingIndex)")
                    print("🎬 SHEET_ERROR: episodeSource=\(episodeSource)")
                    print("🎬 SHEET_ERROR: newEpisodesFound.count=\(newEpisodesFound.count)")
                    print("🎬 SHEET_ERROR: rssData episodes count=\(rssData?.episodes.count ?? 0)")
                }
            }
        } else {
            VStack(spacing: 16) {
                Text("Error: No episode index selected")
                    .foregroundColor(.red)
                Button("Close") {
                    showingEditSheet = false
                    editingEpisodeIndex = nil
                }
            }
            .padding()
        }
    }
    
    // MARK: - Individual Feed Browsing
    
    @ViewBuilder
    private var individualFeedBrowsingView: some View {
        NavigationView {
            Group {
                if let feedData = individualFeedData {
                    individualFeedContentView(feedData)
                } else {
                    // Show loading state when individual feed data is nil
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        
                        VStack(spacing: 8) {
                            Text("Loading RSS Feed...")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if let subscription = selectedSubscription {
                                Text(subscription.feedTitle)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            
                            Text("Fetching latest episodes...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Episodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        showingIndividualFeed = false
                        individualFeedData = nil
                        selectedSubscription = nil
                        individualFeedSelectedEpisodes.removeAll()
                        isUploadingFromIndividualFeed = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func individualFeedContentView(_ feedData: RSSFeedData) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Feed header with image
                VStack(spacing: 16) {
                    // RSS Feed Image
                    AsyncImage(url: URL(string: feedData.channelImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 8) {
                        Text(feedData.channelTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if !feedData.channelDescription.isEmpty {
                            Text(feedData.channelDescription)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("Total Episodes: \(feedData.episodes.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color("accentColor"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                
                // Selection controls and upload button
                if !feedData.episodes.isEmpty {
                    VStack(spacing: 16) {
                        HStack {
                            Button(action: {
                                // Select only new episodes (not already uploaded)
                                individualFeedSelectedEpisodes = Set(feedData.episodes.indices.compactMap { index in
                                    let episode = feedData.episodes[index]
                                    return isEpisodeNew(episode, cachedGuids: selectedSubscriptionImportedGuids) ? String(index) : nil
                                })
                            }) {
                                Text("Select All")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                            }
                            
                            Spacer()
                            
                            if !individualFeedSelectedEpisodes.isEmpty {
                                Button(action: {
                                    individualFeedSelectedEpisodes.removeAll()
                                }) {
                                    Text("Deselect All")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(individualFeedSelectedEpisodes.count) selected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Upload button at the top
                        if !individualFeedSelectedEpisodes.isEmpty {
                            Button(action: {
                                uploadSelectedFromIndividualFeed()
                            }) {
                                HStack {
                                    if isUploadingFromIndividualFeed {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                        Text("Uploading...")
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Upload \(individualFeedSelectedEpisodes.count) Episodes")
                                    }
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("accentColor"))
                                        .shadow(color: Color("accentColor").opacity(0.25), radius: 8, x: 0, y: 4)
                                )
                            }
                            .disabled(isUploadingFromIndividualFeed || isLoading)
                        }
                        
                        // Progress bar when uploading
                        if isUploadingFromIndividualFeed {
                            VStack(spacing: 12) {
                                Text("Uploading Episodes...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                ProgressView(value: uploadProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: Color("accentColor")))
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                                
                                Text("\(Int(uploadProgress * 100))% Complete")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Episodes list with selection
                VStack(spacing: 12) {
                    ForEach(Array(feedData.episodes.enumerated()), id: \.element.audioURL) { index, episode in
                        individualFeedEpisodeRow(episode: episode, index: index)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    @ViewBuilder
    private func rssEpisodeRow(episode: RSSEpisode, index: Int) -> some View {
        let isNewEpisode = isEpisodeNew(episode, cachedGuids: matchingSubscriptionImportedGuids)
        let indexString = String(index)
        let hasEdits = editedEpisodes[indexString] != nil
        let hasValidationWarnings = !episode.validationWarnings.isEmpty
        
        // Use edited data if available, otherwise use original
        let displayTitle = editedEpisodes[indexString]?.title ?? episode.title
        let displayDescription = editedEpisodes[indexString]?.description ?? episode.description
        
        HStack(spacing: 12) {
            // Selection button
            Button(action: {
                // Only allow selection if episode is new
                guard isNewEpisode else { return }
                
                if selectedEpisodes.contains(indexString) {
                    selectedEpisodes.remove(indexString)
                } else {
                    selectedEpisodes.insert(indexString)
                }
            }) {
                Image(systemName: selectedEpisodes.contains(indexString) ? "checkmark.circle.fill" : (isNewEpisode ? "circle" : "checkmark.circle.fill"))
                    .font(.system(size: 24))
                    .foregroundColor(isNewEpisode ? (selectedEpisodes.contains(indexString) ? Color("accentColor") : .gray) : .gray)
            }
            .disabled(!isNewEpisode)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isNewEpisode ? .primary : .secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // Edit button for new episodes
                    if isNewEpisode {
                        NavigationLink(destination: 
                            EpisodeEditView(
                                episode: episode,
                                editedEpisode: editedEpisodes[indexString] ?? EditedEpisode(from: episode)
                            ) { savedEpisode in
                                editedEpisodes[indexString] = savedEpisode
                            }
                        ) {
                            HStack(spacing: 4) {
                                Image(systemName: hasEdits ? "pencil.circle.fill" : "pencil.circle")
                                    .font(.system(size: 16))
                                if hasEdits {
                                    Text("Edited")
                                        .font(.system(size: 10, weight: .medium))
                                }
                            }
                            .foregroundColor(hasEdits ? Color("accentColor") : .blue)
                        }
                    }
                    
                    // Validation warning indicator
                    if hasValidationWarnings && isNewEpisode {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    
                    // New/Uploaded indicator
                    if isNewEpisode {
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    } else {
                        Text("UPLOADED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.gray)
                            )
                    }
                }
                
                if !displayDescription.isEmpty {
                    Text(displayDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Validation warnings
                if hasValidationWarnings && isNewEpisode {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(episode.validationWarnings, id: \.self) { warning in
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text(warning)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Text(formatDate(episode.pubDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isNewEpisode ? (selectedEpisodes.contains(indexString) ? Color("accentColor").opacity(0.1) : Color(.systemBackground)) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isNewEpisode && selectedEpisodes.contains(indexString) ? Color("accentColor") : Color.clear, lineWidth: 1.5)
        )
        .opacity(isNewEpisode ? 1.0 : 0.6)
    }
    
    @ViewBuilder
    private func individualFeedEpisodeRow(episode: RSSEpisode, index: Int) -> some View {
        let isNewEpisode = isEpisodeNew(episode, cachedGuids: selectedSubscriptionImportedGuids)
        let indexString = String(index)
        let hasEdits = editedEpisodes[indexString] != nil
        let hasValidationWarnings = !episode.validationWarnings.isEmpty
        
        // Use edited data if available, otherwise use original
        let displayTitle = editedEpisodes[indexString]?.title ?? episode.title
        let displayDescription = editedEpisodes[indexString]?.description ?? episode.description
        
        HStack(spacing: 12) {
            // Selection button
            Button(action: {
                // Only allow selection if episode is new
                guard isNewEpisode else { return }
                
                if individualFeedSelectedEpisodes.contains(indexString) {
                    individualFeedSelectedEpisodes.remove(indexString)
                } else {
                    individualFeedSelectedEpisodes.insert(indexString)
                }
            }) {
                Image(systemName: getSelectionIcon(for: index, isNew: isNewEpisode))
                    .font(.system(size: 24))
                    .foregroundColor(getSelectionColor(for: index, isNew: isNewEpisode))
            }
            .disabled(!isNewEpisode)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // Edit button for new episodes
                    if isNewEpisode {
                        NavigationLink(destination: 
                            EpisodeEditView(
                                episode: episode,
                                editedEpisode: editedEpisodes[indexString] ?? EditedEpisode(from: episode)
                            ) { savedEpisode in
                                editedEpisodes[indexString] = savedEpisode
                            }
                        ) {
                            HStack(spacing: 4) {
                                Image(systemName: hasEdits ? "pencil.circle.fill" : "pencil.circle")
                                    .font(.system(size: 16))
                                if hasEdits {
                                    Text("Edited")
                                        .font(.system(size: 10, weight: .medium))
                                }
                            }
                            .foregroundColor(hasEdits ? Color("accentColor") : .blue)
                        }
                    }
                    
                    // Validation warning indicator
                    if hasValidationWarnings && isNewEpisode {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    
                    // New/Uploaded indicator
                    if isNewEpisode {
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    } else {
                        Text("UPLOADED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.gray)
                            )
                        }
                    }
                    
                    if !displayDescription.isEmpty {
                        Text(displayDescription)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Validation warnings
                    if hasValidationWarnings && isNewEpisode {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(episode.validationWarnings, id: \.self) { warning in
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                    Text(warning)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.orange)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Text(formatDate(episode.pubDate))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(getRowBackgroundColor(for: index, isNew: isNewEpisode))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .opacity(isNewEpisode ? 1.0 : 0.6) // Dim uploaded episodes
    }
    
    // MARK: - Helper Functions
    
    private func getEpisodeData(for editingIndex: Int) -> (episode: RSSEpisode?, source: String) {
        if showNewEpisodePreview && editingIndex < newEpisodesFound.count {
            return (newEpisodesFound[editingIndex], "newEpisodes")
        } else if showingIndividualFeed, let feedData = individualFeedData, editingIndex < feedData.episodes.count {
            return (feedData.episodes[editingIndex], "individualFeed")
        } else if let rssData = rssData, editingIndex < rssData.episodes.count {
            return (rssData.episodes[editingIndex], "rssData")
        } else {
            return (nil, "unknown")
        }
    }
    
    private func loadIndividualFeed(_ subscription: RSSSubscription) {
        showingIndividualFeed = true
        individualFeedData = nil // Clear previous data to trigger loading state
        
        Task {
            do {
                guard let url = URL(string: subscription.feedUrl) else {
                    throw RSSImportError.invalidURL
                }
                
                guard let subscriptionId = subscription.id else {
                    throw RSSImportError.invalidSubscription
                }
                
                // Load feed data and imported GUIDs in parallel
                async let feedDataTask: RSSFeedData = {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let parser = RSSParser()
                    return try parser.parse(data: data)
                }()
                
                async let importedGuidsTask = rssSubscriptionService.getImportedEpisodeGuids(
                    for: subscriptionId,
                    userId: user.uid
                )
                
                let (feedData, importedGuids) = try await (feedDataTask, importedGuidsTask)
                
                await MainActor.run {
                    self.individualFeedData = feedData
                    self.selectedSubscriptionImportedGuids = importedGuids
                }
                
            } catch {
                await MainActor.run {
                    self.individualFeedData = nil
                    self.selectedSubscriptionImportedGuids = []
                    showError("Failed to load RSS feed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func isEpisodeNew(_ episode: RSSEpisode, cachedGuids: Set<String>) -> Bool {
        let episodeGuid = createEpisodeGuid(from: episode)
        return !cachedGuids.contains(episodeGuid)
    }
    
    private func uploadSelectedFromIndividualFeed() {
        guard let feedData = individualFeedData,
              let subscription = selectedSubscription,
              !individualFeedSelectedEpisodes.isEmpty else { return }
        
        isUploadingFromIndividualFeed = true
        
        Task {
            var successfulUploads = 0 // Declared outside do-catch for error handler access
            
            do {
                // Get selected episodes
                let selectedIndices = individualFeedSelectedEpisodes.compactMap { Int($0) }.sorted()
                let selectedEpisodes = selectedIndices.compactMap { index in
                    index < feedData.episodes.count ? feedData.episodes[index] : nil
                }
                
                var uploadedGuids: [String] = []
                
                // Upload artwork
                await MainActor.run { uploadProgress = 0.1 }
                let thumbnailUrl: String
                if let imageUrl = subscription.feedImageURL {
                    thumbnailUrl = try await uploadPodcastArtwork(from: imageUrl)
                } else {
                    thumbnailUrl = try await uploadPodcastArtwork(from: nil)
                }
                
                // Process episodes with edits applied
                var uploadedPods: [Pod] = []
                var failedEpisodes: [(episode: RSSEpisode, error: String)] = []
                
                for (processedIndex, episode) in selectedEpisodes.enumerated() {
                    do {
                        let originalIndex = selectedIndices[processedIndex]
                        let indexString = String(originalIndex)
                        
                        // Apply edits if they exist
                        var episodeToUpload = episode
                        if let edited = editedEpisodes[indexString] {
                            print("📝 [Upload] Applying edits to episode: \(episode.title)")
                            // Apply the edits by creating a modified episode
                            episodeToUpload = RSSEpisode(
                                title: edited.title,
                                description: edited.description,
                                audioURL: episode.audioURL,
                                pubDate: episode.pubDate,
                                duration: episode.duration,
                                fileSize: episode.fileSize,
                                mimeType: episode.mimeType,
                                keywords: edited.keywords.isEmpty ? episode.keywords : edited.keywords
                            )
                        }
                        
                        // Validate before uploading
                        guard episodeToUpload.isValid else {
                            let validationErrors = [
                                episodeToUpload.sanitizedTitle.isEmpty ? "Title is empty" : nil,
                                episodeToUpload.sanitizedTitle.count > 200 ? "Title exceeds 200 characters (\(episodeToUpload.sanitizedTitle.count))" : nil,
                                episodeToUpload.audioURL.isEmpty ? "No audio URL" : nil,
                                !episodeToUpload.isValidAudioURL ? "Invalid audio URL format" : nil
                            ].compactMap { $0 }.joined(separator: ", ")
                            
                            throw NSError(domain: "RSSUpload", code: 1, userInfo: [
                                NSLocalizedDescriptionKey: "Validation failed: \(validationErrors). Please edit this episode to fix these issues."
                            ])
                        }
                        
                        // Create GUID from ORIGINAL episode (before edits) for tracking
                        let episodeGuid = createEpisodeGuid(from: episode)
                        
                        // Create pod with edited data but original GUID and stream ID
                        let pod = try await createPodFromRSSEpisode(episodeToUpload, thumbnailUrl: thumbnailUrl, episodeIndex: originalIndex, originalGuid: episodeGuid, streamId: subscription.streamId)
                        uploadedPods.append(pod)
                        successfulUploads += 1
                        
                        uploadedGuids.append(episodeGuid)
                        
                    } catch {
                        let errorMessage = error.localizedDescription
                        print("❌ Failed to process episode '\(episode.title)': \(errorMessage)")
                        failedEpisodes.append((episode: episode, error: errorMessage))
                        failedEpisodeDetails.append((title: episode.title, error: errorMessage))
                    }
                    
                    let progress = 0.1 + (0.7 * Double(processedIndex + 1) / Double(selectedEpisodes.count))
                    await MainActor.run { uploadProgress = progress }
                }
                
                // Save to Firebase
                await MainActor.run { uploadProgress = 0.8 }
                try await savePodsToFirebaseWithRetry(&uploadedPods)
                
                // Update subscription tracking
                if let subscriptionId = subscription.id {
                    try await rssSubscriptionService.addImportedEpisodeGuids(uploadedGuids, to: subscriptionId, for: user.uid)
                    
                    // Also add episodes to RSS stream
                    if let streamId = subscription.streamId {
                        let podIds = uploadedPods.compactMap { $0.id }
                        print("🔵 [Upload] Subscription has streamId: \(streamId)")
                        print("🔵 [Upload] Uploaded \(uploadedPods.count) pods")
                        print("🔵 [Upload] After save - Pod IDs: \(podIds)")
                        
                        if !podIds.isEmpty {
                            try await rssStreamService.addEpisodesToStream(podIds, to: streamId)
                        } else {
                            print("⚠️ [Upload] No pod IDs found - pods may not have been saved yet!")
                        }
                    } else {
                        print("⚠️ [Upload] Subscription has no streamId!")
                    }
                    
                    // Refresh the subscription to get updated GUIDs
                    let updatedSubscription = try await rssSubscriptionService.getSubscription(id: subscriptionId, for: user.uid)
                    await MainActor.run {
                        // Update the selected subscription with fresh data
                        self.selectedSubscription = updatedSubscription
                        
                        // Also update it in the userSubscriptions array
                        if let index = self.userSubscriptions.firstIndex(where: { $0.id == subscriptionId }) {
                            self.userSubscriptions[index] = updatedSubscription
                        }
                    }
                }
                
                await MainActor.run {
                    uploadProgress = 1.0
                    isUploadingFromIndividualFeed = false
                    uploadedEpisodeCount = successfulUploads
                    
                    // Clear selections but keep the browser open with updated data
                    individualFeedSelectedEpisodes.removeAll()
                    
                    // Show appropriate alert based on results
                    if failedEpisodes.isEmpty {
                        // Complete success
                        showSuccessAlert = true
                    } else if successfulUploads > 0 {
                        // Partial success - show detailed failure info
                        showPartialSuccessAlert = true
                    } else {
                        // Complete failure
                        showError("All episodes failed to upload. Common reasons:\n\n• Title or description too long (use Edit to fix)\n• Invalid audio URL\n• Network issues\n\nTap 'Edit' next to each episode to review and fix validation warnings before trying again.")
                    }
                }
                
            } catch {
                await MainActor.run {
                    isUploadingFromIndividualFeed = false
                    if successfulUploads > 0 {
                        showError("Uploaded \(successfulUploads) episode(s) successfully, but failed to complete:\n\n\(error.localizedDescription)\n\nThe uploaded episodes have been saved.")
                    } else {
                        showError("Failed to upload episodes:\n\n\(error.localizedDescription)\n\nPlease check:\n• Network connection\n• Episode validation (tap Edit)\n• Title/description length")
                    }
                }
            }
        }
    }
    
    // MARK: - RSS Subscription Functions
    
    /// Loads user's RSS subscriptions on view appear
    private func loadUserSubscriptions() {
        isLoadingSubscriptions = true
        Task {
            do {
                let subscriptions = try await rssSubscriptionService.getActiveSubscriptions(for: user.uid)
                await MainActor.run {
                    self.userSubscriptions = subscriptions
                    self.isLoadingSubscriptions = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSubscriptions = false
                    showError("Failed to load your RSS subscriptions: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Creates a subscription and shows episode preview
    private func subscribeAndViewEpisodes() {
        guard let rssData = subscriptionChoiceData else { return }
        
        Task {
            do {
                let subscription = RSSSubscription.create(
                    from: rssData,
                    feedUrl: rssURL,
                    userId: user.uid
                )
                
                let createdSubscription = try await rssSubscriptionService.createSubscription(subscription, rssData: rssData, for: user.uid)
                
                // Load imported GUIDs for the new subscription (should be empty for new subscription)
                let importedGuids = if let subscriptionId = createdSubscription.id {
                    try await rssSubscriptionService.getImportedEpisodeGuids(for: subscriptionId, userId: user.uid)
                } else {
                    Set<String>()
                }
                
                await MainActor.run {
                    // Add to local array
                    self.userSubscriptions.append(createdSubscription)
                    
                    // Show episode preview
                    self.rssData = rssData
                    self.matchingSubscription = createdSubscription
                    self.matchingSubscriptionImportedGuids = importedGuids
                    self.showSubscriptionChoice = false
                    self.showEpisodePreview = true
                    self.subscriptionChoiceData = nil
                }
                
            } catch {
                await MainActor.run {
                    showError("Failed to create subscription: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    /// Checks all user's RSS feeds for new episodes
    private func checkAllFeedsForNewEpisodes() {
        guard !userSubscriptions.isEmpty else { return }
        
        isCheckingForNew = true
        newEpisodesFound.removeAll()
        newEpisodesWithSource.removeAll()
        selectedEpisodes.removeAll()
        selectedRSSFilter = nil // Reset filter
        
        Task {
            var allNewEpisodesWithSource: [(episode: RSSEpisode, subscription: RSSSubscription)] = []
            var hasErrors = false
            
            for subscription in userSubscriptions {
                do {
                    let newEpisodes = try await checkSubscriptionForNewEpisodes(subscription)
                    // Track which subscription each episode came from
                    let episodesWithSource = newEpisodes.map { (episode: $0, subscription: subscription) }
                    allNewEpisodesWithSource.append(contentsOf: episodesWithSource)
                    
                    // Update last checked timestamp
                    if let subscriptionId = subscription.id {
                        try await rssSubscriptionService.updateLastChecked(for: subscriptionId, userId: user.uid)
                    }
                    
                } catch {
                    print("❌ Failed to check subscription \(subscription.feedTitle): \(error.localizedDescription)")
                    hasErrors = true
                }
            }
            
            await MainActor.run {
                self.isCheckingForNew = false
                // Sort by publication date, newest first
                self.newEpisodesWithSource = allNewEpisodesWithSource.sorted { $0.episode.pubDate > $1.episode.pubDate }
                self.newEpisodesFound = self.newEpisodesWithSource.map { $0.episode }
                
                if allNewEpisodesWithSource.isEmpty && !hasErrors {
                    // No new episodes found
                    self.showNewEpisodePreview = true
                } else if !allNewEpisodesWithSource.isEmpty {
                    // New episodes found
                    self.showNewEpisodePreview = true
                } else if hasErrors {
                    showError("Some RSS feeds could not be checked. Please try again.")
                }
                
                // Reload subscriptions to update "last checked" times
                loadUserSubscriptions()
            }
        }
    }
    
    /// Checks a single subscription for new episodes using subcollection
    private func checkSubscriptionForNewEpisodes(_ subscription: RSSSubscription) async throws -> [RSSEpisode] {
        guard let url = URL(string: subscription.feedUrl) else {
            throw RSSImportError.invalidURL
        }
        
        guard let subscriptionId = subscription.id else {
            throw RSSImportError.invalidSubscription
        }
        
        // Fetch and parse RSS feed
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = RSSParser()
        let rssData = try parser.parse(data: data)
        
        // Fetch all imported GUIDs from subcollection (one query, then in-memory checks)
        let importedGuids = try await rssSubscriptionService.getImportedEpisodeGuids(
            for: subscriptionId,
            userId: user.uid
        )
        
        print("📱 [RSSUploadView] Checking \(rssData.episodes.count) episodes against \(importedGuids.count) imported GUIDs")
        
        // Filter for new episodes
        var newEpisodes: [RSSEpisode] = []
        
        for episode in rssData.episodes {
            // Check if episode GUID is in the imported set
            let episodeGuid = createEpisodeGuid(from: episode)
            if !importedGuids.contains(episodeGuid) {
                newEpisodes.append(episode)
            }
        }
        
        print("📱 [RSSUploadView] Found \(newEpisodes.count) new episodes")
        
        return newEpisodes
    }
    
    /// Creates a unique GUID for an episode for deduplication
    private func createEpisodeGuid(from episode: RSSEpisode) -> String {
        // IMPORTANT: Since uploaded pods will have Firebase Storage URLs (not original RSS URLs),
        // we should prefer the title+date combo for better matching during deletion
        
        // Use title + pubdate combo as primary (more reliable for deletion matching)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: episode.pubDate)
        let titleDateGuid = "\(episode.title)_\(dateString)"
        
        // Sanitize for Firestore document ID (no slashes allowed)
        let sanitized = titleDateGuid
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        
        return sanitized
    }
    
    /// Uploads selected new episodes and updates subscription tracking
    private func uploadSelectedNewEpisodes() {
        guard !selectedEpisodes.isEmpty else { return }
        
        isUploading = true
        uploadProgress = 0.0
        
        Task {
            await performNewEpisodeUpload()
        }
    }
    
    /// Performs upload of new episodes from subscription check
    private func performNewEpisodeUpload() async {
        let selectedIndices = selectedEpisodes.compactMap { Int($0) }.sorted()
        let selectedRSSEpisodes = selectedIndices.compactMap { index in
            index < newEpisodesFound.count ? newEpisodesFound[index] : nil
        }
        
        var successfulUploads = 0
        var failedEpisodes: [(episode: RSSEpisode, error: String)] = []
        var uploadedGuids: [String] = []
        
        do {
            // Upload artwork - try to get from any subscription that has one
            await MainActor.run { uploadProgress = 0.1 }
            let thumbnailUrl: String
            let firstSubscriptionWithImage = userSubscriptions.first { $0.feedImageURL != nil }
            if let imageUrl = firstSubscriptionWithImage?.feedImageURL {
                thumbnailUrl = try await uploadPodcastArtwork(from: imageUrl)
            } else {
                // Fallback to a default or use first episode thumbnail
                thumbnailUrl = try await uploadPodcastArtwork(from: nil)
            }
            
            // Process selected episodes with individual error handling
            var uploadedPods: [Pod] = []
            
            for (processedIndex, episode) in selectedRSSEpisodes.enumerated() {
                do {
                    let originalIndex = selectedIndices[processedIndex]
                    
                    // Find which subscription (and stream) this episode came from
                    let streamId = newEpisodesWithSource.first(where: { $0.episode.audioURL == episode.audioURL })?.subscription.streamId
                    
                    let pod = try await createPodFromRSSEpisode(episode, thumbnailUrl: thumbnailUrl, episodeIndex: originalIndex, streamId: streamId)
                    uploadedPods.append(pod)
                    successfulUploads += 1
                    
                    // Track GUID for subscription deduplication
                    let episodeGuid = createEpisodeGuid(from: episode)
                    uploadedGuids.append(episodeGuid)
                    
                } catch {
                    failedEpisodes.append((episode: episode, error: error.localizedDescription))
                    failedEpisodeDetails.append((title: episode.title, error: error.localizedDescription))
                    print("❌ Failed to process episode '\(episode.title)': \(error.localizedDescription)")
                }
                
                // Update progress
                let progress = 0.1 + (0.7 * Double(processedIndex + 1) / Double(selectedRSSEpisodes.count))
                await MainActor.run { uploadProgress = progress }
            }
            
            // Only proceed if we have valid pods to upload
            guard !uploadedPods.isEmpty else {
                await MainActor.run {
                    isUploading = false
                    showError("All selected episodes failed validation. Please check episode data and try again.")
                }
                return
            }
            
            // Save to Firebase with retry logic
            await MainActor.run { uploadProgress = 0.8 }
            try await savePodsToFirebaseWithRetry(&uploadedPods)
            
            // Update subscription tracking with uploaded episode GUIDs
            try await updateSubscriptionTracking(with: uploadedGuids, pods: uploadedPods, from: selectedRSSEpisodes)
            
            // Complete
            await MainActor.run {
                uploadProgress = 1.0
                isUploading = false
                uploadedEpisodeCount = successfulUploads
                
                if failedEpisodes.isEmpty {
                    showSuccessAlert = true
                } else {
                    showPartialSuccessAlert = true
                }
                
                // Remove successfully uploaded episodes from newEpisodesFound
                // Sort selected indices in descending order to avoid index shifting issues
                let sortedSelectedIndices = selectedIndices.sorted(by: >)
                for index in sortedSelectedIndices {
                    if index < newEpisodesFound.count {
                        // Check if this episode was successfully uploaded
                        let episode = newEpisodesFound[index]
                        let episodeGuid = createEpisodeGuid(from: episode)
                        if uploadedGuids.contains(episodeGuid) {
                            newEpisodesFound.remove(at: index)
                        }
                    }
                }
                
                // Clear selected episodes
                selectedEpisodes.removeAll()
                
                // If no episodes remain, close the preview
                if newEpisodesFound.isEmpty {
                    showNewEpisodePreview = false
                }
                
                // Reload subscriptions to update tracking
                loadUserSubscriptions()
            }
            
        } catch {
            await MainActor.run {
                isUploading = false
                showError("Upload failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Updates subscription tracking with newly uploaded episode GUIDs and adds to RSS streams
    private func updateSubscriptionTracking(with uploadedGuids: [String], pods uploadedPods: [Pod], from episodes: [RSSEpisode]) async throws {
        // Group uploaded GUIDs and pod IDs by their source subscription
        var subscriptionToGuids: [String: [String]] = [:]
        var subscriptionToPods: [String: [String]] = [:]
        
        for (index, episode) in episodes.enumerated() {
            guard index < uploadedGuids.count, index < uploadedPods.count else { continue }
            
            // Find which subscription this episode came from using newEpisodesWithSource
            if let episodeWithSource = newEpisodesWithSource.first(where: { $0.episode.audioURL == episode.audioURL }),
               let subscriptionId = episodeWithSource.subscription.id {
                
                if subscriptionToGuids[subscriptionId] == nil {
                    subscriptionToGuids[subscriptionId] = []
                }
                subscriptionToGuids[subscriptionId]?.append(uploadedGuids[index])
                
                if subscriptionToPods[subscriptionId] == nil {
                    subscriptionToPods[subscriptionId] = []
                }
                if let podId = uploadedPods[index].id {
                    subscriptionToPods[subscriptionId]?.append(podId)
                }
            }
        }
        
        // Update each subscription with its relevant GUIDs and add pods to streams
        for (subscriptionId, guids) in subscriptionToGuids {
            if !guids.isEmpty {
                try await rssSubscriptionService.addImportedEpisodeGuids(guids, to: subscriptionId, for: user.uid)
                
                // Add episodes to RSS stream
                let updatedSubscription = try await rssSubscriptionService.getSubscription(id: subscriptionId, for: user.uid)
                if let streamId = updatedSubscription.streamId,
                   let podIds = subscriptionToPods[subscriptionId],
                   !podIds.isEmpty {
                    print("🔵 [UpdateTracking] Adding \(podIds.count) pods to stream: \(streamId)")
                    print("🔵 [UpdateTracking] Pod IDs: \(podIds)")
                    try await rssStreamService.addEpisodesToStream(podIds, to: streamId)
                }
                
                await MainActor.run {
                    // Update it in the userSubscriptions array
                    if let index = self.userSubscriptions.firstIndex(where: { $0.id == subscriptionId }) {
                        self.userSubscriptions[index] = updatedSubscription
                    }
                }
            }
        }
    }
    
    /// Removes an RSS subscription
    private func removeSubscription(_ subscription: RSSSubscription) async {
        guard let subscriptionId = subscription.id else { return }
        
        do {
            try await rssSubscriptionService.deleteSubscription(id: subscriptionId, for: user.uid)
            
            await MainActor.run {
                // Remove from local array
                self.userSubscriptions.removeAll { $0.id == subscriptionId }
                self.subscriptionToRemove = nil
            }
            
        } catch {
            await MainActor.run {
                showError("Failed to remove subscription: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Finds a subscription that matches the given RSS feed data (both active and inactive)
    private func findSubscriptionForFeed(_ rssData: RSSFeedData) async -> RSSSubscription? {
        // First check active subscriptions (already loaded)
        if let activeSubscription = userSubscriptions.first(where: { subscription in
            subscription.matchesFeed(title: rssData.channelTitle, description: rssData.channelDescription)
        }) {
            return activeSubscription
        }
        
        // If not found in active, check for inactive subscriptions in the database
        do {
            // Use the RSS subscription service to find by URL (more reliable than title matching)
            let feedUrl = rssURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return try await rssSubscriptionService.findExistingSubscription(feedUrl: feedUrl, for: user.uid)
        } catch {
            print("❌ Failed to check for inactive subscriptions: \(error)")
            return nil
        }
    }
}

// MARK: - Error Types
enum RSSImportError: Error, LocalizedError {
    case invalidURL
    case parseError
    case noData
    case missingArtwork
    case unsupportedFormat
    case invalidEpisodeData(String)
    case invalidPodData(String)
    case uploadFailed
    case networkError(String)
    case invalidSubscription
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid RSS URL"
        case .parseError:
            return "Failed to parse RSS feed"
        case .noData:
            return "No episode data found"
        case .missingArtwork:
            return "Could not download podcast artwork"
        case .unsupportedFormat:
            return "Unsupported RSS format. Currently only iTunes-compatible RSS 2.0 feeds are supported. We'll add support for other formats like Spotify in future updates."
        case .invalidEpisodeData(let details):
            return "Invalid episode data: \(details)"
        case .invalidPodData(let details):
            return "Invalid pod data: \(details)"
        case .uploadFailed:
            return "Failed to upload episode to server"
        case .networkError(let details):
            return "Network error: \(details)"
        case .invalidSubscription:
            return "Invalid RSS subscription"
        }
    }
}

// MARK: - Episode Edit View
struct EpisodeEditView: View {
    let episode: RSSEpisode
    @State var editedEpisode: EditedEpisode
    let onSave: (EditedEpisode) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var keywordInput = ""
    @FocusState private var isKeywordInputFocused: Bool
    
    init(episode: RSSEpisode, editedEpisode: EditedEpisode, onSave: @escaping (EditedEpisode) -> Void) {
        self.episode = episode
        self.onSave = onSave
        self._editedEpisode = State(initialValue: editedEpisode)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    TextField("Episode title", text: $editedEpisode.title)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        )
                }
                
                // Description Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    TextEditor(text: $editedEpisode.description)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        )
                }
                
                // Keywords Section
                keywordsSection
                
                // Original Episode Info Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original Episode Info")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date: \(formatDate(episode.pubDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let duration = episode.duration {
                            Text("Duration: \(formatDuration(duration))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text("Audio URL: \(episode.audioURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationTitle("Edit Episode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    onSave(editedEpisode)
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
                .disabled(editedEpisode.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    // MARK: - Keywords Section
    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keywords (\(editedEpisode.keywords.count)/10)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Keywords help users discover this episode. They're combined from RSS and any you add.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Keyword input field
            HStack(spacing: 12) {
                TextField("Add keywords...", text: $keywordInput)
                    .focused($isKeywordInputFocused)
                    .onSubmit {
                        addKeyword()
                    }
                    .onChange(of: keywordInput) { newValue in
                        if newValue.contains(" ") {
                            let trimmedKeyword = newValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
                            if !trimmedKeyword.isEmpty {
                                keywordInput = trimmedKeyword
                                addKeyword()
                            } else {
                                keywordInput = ""
                            }
                        }
                    }
                    .submitLabel(.return)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
            
                Button(action: addKeyword) {
                    Text("Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("accentColor"))
                        )
                }
                .disabled(keywordInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedEpisode.keywords.count >= 10)
            }
            
            // Current keywords display - stacked vertically for full width
            if !editedEpisode.keywords.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(editedEpisode.keywords.enumerated()), id: \.offset) { index, keyword in
                        HStack(spacing: 8) {
                            Text(keyword)
                                .font(.system(size: 14))
                                .fontWeight(.medium)
                                .foregroundColor(Color("accentColor"))
                                .lineLimit(1)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            Button(action: {
                                deleteKeyword(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color("accentColor"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("accentColor").opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color("accentColor"), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.top, 8)
            }
            
            if editedEpisode.keywords.count >= 10 {
                Text("Maximum of 10 keywords reached")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Keyword Management
    func addKeyword() {
        let trimmedKeyword = keywordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKeyword.isEmpty && 
           !editedEpisode.keywords.contains(trimmedKeyword) && 
           editedEpisode.keywords.count < 10 {
            editedEpisode.keywords.append(trimmedKeyword)
            keywordInput = ""
        }
    }
    
    func deleteKeyword(at index: Int) {
        if index < editedEpisode.keywords.count {
            editedEpisode.keywords.remove(at: index)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    RSSUploadView(user: User(uid: "test", username: "test", fullname: "Test User", profileImageUrl: "", email: "test@test.com", isVerified: false))
}
