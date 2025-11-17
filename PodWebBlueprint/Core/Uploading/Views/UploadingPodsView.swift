//
//  UploadingPodsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/15/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct UploadingPodsView: View {
    @ObservedObject private var uploadQueue = UploadQueueManager.shared
    @State private var showInterruptedUploadsAlert = false
    @State private var interruptedUploads: [UploadItem] = []
    @State private var refreshTimer: Timer?
    @State private var showQueueFullAlert = false
    @State private var queueFullMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // RSS Upload Section - Always at top, prioritized
                rssUploadSection
                
                // Device Upload Section - Bottom half, secondary
                deviceUploadSection
            }
            .padding(.bottom, 100) // Tab bar spacing
        }
        .onAppear {
                print("📱 UploadingPodsView appeared. Active uploads: \(uploadQueue.activeUploads.count), Failed uploads: \(uploadQueue.failedUploads.count)")
                
                // Start a timer to force UI updates every second when there are active uploads
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    if !uploadQueue.activeUploads.isEmpty {
                        // Force UI refresh by triggering objectWillChange
                        uploadQueue.objectWillChange.send()
                    }
                }
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InterruptedUploadsDetected"))) { notification in
                if let uploads = notification.userInfo?["uploads"] as? [UploadItem] {
                    interruptedUploads = uploads
                    showInterruptedUploadsAlert = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UploadsClearedDueToTermination"))) { notification in
                // Show a simple alert overlay informing the user
                let count = (notification.userInfo?["count"] as? Int) ?? 0
                interruptedUploads = []
                showInterruptedUploadsAlert = true
                print("⚠️ \(count) uploads were cleared because the app was fully closed.")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UploadQueueFull"))) { notification in
                if let userInfo = notification.userInfo,
                   let maxSize = userInfo["maxSize"] as? Int,
                   let currentCount = userInfo["currentCount"] as? Int {
                    queueFullMessage = "Upload queue is full (\(currentCount)/\(maxSize)). Please wait for uploads to complete before adding more."
                    showQueueFullAlert = true
                }
            }
            .alert("Queue Full", isPresented: $showQueueFullAlert) {
                Button("OK") { showQueueFullAlert = false }
            } message: {
                Text(queueFullMessage)
            }
            .overlay(
                Group {
                    if showInterruptedUploadsAlert {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showInterruptedUploadsAlert = false
                            }
                        
                        InterruptedUploadsAlert(
                            uploads: interruptedUploads,
                            onRetryAll: {
                                retryAllInterruptedUploads()
                                showInterruptedUploadsAlert = false
                            },
                            onDismiss: {
                                showInterruptedUploadsAlert = false
                            }
                        )
                        .padding()
                    }
                }
            )
    }
    
    // MARK: - RSS Upload Section (Top Priority)
    
    private var rssUploadSection: some View {
        VStack(spacing: 20) {
            // Header with emphasis on RSS being preferred
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RSS Import")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Recommended")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                    }
                    
                    Spacer()
                    
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text("Import multiple episodes at once from your podcast RSS feed. Much faster than uploading individual files!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            // RSS Upload Button - Primary CTA
            NavigationLink {
                if let currentUser = Auth.auth().currentUser {
                    let user = User(
                        uid: currentUser.uid,
                        username: currentUser.displayName ?? "User",
                        fullname: currentUser.displayName ?? "User",
                        profileImageUrl: currentUser.photoURL?.absoluteString ?? "",
                        email: currentUser.email ?? "",
                        isVerified: false
                    )
                    RSSUploadView(user: user)
                } else {
                    Text("Sign in to upload")
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from RSS Feed")
                            .font(.system(size: 18, weight: .bold))
                        Text("Upload multiple episodes instantly")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.9)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .opacity(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.85)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color("accentColor").opacity(0.3), radius: 15, x: 0, y: 8)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("accentColor").opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Device Upload Section (Secondary)
    
    private var deviceUploadSection: some View {
        VStack(spacing: 20) {
            // Header for device uploads
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Individual Upload")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("Upload Queue")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Queue indicator
                    HStack(spacing: 4) {
                        Text("\(uploadQueue.totalQueueCount)")
                            .font(.headline)
                            .foregroundColor(uploadQueue.isQueueFull ? .red : .primary)
                        Text("/")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("\(UploadQueueManager.maxQueueSize)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(uploadQueue.isQueueFull ? Color.red : (uploadQueue.totalQueueCount > 0 ? Color.orange : Color.green))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: uploadQueue.isQueueFull)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                Text("For individual episodes from device storage. Use RSS import above for faster bulk uploads.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            // Device Upload Button - Secondary CTA
            if uploadQueue.canAddUpload {
                NavigationLink {
                    if let currentUser = Auth.auth().currentUser {
                        let user = User(
                            uid: currentUser.uid,
                            username: currentUser.displayName ?? "User",
                            fullname: currentUser.displayName ?? "User",
                            profileImageUrl: currentUser.photoURL?.absoluteString ?? "",
                            email: currentUser.email ?? "",
                            isVerified: false
                        )
                        UploadPodView(user: user)
                    } else {
                        Text("Sign in to upload")
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18, weight: .medium))
                        Text("Upload from Device")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14))
                            .opacity(0.6)
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("accentColor").opacity(0.5), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color("accentColor").opacity(0.05))
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture())
            } else {
                Button {
                    queueFullMessage = "Upload queue is full (\(uploadQueue.totalQueueCount)/\(UploadQueueManager.maxQueueSize)). Please wait for uploads to complete."
                    showQueueFullAlert = true
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 18, weight: .medium))
                            Text("Queue Full (\(uploadQueue.totalQueueCount)/\(UploadQueueManager.maxQueueSize))")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text("Wait for uploads to complete")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(true)
            }
            
            // Upload Queue Content
            if !uploadQueue.activeUploads.isEmpty || !uploadQueue.failedUploads.isEmpty {
                uploadsListContent
            } else {
                emptyQueueView
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Uploads List Content (for device uploads)
    
    private var uploadsListContent: some View {
        VStack(spacing: 16) {
            // Active uploads section
            if !uploadQueue.activeUploads.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Active Uploads")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    ForEach(uploadQueue.activeUploads) { upload in
                        UploadProgressRow(upload: upload, uploadQueue: uploadQueue)
                    }
                }
            }
            
            // Failed uploads section
            if !uploadQueue.failedUploads.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Failed Uploads")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    
                    ForEach(uploadQueue.failedUploads) { upload in
                        UploadFailedRow(upload: upload, uploadQueue: uploadQueue)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Queue View
    
    private var emptyQueueView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
                .opacity(0.6)
            
            Text("Upload queue is empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Use RSS import above for multiple episodes, or upload individual files here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
    }
    
    // MARK: - Uploads List View (Legacy)
    
    private var uploadsListView: some View {
        VStack(spacing: 0) {
                // Queue Status Header - Fixed at top
                VStack(alignment: .leading, spacing: 16) {
                    // Queue capacity indicator
                    HStack {
                        Text("Upload Queue")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("\(uploadQueue.totalQueueCount)")
                                .font(.headline)
                                .foregroundColor(uploadQueue.isQueueFull ? .red : .primary)
                            Text("/")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("\(UploadQueueManager.maxQueueSize)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Circle()
                                .fill(uploadQueue.isQueueFull ? Color.red : (uploadQueue.totalQueueCount > 0 ? Color.orange : Color.green))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: uploadQueue.isQueueFull)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Upload CTA
                    VStack(alignment: .leading, spacing: 8) {
                        Text(uploadQueue.canAddUpload ? "Start a new upload" : "Queue is full")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !uploadQueue.canAddUpload {
                            Text("Wait for current uploads to complete before adding more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // CTA removed - now handled in the new layout sections above
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGroupedBackground))
                
                // Uploads Content
                VStack(spacing: 16) {
                    // Active uploads section
                    if !uploadQueue.activeUploads.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Active Uploads")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            ForEach(uploadQueue.activeUploads) { upload in
                                UploadProgressRow(upload: upload, uploadQueue: uploadQueue)
                            }
                        }
                    }
                    
                    // Failed uploads section
                    if !uploadQueue.failedUploads.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Failed Uploads")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            ForEach(uploadQueue.failedUploads) { upload in
                                UploadFailedRow(upload: upload, uploadQueue: uploadQueue)
                            }
                        }
                    }
                    
                    // Bottom padding for tab bar
                    Spacer(minLength: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    
    private func retryAllInterruptedUploads() {
        // Get current user from Firebase Auth
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No current user found for retry")
            return
        }
        
        // Create User object with current Firebase user data
        let user = User(
            uid: currentUser.uid,
            username: currentUser.displayName ?? "User",
            fullname: currentUser.displayName ?? "User",
            profileImageUrl: currentUser.photoURL?.absoluteString ?? "",
            email: currentUser.email ?? "",
            isVerified: false
        )
        
        for upload in interruptedUploads {
            uploadQueue.retryUpload(upload, user: user)
        }
    }
}


// MARK: - Upload Progress Row

struct UploadProgressRow: View {
    let upload: UploadItem
    let uploadQueue: UploadQueueManager
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern floating card container (like PodRowView)
            VStack(spacing: 16) {
                // Thumbnail section (if available)
                thumbnailSection
                
                // Upload progress section
                progressSection
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
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    
    // MARK: - Thumbnail Section
    
    private var thumbnailSection: some View {
        HStack {
            Spacer()
            if let thumbnailData = upload.thumbnailImage,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit) // Changed from scaledToFill to fit to preserve aspect ratio
                    .frame(maxHeight: 200) // Use maxHeight to allow adaptive width
                    .clipped()
                    .cornerRadius(12)
            } else {
                // Placeholder for no thumbnail
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200) // Keep fixed height for placeholder
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("No thumbnail")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    )
            }
            Spacer()
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Cancel Button
            HStack {
                Text(upload.podTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Cancel button - larger and more prominent
                Button(action: {
                    print("🛑 Cancel button tapped for: \(upload.podTitle)")
                    uploadQueue.cancelUpload(upload)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red)
                    )
                }
                .buttonStyle(PlainButtonStyle()) // Prevent row highlighting
            }
            
            // Description
            if !upload.podDescription.isEmpty {
                Text(upload.podDescription)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                // Show compression progress if compressing
                if upload.isCompressing {
                    HStack {
                        Text("Compressing... \(Int(upload.compressionProgress * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                            .id("compression-\(upload.id)-\(Int(upload.compressionProgress * 100))")
                        
                        Spacer()
                    }
                    
                    ProgressView(value: upload.compressionProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .frame(height: 6)
                        .cornerRadius(3)
                } else {
                    // Show upload progress
                    HStack {
                        Text("\(Int(upload.progress * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .id("progress-\(upload.id)-\(Int(upload.progress * 100))") // Force UI update
                    
                    Spacer()
                    
                        HStack(spacing: 8) {
                            // Duration
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(upload.formattedDuration)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                            
                            // Upload Speed
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.blue)
                                Text(upload.formattedUploadSpeed)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                            
                            // ETA
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.orange)
                                Text(upload.formattedETA)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                    }
                    
                    ProgressView(value: upload.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color("accentColor")))
                        .scaleEffect(y: 2.0) // Make progress bar thicker
                        .id("progress-bar-\(upload.id)-\(Int(upload.progress * 100))") // Force UI update
                }
            }
            
            // File Info
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(upload.formattedFileSize)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(upload.source.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Upload Completed Row

struct UploadCompletedRow: View {
    let upload: UploadItem
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(upload.podTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Uploaded \(upload.formattedDuration) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(upload.formattedFileSize)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Upload Failed Row

struct UploadFailedRow: View {
    let upload: UploadItem
    let uploadQueue: UploadQueueManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern floating card container (like PodRowView)
            VStack(spacing: 16) {
                // Thumbnail section (if available)
                thumbnailSection
                
                // Error section
                errorSection
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
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    
    // MARK: - Thumbnail Section
    
    private var thumbnailSection: some View {
        Group {
            if let thumbnailData = upload.thumbnailImage,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            } else {
                // Placeholder for no thumbnail
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
                            Image(systemName: "photo")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("No thumbnail")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Action Buttons
            HStack {
                Text(upload.podTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // Dismiss button (for failed uploads)
                    Button(action: {
                        print("🛑 Dismiss failed upload: \(upload.podTitle)")
                        uploadQueue.cancelUpload(upload)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Dismiss")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Retry button
                    Button(action: {
                        print("🔄 Retry upload: \(upload.podTitle)")
                        retryUpload()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Retry")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Description
            if !upload.podDescription.isEmpty {
                Text(upload.podDescription)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            
            // Error Message
            if let errorMessage = upload.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                )
            }
            
            // File Info
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(upload.formattedFileSize)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(upload.source.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func retryUpload() {
        // Get current user from Firebase Auth
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No current user found for retry")
            return
        }
        
        // Create User object with current Firebase user data
        let user = User(
            uid: currentUser.uid,
            username: currentUser.displayName ?? "User",
            fullname: currentUser.displayName ?? "User",
            profileImageUrl: currentUser.photoURL?.absoluteString ?? "",
            email: currentUser.email ?? "",
            isVerified: false
        )
        
        uploadQueue.retryUpload(upload, user: user)
    }
}

// MARK: - Preview

struct UploadingPodsView_Previews: PreviewProvider {
    static var previews: some View {
        UploadingPodsView()
    }
}
