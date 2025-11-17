//
//  R2UploadService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 7/13/25.
//

import Foundation
import AVFoundation
import BackgroundTasks
import UIKit

class R2UploadService: ObservableObject {
    @Published var uploadProgress: Double = 0.0
    @Published var uploadStatus: String = ""
    @Published var isUploading: Bool = false
    @Published var uploadedVideoURL: String?
    @Published var errorMessage: String?
    @Published var uploadSpeed: String = "" // MB/s
    @Published var timeRemaining: String = "" // ETA
    
    private var uploadTask: URLSessionUploadTask?
    private var uploadStartTime: Date?
    private var lastProgressUpdate: Date?
    private var lastProgressValue: Double = 0.0
    private var totalFileSize: Int64 = 0
    private var bytesUploaded: Int64 = 0
    
    // Background upload support
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundUploadTask: URLSessionUploadTask?
    private var backgroundUploadData: Data?
    private var backgroundUploadURL: URL?
    private var backgroundFileName: String?
    private var backgroundCompletion: ((Result<VideoMetadata, Error>) -> Void)?
    private var backgroundTaskTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        // No need for credential setup - using hardcoded credentials
    }
    
    deinit {
        // Clean up any remaining timers and background tasks
        endBackgroundTask()
        uploadTask?.cancel()
        backgroundUploadTask?.cancel()
    }
    
    // MARK: - Credential Management
    
    /// Check if R2 credentials are available
    var hasCredentials: Bool {
        return true // Always true with hardcoded credentials
    }
    
    // Custom delegate to track real upload progress
    class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
        weak var service: R2UploadService?
        var progressCallback: ((Double) -> Void)?
        
        init(service: R2UploadService, progressCallback: @escaping (Double) -> Void) {
            self.service = service
            self.progressCallback = progressCallback
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            DispatchQueue.main.async {
                guard let service = self.service else { return }
                
                service.bytesUploaded = totalBytesSent
                let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
                service.uploadProgress = progress
                
                // Call the progress callback to update UploadQueueManager
                let progressPercent = Int(progress * 100)
                // Only log at significant milestones to reduce log noise
                if progressPercent % 25 == 0 || progressPercent >= 95 {
                    print("📊 R2UploadService: Progress \(progressPercent)%")
                }
                self.progressCallback?(progress)
                
                // Update speed calculation
                let now = Date()
                if let startTime = service.uploadStartTime {
                    let timeElapsed = now.timeIntervalSince(startTime)
                    let totalMB = Double(totalBytesSent) / (1024 * 1024)
                    let speedMBps = timeElapsed > 0 ? totalMB / timeElapsed : 0
                    
                    service.uploadSpeed = String(format: "%.1f MB/s", speedMBps)
                    
                    // Calculate ETA
                    if progress > 0 {
                        let remainingProgress = 1.0 - progress
                        let estimatedTimeRemaining = (timeElapsed / progress) * remainingProgress
                        
                        let minutes = Int(estimatedTimeRemaining) / 60
                        let seconds = Int(estimatedTimeRemaining) % 60
                        if minutes > 0 {
                            service.timeRemaining = String(format: "%dm %ds remaining", minutes, seconds)
                        } else {
                            service.timeRemaining = String(format: "%ds remaining", seconds)
                        }
                    }
                }
            }
        }
    }
    
    struct VideoMetadata {
        let fileUrl: String
        let fileName: String
        let fileSize: Int64
        let uploadDate: Date
    }
    
    enum VideoSource {
        case photosPicker
        case filesApp
        case unknown
    }
    
    func uploadVideo(videoData: Data, fileName: String, source: VideoSource = .unknown, progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<VideoMetadata, Error>) -> Void) {
        isUploading = true
        uploadProgress = 0.0
        uploadStatus = "Getting upload URL..."
        errorMessage = nil
        uploadSpeed = ""
        timeRemaining = ""
        uploadStartTime = Date()
        lastProgressUpdate = Date()
        lastProgressValue = 0.0
        totalFileSize = Int64(videoData.count)
        
        // Generate unique filename
        let uniqueFileName = R2Config.generateFileName(originalName: fileName)
        
        // Check if we should use Firebase-style optimizations
        let fileSize = Int64(videoData.count)
        let shouldUseOptimizations = fileSize > 10 * 1024 * 1024 // 10MB threshold
        
        if shouldUseOptimizations {
            uploadStatus = "Preparing optimized upload..."
            print("🚀 Using Firebase-style optimizations for \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) file")
        }
        
        // Compress video if needed (only for video files, not audio)
        compressVideoIfNeeded(videoData: videoData, fileName: fileName, source: source) { [weak self] processedData in
            guard let self = self else { return }
            
            self.uploadStatus = "Uploading main file..."
            
            // Get upload URL from worker
            self.getUploadURL(fileName: uniqueFileName) { result in
                switch result {
                case .success(let presignedURL):
                    self.uploadToURL(videoData: processedData, uploadURL: presignedURL, uniqueFileName: uniqueFileName, progressCallback: progressCallback, completion: completion)
                case .failure(let error):
                    print("❌ Failed to get presigned URL from worker: \(error.localizedDescription)")
                    completion(.failure(error))
            }
        }
        }
    }
    
    // MARK: - Error Handling
    
    /// Handles upload errors with simple error reporting
    private func handleUploadError(error: Error, completion: @escaping (Result<VideoMetadata, Error>) -> Void) {
        print("❌ Upload error: \(error.localizedDescription)")
        
        // Stop uploading and show error
        isUploading = false
        uploadStatus = "Upload failed"
        errorMessage = error.localizedDescription
        completion(.failure(error))
    }
    
    // MARK: - Video Compression
    
    /// Compresses video/audio files based on new smart compression rules
    private func compressVideoIfNeeded(videoData: Data, fileName: String, source: VideoSource, completion: @escaping (Data) -> Void) {
        // Upload is already pre-processed in UploadPodView. Do not re-compress here.
        print("🛑 R2UploadService: Skipping compression (passthrough)")
        completion(videoData)
    }
    
    private func getUploadURL(fileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Use environment-aware worker URL
        let workerURLString = "\(EnvironmentConfig.r2UploadWorkerURL)/?filename=\(fileName)"
        
        print("🔍 Environment: \(EnvironmentConfig.isProduction ? "Production" : "Development")")
        print("🔍 Worker URL: \(workerURLString)")
        
        guard let workerURL = URL(string: workerURLString) else {
            completion(.failure(NSError(domain: "WorkerUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid worker URL"])))
            return
        }
        
        print("Calling worker at: \(workerURLString)")
        
        URLSession.shared.dataTask(with: workerURL) { data, response, error in
            if let error = error {
                print("❌ Worker network error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
                if let nsError = error as NSError? {
                    print("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("❌ User info: \(nsError.userInfo)")
                }
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Worker response status: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Worker response: \(responseString)")
                }
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let uploadURLString = json["url"],
                  let uploadURL = URL(string: uploadURLString) else {
                print("❌ Failed to parse worker response")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                completion(.failure(NSError(domain: "WorkerUpload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get upload URL from worker"])))
                return
            }
            
            print("✅ Worker returned URL: \(uploadURLString)")
        print("⏰ URL received at: \(Date())")
            completion(.success(uploadURL))
        }.resume()
    }
    
    // Fast upload entrypoint: use presigned URL from worker
    private func uploadToURL(videoData: Data, uploadURL: URL, uniqueFileName: String, progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<VideoMetadata, Error>) -> Void) {
        print("🚀 Using presigned URL from worker: \(uploadURL.absoluteString)")
        fastSinglePutUpload(videoData: videoData, presignedURL: uploadURL, uniqueFileName: uniqueFileName, progressCallback: progressCallback, completion: completion)
    }

    // Fast upload method: basic session with progress tracking but no problematic config
    private func fastSinglePutUpload(videoData: Data, presignedURL: URL, uniqueFileName: String, progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<VideoMetadata, Error>) -> Void) {
        let uploadStartTime = Date()
        print("⏰ Upload started at: \(uploadStartTime)")
        
        // Use basic session configuration
        let config = URLSessionConfiguration.default
        // Only set basic timeout values - no connection persistence settings
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        
        let delegate = UploadProgressDelegate(service: self, progressCallback: progressCallback)
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        
        print("📤 Starting fast upload: \(videoData.count / 1024 / 1024)MB to \(presignedURL.absoluteString)")
        print("⏰ Upload starting at: \(Date())")
        
        let task = session.uploadTask(with: request, from: videoData) { data, resp, err in
            DispatchQueue.main.async {
                if let err = err { 
                    print("❌ Upload task error: \(err.localizedDescription)")
                    completion(.failure(err))
                    return 
                }
                
                guard let http = resp as? HTTPURLResponse else {
                    print("❌ No HTTP response received")
                    completion(.failure(NSError(domain: "R2", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])))
                    return
                }
                
                print("📡 Upload response: status=\(http.statusCode)")
                print("⏰ Upload completed at: \(Date()) (duration: \(Date().timeIntervalSince(uploadStartTime)) seconds)")
                
                if (200...299).contains(http.statusCode) {
                    print("✅ Upload successful with status \(http.statusCode)")
                    let videoURL = R2Config.getVideoURL(fileName: uniqueFileName)
                    let meta = VideoMetadata(fileUrl: videoURL, fileName: uniqueFileName, fileSize: Int64(videoData.count), uploadDate: Date())
                    completion(.success(meta))
                } else {
                    print("❌ Upload failed with status \(http.statusCode)")
                    if let responseBody = data, let bodyString = String(data: responseBody, encoding: .utf8) {
                        print("❌ Response body: \(bodyString)")
                    }
                    let errorMsg = "Upload failed with status \(http.statusCode)"
                    completion(.failure(NSError(domain: "R2", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                }
            }
        }
        
        // Store the task for cancellation
        uploadTask = task
        task.resume()
    }
    
    func cancelUpload() {
        uploadTask?.cancel()
        backgroundUploadTask?.cancel()
        endBackgroundTask()
        isUploading = false
        uploadStatus = "Upload cancelled"
        print("🛑 Upload cancelled and all timers cleaned up")
    }
    
    // MARK: - Background Upload Support
    
    private func beginBackgroundTask() {
        // End any existing background task
        endBackgroundTask()
        
        // Start new background task with optimized expiration handler
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "R2Upload") { [weak self] in
            // This is called when the background task is about to expire
            print("⚠️ Background task expiring, attempting to complete upload...")
            // Give the upload a short time to finish, then end the task
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self?.endBackgroundTask()
            }
        }
        
        print("🔄 Background task started: \(backgroundTaskID.rawValue)")
        
        // Only start extension timer if we're actually uploading
        // This prevents unnecessary battery drain when not uploading
        if isUploading {
            startBackgroundTaskExtensionTimer()
        }
    }
    
    private func startBackgroundTaskExtensionTimer() {
        // Stop any existing timer
        backgroundTaskTimer?.invalidate()
        
        // Only extend if we're still uploading and have a valid background task
        guard isUploading && backgroundTaskID != .invalid else {
            return
        }
        
        // Use a more efficient approach: only extend when we're close to expiration
        // iOS typically gives 30 seconds, so we extend at 20 seconds
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] timer in
            guard let self = self, self.isUploading else {
                timer.invalidate()
                return
            }
            
            // Only extend if we're still actively uploading
            if self.backgroundTaskID != .invalid {
                print("🔄 Extending background task before expiration...")
                
                // End the current task
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                
                // Start a new one
                self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "R2Upload") { [weak self] in
                print("⚠️ Extended background task expiring...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.endBackgroundTask()
                }
            }
            
                print("🔄 Background task extended: \(self.backgroundTaskID.rawValue)")
                
                // Schedule the next extension
                self.startBackgroundTaskExtensionTimer()
            }
        }
    }
    
    private func endBackgroundTask() {
        // Stop the extension timer first
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil
        
        // End the background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            print("🔄 Background task ended: \(backgroundTaskID.rawValue)")
            backgroundTaskID = .invalid
        }
    }
    
    // Resume background upload if app becomes active
    func resumeBackgroundUpload() {
        guard let data = backgroundUploadData,
              let url = backgroundUploadURL,
              let fileName = backgroundFileName,
              let completion = backgroundCompletion else {
            return
        }
        
        if isUploading {
            print("🔄 Resuming background upload...")
            uploadStatus = "Resuming upload..."
            uploadToURL(videoData: data, uploadURL: url, uniqueFileName: fileName, progressCallback: { _ in }, completion: completion)
        }
    }
    
    // Clean up background upload data
    func cleanupBackgroundUpload() {
        backgroundUploadData = nil
        backgroundUploadURL = nil
        backgroundFileName = nil
        backgroundCompletion = nil
        endBackgroundTask()
    }
    
    // MARK: - Network Utility Methods
    
    // Provide speed recommendations
    func getSpeedRecommendation() -> String {
        let speedMBps = Double(uploadSpeed.replacingOccurrences(of: " MB/s", with: "")) ?? 0
        let isCellular = isOnCellularNetwork()
        
        if isCellular {
            switch speedMBps {
            case 0..<0.1:
                return "Very slow cellular - try moving to better signal area"
            case 0.1..<0.5:
                return "Slow cellular - consider waiting for better signal"
            case 0.5..<1.0:
                return "Moderate cellular speed - upload will take time"
            case 1.0..<2.0:
                return "Good cellular speed!"
            default:
                return "Excellent cellular speed!"
            }
        } else {
            switch speedMBps {
            case 0..<1:
                return "Slow connection - consider using WiFi"
            case 1..<3:
                return "Good speed for most uploads"
            case 3..<10:
                return "Excellent upload speed!"
            default:
                return "Very fast connection!"
            }
        }
    }
    
    // Check if user should switch to WiFi
    func shouldSwitchToWiFi() -> Bool {
        let speedMBps = Double(uploadSpeed.replacingOccurrences(of: " MB/s", with: "")) ?? 0
        let isCellular = isOnCellularNetwork()
        
        // Suggest WiFi if cellular speed is very slow
        return isCellular && speedMBps < 0.3
    }
    
    // Get cellular upload time estimate
    func getCellularUploadEstimate(fileSizeMB: Double) -> String {
        let speedMBps = Double(uploadSpeed.replacingOccurrences(of: " MB/s", with: "")) ?? 0.1
        
        if speedMBps <= 0 {
            return "Calculating..."
        }
        
        let estimatedSeconds = fileSizeMB / speedMBps
        let minutes = Int(estimatedSeconds) / 60
        let seconds = Int(estimatedSeconds) % 60
        
        if minutes > 0 {
            return "~\(minutes)m \(seconds)s on cellular"
        } else {
            return "~\(seconds)s on cellular"
        }
    }
    
    private func isOnCellularNetwork() -> Bool {
        // Simple heuristic based on upload speed
        let speedMBps = Double(uploadSpeed.replacingOccurrences(of: " MB/s", with: "")) ?? 0
        
        // If speed is consistently low, likely cellular
        if speedMBps < 0.5 && !uploadSpeed.isEmpty {
            return true
        }
        
        // Check network reachability (simplified)
        return false // Default to WiFi, will be updated based on actual performance
    }
}