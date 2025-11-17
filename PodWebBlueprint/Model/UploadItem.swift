//
//  UploadItem.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/15/25.
//

import Foundation
import SwiftUI // For UIImage

struct UploadItem: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let fileUrl: URL // Local URL of the file
    let fileSize: Int64
    let podTitle: String
    let podDescription: String
    let tags: [String]
    let thumbnailImage: Data? // UIImage converted to Data
    let source: VideoSource
    let userId: String
    
    var progress: Double
    var status: UploadStatus
    var errorMessage: String?
    var uploadedThumbnailUrl: String?
    var uploadedFileUrl: String?
    var startTime: Date
    var lastUpdated: Date
    var retryCount: Int
    
    // Compression progress
    var compressionProgress: Double
    var isCompressing: Bool
    var compressedFileUrl: URL?
    
    // Upload speed tracking
    var uploadSpeed: Double // MB/s
    var estimatedTimeRemaining: TimeInterval // seconds
    var lastProgressUpdate: Date
    
    // Multipart upload state (for resumable uploads)
    var multipartUploadId: String?
    var uploadedParts: [Int: String] // partNumber -> ETag
    var currentPartNumber: Int
    var partSize: Int
    
    init(id: UUID = UUID(), fileName: String, fileUrl: URL, fileSize: Int64, podTitle: String, podDescription: String, tags: [String], thumbnailImage: UIImage?, source: VideoSource, user: User) {
        self.id = id
        self.fileName = fileName
        self.fileUrl = fileUrl
        self.fileSize = fileSize
        self.podTitle = podTitle
        self.podDescription = podDescription
        self.tags = tags
        self.thumbnailImage = thumbnailImage?.jpegData(compressionQuality: 0.8)
        self.source = source
        self.userId = user.uid
        self.progress = 0.0
        self.status = .pending
        self.startTime = Date()
        self.lastUpdated = Date()
        self.retryCount = 0
        self.compressionProgress = 0.0
        self.isCompressing = false
        self.compressedFileUrl = nil
        self.uploadSpeed = 0.0
        self.estimatedTimeRemaining = 0.0
        self.lastProgressUpdate = Date()
        self.multipartUploadId = nil
        self.uploadedParts = [:]
        self.currentPartNumber = 1
        self.partSize = 8 * 1024 * 1024 // 8 MB default part size
    }
    
    // Computed properties
    var isCompleted: Bool {
        return status == .completed
    }
    
    var isFailed: Bool {
        return status == .failed
    }
    
    var isUploading: Bool {
        return status == .uploading
    }
    
    var duration: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedUploadSpeed: String {
        if uploadSpeed > 0 {
            return String(format: "%.1f MB/s", uploadSpeed)
        } else {
            return "Calculating..."
        }
    }
    
    var formattedETA: String {
        if estimatedTimeRemaining > 0 {
            let minutes = Int(estimatedTimeRemaining) / 60
            let seconds = Int(estimatedTimeRemaining) % 60
            
            if minutes > 0 {
                return "\(minutes)m \(seconds)s left"
            } else {
                return "\(seconds)s left"
            }
        } else {
            return "Calculating..."
        }
    }
}

enum UploadStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case uploading = "uploading"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .uploading:
            return "Uploading"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var systemImage: String {
        switch self {
        case .pending:
            return "clock"
        case .uploading:
            return "arrow.up.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "minus.circle.fill"
        }
    }
}

enum VideoSource: String, Codable, CaseIterable {
    case photosPicker = "photosPicker"
    case filesApp = "filesApp"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .photosPicker:
            return "Camera Roll"
        case .filesApp:
            return "Files"
        case .unknown:
            return "Unknown"
        }
    }
}
