import SwiftUI
import AVKit
import Kingfisher

struct MediaBar: View {
    @StateObject private var playerManager = PlayerManager.shared
    @StateObject private var mediaBarManager = MediaBarManager.shared
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isVideo: Bool = false
    
    var body: some View {
        Group {
            if let currentPod = playerManager.currentPod {
                VStack(spacing: 0) {
                    // Enhanced progress bar at the top
                    if let currentItem = playerManager.currentItem {
                        let progress = duration > 0 ? currentTime / duration : 0
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.black.opacity(0.1))
                                    .frame(height: 3)
                                
                                // Progress fill with gradient
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color("accentColor"),
                                                Color("accentColor").opacity(0.8)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progress, height: 3)
                                    .animation(.easeInOut(duration: 0.1), value: progress)
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    
                    // Main bar content with enhanced styling
                    HStack(spacing: 14) {
                        // Enhanced thumbnail with better styling
                        NavigationLink(
                            destination: PlayerView(url: URL(string: currentPod.fileUrl)!, pod: currentPod)
                        ) {
                            MediaBarThumbnail(player: playerManager.player, pod: currentPod, isVideo: $isVideo)
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Content stack: title on top, username + controls on bottom
                        VStack(spacing: 4) {
                            // Title - clickable and spans full width
                            NavigationLink(
                                destination: PlayerView(url: URL(string: currentPod.fileUrl)!, pod: currentPod)
                            ) {
                                Text(currentPod.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Bottom row: username + controls
                            HStack(spacing: 12) {
                                // Username with verified badge
                                if let username = currentPod.user?.username {
                                    HStack(spacing: 4) {
                                        Text("@\(username)")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                        
                                        // Verified badge if applicable
                                        if currentPod.user?.isVerified == true {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Play/Pause button with glass morphism
                                Button {
                                    if playerManager.isPlaying {
                                        playerManager.pause()
                                    } else {
                                        playerManager.resume()
                                    }
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
                                            .frame(width: 36, height: 36)
                                        
                                        // Icon with enhanced styling
                                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .offset(x: playerManager.isPlaying ? 0 : 1) // Slight offset for play icon
                                    }
                                }
                                .scaleEffect(playerManager.isPlaying ? 1.0 : 0.95)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: playerManager.isPlaying)
                                
                                // Close button with subtle styling
                                Button {
                                    playerManager.stop()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.05))
                                            .frame(width: 28, height: 28)
                                        
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
                .frame(maxHeight: 80)  // Maximum height for media bar to accommodate 2-line title
                .padding(.horizontal, 16)  // Add horizontal padding to create floating effect
                .padding(.bottom, 8)  // Add bottom padding for floating effect
                .offset(y: mediaBarManager.animationOffset)
                .opacity(mediaBarManager.isVisible ? 1.0 : 0.0)
            }
        }
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
            stopProgressTimer()
        }
        .onReceive(playerManager.$currentItem) { _ in
            updateProgressInfo()
        }
    }
    
    private func startProgressTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateProgressInfo()
        }
    }
    
    private func stopProgressTimer() {
        // Timer will be invalidated when view disappears
    }
    
    private func updateProgressInfo() {
        if let currentItem = playerManager.currentItem {
            currentTime = playerManager.player.currentTime().seconds
            duration = currentItem.asset.duration.seconds.isNaN ? 0 : currentItem.asset.duration.seconds
        }
    }
}

// MARK: - Media Bar Thumbnail Component
struct MediaBarThumbnail: View {
    let player: AVPlayer
    let pod: Pod
    @Binding var isVideo: Bool
    @State private var isDetecting: Bool = true
    
    var body: some View {
        ZStack {
            if isDetecting {
                // Loading state
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                    )
            } else if isVideo {
                // Video content - fill entire media bar height
                VideoPlayer(player: player)
                    .clipped()
            } else {
                // Audio content - show rounded thumbnail with adaptive aspect ratio
                if !pod.thumbnailUrl.isEmpty {
                    KFImage(URL(string: pod.thumbnailUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fit) // Changed to fit to preserve original aspect ratio
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(4/3, contentMode: .fit)
                }
            }
        }
        .frame(
            width: isVideo ? nil : 70,  // Video fills width, audio has slightly smaller width for more text space
            height: 60  // Both video and audio use same height (media bar height)
        )
        .cornerRadius(12)  // Rounded corners for both video and audio to match floating design
        .clipped()
        .onAppear {
            detectMediaType()
        }
        .onChange(of: pod.id) { _ in
            detectMediaType()
        }
    }
    
    private func detectMediaTypeSync() -> Bool {
        // Fast path: check file extension first (most reliable and fastest)
        let fileUrl = pod.fileUrl
        let fileExtension = URL(string: fileUrl)?.pathExtension.lowercased() ?? ""
        let audioExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus", "aiff", "caf"]
        
        print("🎵 MediaBar: Checking file extension '\(fileExtension)' for pod '\(pod.title)'")
        
        if audioExtensions.contains(fileExtension) {
            print("🎵 MediaBar: Detected AUDIO by extension: \(fileExtension)")
            return false // Audio
        }
        
        // Check URL path patterns (fast string operations)
        let isAudioPath = fileUrl.contains("/audios/") || fileUrl.contains("audios%2F")
        let isVideoPath = fileUrl.contains("/videos/") || fileUrl.contains("videos%2F")
        
        print("🎵 MediaBar: URL path check - Audio: \(isAudioPath), Video: \(isVideoPath)")
        
        if isAudioPath {
            print("🎵 MediaBar: Detected AUDIO by URL path")
            return false // Audio
        } else if (isVideoPath) {
            print("🎵 MediaBar: Detected VIDEO by URL path")
            return true // Video
        }
        
        // Fallback: check AVPlayer tracks (slowest, only if needed)
        guard let currentItem = player.currentItem else {
            print("🎵 MediaBar: No current item, defaulting to VIDEO")
            return true // Default to video
        }
        
        let hasVideoTracks = currentItem.asset.tracks(withMediaType: .video).count > 0
        let hasAudioTracks = currentItem.asset.tracks(withMediaType: .audio).count > 0
        
        print("🎵 MediaBar: Track check - Video: \(hasVideoTracks), Audio: \(hasAudioTracks)")
        
        if hasVideoTracks {
            print("🎵 MediaBar: Detected VIDEO by tracks")
            return true
        } else if hasAudioTracks {
            print("🎵 MediaBar: Detected AUDIO by tracks")
            return false
        }
        
        // Final fallback: if no tracks detected, check file extension again
        print("🎵 MediaBar: No tracks detected, final fallback to extension: \(fileExtension)")
        return !audioExtensions.contains(fileExtension)
    }
    
    private func detectMediaType() {
        isDetecting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let newIsVideo = self.detectMediaTypeSync()
            DispatchQueue.main.async {
                self.isVideo = newIsVideo
                self.isDetecting = false
            }
        }
    }
}
