//
//  VideoPlayer.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 6/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import Kingfisher
import Firebase

struct VideoPlayer: View {
    let player: AVPlayer
    @State private var playerController: AVPlayerViewController?
    
    var body: some View {
        FullscreenVideoPlayerView(player: player, playerController: $playerController)
            .id("VideoPlayer") // Prevent recreation during fullscreen
    }
}

// MARK: - Fullscreen Video Player View
struct FullscreenVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var playerController: AVPlayerViewController?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        
        // Enable fullscreen and PiP
        controller.allowsPictureInPicturePlayback = true
        controller.showsPlaybackControls = true
        
        // CRITICAL FIX: Disable AVPlayerViewController from managing now playing info
        // This prevents it from interfering with our custom now playing info setup
        controller.updatesNowPlayingInfoCenter = false
        
        playerController = controller
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player {
            uiViewController.player = player
        }
    }
}

// MARK: - Smart Media Player

struct SmartMediaPlayer: View {
    let player: AVPlayer
    let pod: Pod
    @State private var isVideo: Bool = true
    @State private var isDetecting: Bool = false
    @State private var lastPodId: String?
    
    
    var body: some View {
        ZStack {
            if isDetecting {
                // Loading state - show a simple placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                    )
                    .transition(.opacity)
            } else if isVideo {
                // Video content - use the existing VideoPlayer
                VideoPlayer(player: player)
                    .transition(.opacity)
            } else {
                // Audio content - show thumbnail as background
                AudioPlayerView(player: player, thumbnailUrl: pod.thumbnailUrl)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isVideo)
        .animation(.easeInOut(duration: 0.2), value: isDetecting)
        .onAppear {
            print("🎵 SmartMediaPlayer: onAppear called for pod '\(pod.title)' with fileUrl: '\(pod.fileUrl)'")
            detectMediaType()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Detect media type when app becomes active (catches some edge cases)
            forceMediaTypeDetection()
        }
        .onChange(of: pod.id) { _ in
            // Force media type detection when pod changes
            forceMediaTypeDetection()
        }
        .onChange(of: pod.fileUrl) { _ in
            // Force media type detection when file URL changes
            forceMediaTypeDetection()
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Check for pod changes more frequently
            if let currentPodId = pod.id, currentPodId != lastPodId {
                lastPodId = currentPodId
                forceMediaTypeDetection()
            }
        }

    }
    
    private func detectMediaTypeSync() -> Bool {
        // Fast path: check file extension first (most reliable and fastest)
        let fileUrl = pod.fileUrl
        let fileExtension = URL(string: fileUrl)?.pathExtension.lowercased() ?? ""
        let audioExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus", "aiff", "caf"]
        
        print("🎵 SmartMediaPlayer: Checking file extension '\(fileExtension)' for pod '\(pod.title)'")
        
        if audioExtensions.contains(fileExtension) {
            print("🎵 SmartMediaPlayer: Detected AUDIO by extension: \(fileExtension)")
            return false // Audio
        }
        
        // Check URL path patterns (fast string operations)
        let isAudioPath = fileUrl.contains("/audios/") || fileUrl.contains("audios%2F")
        let isVideoPath = fileUrl.contains("/videos/") || fileUrl.contains("videos%2F")
        
        print("🎵 SmartMediaPlayer: URL path check - Audio: \(isAudioPath), Video: \(isVideoPath)")
        
        if isAudioPath {
            print("🎵 SmartMediaPlayer: Detected AUDIO by URL path")
            return false // Audio
        } else if (isVideoPath) {
            print("🎵 SmartMediaPlayer: Detected VIDEO by URL path")
            return true // Video
        }
        
        // Fallback: check AVPlayer tracks (slowest, only if needed)
        guard let currentItem = player.currentItem else {
            print("🎵 SmartMediaPlayer: No current item, defaulting to VIDEO")
            return true // Default to video
        }
        
        let hasVideoTracks = currentItem.asset.tracks(withMediaType: .video).count > 0
        let hasAudioTracks = currentItem.asset.tracks(withMediaType: .audio).count > 0
        
        print("🎵 SmartMediaPlayer: Track check - Video: \(hasVideoTracks), Audio: \(hasAudioTracks)")
        
        if hasVideoTracks {
            print("🎵 SmartMediaPlayer: Detected VIDEO by tracks")
            return true
        } else if hasAudioTracks {
            print("🎵 SmartMediaPlayer: Detected AUDIO by tracks")
            return false
        }
        
        // Final fallback: if no tracks detected, check file extension again
        print("🎵 SmartMediaPlayer: No tracks detected, final fallback to extension: \(fileExtension)")
        return !audioExtensions.contains(fileExtension)
    }
    
    private func detectMediaType() {
        print("🎵 SmartMediaPlayer: detectMediaType() called for pod '\(pod.title)'")
        isDetecting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let newIsVideo = self.detectMediaTypeSync()
            DispatchQueue.main.async {
                print("🎵 SmartMediaPlayer: Detection complete - isVideo: \(newIsVideo) for pod '\(self.pod.title)'")
                self.isVideo = newIsVideo
                self.isDetecting = false
            }
        }
    }
    
    private func forceMediaTypeDetection() {
        print("🎵 SmartMediaPlayer: Force detecting media type for pod '\(pod.title)'")
        
        // Reset state and force immediate detection
        isDetecting = true
        
        // Use main queue for immediate UI update
        DispatchQueue.main.async {
            let newIsVideo = self.detectMediaTypeSync()
            print("🎵 SmartMediaPlayer: Force detection result - isVideo: \(newIsVideo)")
            self.isVideo = newIsVideo
            self.isDetecting = false
        }
    }
}

struct AudioPlayerView: View {
    let player: AVPlayer
    let thumbnailUrl: String
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background thumbnail image - contained within the view bounds
                KFImage(URL(string: thumbnailUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 4)
                    .overlay(
                        // Dark overlay for better control visibility
                        Color.black.opacity(0.5)
                    )
                    .clipped()
                
                // Main content - with progress bar at top
                VStack(spacing: 0) {
                    // Progress section at top
                    VStack(spacing: 8) {
                        // Progress bar with custom design - spans width
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.white, Color.white.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, CGFloat(currentTime / max(duration, 1)) * (geometry.size.width - 60)), height: 4)
                                .animation(.easeInOut(duration: 0.1), value: currentTime)
                            
                            // Progress thumb (only visible when dragging)
                            if isDragging {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                    .offset(x: max(0, CGFloat(currentTime / max(duration, 1)) * (geometry.size.width - 60) - 7))
                            }
                        }
                        .frame(width: geometry.size.width - 60)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let progress = value.location.x / (geometry.size.width - 60)
                                    currentTime = progress * duration
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
                                    player.seek(to: targetTime)
                                }
                        )
                        
                        // Time labels with better styling
                        HStack {
                            Text(timeString(from: currentTime))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text(timeString(from: duration))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: geometry.size.width - 60)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 5)
                    
                    Spacer()
                    
                    // Audio waveform visualization
                    HStack(spacing: 4) {
                        ForEach(0..<18, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.6)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 4, height: CGFloat.random(in: 12...38))
                                .scaleEffect(y: isPlaying ? CGFloat.random(in: 0.7...1.4) : 1.0)
                                .opacity(isPlaying ? 1.0 : 0.7)
                                .animation(
                                    isPlaying 
                                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.05)
                                    : .default,
                                    value: isPlaying
                                )
                                .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }
                    .frame(width: geometry.size.width - 60, height: 50)
                    
                    Spacer()
                    
                    // Control buttons
                    HStack(spacing: 30) {
                        // Skip backward button
                        Button {
                            let newTime = max(0, currentTime - 30)
                            currentTime = newTime
                            let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
                            player.seek(to: targetTime)
                            
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 45, height: 45)
                                    .shadow(color: .white.opacity(0.2), radius: 4, x: 0, y: 2)
                                
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 45, height: 45)
                                
                                Image(systemName: "gobackward.30")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(isHovering ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
                        
                        // Play/Pause button (larger and more prominent)
                        Button {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                            isPlaying.toggle()
                            
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        } label: {
                            ZStack {
                                // Pulsing background effect when playing
                                if isPlaying {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 90, height: 90)
                                        .scaleEffect(isPlaying ? 1.2 : 1.0)
                                        .opacity(isPlaying ? 0 : 0.8)
                                        .animation(
                                            .easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: false),
                                            value: isPlaying
                                        )
                                }
                                
                                // Circular progress indicator
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(currentTime / max(duration, 1)))
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.1), value: currentTime)
                                
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.white, Color.white.opacity(0.9)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.black)
                                    .offset(x: isPlaying ? 0 : 2) // Slight offset for play button centering
                                    .scaleEffect(isPlaying ? 0.9 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPlaying)
                            }
                        }
                        .scaleEffect(isPlaying ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                        
                        // Skip forward button
                        Button {
                            let newTime = min(duration, currentTime + 30)
                            currentTime = newTime
                            let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
                            player.seek(to: targetTime)
                            
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 45, height: 45)
                                    .shadow(color: .white.opacity(0.2), radius: 4, x: 0, y: 2)
                                
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 45, height: 45)
                                
                                Image(systemName: "goforward.30")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(isHovering ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
                    }
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 8)
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard !isDragging else { return }
            updateProgress()
        }
        .onAppear {
            setupPlayerObserver()
            // CRITICAL FIX: Immediately sync UI state with actual player state
            syncWithPlayerState()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func setupPlayerObserver() {
        // Update duration when item is ready
        if let currentItem = player.currentItem {
            let duration = currentItem.duration
            if duration.isValid && !duration.isIndefinite {
                self.duration = duration.seconds
            }
        }
        
        // Monitor playback state
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
            if !isDragging {
                currentTime = time.seconds
            }
        }
    }
    
    private func updateProgress() {
        guard let currentItem = player.currentItem else { return }
        
        let duration = currentItem.duration
        if duration.isValid && !duration.isIndefinite {
            self.duration = duration.seconds
        }
        
        if !isDragging {
            currentTime = player.currentTime().seconds
        }
        
        // Update play state based on player rate
        isPlaying = player.rate > 0
    }
    
    private func timeString(from seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    // MARK: - State Synchronization
    
    /// Immediately syncs UI state with the actual player state when the view appears
    private func syncWithPlayerState() {
        print("🎵 AudioPlayerView: Syncing with player state on appear")
        
        // Get current player state
        let playerIsPlaying = player.rate > 0
        let currentPlayerTime = player.currentTime().seconds
        
        // Update UI state to match actual player state
        DispatchQueue.main.async {
            self.isPlaying = playerIsPlaying
            self.currentTime = currentPlayerTime
            
            print("🎵 AudioPlayerView: Synced state - isPlaying: \(self.isPlaying), currentTime: \(self.currentTime)")
        }
        
        // Also update duration if available
        if let currentItem = player.currentItem {
            let duration = currentItem.duration
            if duration.isValid && !duration.isIndefinite {
                DispatchQueue.main.async {
                    self.duration = duration.seconds
                }
            }
        }
    }
}



#Preview {
    VideoPlayer(player: AVPlayer())
}
