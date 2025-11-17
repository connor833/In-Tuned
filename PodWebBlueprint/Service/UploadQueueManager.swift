//
//  UploadQueueManager.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/15/25.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import Network
import UserNotifications
import AVFoundation
import FirebaseAuth

class UploadQueueManager: ObservableObject {
    @Published var activeUploads: [UploadItem] = []
    @Published var failedUploads: [UploadItem] = []
    
    private let r2UploadService = R2UploadService()
    private let storageUploader = StorageUploader()
    private let aiProcessor = AIProcessor()
    private let openAIProcessor = OpenAIProcessor(apiKey: AIConfig.openAIAPIKey)
    
    // Persistence
    private let userDefaults = UserDefaults.standard
    private let activeUploadsKey = "activeUploads"
    private let failedUploadsKey = "failedUploads"
    private let terminationFlagKey = "lastTerminationHadActiveUploads"
    private let terminatedCountKey = "lastTerminatedUploadsCount"
    
    // Progress persistence timer
    private var progressPersistenceTimer: Timer?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    // Retry configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 2.0 // 2 seconds
    private let maxRetryDelay: TimeInterval = 300.0 // 5 minutes
    
    // Queue limits
    static let maxQueueSize = 3
    
    // Retry cancellation
    private var pendingRetries: [UUID: DispatchWorkItem] = [:]
    
    // Singleton instance
    static let shared = UploadQueueManager()
    
    init() {
        loadPersistedUploads()
        checkTerminationFlagOnLaunch()
        setupR2ServiceBinding()
        setupAppLifecycleObservers()
        setupNetworkMonitoring()
        
        // Clean up any stuck uploads on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.clearStuckUploads()
        }
        
        // Only start timers if we have active uploads from previous session
        if !activeUploads.isEmpty {
            startProgressPersistenceTimer()
            startNetworkMonitoring()
        }
    }
    
    deinit {
        progressPersistenceTimer?.invalidate()
        networkMonitor.cancel()
    }
    
    // MARK: - Queue Management Properties
    
    /// Total number of items in the queue (active + failed)
    var totalQueueCount: Int {
        return activeUploads.count + failedUploads.count
    }
    
    /// Check if the queue is at maximum capacity
    var isQueueFull: Bool {
        return totalQueueCount >= Self.maxQueueSize
    }
    
    /// Remaining queue slots available
    var remainingSlots: Int {
        return max(0, Self.maxQueueSize - totalQueueCount)
    }
    
    /// Check if we can add a new upload to the queue
    var canAddUpload: Bool {
        return !isQueueFull
    }
    
    // MARK: - Public Methods
    
    func addUpload(
        fileName: String,
        fileUrl: URL,
        fileSize: Int64,
        podTitle: String,
        podDescription: String,
        tags: [String],
        thumbnailImage: UIImage?,
        source: VideoSource,
        user: User
    ) -> Bool {
        // Check if queue is full
        guard canAddUpload else {
            print("🚫 UploadQueueManager: Cannot add upload - queue is full (\(totalQueueCount)/\(Self.maxQueueSize))")
            
            // Post notification for UI to show error
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UploadQueueFull"), 
                    object: nil,
                    userInfo: ["maxSize": Self.maxQueueSize, "currentCount": self.totalQueueCount]
                )
            }
            
            return false
        }
        
        let uploadItem = UploadItem(
            fileName: fileName,
            fileUrl: fileUrl,
            fileSize: fileSize,
            podTitle: podTitle,
            podDescription: podDescription,
            tags: tags,
            thumbnailImage: thumbnailImage,
            source: source,
            user: user
        )
        
        DispatchQueue.main.async {
            self.activeUploads.append(uploadItem)
            self.persistAllUploads()
            print("📋 UploadQueueManager: Added upload to queue. Total queue size: \(self.totalQueueCount)/\(Self.maxQueueSize)")
            
            // Start timers only when we have uploads
            if self.activeUploads.count == 1 {
                self.startProgressPersistenceTimer()
                self.startNetworkMonitoring()
            }
        }
        
        // Start the upload process
        startUpload(for: uploadItem, user: user)
        return true
    }
    
    func cancelUpload(_ uploadItem: UploadItem) {
        print("🛑 Cancelling upload: \(uploadItem.podTitle)")
        
        DispatchQueue.main.async {
            // Cancel any pending retry for this upload
            if let retryWorkItem = self.pendingRetries[uploadItem.id] {
                retryWorkItem.cancel()
                self.pendingRetries.removeValue(forKey: uploadItem.id)
                print("🛑 Cancelled pending retry for upload: \(uploadItem.podTitle)")
            }
            
            // First check if it's in active uploads (still uploading)
            if let index = self.activeUploads.firstIndex(where: { $0.id == uploadItem.id }) {
                print("🛑 Found active upload to cancel at index \(index)")
                
                // Mark as cancelled and remove from active uploads
                self.activeUploads[index].status = .cancelled
                self.activeUploads.remove(at: index)
                self.persistAllUploads()
                
                // Stop timers if no more active uploads
                if self.activeUploads.isEmpty {
                    self.stopProgressPersistenceTimer()
                    self.stopNetworkMonitoring()
                }
                
                print("🛑 Active upload cancelled and removed from queue")
                
                // Cancel the actual upload in R2 service
                self.r2UploadService.cancelUpload()
            }
            // If not in active uploads, check if it's in failed uploads (already failed)
            else if let index = self.failedUploads.firstIndex(where: { $0.id == uploadItem.id }) {
                print("🛑 Found failed upload to dismiss at index \(index)")
                
                // Remove from failed uploads (dismiss it)
                self.failedUploads.remove(at: index)
                self.persistAllUploads()
                
                print("🛑 Failed upload dismissed and removed from queue")
            } else {
                print("⚠️ Could not find upload to cancel/dismiss: \(uploadItem.id)")
            }
        }
    }
    
    func retryUpload(_ uploadItem: UploadItem, user: User) {
        DispatchQueue.main.async {
            if let index = self.failedUploads.firstIndex(where: { $0.id == uploadItem.id }) {
                var retryItem = self.failedUploads[index]
                retryItem.status = .pending
                retryItem.progress = 0.0
                retryItem.errorMessage = nil
                
                self.failedUploads.remove(at: index)
                self.activeUploads.append(retryItem)
                self.persistAllUploads()
                
                // Start the upload process
                self.startUpload(for: retryItem, user: user)
            }
        }
    }
    
    
    func clearFailedUploads() {
        DispatchQueue.main.async {
            self.failedUploads.removeAll()
            self.persistAllUploads()
        }
    }
    
    func clearStuckUploads() {
        DispatchQueue.main.async {
            print("🧹 Clearing stuck uploads...")
            
            // Find uploads that have been stuck for more than 10 minutes
            let tenMinutesAgo = Date().addingTimeInterval(-600)
            let stuckUploads = self.activeUploads.filter { 
                $0.status == .uploading && $0.lastUpdated < tenMinutesAgo 
            }
            
            if !stuckUploads.isEmpty {
                print("🧹 Found \(stuckUploads.count) stuck uploads older than 10 minutes")
                
                for upload in stuckUploads {
                    var failedUpload = upload
                    failedUpload.status = .failed
                    failedUpload.errorMessage = "Upload timed out - please retry"
                    self.moveToFailed(failedUpload)
                }
                
                // Remove from active uploads
                self.activeUploads.removeAll { 
                    $0.status == .uploading && $0.lastUpdated < tenMinutesAgo 
                }
                
                self.persistAllUploads()
                print("🧹 Cleared \(stuckUploads.count) stuck uploads")
            } else {
                print("🧹 No stuck uploads found")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startUpload(for uploadItem: UploadItem, user: User) {
        print("🚀 Starting background upload for: \(uploadItem.fileName)")
        
        // Check if compression is needed
        if needsCompression(uploadItem) {
            startCompression(uploadItem, user: user)
        } else {
            // No compression needed, start upload directly
            updateUploadStatus(uploadItem.id, status: .uploading)
            uploadCompletePod(
                uploadItem: uploadItem,
                user: user
            ) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let (thumbnailUrl, mainFileUrl)):
                        print("✅ Background upload successful: \(uploadItem.fileName)")
                        print("✅ Thumbnail URL: \(thumbnailUrl)")
                        print("✅ Main file URL: \(mainFileUrl)")
                        self?.updateUploadSuccess(uploadItem.id, thumbnailUrl: thumbnailUrl, mainFileUrl: mainFileUrl)
                    case .failure(let error):
                        print("❌ Background upload failed: \(error.localizedDescription)")
                        print("❌ Error details: \(error)")
                        self?.updateUploadFailure(uploadItem.id, error: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Compression Methods
    
    private func needsCompression(_ upload: UploadItem) -> Bool {
        // Check if this is a PhotosPicker video that needs compression
        if upload.source == .photosPicker {
            let fileSize = upload.fileSize
            let sizeGB = Double(fileSize) / (1024 * 1024 * 1024)
            
            // Compress PhotosPicker videos to match iOS automatic compression
            // Only skip compression for very small files (< 100MB)
            return sizeGB > 0.1 // 100MB threshold
        }
        
        // For Files app videos, always compress if larger than 2GB
        if upload.source == .filesApp {
            let fileSize = upload.fileSize
            let sizeGB = Double(fileSize) / (1024 * 1024 * 1024)
            return sizeGB > 2.0
        }
        
        return false
    }
    
    private func startCompression(_ upload: UploadItem, user: User) {
        print("🗜️ Starting compression for: \(upload.podTitle)")
        
        // Update status to compressing
        updateUploadStatus(upload.id, status: .uploading) // Use uploading status but show compression progress
        updateCompressionStatus(upload.id, isCompressing: true, progress: 0.0)
        
        // Start compression in background
        Task {
            await compressVideo(upload, user: user)
        }
    }
    
    private func compressVideo(_ upload: UploadItem, user: User) async {
        do {
            // Determine if this is audio or video based on file extension
            let originalExtension = upload.fileUrl.pathExtension.lowercased()
            let audioExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus", "aiff", "caf"]
            let isAudioFile = audioExtensions.contains(originalExtension)
            
            print("🗜️ UploadQueueManager: Original extension: \(originalExtension), isAudio: \(isAudioFile)")
            
            // Skip compression for audio files - they're already small and don't need it
            if isAudioFile {
                print("🗜️ UploadQueueManager: Audio file detected - skipping compression")
                updateCompressedFileUrl(upload.id, compressedFileUrl: upload.fileUrl) // Use original file
                updateCompressionStatus(upload.id, isCompressing: false, progress: 1.0)
                
                // Start upload with original audio file
                uploadCompletePod(uploadItem: upload, user: user) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let (thumbnailUrl, mainFileUrl)):
                            print("✅ Background upload successful: \(upload.fileName)")
                            self?.updateUploadSuccess(upload.id, thumbnailUrl: thumbnailUrl, mainFileUrl: mainFileUrl)
                        case .failure(let error):
                            print("❌ Background upload failed: \(error.localizedDescription)")
                            self?.updateUploadFailure(upload.id, error: error.localizedDescription)
                        }
                    }
                }
                return
            }
            
            // Only compress video files
            print("🗜️ UploadQueueManager: Video file detected - proceeding with compression")
            
            // Read file data
            let fileData = try Data(contentsOf: upload.fileUrl)
            
            // Create temporary file for compressed output
            let tempDir = FileManager.default.temporaryDirectory
            let compressedFileName = "compressed_\(upload.id.uuidString).mp4"
            let compressedFileUrl = tempDir.appendingPathComponent(compressedFileName)
            
            // Use AVAssetExportSession for compression (same as iOS)
            let asset = AVAsset(url: upload.fileUrl)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                throw NSError(domain: "CompressionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
            }
            
            exportSession.outputURL = compressedFileUrl
            exportSession.outputFileType = .mp4 // Only video files reach this point
            
            exportSession.shouldOptimizeForNetworkUse = true
            
            print("🗜️ UploadQueueManager: Export file type set to: \(exportSession.outputFileType?.rawValue)")
            
            // Monitor compression progress
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.updateCompressionProgress(upload.id, progress: Double(exportSession.progress))
                }
            }
            
            // Start compression
            await exportSession.export()
            
            // Stop progress timer
            progressTimer.invalidate()
            
            // Check if compression was successful
            if exportSession.status == .completed {
                print("✅ Compression completed for: \(upload.podTitle)")
                
                // Update upload item with compressed file
                updateCompressedFileUrl(upload.id, compressedFileUrl: compressedFileUrl)
                print("🗜️ UploadQueueManager: Final compressed file: \(compressedFileUrl.lastPathComponent)")
                updateCompressionStatus(upload.id, isCompressing: false, progress: 1.0)
                
                // Start upload with compressed file
                uploadCompletePod(
                    uploadItem: upload,
                    user: user
                ) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let (thumbnailUrl, mainFileUrl)):
                            print("✅ Background upload successful: \(upload.fileName)")
                            self?.updateUploadSuccess(upload.id, thumbnailUrl: thumbnailUrl, mainFileUrl: mainFileUrl)
                        case .failure(let error):
                            print("❌ Background upload failed: \(error.localizedDescription)")
                            self?.updateUploadFailure(upload.id, error: error)
                        }
                    }
                }
            } else if let error = exportSession.error {
                print("❌ Compression failed for: \(upload.podTitle): \(error.localizedDescription)")
                updateUploadFailure(upload.id, error: "Compression failed: \(error.localizedDescription)")
            } else {
                print("❌ Compression cancelled for: \(upload.podTitle)")
                updateUploadFailure(upload.id, error: "Compression was cancelled")
            }
            
        } catch {
            print("❌ Compression error for: \(upload.podTitle): \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.updateUploadFailure(upload.id, error: "Compression failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadCompletePod(
        uploadItem: UploadItem,
        user: User,
        completion: @escaping (Result<(String, String), Error>) -> Void
    ) {
        print("🔄 UploadQueueManager.uploadCompletePod called for: \(uploadItem.fileName)")
        
        // Calculate total steps: thumbnail (5%) + main file (95%)
        let thumbnailWeight = 0.05
        let mainFileWeight = 0.95
        
        // Step 1: Upload thumbnail if provided
        if let thumbnailData = uploadItem.thumbnailImage, let thumbnailImage = UIImage(data: thumbnailData) {
            print("🖼️ Starting thumbnail upload...")
            // Don't show thumbnail progress - keep at 0% until thumbnail is complete
            storageUploader.uploadImage(image: thumbnailImage, progressHandler: { [weak self] progress in
                // Don't update progress during thumbnail upload - keep at 0%
                print("🖼️ Thumbnail upload progress: \(Int(progress * 100))% (not showing in UI)")
            }) { thumbnailUrl in
                print("✅ Thumbnail upload successful: \(thumbnailUrl)")
                
                // Now show 5% progress after thumbnail is complete
                DispatchQueue.main.async {
                    self.updateUploadProgress(uploadItem.id, progress: thumbnailWeight)
                }
                
                // Step 2: Upload main file
                self.uploadMainFile(
                    uploadItem: uploadItem,
                    thumbnailWeight: thumbnailWeight,
                    mainFileWeight: mainFileWeight,
                    thumbnailUrl: thumbnailUrl,
                    completion: completion
                )
            }
        } else {
            print("🖼️ No thumbnail provided, skipping thumbnail upload")
            // No thumbnail, just upload main file starting from 0%
            uploadMainFile(
                uploadItem: uploadItem,
                thumbnailWeight: 0.0,
                mainFileWeight: 1.0,
                thumbnailUrl: "",
                completion: completion
            )
        }
    }
    
    private func uploadMainFile(
        uploadItem: UploadItem,
        thumbnailWeight: Double,
        mainFileWeight: Double,
        thumbnailUrl: String,
        completion: @escaping (Result<(String, String), Error>) -> Void
    ) {
        print("📁 UploadQueueManager - File name: \(uploadItem.fileName)")
        
        // Start accessing security-scoped resource
        let isAccessing = uploadItem.fileUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                uploadItem.fileUrl.stopAccessingSecurityScopedResource()
            }
        }
        
        // Try to read file data (use compressed file if available)
        let fileData: Data
        let fileUrlToUse = uploadItem.compressedFileUrl ?? uploadItem.fileUrl
        do {
            fileData = try Data(contentsOf: fileUrlToUse)
            print("✅ Successfully read file data: \(fileData.count) bytes from \(uploadItem.compressedFileUrl != nil ? "compressed" : "original") file")
        } catch {
            print("❌ Failed to read file data: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // Convert VideoSource to R2UploadService.VideoSource
        let r2Source: R2UploadService.VideoSource
        switch uploadItem.source {
        case .photosPicker:
            r2Source = .photosPicker
        case .filesApp:
            r2Source = .filesApp
        case .unknown:
            r2Source = .unknown
        }
        
        r2UploadService.uploadVideo(videoData: fileData, fileName: uploadItem.fileName, source: r2Source) { [weak self] progress in
            DispatchQueue.main.async {
                // Scale R2 progress to the remaining percentage after thumbnail
                let totalProgress = thumbnailWeight + (progress * mainFileWeight)
                let progressPercent = Int(totalProgress * 100)
                // Only log at significant milestones to reduce log noise
                if progressPercent % 25 == 0 || progressPercent >= 95 {
                    print("📊 UploadQueueManager: Progress \(progressPercent)% (main file: \(Int(progress * 100))%)")
                }
                self?.updateUploadProgress(uploadItem.id, progress: totalProgress)
            }
        } completion: { [weak self] result in
            switch result {
            case .success(let videoMetadata):
                print("✅ Main file upload successful: \(videoMetadata.fileUrl)")
                completion(.success((thumbnailUrl, videoMetadata.fileUrl)))
            case .failure(let error):
                print("❌ Main file upload failed: \(error.localizedDescription)")
                // Use smart retry logic instead of immediate failure
                self?.handleUploadFailure(uploadItem, error: error.localizedDescription, completion: completion)
            }
        }
    }
    
    private func updateUploadStatus(_ uploadId: UUID, status: UploadStatus) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            activeUploads[index].status = status
            persistAllUploads()
        }
    }
    
    private func updateUploadProgress(_ uploadId: UUID, progress: Double) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            let progressPercent = Int(progress * 100)
            // Only log at significant milestones to reduce log noise
            if progressPercent % 25 == 0 || progressPercent >= 95 {
                print("📊 Upload \(String(uploadId.uuidString.prefix(8))): \(progressPercent)%")
            }
            
            // Create a completely new array to force SwiftUI to detect changes
            var newActiveUploads = activeUploads
            let previousProgress = newActiveUploads[index].progress
            let previousUpdateTime = newActiveUploads[index].lastProgressUpdate
            let currentTime = Date()
            
            newActiveUploads[index].progress = progress
            newActiveUploads[index].lastUpdated = currentTime
            newActiveUploads[index].lastProgressUpdate = currentTime
            
            // Calculate upload speed and ETA
            if progress > previousProgress && previousProgress > 0 {
                let progressDelta = progress - previousProgress
                let timeDelta = currentTime.timeIntervalSince(previousUpdateTime)
                
                if timeDelta > 0 {
                    // Calculate speed in MB/s
                    let totalFileSizeMB = Double(newActiveUploads[index].fileSize) / (1024 * 1024)
                    let speedMBps = (progressDelta * totalFileSizeMB) / timeDelta
                    newActiveUploads[index].uploadSpeed = speedMBps
                    
                    // Calculate ETA
                    let remainingProgress = 1.0 - progress
                    if speedMBps > 0 {
                        let remainingSizeMB = remainingProgress * totalFileSizeMB
                        newActiveUploads[index].estimatedTimeRemaining = remainingSizeMB / speedMBps
                    }
                }
            }
            
            // Replace the entire array
            activeUploads = newActiveUploads
            
            // Force UI update
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } else {
            print("⚠️ Could not find upload with ID \(uploadId) to update progress")
        }
    }
    
    private func updateUploadSuccess(_ uploadId: UUID, thumbnailUrl: String, mainFileUrl: String) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            var upload = activeUploads[index]
            upload.status = .completed
            upload.progress = 1.0
            upload.uploadedThumbnailUrl = thumbnailUrl
            upload.uploadedFileUrl = mainFileUrl
            
            // Send success notification
            sendUploadCompleteNotification(upload)
            
            // Remove from active uploads (completed uploads go to profile)
            activeUploads.remove(at: index)
            persistAllUploads()
            
            // Stop timers if no more active uploads
            if activeUploads.isEmpty {
                stopProgressPersistenceTimer()
                stopNetworkMonitoring()
            }
            
            // Upload pod data to Firestore
            uploadPodData(upload: upload, thumbnailUrl: thumbnailUrl, mainFileUrl: mainFileUrl)
        }
    }
    
    private func updateUploadFailure(_ uploadId: UUID, error: Error) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            var upload = activeUploads[index]
            upload.status = .failed
            upload.errorMessage = error.localizedDescription
            
            // Send failure notification
            sendUploadFailedNotification(upload)
            
            // Move to failed uploads
            moveToFailed(upload)
            activeUploads.remove(at: index)
            persistAllUploads()
            
            // Stop timers if no more active uploads
            if activeUploads.isEmpty {
                stopProgressPersistenceTimer()
                stopNetworkMonitoring()
            }
        }
    }
    
    private func updateUploadFailure(_ uploadId: UUID, error: String) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            var upload = activeUploads[index]
            upload.status = .failed
            upload.errorMessage = error
            
            // Send failure notification
            sendUploadFailedNotification(upload)
            
            // Move to failed uploads
            moveToFailed(upload)
            activeUploads.remove(at: index)
            persistAllUploads()
            
            // Stop timers if no more active uploads
            if activeUploads.isEmpty {
                stopProgressPersistenceTimer()
                stopNetworkMonitoring()
            }
        }
    }
    
    
    private func moveToFailed(_ upload: UploadItem) {
        failedUploads.append(upload)
    }
    
    private func handleUploadFailure(_ upload: UploadItem, error: String, completion: @escaping (Result<(String, String), Error>) -> Void) {
        // First check if the upload still exists in active uploads (not cancelled)
        guard activeUploads.contains(where: { $0.id == upload.id }) else {
            print("🛑 Upload \(upload.podTitle) was cancelled, not retrying")
            completion(.failure(NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload was cancelled"])))
            return
        }
        
        // Check if we should retry
        if shouldRetryUpload(upload) {
            let retryDelay = calculateRetryDelay(for: upload.retryCount)
            print("🔄 Scheduling retry for \(upload.podTitle) in \(retryDelay) seconds (attempt \(upload.retryCount + 1))")
            
            // Update retry count
            updateUploadRetryCount(upload.id, retryCount: upload.retryCount + 1)
            
            // Create cancellable work item for retry
            let retryWorkItem = DispatchWorkItem { [weak self] in
                // Double-check the upload still exists before retrying
                guard let self = self, self.activeUploads.contains(where: { $0.id == upload.id }) else {
                    print("🛑 Upload \(upload.podTitle) was cancelled during retry delay, not retrying")
                    return
                }
                self.retryUpload(upload, completion: completion)
                self.pendingRetries.removeValue(forKey: upload.id)
            }
            
            // Store the work item for potential cancellation
            pendingRetries[upload.id] = retryWorkItem
            
            // Schedule retry
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay, execute: retryWorkItem)
        } else {
            // Move to failed uploads
            updateUploadFailure(upload.id, error: error)
            completion(.failure(NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
        }
    }
    
    private func updateUploadRetryCount(_ uploadId: UUID, retryCount: Int) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            activeUploads[index].retryCount = retryCount
            activeUploads[index].lastUpdated = Date()
            persistAllUploads()
        }
    }
    
    private func updateCompressionStatus(_ uploadId: UUID, isCompressing: Bool, progress: Double) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            activeUploads[index].isCompressing = isCompressing
            activeUploads[index].compressionProgress = progress
            activeUploads[index].lastUpdated = Date()
            persistAllUploads()
            
            // Force UI update
            objectWillChange.send()
        }
    }
    
    private func updateCompressionProgress(_ uploadId: UUID, progress: Double) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            activeUploads[index].compressionProgress = progress
            activeUploads[index].lastUpdated = Date()
            
            // Force UI update
            objectWillChange.send()
        }
    }
    
    private func updateCompressedFileUrl(_ uploadId: UUID, compressedFileUrl: URL) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            activeUploads[index].compressedFileUrl = compressedFileUrl
            activeUploads[index].lastUpdated = Date()
            persistAllUploads()
        }
    }
    
    private func retryUpload(_ upload: UploadItem, completion: @escaping (Result<(String, String), Error>) -> Void) {
        print("🔄 Retrying upload: \(upload.podTitle)")
        
        // Reset progress and status
        updateUploadStatus(upload.id, status: .uploading)
        updateUploadProgress(upload.id, progress: 0.0)
        
        // Get current user for retry
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No user logged in for retry")
            updateUploadFailure(upload.id, error: "No user logged in")
            completion(.failure(NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        let user = User(
            uid: currentUser.uid,
            username: currentUser.displayName ?? "User",
            fullname: currentUser.displayName ?? "User",
            profileImageUrl: currentUser.photoURL?.absoluteString ?? "",
            email: currentUser.email ?? "",
            isVerified: false
        )
        
        // Retry the upload
        uploadCompletePod(uploadItem: upload, user: user, completion: completion)
    }
    
    private func uploadPodData(upload: UploadItem, thumbnailUrl: String, mainFileUrl: String) {
        // Process the pod using OpenAI with fallback
        Task {
            let processedPod = await openAIProcessor.processPodWithFallback(
                title: upload.podTitle,
                description: upload.podDescription,
                userTags: upload.tags.isEmpty ? nil : upload.tags,
                originalProcessor: aiProcessor
            )
            
            // Upload to Firestore
            let db = Firestore.firestore()
            let uniqueID = UUID().uuidString
            let podRef = db.collection("pods").document(uniqueID)
            
            let currentTime = Timestamp()
            var podData: [String: Any] = [
                "title": upload.podTitle,
                "titleLowercased": upload.podTitle.lowercased(),
                "timestamp": currentTime,
                "description": upload.podDescription,
                "fileUrl": mainFileUrl,
                "thumbnailUrl": thumbnailUrl,
                "userId": upload.userId,
                "likes": 0,
                "views": 0,
                "shares": 0,
                "comments": 0,
                "saves": 0,
                "fileSize": upload.fileSize,
                "category": processedPod.category,
                "keywords": processedPod.keywords,
                "isActive": true,
                "createdAt": currentTime,
                "updatedAt": currentTime,
                "version": 1,
                "isReported": false,
                "moderationStatus": "approved",
                "contentWarnings": []
            ]
            
            // Only add duration and mimeType if they have values (Firestore doesn't like nil)
            // You can extract these from the file metadata if needed
            // podData["duration"] = extractedDuration
            // podData["mimeType"] = extractedMimeType
            
            podRef.setData(podData) { error in
                if let error = error {
                    print("❌ Error uploading pod data: \(error.localizedDescription)")
                } else {
                    print("✅ Pod data uploaded successfully")
                    
                    // Increment user's pod count
                    self.incrementUserPodCount(userId: upload.userId)
                    
                    // Post notification to refresh profile views AFTER Firestore upload completes
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("UploadCompleted"), object: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - User Pod Count Management
    
    /// Increments the user's pod count atomically
    private func incrementUserPodCount(userId: String) {
        let userRef = Firestore.firestore().collection("users").document(userId)
        
        userRef.updateData([
            "podCount": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("❌ Failed to increment user pod count: \(error)")
            } else {
                print("✅ User pod count incremented successfully for user: \(userId)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func persistAllUploads() {
        persistUploads(activeUploads, key: activeUploadsKey)
        persistUploads(failedUploads, key: failedUploadsKey)
    }
    
    private func persistUploads(_ uploads: [UploadItem], key: String) {
        do {
            // Revert to full persistence to preserve background-resume behavior
            let data = try JSONEncoder().encode(uploads)
            userDefaults.set(data, forKey: key)
            print("💾 Persisted \(uploads.count) uploads to \(key)")
        } catch {
            print("❌ Failed to persist uploads to \(key): \(error)")
        }
    }
    
    private func loadPersistedUploads() {
        loadUploads(key: activeUploadsKey) { uploads in
            DispatchQueue.main.async {
                self.activeUploads = uploads
            }
        }
        
        loadUploads(key: failedUploadsKey) { uploads in
            DispatchQueue.main.async {
                self.failedUploads = uploads
            }
        }
        
        // Handle interrupted uploads from previous session
        handleInterruptedUploads()
    }
    
    private func loadUploads(key: String, completion: @escaping ([UploadItem]) -> Void) {
        guard let data = userDefaults.data(forKey: key) else {
            completion([])
            return
        }
        
        do {
            // Prefer full format
            let uploads = try JSONDecoder().decode([UploadItem].self, from: data)
            print("📂 Loaded \(uploads.count) uploads from \(key)")
            completion(uploads)
        } catch {
            // Fallback: try lightweight format if present
            if let persisted = try? JSONDecoder().decode([PersistedUploadItem].self, from: data) {
                let restored = persisted.map { $0.toUploadItem() }
                print("📂 Loaded \(restored.count) uploads (lightweight fallback) from \(key)")
                completion(restored)
                return
            }
            print("❌ Failed to load uploads from \(key): \(error)")
            completion([])
        }
    }

    // Lightweight persisted copy (omits large/transient fields like thumbnailImage and speeds)
    private struct PersistedUploadItem: Codable {
        let id: UUID
        let fileName: String
        let fileUrl: URL
        let fileSize: Int64
        let podTitle: String
        let podDescription: String
        let tags: [String]
        let source: VideoSource
        let userId: String
        let progress: Double
        let status: UploadStatus
        let errorMessage: String?
        let uploadedThumbnailUrl: String?
        let uploadedFileUrl: String?
        let startTime: Date
        let lastUpdated: Date
        let retryCount: Int
        // Compression
        let compressionProgress: Double
        let isCompressing: Bool
        let compressedFileUrl: URL?

        init(from upload: UploadItem) {
            id = upload.id
            fileName = upload.fileName
            fileUrl = upload.fileUrl
            fileSize = upload.fileSize
            podTitle = upload.podTitle
            podDescription = upload.podDescription
            tags = upload.tags
            source = upload.source
            userId = upload.userId
            progress = upload.progress
            status = upload.status
            errorMessage = upload.errorMessage
            uploadedThumbnailUrl = upload.uploadedThumbnailUrl
            uploadedFileUrl = upload.uploadedFileUrl
            startTime = upload.startTime
            lastUpdated = upload.lastUpdated
            retryCount = upload.retryCount
            compressionProgress = upload.compressionProgress
            isCompressing = upload.isCompressing
            compressedFileUrl = upload.compressedFileUrl
        }

        func toUploadItem() -> UploadItem {
            var item = UploadItem(
                id: id,
                fileName: fileName,
                fileUrl: fileUrl,
                fileSize: fileSize,
                podTitle: podTitle,
                podDescription: podDescription,
                tags: tags,
                thumbnailImage: nil, // intentionally not persisted
                source: source,
                user: User(uid: userId, username: "", fullname: "", profileImageUrl: "", email: "", isVerified: false)
            )
            item.progress = progress
            item.status = status
            item.errorMessage = errorMessage
            item.uploadedThumbnailUrl = uploadedThumbnailUrl
            item.uploadedFileUrl = uploadedFileUrl
            item.startTime = startTime
            item.lastUpdated = lastUpdated
            item.retryCount = retryCount
            item.compressionProgress = compressionProgress
            item.isCompressing = isCompressing
            item.compressedFileUrl = compressedFileUrl
            // uploadSpeed/ETA intentionally reset; recalculated during runtime
            return item
        }
    }
    
    // MARK: - Progress Persistence
    
    private func startProgressPersistenceTimer() {
        // Only start timer if we have active uploads
        guard !activeUploads.isEmpty else {
            print("📊 No active uploads - skipping persistence timer")
            return
        }
        
        progressPersistenceTimer?.invalidate()
        progressPersistenceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Only persist if we still have active uploads
            if let self = self, !self.activeUploads.isEmpty {
                self.persistAllUploads()
            } else {
                // Stop timer if no more active uploads
                self?.stopProgressPersistenceTimer()
            }
        }
        print("📊 Started progress persistence timer")
    }
    
    private func stopProgressPersistenceTimer() {
        progressPersistenceTimer?.invalidate()
        progressPersistenceTimer = nil
        print("📊 Stopped progress persistence timer")
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasAvailable = self?.isNetworkAvailable ?? true
                self?.isNetworkAvailable = path.status == .satisfied
                
                // Only log if status actually changed
                if wasAvailable != (self?.isNetworkAvailable ?? true) {
                    print("🌐 Network status changed: \(self?.isNetworkAvailable == true ? "Available" : "Unavailable")")
                }
                
                // If network becomes available and we have failed uploads, consider retrying
                if self?.isNetworkAvailable == true && !(self?.failedUploads.isEmpty ?? true) {
                    print("🌐 Network restored - considering retry of failed uploads")
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func startNetworkMonitoring() {
        // Only start if we have uploads that might need retrying
        if !activeUploads.isEmpty || !failedUploads.isEmpty {
            print("🌐 Starting network monitoring for upload retry logic")
        }
    }
    
    private func stopNetworkMonitoring() {
        // Only stop if we have no uploads at all
        if activeUploads.isEmpty && failedUploads.isEmpty {
            print("🌐 Stopping network monitoring - no uploads to monitor")
        }
    }
    
    // MARK: - Smart Retry Logic
    
    private func calculateRetryDelay(for retryCount: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(retryCount))
        let jitter = Double.random(in: 0.5...1.5) // Add randomness to prevent thundering herd
        let finalDelay = min(exponentialDelay * jitter, maxRetryDelay)
        
        print("🔄 Retry delay for attempt \(retryCount): \(finalDelay) seconds")
        return finalDelay
    }
    
    private func shouldRetryUpload(_ upload: UploadItem) -> Bool {
        // Don't retry if we've exceeded max attempts
        guard upload.retryCount < maxRetryAttempts else {
            print("🔄 Upload \(upload.podTitle) exceeded max retry attempts (\(maxRetryAttempts))")
            return false
        }
        
        // Don't retry if network is unavailable
        guard isNetworkAvailable else {
            print("🔄 Upload \(upload.podTitle) not retried - network unavailable")
            return false
        }
        
        // Don't retry if upload is too old (more than 24 hours)
        let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
        if Date().timeIntervalSince(upload.startTime) > maxAge {
            print("🔄 Upload \(upload.podTitle) not retried - too old (\(Date().timeIntervalSince(upload.startTime)/3600) hours)")
            return false
        }
        
        return true
    }
    
    // MARK: - Push Notifications
    
    private func sendUploadCompleteNotification(_ upload: UploadItem) {
        let content = UNMutableNotificationContent()
        content.title = "Upload Complete"
        content.body = "Your pod '\(upload.podTitle)' has been successfully uploaded!"
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "upload_complete_\(upload.id.uuidString)",
            content: content,
            trigger: nil // Send immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send upload complete notification: \(error)")
            } else {
                print("✅ Sent upload complete notification for: \(upload.podTitle)")
            }
        }
    }
    
    private func sendUploadFailedNotification(_ upload: UploadItem) {
        let content = UNMutableNotificationContent()
        content.title = "Upload Failed"
        content.body = "Your pod '\(upload.podTitle)' failed to upload."
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "upload_failed_\(upload.id.uuidString)",
            content: content,
            trigger: nil // Send immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send upload failed notification: \(error)")
            } else {
                print("✅ Sent upload failed notification for: \(upload.podTitle)")
            }
        }
    }
    
    private func sendUploadInterruptedNotification(_ upload: UploadItem) {
        let content = UNMutableNotificationContent()
        content.title = "Upload Canceled"
        content.body = "The app was closed, so '\(upload.podTitle)' was canceled."
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "upload_interrupted_\(upload.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send upload interrupted notification: \(error)")
            } else {
                print("✅ Sent upload interrupted notification for: \(upload.podTitle)")
            }
        }
    }
    
    // MARK: - App Lifecycle Management
    
    private func setupAppLifecycleObservers() {
        // Save uploads when app goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Restore uploads when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Save uploads when app will terminate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("📱 App entered background - saving upload state")
        saveUploadState()
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 App became active - checking for interrupted uploads")
        handleInterruptedUploads()
    }
    
    @objc private func appWillTerminate() {
        print("📱 App will terminate - marking all uploads as failed")
        // New behavior: do NOT persist interrupted uploads. Notify user (interrupted), then delete entirely.
        var terminatedCount = 0
        for upload in activeUploads where upload.status == .uploading || upload.status == .pending {
            sendUploadInterruptedNotification(upload)
            terminatedCount += 1
        }
        activeUploads.removeAll()
        persistAllUploads()
        // Set flag so UI can show an in-app alert on next launch
        if terminatedCount > 0 {
            userDefaults.set(true, forKey: terminationFlagKey)
            userDefaults.set(terminatedCount, forKey: terminatedCountKey)
        }
    }
    
    private func saveUploadState() {
        // Only save state when app goes to background (not terminating)
        // This allows uploads to continue if user just switches apps
        persistAllUploads()
    }
    
    private func markAllUploadsAsFailed() {
        // Deprecated behavior retained for backwards compatibility (no-op now)
        print("ℹ️ markAllUploadsAsFailed called (no-op under new policy)")
    }
    
    private func handleInterruptedUploads() {
        // Check for uploads that were marked as failed due to app termination
        let interruptedUploads = failedUploads.filter { 
            $0.errorMessage?.contains("app was closed") == true 
        }
        
        if !interruptedUploads.isEmpty {
            print("📱 Found \(interruptedUploads.count) interrupted uploads from app termination")
            notifyUserAboutInterruptedUploads(interruptedUploads)
        }
        
        // Also check for stuck uploads
        clearStuckUploads()
    }
    
    private func notifyUserAboutInterruptedUploads(_ uploads: [UploadItem]) {
        DispatchQueue.main.async {
            // Post notification for UI to show alert
            NotificationCenter.default.post(
                name: NSNotification.Name("InterruptedUploadsDetected"),
                object: nil,
                userInfo: ["uploads": uploads]
            )
        }
    }

    /// Check if the previous session had uploads cleared due to termination and notify UI
    private func checkTerminationFlagOnLaunch() {
        let hadTerminated = userDefaults.bool(forKey: terminationFlagKey)
        if hadTerminated {
            let count = userDefaults.integer(forKey: terminatedCountKey)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UploadsClearedDueToTermination"),
                    object: nil,
                    userInfo: ["count": count]
                )
            }
            userDefaults.removeObject(forKey: terminationFlagKey)
            userDefaults.removeObject(forKey: terminatedCountKey)
        }
    }

    // MARK: - Launch Migration: Move persisted active uploads to failed
    private func migrateInterruptedActiveUploadsOnLaunch() {
        DispatchQueue.main.async {
            // Find any uploads that persisted as active (pending/uploading) from a previous session
            let interrupted = self.activeUploads.filter { $0.status == .uploading || $0.status == .pending }
            guard !interrupted.isEmpty else { return }

            // Convert them to failed with a clear message
            let failedConverted: [UploadItem] = interrupted.map { upload in
                var u = upload
                u.status = .failed
                u.errorMessage = "Upload interrupted - app was closed"
                u.lastUpdated = Date()
                return u
            }

            // Append to failed list and remove from active
            self.failedUploads.append(contentsOf: failedConverted)
            let interruptedIds = Set(interrupted.map { $0.id })
            self.activeUploads.removeAll { interruptedIds.contains($0.id) }

            // Persist and notify UI
            self.persistAllUploads()
            self.notifyUserAboutInterruptedUploads(failedConverted)
            print("📱 Migrated \(failedConverted.count) interrupted active uploads to failed on launch")
        }
    }
    
    // MARK: - Background App Refresh
    
    func retryInterruptedUploads() {
        print("🔄 Background app refresh - retrying interrupted uploads")
        
        // Get current user from Firebase Auth
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No current user found for background retry")
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
        
        let interruptedUploads = failedUploads.filter { $0.errorMessage?.contains("interrupted") == true }
        
        for upload in interruptedUploads {
            // Move back to active uploads
            var retryUpload = upload
            retryUpload.status = .pending
            retryUpload.progress = 0.0
            retryUpload.errorMessage = nil
            
            DispatchQueue.main.async {
                self.failedUploads.removeAll { $0.id == upload.id }
                self.activeUploads.append(retryUpload)
                self.persistAllUploads()
            }
            
            // Start retry with user object
            startUpload(for: retryUpload, user: user)
        }
    }
    
    // MARK: - Smart Retry Logic
    
    func retryFailedUpload(_ upload: UploadItem, user: User) {
        print("🔄 Retrying failed upload: \(upload.fileName)")
        
        // Add exponential backoff delay for retries
        let retryDelay = calculateRetryDelay(for: upload)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
            self.retryUpload(upload, user: user)
        }
    }
    
    private func calculateRetryDelay(for upload: UploadItem) -> TimeInterval {
        // Simple exponential backoff: 1s, 2s, 4s, 8s, max 30s
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 30.0
        let retryCount = getRetryCount(for: upload)
        
        let delay = min(baseDelay * pow(2.0, Double(retryCount)), maxDelay)
        print("⏱️ Retry delay for \(upload.fileName): \(delay)s (attempt #\(retryCount + 1))")
        
        return delay
    }
    
    private func getRetryCount(for upload: UploadItem) -> Int {
        // You could store retry count in the UploadItem model
        // For now, return 0 (first retry)
        return 0
    }
    
    // MARK: - R2 Service Binding
    
    private func setupR2ServiceBinding() {
        // Bind R2UploadService properties to update upload progress
        // This is already handled in the upload methods above
    }
}
