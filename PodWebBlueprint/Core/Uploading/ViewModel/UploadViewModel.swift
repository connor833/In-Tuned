import Foundation
import UIKit
import AVFoundation
import FirebaseStorage

class UploadViewModel: ObservableObject {
    @Published var uploadProgress: Double = 0.0
    @Published var uploadStatus: String = ""
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?
    @Published var uploadSpeed: String = ""
    @Published var timeRemaining: String = ""
    
    private let r2UploadService = R2UploadService()
    private let storageUploader = StorageUploader()
    
    init() {
        // Bind R2UploadService properties to this ViewModel
        r2UploadService.$uploadProgress
            .assign(to: &$uploadProgress)
        r2UploadService.$uploadStatus
            .assign(to: &$uploadStatus)
        r2UploadService.$isUploading
            .assign(to: &$isUploading)
        r2UploadService.$errorMessage
            .assign(to: &$errorMessage)
        r2UploadService.$uploadSpeed
            .assign(to: &$uploadSpeed)
        r2UploadService.$timeRemaining
            .assign(to: &$timeRemaining)
    }
    
    func uploadCompletePod(thumbnailImage: UIImage?, fileUrl: URL, fileName: String, source: R2UploadService.VideoSource = .unknown, completion: @escaping (Result<(String, String), Error>) -> Void) {
        print("🔄 UploadViewModel.uploadCompletePod called")
        isUploading = true
        uploadProgress = 0.0
        uploadStatus = "Starting upload..."
        errorMessage = nil
        
        // Calculate total steps: thumbnail (5%) + main file (95%)
        let thumbnailWeight = 0.05
        let mainFileWeight = 0.95
        
        // Step 1: Upload thumbnail if provided
        if let thumbnailImage = thumbnailImage {
            print("🖼️ Starting thumbnail upload...")
            uploadStatus = "Uploading thumbnail..."
            storageUploader.uploadImage(image: thumbnailImage, progressHandler: { [weak self] progress in
                print("📊 Thumbnail progress: \(progress)")
                DispatchQueue.main.async {
                    // Scale thumbnail progress to 5% of total
                    self?.uploadProgress = progress * thumbnailWeight
                }
            }) { [weak self] thumbnailUrl in
                print("✅ Thumbnail upload complete: \(thumbnailUrl)")
                DispatchQueue.main.async {
                    // Keep progress at 5% and update status
                    self?.uploadProgress = thumbnailWeight
                    self?.uploadStatus = "Uploading main file..."
                    
                    // Step 2: Upload main file to R2
                    print("📁 Starting main file upload...")
                    self?.uploadMainFile(fileUrl: fileUrl, fileName: fileName, source: source, thumbnailWeight: thumbnailWeight, mainFileWeight: mainFileWeight) { result in
                        switch result {
                        case .success(let mainFileUrl):
                            print("✅ Main file upload complete: \(mainFileUrl)")
                            completion(.success((thumbnailUrl, mainFileUrl)))
                        case .failure(let error):
                            print("❌ Main file upload failed: \(error)")
                            self?.isUploading = false
                            self?.errorMessage = error.localizedDescription
                            completion(.failure(error))
                        }
                    }
                }
            }
        } else {
            print("📁 No thumbnail, uploading main file only...")
            // No thumbnail, just upload main file
            uploadStatus = "Uploading main file..."
            uploadMainFile(fileUrl: fileUrl, fileName: fileName, source: source, thumbnailWeight: 0.0, mainFileWeight: 1.0) { result in
                switch result {
                case .success(let mainFileUrl):
                    print("✅ Main file upload complete: \(mainFileUrl)")
                    completion(.success(("", mainFileUrl)))
                case .failure(let error):
                    print("❌ Main file upload failed: \(error)")
                    self.isUploading = false
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func uploadMainFile(fileUrl: URL, fileName: String, source: R2UploadService.VideoSource, thumbnailWeight: Double, mainFileWeight: Double, completion: @escaping (Result<String, Error>) -> Void) {
        print("📁 UploadViewModel - File name: \(fileName)")
        
        // Start accessing security-scoped resource
        let isAccessing = fileUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileUrl.stopAccessingSecurityScopedResource()
            }
        }
        
        // Try to read file data with better error handling
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileUrl)
            print("✅ Successfully read file data: \(fileData.count) bytes")
        } catch {
            print("❌ Failed to read file data: \(error.localizedDescription)")
            let uploadError = NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read file data: \(error.localizedDescription)"])
            completion(.failure(uploadError))
            return
        }
        
        // Optimize file for upload
        let optimizedData = optimizeFileForUpload(fileData: fileData, fileName: fileName)
        print("📊 File size: \(fileData.count / 1024 / 1024)MB -> \(optimizedData.count / 1024 / 1024)MB (optimized)")
        
        r2UploadService.uploadVideo(videoData: optimizedData, fileName: fileName, source: source) { [weak self] progress in
            DispatchQueue.main.async {
                // Scale R2 progress to the remaining percentage after thumbnail
                self?.uploadProgress = thumbnailWeight + (progress * mainFileWeight)
            }
        } completion: { result in
            DispatchQueue.main.async {
                self.isUploading = false
                self.uploadProgress = 1.0
                self.uploadStatus = "Upload completed!"
                
                // Release file access after upload is complete
                FileValidator.releaseFileAccess(for: fileUrl)
                
                switch result {
                case .success(let metadata):
                    print("R2 upload successful: \(metadata.fileUrl)")
                    completion(.success(metadata.fileUrl))
                case .failure(let error):
                    print("R2 upload failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func uploadFile(fileUrl: URL, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("R2 upload file called")
        
        // Start accessing security-scoped resource
        let isAccessing = fileUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileUrl.stopAccessingSecurityScopedResource()
            }
        }
        
        // Try to read file data with better error handling
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileUrl)
            print("✅ Successfully read file data: \(fileData.count) bytes")
        } catch {
            print("❌ Failed to read file data: \(error.localizedDescription)")
            let uploadError = NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read file data: \(error.localizedDescription)"])
            completion(.failure(uploadError))
            return
        }
        
        r2UploadService.uploadVideo(videoData: fileData, fileName: fileName) { progress in
            // Progress is handled by the published properties
        } completion: { result in
            // Release file access after upload is complete
            FileValidator.releaseFileAccess(for: fileUrl)
            
            switch result {
            case .success(let metadata):
                print("R2 upload successful: \(metadata.fileUrl)")
                completion(.success(metadata.fileUrl))
            case .failure(let error):
                print("R2 upload failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func uploadVideo(fileUrl: URL, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("R2 upload video called")
        
        // Start accessing security-scoped resource
        let isAccessing = fileUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileUrl.stopAccessingSecurityScopedResource()
            }
        }
        
        // Try to read video data with better error handling
        let videoData: Data
        do {
            videoData = try Data(contentsOf: fileUrl)
            print("✅ Successfully read video data: \(videoData.count) bytes")
        } catch {
            print("❌ Failed to read video data: \(error.localizedDescription)")
            let uploadError = NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read video data: \(error.localizedDescription)"])
            completion(.failure(uploadError))
            return
        }
        
        r2UploadService.uploadVideo(videoData: videoData, fileName: fileName) { progress in
            // Progress is handled by the published properties
        } completion: { result in
            // Release file access after upload is complete
            FileValidator.releaseFileAccess(for: fileUrl)
            
            switch result {
            case .success(let metadata):
                print("R2 video upload successful: \(metadata.fileUrl)")
                completion(.success(metadata.fileUrl))
            case .failure(let error):
                print("R2 video upload failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func cancelUpload() {
        r2UploadService.cancelUpload()
        isUploading = false
        uploadStatus = "Upload cancelled"
    }
    
    func getSpeedRecommendation() -> String {
        return r2UploadService.getSpeedRecommendation()
    }
    
    func shouldSwitchToWiFi() -> Bool {
        return r2UploadService.shouldSwitchToWiFi()
    }
    
    func getCellularUploadEstimate(fileSizeMB: Double) -> String {
        return r2UploadService.getCellularUploadEstimate(fileSizeMB: fileSizeMB)
    }
    
    // MARK: - File Optimization
    
    private func optimizeFileForUpload(fileData: Data, fileName: String) -> Data {
        // Check if it's a video file that can be compressed
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v"]
        
        if videoExtensions.contains(fileExtension) {
            return compressVideoData(fileData)
        }
        
        // For audio files, return as-is (they're usually already compressed)
        return fileData
    }
    
    private func compressVideoData(_ data: Data) -> Data {
        // For now, return original data
        // TODO: Implement video compression using AVFoundation
        // This would significantly reduce file size and upload time
        
        // Quick optimization: if file is very large (>100MB), suggest compression
        let fileSizeMB = Double(data.count) / (1024 * 1024)
        if fileSizeMB > 100 {
            print("⚠️ Large file detected (\(Int(fileSizeMB))MB) - consider implementing video compression")
        }
        
        return data
    }
}
