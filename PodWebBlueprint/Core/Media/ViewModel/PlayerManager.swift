import AVFoundation
import Combine
import MediaPlayer
import FirebaseFirestore
import FirebaseFunctions

class PlayerManager: NSObject, ObservableObject {
    static let shared = PlayerManager()
    
    @Published var player = AVPlayer()
    @Published var currentItem: AVPlayerItem?
    @Published var isPlaying = false
    @Published var currentPod: Pod?
    
    private var updateTimer: Timer?
    private var currentArtwork: MPMediaItemArtwork?
    private var hasValidNowPlayingInfo = false
    
    // Caching properties
    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private var metadataCache: [String: [String: Any]] = [:]
    private var durationCache: [String: Double] = [:]
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        setupMemoryPressureHandling()
    }
    
    // MARK: - Engagement Metrics
    
    private func incrementPodViews(podId: String) {
        guard !podId.isEmpty else { return }
        
        Task {
            do {
                let functions = Functions.functions()
                let incrementViews = functions.httpsCallable("incrementPodViews")
                let result = try await incrementViews.call(["podId": podId])
                print("✅ Successfully incremented views for pod: \(podId)")
            } catch {
                print("❌ Error incrementing pod views: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Caching Methods
    
    private func cacheKey(for pod: Pod) -> String {
        return "\(String(describing: pod.id))_\(pod.fileUrl)"
    }
    
    private func getCachedArtwork(for pod: Pod) -> MPMediaItemArtwork? {
        let key = cacheKey(for: pod)
        return artworkCache[key]
    }
    
    private func cacheArtwork(_ artwork: MPMediaItemArtwork, for pod: Pod) {
        let key = cacheKey(for: pod)
        artworkCache[key] = artwork
    }
    
    private func getCachedMetadata(for pod: Pod) -> [String: Any]? {
        let key = cacheKey(for: pod)
        return metadataCache[key]
    }
    
    private func cacheMetadata(_ metadata: [String: Any], for pod: Pod) {
        let key = cacheKey(for: pod)
        metadataCache[key] = metadata
    }
    
    private func getCachedDuration(for pod: Pod) -> Double? {
        let key = cacheKey(for: pod)
        return durationCache[key]
    }
    
    private func cacheDuration(_ duration: Double, for pod: Pod) {
        let key = cacheKey(for: pod)
        durationCache[key] = duration
    }
    
    private func clearCache(for pod: Pod? = nil) {
        if let pod = pod {
            let key = cacheKey(for: pod)
            artworkCache.removeValue(forKey: key)
            metadataCache.removeValue(forKey: key)
            durationCache.removeValue(forKey: key)
        } else {
            // Clear all cache if memory pressure is high
            artworkCache.removeAll()
            metadataCache.removeAll()
            durationCache.removeAll()
        }
    }
    
    // MARK: - Existing Methods
    
    private func setupAudioSession() {
        do {
            // Deactivate first to clear any existing session
            try AVAudioSession.sharedInstance().setActive(false)
            
            // Set category with proper options
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .mixWithOthers])
            
            // Activate the session
            try AVAudioSession.sharedInstance().setActive(true)
            print("PlayerManager: Audio session setup successful")
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupPlayerObservers() {
        // Observe when the current item finishes playing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    @objc private func playerItemDidReachEnd() {
        print("PlayerManager: Player item reached end")
        stopUpdateTimer()
        // Keep the now playing info visible for a moment before clearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.currentItem == nil {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
        }
    }
    
    private func checkVideoReadiness() {
        guard let currentItem = currentItem else { return }
        
        if currentItem.status == .readyToPlay {
            print("PlayerManager: Video is ready to play")
            setupBasicNowPlayingInfo()
            
            // Ensure the player is ready for scrubbing
            if currentItem.isPlaybackLikelyToKeepUp {
                print("PlayerManager: Player item is ready for scrubbing")
            }
        } else if currentItem.status == .unknown {
            // Video is still loading, check again in a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.checkVideoReadiness()
            }
        } else if currentItem.status == .failed {
            print("PlayerManager: Video failed to load")
        }
    }
    
    func setupBasicNowPlayingInfo() {
        guard let currentPod = currentPod, !hasValidNowPlayingInfo else { return }
        
        print("PlayerManager: setupBasicNowPlayingInfo - Setting basic now playing info")
        
        // Set basic now playing info when the video is actually ready to play
        let basicNowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: currentPod.title,
            MPMediaItemPropertyArtist: currentPod.user?.username ?? "Loading...",
            MPNowPlayingInfoPropertyPlaybackRate: self.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = basicNowPlayingInfo
        hasValidNowPlayingInfo = true
        
        // Cache the basic metadata so updateNowPlayingInfo can find it
        cacheMetadata(basicNowPlayingInfo, for: currentPod)
        
        // Start the update timer now that we have valid now playing info
        startUpdateTimer()
        
        print("PlayerManager: setupBasicNowPlayingInfo - Basic info set with title: \(currentPod.title)")
        print("PlayerManager: setupBasicNowPlayingInfo - Basic info artist: \(currentPod.user?.username ?? "Loading...")")
        
        // Immediately load and set the thumbnail artwork
        loadThumbnailArtwork(for: currentPod)
    }
    
    private func loadThumbnailArtwork(for pod: Pod) {
        guard let thumbnailURL = URL(string: pod.thumbnailUrl), getCachedArtwork(for: pod) == nil else {
            print("PlayerManager: Thumbnail already cached or no URL available")
            return
        }
        
        print("PlayerManager: Loading thumbnail artwork from URL: \(thumbnailURL.absoluteString)")
        
        // Download image from the URL
        URLSession.shared.dataTask(with: thumbnailURL) { data, response, error in
            if let error = error {
                print("PlayerManager: Error loading thumbnail: \(error.localizedDescription)")
                return
            }

            guard let data = data, let image = UIImage(data: data) else {
                print("PlayerManager: Failed to create image from thumbnail data")
                return
            }

            print("PlayerManager: Successfully loaded thumbnail artwork")

            DispatchQueue.main.async {
                // Create artwork and cache it
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.currentArtwork = artwork
                self.cacheArtwork(artwork, for: pod)
                
                // Update the now playing info with artwork
                var updatedInfo = self.getCachedMetadata(for: pod) ?? [:]
                updatedInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                print("PlayerManager: Updated now playing info with thumbnail artwork")
            }
        }.resume()
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Remove existing targets first
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            print("PlayerManager: Remote play command received")
            DispatchQueue.main.async {
                self?.resume()
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            print("PlayerManager: Remote pause command received")
            DispatchQueue.main.async {
                self?.pause()
            }
            return .success
        }
        
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            print("PlayerManager: Remote skip forward command received")
            self?.skipForward()
            return .success
        }
        
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            print("PlayerManager: Remote skip backward command received")
            self?.skipBackward()
            return .success
        }
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        print("PlayerManager: Remote commands setup complete")
    }
    
    func play(url: URL, pod: Pod, isRecommendedPod: Bool = false) {
        print("PlayerManager: play() method called with URL: \(url.absoluteString)")
        print("PlayerManager: Pod title: \(pod.title)")
        
        let item = AVPlayerItem(url: url)
        
        // Configure the player item for better scrubbing
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        player.replaceCurrentItem(with: item)
        
        // Update published properties on main thread
        DispatchQueue.main.async {
            self.currentItem = item
            self.currentPod = pod
            self.isPlaying = true
            
            // Show media bar with animation when a pod starts playing
            MediaBarManager.shared.animateIn()
        }
        
        // Set up observer for the new item
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        player.play()
        
        // Increment views count when pod starts playing
        incrementPodViews(podId: pod.id ?? "")
        
        // Ensure audio session is active with better error handling
        do {
            // Try to activate the audio session
            try AVAudioSession.sharedInstance().setActive(true)
            print("PlayerManager: Audio session activated")
        } catch {
            print("PlayerManager: Failed to activate audio session: \(error)")
            // Try to re-setup the audio session
            setupAudioSession()
        }
        
        if isRecommendedPod {
            // For recommended pods, set basic now playing info immediately since video is already loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.setupBasicNowPlayingInfo()
            }
        } else {
            // For initial loads, wait for video to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkVideoReadiness()
            }
        }
    }
    
    func pause() {
        print("PlayerManager: pause() called")
        player.pause()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        updateNowPlayingInfo()
        // Keep timer running to maintain now playing info
    }
    
    func resume() {
        print("PlayerManager: resume() called")
        player.play()
        DispatchQueue.main.async {
            self.isPlaying = true
        }
        updateNowPlayingInfo()
        // Timer should already be running
    }
    
    func stop() {
        // Remove observer for current item
        if let currentItem = currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        
        // Clear cache for the current pod
        if let currentPod = currentPod {
            clearCache(for: currentPod)
        }
        
        player.replaceCurrentItem(with: nil)
        
        // Update published properties on main thread
        DispatchQueue.main.async {
            self.currentItem = nil
            self.currentPod = nil
            self.isPlaying = false
        }
        
        currentArtwork = nil
        hasValidNowPlayingInfo = false
        stopUpdateTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func skipForward() {
        let newTime = CMTimeAdd(player.currentTime(), CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: newTime)
    }
    
    func skipBackward() {
        let newTime = CMTimeSubtract(player.currentTime(), CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: newTime)
    }
    
    func setNowPlayingInfo(title: String, creator: String, artworkURL: URL?) {
        guard let currentPod = currentPod else { return }
        
        print("PlayerManager: setNowPlayingInfo - Called with title: \(title), creator: \(creator)")
        
        let currentTime = player.currentTime().seconds
        
        // Check for cached duration first
        var duration = getCachedDuration(for: currentPod)
        if duration == nil {
            duration = player.currentItem?.asset.duration.seconds ?? 0
            if duration! > 0 {
                cacheDuration(duration!, for: currentPod)
            }
        }

        // Always create fresh metadata to ensure we have the latest info
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: creator,
            MPMediaItemPropertyPlaybackDuration: duration ?? 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: self.isPlaying ? 1.0 : 0.0
        ]
        
        // Cache the fresh metadata
        cacheMetadata(nowPlayingInfo, for: currentPod)

        // Check for cached artwork
        if let cachedArtwork = getCachedArtwork(for: currentPod) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = cachedArtwork
            currentArtwork = cachedArtwork
            print("PlayerManager: Using cached artwork")
        }

        // Set the info immediately
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        hasValidNowPlayingInfo = true
        print("PlayerManager: setNowPlayingInfo - Info set with title: \(title), creator: \(creator)")

        // If we don't have cached artwork and have a valid artwork URL, load it asynchronously
        guard let artworkURL = artworkURL, getCachedArtwork(for: currentPod) == nil else {
            print("PlayerManager: No artwork URL provided or artwork already cached")
            return
        }

        print("PlayerManager: Loading artwork from URL: \(artworkURL.absoluteString)")

        // Download image from the URL
        URLSession.shared.dataTask(with: artworkURL) { data, response, error in
            if let error = error {
                print("PlayerManager: Error loading artwork: \(error.localizedDescription)")
                return
            }

            guard let data = data, let image = UIImage(data: data) else {
                print("PlayerManager: Failed to create image from data")
                return
            }

            print("PlayerManager: Successfully loaded artwork image")

            DispatchQueue.main.async {
                // Create artwork and cache it
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.currentArtwork = artwork
                self.cacheArtwork(artwork, for: currentPod)
                
                // Update the now playing info with artwork
                var updatedInfo = self.getCachedMetadata(for: currentPod) ?? nowPlayingInfo
                updatedInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                print("PlayerManager: Updated now playing info with artwork and cached it")
            }
        }.resume()
    }
    
    // Convenience method for setting now playing info with complete pod data
    func setNowPlayingInfoWithPod(_ pod: Pod, user: User?) {
        let artworkURL = URL(string: pod.thumbnailUrl)
        
        // Stop the timer temporarily to prevent interference
        stopUpdateTimer()
        
        setNowPlayingInfo(
            title: pod.title,
            creator: user?.username ?? "UNKNOWN",
            artworkURL: artworkURL
        )
        
        // Restart the timer after setting the new info
        startUpdateTimer()
    }
    
    func updateNowPlayingInfo() {
        guard let currentPod = currentPod, hasValidNowPlayingInfo else {
            return
        }
        
        let currentTime = player.currentTime().seconds
        
        // Get the existing now playing info
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        
        // If no existing info, try to restore from cache
        if nowPlayingInfo.isEmpty {
            if let cachedMetadata = getCachedMetadata(for: currentPod) {
                nowPlayingInfo = cachedMetadata
                // Add current dynamic values
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                return
            } else {
                return
            }
        }
        
        // Only update if the values have changed significantly to reduce blinking
        let existingElapsedTime = nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0
        let existingPlaybackRate = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
        
        var needsUpdate = false
        
        // Check if elapsed time changed significantly (more than 1 second)
        if abs(existingElapsedTime - currentTime) > 1.0 {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            needsUpdate = true
        }
        
        // Check if playback rate changed
        let shouldBePlaying = self.isPlaying ? 1.0 : 0.0
        if abs(existingPlaybackRate - shouldBePlaying) > 0.01 {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = shouldBePlaying
            needsUpdate = true
        }
        
        // Update duration if it changed significantly
        let duration = getCachedDuration(for: currentPod) ?? player.currentItem?.asset.duration.seconds ?? 0
        let existingDuration = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0
        if abs(existingDuration - duration) > 1.0 && duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            cacheDuration(duration, for: currentPod)
            needsUpdate = true
        }
        
        // Only update if something actually changed
        if needsUpdate {
            // Always preserve existing metadata (title, artist, artwork)
            var finalNowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyTitle: nowPlayingInfo[MPMediaItemPropertyTitle] ?? currentPod.title,
                MPMediaItemPropertyArtist: nowPlayingInfo[MPMediaItemPropertyArtist] ?? currentPod.user?.username ?? "UNKNOWN",
                MPMediaItemPropertyPlaybackDuration: nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] ?? duration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] ?? currentTime,
                MPNowPlayingInfoPropertyPlaybackRate: nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] ?? shouldBePlaying
            ]
            
            // Preserve artwork if it exists
            if let artwork = nowPlayingInfo[MPMediaItemPropertyArtwork] {
                finalNowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
            
            // Update the now playing info
            MPNowPlayingInfoCenter.default().nowPlayingInfo = finalNowPlayingInfo
        }
    }
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryPressure() {
        print("PlayerManager: Memory pressure detected, clearing cache")
        clearCache()
    }
    
    // Public method to manually clear cache
    func clearAllCache() {
        print("PlayerManager: Manually clearing all cache")
        clearCache()
    }
    
    deinit {
        stopUpdateTimer()
        NotificationCenter.default.removeObserver(self)
    }
}
