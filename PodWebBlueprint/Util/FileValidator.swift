import Foundation
import UIKit
import AVFoundation

/// Comprehensive file validation utility that ensures security and data integrity
/// for all file uploads in the app
struct FileValidator {
    
    // MARK: - File Type Definitions
    
    /// Supported file types for different upload categories
    enum FileCategory {
        case profileImage
        case podContent
        case thumbnail
        case userDataExport
        case accountData
        
        /// Maximum file size in bytes for this category
        var maxFileSize: Int64 {
            switch self {
            case .profileImage:
                return 5 * 1024 * 1024 // 5MB
            case .podContent:
                return 10 * 1024 * 1024 * 1024 // 10GB (practical limit for 1 hour content)
            case .thumbnail:
                return 2 * 1024 * 1024 // 2MB
            case .userDataExport:
                return 10 * 1024 * 1024 // 10MB
            case .accountData:
                return 1 * 1024 * 1024 // 1MB
            }
        }
        
        /// Allowed file extensions for this category
        var allowedExtensions: [String] {
            switch self {
            case .profileImage:
                return ["jpg", "jpeg", "png", "heic", "heif"]
            case .podContent:
                return ["mp4", "mov", "avi", "mkv", "m4v", "mpeg", "mpg", "3gp", "webm", "mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus"]
            case .thumbnail:
                return ["jpg", "jpeg", "png", "heic", "heif"]
            case .userDataExport:
                return ["json", "csv", "txt", "pdf"]
            case .accountData:
                return ["json", "txt", "pdf"]
            }
        }
        
        /// Allowed MIME types for this category
        var allowedMimeTypes: [String] {
            switch self {
            case .profileImage:
                return ["image/jpeg", "image/png", "image/heic", "image/heif"]
            case .thumbnail:
                return ["image/jpeg", "image/png", "image/heic", "image/heif"]
            case .podContent:
                return [
                    "video/mp4", "video/quicktime", "video/x-msvideo", "video/x-matroska",
                    "video/x-ms-wmv", "video/mpeg", "video/3gpp", "video/webm",
                    "audio/mpeg", "audio/wav", "audio/mp4", "audio/aac", "audio/flac",
                    "audio/mp2", "audio/x-ms-wma", "audio/ogg", "audio/opus"
                ]
            case .userDataExport:
                return ["application/json", "text/csv", "text/plain", "application/pdf"]
            case .accountData:
                return ["application/json", "text/plain", "application/pdf"]
            }
        }
    }
    
    // MARK: - Validation Result
    
    /// Result of file validation
    struct ValidationResult {
        let isValid: Bool
        let errorMessage: String?
        let fileSize: Int64
        let fileType: String
        let mimeType: String?
        
        static func success(fileSize: Int64, fileType: String, mimeType: String?) -> ValidationResult {
            return ValidationResult(isValid: true, errorMessage: nil, fileSize: fileSize, fileType: fileType, mimeType: mimeType)
        }
        
        static func failure(errorMessage: String, fileSize: Int64, fileType: String, mimeType: String?) -> ValidationResult {
            return ValidationResult(isValid: false, errorMessage: errorMessage, fileSize: fileSize, fileType: fileType, mimeType: mimeType)
        }
    }
    
    // MARK: - Main Validation Method
    
    /// Validates a file for upload based on the specified category
    /// - Parameters:
    ///   - fileURL: URL to the file to validate
    ///   - category: The file category to validate against
    /// - Returns: ValidationResult indicating if the file is valid
    static func validate(fileURL: URL, for category: FileCategory) async -> ValidationResult {
        print("🔍 FileValidator: Starting validation for URL: \(fileURL)")
        print("🔍 FileValidator: URL scheme: \(fileURL.scheme ?? "nil")")
        print("🔍 FileValidator: URL path: \(fileURL.path)")
        
        // Handle iCloud files differently
        let isICloudFile = fileURL.scheme == "x-apple-icloud" || 
                           fileURL.scheme == "x-apple-icloud-drive" ||
                           fileURL.path.contains("Mobile Documents") ||
                           fileURL.path.contains("com~apple~CloudDocs")
        
        if fileURL.scheme == "file" && isICloudFile {
            // This is a "local" iCloud file - handle it specially
            print("☁️ FileValidator: Local iCloud file detected in Mobile Documents folder")
            
            // For iCloud files, we need to request file access permissions
            // and handle the case where the file might not be fully accessible yet
        } else if fileURL.scheme == "file" {
            // Regular local file - check if it exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("❌ FileValidator: Local file does not exist at path: \(fileURL.path)")
                return ValidationResult.failure(
                    errorMessage: "File does not exist",
                    fileSize: 0,
                    fileType: "",
                    mimeType: nil
                )
            }
        } else if fileURL.scheme == "x-apple-icloud" || fileURL.scheme == "x-apple-icloud-drive" {
            // iCloud file - try to access it to trigger download
            print("☁️ FileValidator: iCloud file detected, attempting to access...")
            
            // For iCloud files, we'll try to read the file to trigger download
            // but we won't fail immediately if the path check fails
        } else {
            print("🔍 FileValidator: Unknown URL scheme: \(fileURL.scheme ?? "nil")")
        }
        
        // Get file attributes - handle both local and iCloud files
        var fileSize: Int64 = 0
        var attributes: [FileAttributeKey: Any]?
        
        if fileURL.scheme == "file" && isICloudFile {
            // Local iCloud file - try both methods
            print("☁️ FileValidator: Attempting to read local iCloud file...")
            
            // Request file access permissions first
            let hasAccess = await requestFileAccess(for: fileURL)
            if !hasAccess {
                print("❌ FileValidator: Could not get file access permissions")
                return ValidationResult.failure(
                    errorMessage: "Permission denied: Cannot access this file",
                    fileSize: 0,
                    fileType: "",
                    mimeType: nil
                )
            }
            
            // First try FileManager
            attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = attributes?[.size] as? Int64 ?? 0
            
            if fileSize == 0 {
                // If FileManager fails, try resourceValues
                print("☁️ FileValidator: FileManager failed, trying resourceValues...")
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isReadableKey])
                    fileSize = Int64(resourceValues.fileSize ?? 0)
                    print("☁️ FileValidator: ResourceValues file size: \(fileSize) bytes")
                    
                    // Check if file is readable
                    if resourceValues.isReadable == false {
                        print("⚠️ FileValidator: Local iCloud file is not readable yet (may still be downloading)")
                    }
                } catch {
                    print("⚠️ FileValidator: Could not read local iCloud file resource values: \(error)")
                }
            }
        } else if fileURL.scheme == "file" {
            // Regular local file - use FileManager
            attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = attributes?[.size] as? Int64 ?? 0
        } else {
            // Remote iCloud file - try to get size by reading the file
            print("☁️ FileValidator: Attempting to read remote iCloud file for size...")
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isReadableKey])
                fileSize = Int64(resourceValues.fileSize ?? 0)
                print("☁️ FileValidator: Remote iCloud file size: \(fileSize) bytes")
                
                // Check if file is readable
                if resourceValues.isReadable == false {
                    print("⚠️ FileValidator: Remote iCloud file is not readable yet (may still be downloading)")
                }
            } catch {
                print("⚠️ FileValidator: Could not read remote iCloud file resource values: \(error)")
            }
        }
        
        // Only fail for regular local files if we can't get size
        if fileSize == 0 && fileURL.scheme == "file" && !isICloudFile {
            return ValidationResult.failure(
                errorMessage: "Unable to read file attributes",
                fileSize: 0,
                fileType: "",
                mimeType: nil
            )
        }
        
        print("📏 FileValidator: Final file size: \(fileSize) bytes")
        
        // Get file extension
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Get MIME type
        let mimeType = getMimeType(for: fileExtension)
        
        // Validate file size
        if fileSize > category.maxFileSize {
            let maxSizeGB = category.maxFileSize / (1024 * 1024 * 1024)
            let actualSizeGB = fileSize / (1024 * 1024 * 1024)
            return ValidationResult.failure(
                errorMessage: "File size (\(actualSizeGB)GB) exceeds maximum allowed size (\(maxSizeGB)GB)",
                fileSize: fileSize,
                fileType: fileExtension,
                mimeType: mimeType
            )
        }
        
        // For pod content, also validate duration (1 hour limit)
        if category == .podContent {
            let durationValidation = await validateDuration(fileURL: fileURL, fileExtension: fileExtension)
            if !durationValidation.isValid {
                return ValidationResult.failure(
                    errorMessage: durationValidation.errorMessage ?? "Duration validation failed",
                    fileSize: fileSize,
                    fileType: fileExtension,
                    mimeType: mimeType
                )
            }
        }
        
        // Validate file extension
        if !category.allowedExtensions.contains(fileExtension) {
            let allowedList = category.allowedExtensions.joined(separator: ", ")
            return ValidationResult.failure(
                errorMessage: "File type '\(fileExtension)' is not allowed. Allowed types: \(allowedList)",
                fileSize: fileSize,
                fileType: fileExtension,
                mimeType: mimeType
            )
        }
        
        // Validate MIME type if available
        if let mimeType = mimeType, !category.allowedMimeTypes.contains(mimeType) {
            let allowedList = category.allowedMimeTypes.joined(separator: ", ")
            return ValidationResult.failure(
                errorMessage: "File MIME type '\(mimeType)' is not allowed. Allowed types: \(allowedList)",
                fileSize: fileSize,
                fileType: fileExtension,
                mimeType: mimeType
            )
        }
        
        // Additional validation for specific file types
        let contentValidation = await validateFileContent(fileURL: fileURL, fileExtension: fileExtension, category: category)
        if !contentValidation.isValid {
            // For iCloud files, be more lenient and retry once
            if isICloudFile && contentValidation.errorMessage?.contains("Unable to load") == true {
                print("☁️ FileValidator: iCloud file validation failed, waiting 2 seconds and retrying...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
                
                let retryValidation = await validateFileContent(fileURL: fileURL, fileExtension: fileExtension, category: category)
                if !retryValidation.isValid {
                    print("☁️ FileValidator: Retry validation also failed: \(retryValidation.errorMessage ?? "Unknown error")")
                    
                    // Don't release access yet - let the upload process handle cleanup
                    if isICloudFile {
                        print("🔐 FileValidator: Keeping security-scoped resource access despite validation failure")
                    }
                    
                    return retryValidation
                } else {
                    print("☁️ FileValidator: Retry validation successful!")
                }
            } else {
                // Don't release access yet - let the upload process handle cleanup
                if isICloudFile {
                    print("🔐 FileValidator: Keeping security-scoped resource access despite validation failure")
                }
                
                return contentValidation
            }
        }
        
        print("✅ FileValidator: All validation passed successfully!")
        
        // Don't release security-scoped resource access yet - let the upload process handle it
        if isICloudFile {
            print("🔐 FileValidator: Keeping security-scoped resource access for upload process")
        }
        
        return ValidationResult.success(fileSize: fileSize, fileType: fileExtension, mimeType: mimeType)
    }
    
    /// Validates a UIImage for profile/thumbnail uploads
    /// - Parameters:
    ///   - image: The UIImage to validate
    ///   - category: The file category (should be .profileImage or .thumbnail)
    /// - Returns: ValidationResult indicating if the image is valid
    static func validate(image: UIImage, for category: FileCategory) -> ValidationResult {
        guard category == .profileImage || category == .thumbnail else {
            return ValidationResult.failure(
                errorMessage: "Invalid category for image validation",
                fileSize: 0,
                fileType: "image",
                mimeType: nil
            )
        }
        
        // No more dimension restrictions - allow any image size!
        // Only check if image has content and is valid
        
        // Check if image has content
        guard image.cgImage != nil || image.ciImage != nil else {
            return ValidationResult.failure(
                errorMessage: "Invalid image format or corrupted image",
                fileSize: 0,
                fileType: "image",
                mimeType: nil
            )
        }
        
        return ValidationResult.success(fileSize: 0, fileType: "image", mimeType: "image/jpeg")
    }
    
    // MARK: - Helper Methods
    
    /// Requests file access permissions for security-scoped URLs
    private static func requestFileAccess(for url: URL) async -> Bool {
        print("🔐 FileValidator: Requesting file access for: \(url)")
        
        // Check if this is a security-scoped URL that needs access
        if url.startAccessingSecurityScopedResource() {
            print("🔐 FileValidator: Security-scoped resource access granted")
            return true
        }
        
        // For regular URLs, try to access them directly
        print("🔐 FileValidator: Regular URL, attempting direct access")
        return true
    }
    
    /// Validates file duration (1 hour limit for pod content)
    private static func validateDuration(fileURL: URL, fileExtension: String) async -> ValidationResult {
        let isMediaFile = ["mp4", "mov", "avi", "mkv", "m4v", "mpeg", "mpg", "3gp", "webm", "mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus"].contains(fileExtension)
        
        guard isMediaFile else {
            return ValidationResult.success(fileSize: 0, fileType: fileExtension, mimeType: nil)
        }
        
        do {
            let asset = AVAsset(url: fileURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            // 1 hour = 3600 seconds
            let maxDuration: Double = 3600
            
            if durationSeconds > maxDuration {
                let hours = Int(durationSeconds / 3600)
                let minutes = Int((durationSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
                let seconds = Int(durationSeconds.truncatingRemainder(dividingBy: 60))
                
                let durationString = hours > 0 ? "\(hours)h \(minutes)m \(seconds)s" : "\(minutes)m \(seconds)s"
                
                return ValidationResult.failure(
                    errorMessage: "File duration (\(durationString)) exceeds maximum allowed duration (1 hour)",
                    fileSize: 0,
                    fileType: fileExtension,
                    mimeType: nil
                )
            }
            
            return ValidationResult.success(fileSize: 0, fileType: fileExtension, mimeType: nil)
        } catch {
            print("⚠️ FileValidator: Could not read file duration: \(error)")
            // If we can't read duration, allow the file (it will be caught later if there's an issue)
            return ValidationResult.success(fileSize: 0, fileType: fileExtension, mimeType: nil)
        }
    }
    
    /// Releases file access permissions for security-scoped URLs
    static func releaseFileAccess(for url: URL) {
        print("🔐 FileValidator: Releasing file access for: \(url)")
        url.stopAccessingSecurityScopedResource()
        print("🔐 FileValidator: Security-scoped resource access released")
    }
    
    /// Gets MIME type for a file extension
    private static func getMimeType(for fileExtension: String) -> String? {
        let mimeTypes: [String: String] = [
            // Images
            "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "heic": "image/heic", "heif": "image/heif",
            
            // Videos
            "mp4": "video/mp4", "mov": "video/quicktime", "avi": "video/x-msvideo",
            "mkv": "video/x-matroska", "m4v": "video/x-m4v", "mpeg": "video/mpeg",
            "mpg": "video/mpeg", "3gp": "video/3gpp", "webm": "video/webm",
            
            // Audio
            "mp3": "audio/mpeg", "wav": "audio/wav", "m4a": "audio/mp4",
            "aac": "audio/aac", "flac": "audio/flac", "mp2": "audio/mpeg",
            "wma": "audio/x-ms-wma", "ogg": "audio/ogg", "opus": "audio/opus",
            
            // Documents
            "json": "application/json", "csv": "text/csv", "txt": "text/plain",
            "pdf": "application/pdf"
        ]
        
        return mimeTypes[fileExtension.lowercased()]
    }
    
    /// Validates file content for additional security checks
    private static func validateFileContent(fileURL: URL, fileExtension: String, category: FileCategory) async -> ValidationResult {
        // For images, check if they can be loaded
        if category == .profileImage || category == .thumbnail {
            if let image = UIImage(contentsOfFile: fileURL.path) {
                return validate(image: image, for: category)
            } else {
                return ValidationResult.failure(
                    errorMessage: "Unable to load image file",
                    fileSize: 0,
                    fileType: fileExtension,
                    mimeType: getMimeType(for: fileExtension)
                )
            }
        }
        
        // For videos, check if they can be loaded
        if category == .podContent && ["mp4", "mov", "avi", "mkv", "m4v", "mpeg", "mpg", "3gp", "webm"].contains(fileExtension) {
            print("🎥 FileValidator: Validating video file...")
            let asset = AVAsset(url: fileURL)
            
            // Use modern async approach for iOS 16+ compatibility
            if #available(iOS 16.0, *) {
                do {
                    let tracks = try await asset.load(.tracks)
                    print("🎥 FileValidator: Video tracks loaded: \(tracks.count)")
                    if tracks.isEmpty {
                        print("❌ FileValidator: No video tracks found")
                        return ValidationResult.failure(
                            errorMessage: "Unable to load video file or corrupted video",
                            fileSize: 0,
                            fileType: fileExtension,
                            mimeType: getMimeType(for: fileExtension)
                        )
                    }
                } catch {
                    print("❌ FileValidator: Error loading video tracks: \(error)")
                    // For iCloud files, be more lenient with validation errors
                    if fileURL.scheme?.contains("icloud") == true {
                        print("☁️ FileValidator: iCloud file validation error, but continuing...")
                        // Don't fail for iCloud files that might still be downloading
                    } else {
                        return ValidationResult.failure(
                            errorMessage: "Unable to load video file: \(error.localizedDescription)",
                            fileSize: 0,
                            fileType: fileExtension,
                            mimeType: getMimeType(for: fileExtension)
                        )
                    }
                }
            } else {
                // Fallback for iOS 15 and earlier
                let tracks = asset.tracks
                print("🎥 FileValidator: Video tracks (legacy): \(tracks.count)")
                if tracks.isEmpty {
                    print("❌ FileValidator: No video tracks found (legacy)")
                    return ValidationResult.failure(
                        errorMessage: "Unable to load video file or corrupted video",
                        fileSize: 0,
                        fileType: fileExtension,
                        mimeType: getMimeType(for: fileExtension)
                    )
                }
            }
        }
        
        // For audio, check if they can be loaded
        if category == .podContent && ["mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus"].contains(fileExtension) {
            let asset = AVAsset(url: fileURL)
            // Use modern async approach for iOS 16+ compatibility
            if #available(iOS 16.0, *) {
                do {
                    let tracks = try await asset.load(.tracks)
                    if tracks.isEmpty {
                        return ValidationResult.failure(
                            errorMessage: "Unable to load audio file or corrupted audio",
                            fileSize: 0,
                            fileType: fileExtension,
                            mimeType: getMimeType(for: fileExtension)
                        )
                    }
                } catch {
                    return ValidationResult.failure(
                        errorMessage: "Unable to load audio file: \(error.localizedDescription)",
                        fileSize: 0,
                        fileType: fileExtension,
                        mimeType: getMimeType(for: fileExtension)
                    )
                }
            } else {
                // Fallback for iOS 15 and earlier
                if asset.tracks.isEmpty {
                    return ValidationResult.failure(
                        errorMessage: "Unable to load audio file or corrupted audio",
                        fileSize: 0,
                        fileType: fileExtension,
                        mimeType: getMimeType(for: fileExtension)
                    )
                }
            }
        }
        
        return ValidationResult.success(fileSize: 0, fileType: fileExtension, mimeType: getMimeType(for: fileExtension))
    }
    
    // MARK: - Utility Methods
    
    /// Formats file size in human-readable format
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Checks if a file is potentially malicious based on extension
    static func isPotentiallyMalicious(fileExtension: String) -> Bool {
        let dangerousExtensions = [
            "exe", "bat", "cmd", "com", "pif", "scr", "vbs", "js", "jar",
            "app", "dmg", "pkg", "deb", "rpm", "msi", "ps1", "sh", "py"
        ]
        return dangerousExtensions.contains(fileExtension.lowercased())
    }
    
    /// Gets a list of all supported file types for a category
    static func getSupportedFileTypes(for category: FileCategory) -> [String] {
        return category.allowedExtensions
    }
    
    // MARK: - Audio Metadata Extraction
    
    /// Extracts metadata from an audio file URL
    /// - Parameter fileURL: The URL of the audio file
    /// - Returns: A tuple containing duration, fileSize, and mimeType
    static func extractAudioMetadata(from fileURL: URL) async -> (duration: TimeInterval?, fileSize: Int64?, mimeType: String?) {
        print("🎵 FileValidator: Extracting audio metadata from: \(fileURL.lastPathComponent)")
        
        // Get file size
        let fileSize = getFileSize(from: fileURL)
        
        // Get MIME type
        let fileExtension = fileURL.pathExtension.lowercased()
        let mimeType = getMimeType(for: fileExtension)
        
        // Get duration using AVAsset (works for both audio and video)
        var duration: TimeInterval? = nil
        
        let supportedExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus", 
                                 "mp4", "mov", "avi", "mkv", "m4v", "mpeg", "mpg", "3gp", "webm"]
        
        if supportedExtensions.contains(fileExtension) {
            let asset = AVAsset(url: fileURL)
            
            do {
                if #available(iOS 16.0, *) {
                    // Modern async approach for iOS 16+
                    let durationValue = try await asset.load(.duration)
                    duration = CMTimeGetSeconds(durationValue)
                } else {
                    // Fallback for iOS 15 and earlier
                    duration = CMTimeGetSeconds(asset.duration)
                }
                
                // Check if duration is valid
                if let durationValue = duration, durationValue.isFinite && durationValue > 0 {
                    print("🎵 FileValidator: Media duration: \(durationValue) seconds")
                } else {
                    print("⚠️ FileValidator: Invalid or zero duration")
                    duration = nil
                }
            } catch {
                print("❌ FileValidator: Error loading media duration: \(error.localizedDescription)")
                duration = nil
            }
        }
        
        print("🎵 FileValidator: Metadata extracted - Duration: \(duration?.description ?? "nil"), Size: \(fileSize ?? 0) bytes, MIME: \(mimeType ?? "nil")")
        
        return (duration: duration, fileSize: fileSize, mimeType: mimeType)
    }
    
    /// Helper function to get file size from URL
    private static func getFileSize(from fileURL: URL) -> Int64? {
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            print("⚠️ FileValidator: Could not get file size: \(error.localizedDescription)")
            return nil
        }
    }
}
